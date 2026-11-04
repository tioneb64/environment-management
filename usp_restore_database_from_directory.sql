USE [master]
GO

/****** Object:  StoredProcedure [dbo].[usp_restore_database_from_directory]    Script Date: 04/11/2026 23:23:18 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

	CREATE PROCEDURE [dbo].[usp_restore_database_from_directory]
	@backup_directory nvarchar(255)
	,@restored_dbname sysname
	,@data_directory nvarchar(255) = NULL
	,@log_directory nvarchar(255) = NULL
	,@original_dbname sysname = NULL
	,@stop_at_time datetime = NULL
	,@only_generate_restore_script bit = 0
	,@new_owner                    sysname = NULL
	,@auto_fix_orphaned_users      bit = 0
	,@pre_restore_script           nvarchar(max) = NULL 
	,@post_restore_script          nvarchar(max) = NULL 
	,@old_path_part                nvarchar(255) = NULL 
	,@new_path_part                nvarchar(255) = NULL
	,@recovery					   tinyint = 0
	AS 
	BEGIN 
	DECLARE @major_product_version tinyint 
	DECLARE @backup_media nvarchar(max) 
	DECLARE @stmt nvarchar(max) 
	DECLARE @cmd VARCHAR(8000) 
	DECLARE @full_backup_Position smallint 
	DECLARE @differential_backup_Position smallint 
	DECLARE @move_data_files_script nvarchar(max) 
	DECLARE @move_log_files_script nvarchar(max) 
	DECLARE @binding_id uniqueidentifier 
	DECLARE @last_log_backup_start_date datetime 
	DECLARE @first_log_backup_start_date datetime 
	DECLARE @max_row_id int 
	DECLARE @orphaned_user sysname 

	SET nocount ON 

	IF Ltrim(Rtrim(@backup_directory)) = N'' 
	BEGIN 
	SET @backup_directory = NULL; 
	END; 

	IF Ltrim(Rtrim(@restored_dbname)) = N'' 
	BEGIN 
	SET @restored_dbname = NULL; 
	END; 

	IF Ltrim(Rtrim(@data_directory)) = N'' 
	BEGIN 
	SET @data_directory = NULL; 
	END; 

	IF Ltrim(Rtrim(@log_directory)) = N'' 
	BEGIN 
	SET @log_directory = NULL; 
	END; 

	IF Ltrim(Rtrim(@original_dbname)) = N'' 
	BEGIN 
	SET @original_dbname = NULL; 
	END; 

	IF Ltrim(Rtrim(@new_owner)) = N'' 
	BEGIN 
	SET @new_owner = NULL; 
	END; 

	IF Ltrim(Rtrim(@pre_restore_script)) = N'' 
	BEGIN 
	SET @pre_restore_script = NULL; 
	END; 

	IF Ltrim(Rtrim(@post_restore_script)) = N'' 
	BEGIN 
	SET @post_restore_script = NULL; 
	END; 

	------------------------------------------------------------------------ 
	--Execute the pre-restore script 
	------------------------------------------------------------------------ 
	IF ( @pre_restore_script IS NOT NULL 
	AND @only_generate_restore_script = 0 ) 
	BEGIN 
	PRint @pre_restore_script 

	EXECUTE AS login = 'sa'; 

	EXEC(@pre_restore_script); 

	REVERT; 
	END; 

	------------------------------------------------------------------------ 
	------------------------------------------------------------------------ 
	--Initializations 
	------------------------------------------------------------------------ 
	SELECT @major_product_version = Cast(Substring(Cast(Serverproperty( 
	'ProductVersion') AS 
		  nvarchar(14)), 
	1, 
	Charindex('.', Cast( 
	Serverproperty( 
	'ProductVersion') 
	AS 
	nvarchar(14)), 
	Charindex 
	   ( 
	   '.', Cast( 
	Serverproperty('ProductVersion') AS 
	nvarchar 
	(14))) 
		  + 1) 
	- 1) 
	AS FLOAT 
	) 

	IF @stop_at_time IS NULL 
	BEGIN 
	SET @stop_at_time = Getdate(); 
	END; 

	IF @data_directory IS NULL 
	BEGIN 
		BEGIN TRY
			EXEC master.dbo.xp_instance_regread 
			N'HKEY_LOCAL_MACHINE', 
			N'Software\Microsoft\MSSQLServer\MSSQLServer', 
			N'DefaultData', 
			@data_directory output; 
		END TRY
		BEGIN CATCH
		END CATCH

		IF @data_directory IS NULL 
		BEGIN 
			BEGIN TRY
				EXEC master.dbo.xp_instance_regread 
				N'HKEY_LOCAL_MACHINE', 
				N'Software\Microsoft\MSSQLServer\Setup', 
				N'SQLDataRoot', 
				@data_directory output; 	
			END TRY
			BEGIN CATCH
			END CATCH
		END; 
	END; 

	IF @log_directory IS NULL 
	BEGIN 
		BEGIN TRY
			EXEC master.dbo.xp_instance_regread 
			N'HKEY_LOCAL_MACHINE', 
			N'Software\Microsoft\MSSQLServer\MSSQLServer', 
			N'DefaultLog', 
			@log_directory output; 
		END TRY
		BEGIN CATCH
		END CATCH
	END; 

	SET @log_directory = Isnull(@log_directory, @data_directory);

	------------------------------------------------------------------------ 
	------------------------------------------------------------------------ 
	--Lists the .BAK and .TRN files within the backup directory and stores the result in a temporary table
	------------------------------------------------------------------------ 
	IF Object_id('tempdb.dbo.#BackupMedium') IS NOT NULL 
	DROP TABLE #backupmedium 

	SET @cmd = 'DIR /B ' + @backup_directory; 

	CREATE TABLE #backupmedium 
	( 
	backup_medium nvarchar(255) NULL 
	); 

	INSERT INTO #backupmedium 
	EXEC master..xp_cmdshell 
	@cmd; 

	DELETE FROM #backupmedium 
	WHERE 
	/*NOT(backup_medium LIKE N'%.TRN' OR backup_medium LIKE N'%.BAK') OR*/ 
	backup_medium IS NULL; 

	------------------------------------------------------------------------ 
	------------------------------------------------------------------------ 
	--Lists the content of the backup medium and stores the result in a temporary table 
	------------------------------------------------------------------------ 
	IF Object_id('tempdb.dbo.#completebackupheader') IS NOT NULL 
	BEGIN 
	DROP TABLE #completebackupheader; 
	END; 

	CREATE TABLE #completebackupheader 
	( 
	BackupMedia            nvarchar(max), 
	BackupName             nvarchar(128), 
	BackupDescription      nvarchar(255), 
	BackupType             smallint, 
	ExpirationDate         datetime, 
	Compressed             tinyint, 
	Position               smallint, 
	DeviceType             tinyint, 
	UserName               nvarchar(128), 
	ServerName             nvarchar(128), 
	DatabaseName           nvarchar(128), 
	DatabaseVersion        int, 
	DatabaseCreationDate   datetime, 
	BackupSize             numeric(20, 0), 
	FirstLSN               numeric(25, 0), 
	LastLSN                numeric(25, 0), 
	CheckpointLSN          numeric(25, 0), 
	DatabaseBackupLSN      numeric(25, 0), 
	BackupStartDate        datetime, 
	BackupFinishDate       datetime, 
	SortOrder              smallint, 
	CodePage               smallint, 
	UnicodeLocaleId        int, 
	UnicodeComparisonStyle int, 
	CompatibilityLevel     tinyint, 
	SoftwareVendorId       int, 
	SoftwareVersionMajor   int, 
	SoftwareVersionMinor   int, 
	SoftwareVersionBuild   int, 
	MachineName            nvarchar(128), 
	Flags                  int, 
	BindingId              uniqueidentifier, 
	RecoveryForkId         uniqueidentifier, 
	Collation              nvarchar(128), 
	FamilyGUID             uniqueidentifier, 
	HasBulkLoggedData      bit, 
	IsSnapshot             bit, 
	IsReadOnly             bit, 
	IsSingleUser           bit, 
	HasBackupChecksums     bit, 
	IsDamaged              bit, 
	BeginsLogChain         bit, 
	HasIncompleteMetadata  bit, 
	IsForceOffline         bit, 
	IsCopyOnly             bit, 
	FirstRecoveryForkId    uniqueidentifier, 
	ForkPointLSN           numeric(25, 0), 
	RecoveryModel          nvarchar(60), 
	DifferentialBaseLSN    numeric(25, 0), 
	DifferentialBaseGUID   uniqueidentifier, 
	BackupTypeDescription  nvarchar(60), 
	BackupsetGUID          uniqueidentifier, 
	CompressedBackupSize   numeric(20, 0) 
	); 

	IF( @@ERROR <> 0 ) 
	BEGIN 
	RAISERROR (N'ERROR CREATE temporary table CompleteBackupHeader.',11, 
	1) 
	WITH 
	log; 
	END; 

	IF Object_id('tempdb.dbo.#BackupHeader') IS NOT NULL 
	BEGIN 
	DROP TABLE #backupheader; 
	END; 

	IF ((@major_product_version = 11) OR (CAST(Serverproperty('ProductVersion') AS nvarchar(14)) = '12.0.2000.8') OR (CAST(Serverproperty('ProductVersion') AS nvarchar(14)) LIKE '12.0.22%')) 
	BEGIN 
		IF Object_id('tempdb.dbo.#backupheaderv11') IS NOT NULL 
		BEGIN 
			DROP TABLE #backupheaderv11; 
		END;
		
		CREATE TABLE #backupheaderv11 
		( 
			BackupName             nvarchar(128), 
			BackupDescription      nvarchar(255), 
			BackupType             smallint, 
			ExpirationDate         datetime, 
			Compressed             tinyint, 
			Position               smallint, 
			DeviceType             tinyint, 
			UserName               nvarchar(128), 
			ServerName             nvarchar(128), 
			DatabaseName           nvarchar(128), 
			DatabaseVersion        int, 
			DatabaseCreationDate   datetime, 
			BackupSize             numeric(20, 0), 
			FirstLSN               numeric(25, 0), 
			LastLSN                numeric(25, 0), 
			CheckpointLSN          numeric(25, 0), 
			DatabaseBackupLSN      numeric(25, 0), 
			BackupStartDate        datetime, 
			BackupFinishDate       datetime, 
			SortOrder              smallint, 
			CodePage               smallint, 
			UnicodeLocaleId        int, 
			UnicodeComparisonStyle int, 
			CompatibilityLevel     tinyint, 
			SoftwareVendorId       int, 
			SoftwareVersionMajor   int, 
			SoftwareVersionMinor   int, 
			SoftwareVersionBuild   int, 
			MachineName            nvarchar(128), 
			Flags                  int, 
			BindingId              uniqueidentifier, 
			RecoveryForkId         uniqueidentifier, 
			Collation              nvarchar(128), 
			FamilyGUID             uniqueidentifier, 
			HasBulkLoggedData      bit, 
			IsSnapshot             bit, 
			IsReadOnly             bit, 
			IsSingleUser           bit, 
			HasBackupChecksums     bit, 
			IsDamaged              bit, 
			BeginsLogChain         bit, 
			HasIncompleteMetadata  bit, 
			IsForceOffline         bit, 
			IsCopyOnly             bit, 
			FirstRecoveryForkId    uniqueidentifier, 
			ForkPointLSN           numeric(25, 0), 
			RecoveryModel          nvarchar(60), 
			DifferentialBaseLSN    numeric(25, 0), 
			DifferentialBaseGUID   uniqueidentifier, 
			BackupTypeDescription  nvarchar(60), 
			BackupsetGUID          uniqueidentifier, 
			CompressedBackupSize   numeric(20, 0), 
			containment            tinyint 
		); 
	END; 

	IF ((@major_product_version >= 12) AND (@major_product_version < 16) AND (CAST(Serverproperty('ProductVersion') AS nvarchar(14)) <> '12.0.2000.8') AND (CAST(Serverproperty('ProductVersion') AS nvarchar(14)) NOT LIKE '12.0.22%')) 
	BEGIN 
		IF Object_id('tempdb.dbo.#backupheaderv12') IS NOT NULL 
		BEGIN 
			DROP TABLE #backupheaderv12; 
		END;
		
		CREATE TABLE #backupheaderv12
		( 
			BackupName             nvarchar(128), 
			BackupDescription      nvarchar(255), 
			BackupType             smallint, 
			ExpirationDate         datetime, 
			Compressed             tinyint, 
			Position               smallint, 
			DeviceType             tinyint, 
			UserName               nvarchar(128), 
			ServerName             nvarchar(128), 
			DatabaseName           nvarchar(128), 
			DatabaseVersion        int, 
			DatabaseCreationDate   datetime, 
			BackupSize             numeric(20, 0), 
			FirstLSN               numeric(25, 0), 
			LastLSN                numeric(25, 0), 
			CheckpointLSN          numeric(25, 0), 
			DatabaseBackupLSN      numeric(25, 0), 
			BackupStartDate        datetime, 
			BackupFinishDate       datetime, 
			SortOrder              smallint, 
			CodePage               smallint, 
			UnicodeLocaleId        int, 
			UnicodeComparisonStyle int, 
			CompatibilityLevel     tinyint, 
			SoftwareVendorId       int, 
			SoftwareVersionMajor   int, 
			SoftwareVersionMinor   int, 
			SoftwareVersionBuild   int, 
			MachineName            nvarchar(128), 
			Flags                  int, 
			BindingId              uniqueidentifier, 
			RecoveryForkId         uniqueidentifier, 
			Collation              nvarchar(128), 
			FamilyGUID             uniqueidentifier, 
			HasBulkLoggedData      bit, 
			IsSnapshot             bit, 
			IsReadOnly             bit, 
			IsSingleUser           bit, 
			HasBackupChecksums     bit, 
			IsDamaged              bit, 
			BeginsLogChain         bit, 
			HasIncompleteMetadata  bit, 
			IsForceOffline         bit, 
			IsCopyOnly             bit, 
			FirstRecoveryForkId    uniqueidentifier, 
			ForkPointLSN           numeric(25, 0), 
			RecoveryModel          nvarchar(60), 
			DifferentialBaseLSN    numeric(25, 0), 
			DifferentialBaseGUID   uniqueidentifier, 
			BackupTypeDescription  nvarchar(60), 
			BackupsetGUID          uniqueidentifier, 
			CompressedBackupSize   numeric(20, 0), 
			containment            tinyint,
			KeyAlgorithm           nvarchar(32),
			EncryptorThumbprint    varbinary(20),
			EncryptorType          nvarchar(32)
		); 
	END; 

	IF (@major_product_version >= 16)
	BEGIN 
		IF Object_id('tempdb.dbo.#backupheaderv16') IS NOT NULL 
		BEGIN 
			DROP TABLE #backupheaderv16; 
		END;
		
		CREATE TABLE #backupheaderv16
		( 
			BackupName             nvarchar(128), 
			BackupDescription      nvarchar(255), 
			BackupType             smallint, 
			ExpirationDate         datetime, 
			Compressed             tinyint, 
			Position               smallint, 
			DeviceType             tinyint, 
			UserName               nvarchar(128), 
			ServerName             nvarchar(128), 
			DatabaseName           nvarchar(128), 
			DatabaseVersion        int, 
			DatabaseCreationDate   datetime, 
			BackupSize             numeric(20, 0), 
			FirstLSN               numeric(25, 0), 
			LastLSN                numeric(25, 0), 
			CheckpointLSN          numeric(25, 0), 
			DatabaseBackupLSN      numeric(25, 0), 
			BackupStartDate        datetime, 
			BackupFinishDate       datetime, 
			SortOrder              smallint, 
			CodePage               smallint, 
			UnicodeLocaleId        int, 
			UnicodeComparisonStyle int, 
			CompatibilityLevel     tinyint, 
			SoftwareVendorId       int, 
			SoftwareVersionMajor   int, 
			SoftwareVersionMinor   int, 
			SoftwareVersionBuild   int, 
			MachineName            nvarchar(128), 
			Flags                  int, 
			BindingId              uniqueidentifier, 
			RecoveryForkId         uniqueidentifier, 
			Collation              nvarchar(128), 
			FamilyGUID             uniqueidentifier, 
			HasBulkLoggedData      bit, 
			IsSnapshot             bit, 
			IsReadOnly             bit, 
			IsSingleUser           bit, 
			HasBackupChecksums     bit, 
			IsDamaged              bit, 
			BeginsLogChain         bit, 
			HasIncompleteMetadata  bit, 
			IsForceOffline         bit, 
			IsCopyOnly             bit, 
			FirstRecoveryForkId    uniqueidentifier, 
			ForkPointLSN           numeric(25, 0), 
			RecoveryModel          nvarchar(60), 
			DifferentialBaseLSN    numeric(25, 0), 
			DifferentialBaseGUID   uniqueidentifier, 
			BackupTypeDescription  nvarchar(60), 
			BackupsetGUID          uniqueidentifier, 
			CompressedBackupSize   numeric(20, 0), 
			containment            tinyint,
			KeyAlgorithm           nvarchar(32),
			EncryptorThumbprint    varbinary(20),
			EncryptorType          nvarchar(32),
			LastValidRestoreTime   datetime,
			TimeZone               nvarchar(32),
			CompressionAlgorithm   nvarchar(32)
		); 
	END; 

	IF Object_id('tempdb.dbo.#backupheader') IS NOT NULL 
	BEGIN 
		DROP TABLE #backupheader; 
	END;
		
	CREATE TABLE #backupheader 
	( 
	BackupName             nvarchar(128), 
	BackupDescription      nvarchar(255), 
	BackupType             smallint, 
	ExpirationDate         datetime, 
	Compressed             tinyint, 
	Position               smallint, 
	DeviceType             tinyint, 
	UserName               nvarchar(128), 
	ServerName             nvarchar(128), 
	DatabaseName           nvarchar(128), 
	DatabaseVersion        int, 
	DatabaseCreationDate   datetime, 
	BackupSize             numeric(20, 0), 
	FirstLSN               numeric(25, 0), 
	LastLSN                numeric(25, 0), 
	CheckpointLSN          numeric(25, 0), 
	DatabaseBackupLSN      numeric(25, 0), 
	BackupStartDate        datetime, 
	BackupFinishDate       datetime, 
	SortOrder              smallint, 
	CodePage               smallint, 
	UnicodeLocaleId        int, 
	UnicodeComparisonStyle int, 
	CompatibilityLevel     tinyint, 
	SoftwareVendorId       int, 
	SoftwareVersionMajor   int, 
	SoftwareVersionMinor   int, 
	SoftwareVersionBuild   int, 
	MachineName            nvarchar(128), 
	Flags                  int, 
	BindingId              uniqueidentifier, 
	RecoveryForkId         uniqueidentifier, 
	Collation              nvarchar(128), 
	FamilyGUID             uniqueidentifier, 
	HasBulkLoggedData      bit, 
	IsSnapshot             bit, 
	IsReadOnly             bit, 
	IsSingleUser           bit, 
	HasBackupChecksums     bit, 
	IsDamaged              bit, 
	BeginsLogChain         bit, 
	HasIncompleteMetadata  bit, 
	IsForceOffline         bit, 
	IsCopyOnly             bit, 
	FirstRecoveryForkId    uniqueidentifier, 
	ForkPointLSN           numeric(25, 0), 
	RecoveryModel          nvarchar(60), 
	DifferentialBaseLSN    numeric(25, 0), 
	DifferentialBaseGUID   uniqueidentifier, 
	BackupTypeDescription  nvarchar(60), 
	BackupsetGUID          uniqueidentifier, 
	CompressedBackupSize   numeric(20, 0) 
	); 

	IF( @@ERROR <> 0 ) 
	BEGIN 
	RAISERROR (N'ERROR CREATE temporary table BackupHeader.',11,1) WITH 
	log; 
	END; 

	DECLARE c_backup_medium CURSOR fast_forward FOR 
	SELECT @backup_directory + N'\' + bm.backup_medium 
	FROM   #backupmedium bm; 

	OPEN c_backup_medium; 

	FETCH next FROM c_backup_medium INTO @backup_media; 

	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		IF ((@major_product_version = 11) OR (CAST(Serverproperty('ProductVersion') AS nvarchar(14)) = '12.0.2000.8') OR (CAST(Serverproperty('ProductVersion') AS nvarchar(14)) LIKE '12.0.22%')) 
		BEGIN 
			TRUNCATE TABLE #backupheaderv11; 

			INSERT INTO #backupheaderv11 
			EXEC ('RESTORE HEADERONLY FROM DISK=''' + @backup_media + '''' 
			); 

			INSERT INTO #backupheader 
			(
				BackupName, 
				BackupDescription, 
				BackupType, 
				ExpirationDate, 
				Compressed, 
				Position, 
				DeviceType, 
				UserName, 
				ServerName, 
				DatabaseName, 
				DatabaseVersion, 
				DatabaseCreationDate, 
				BackupSize, 
				FirstLSN, 
				LastLSN, 
				CheckpointLSN, 
				DatabaseBackupLSN, 
				BackupStartDate, 
				BackupFinishDate, 
				SortOrder, 
				CodePage, 
				UnicodeLocaleId, 
				UnicodeComparisonStyle, 
				CompatibilityLevel, 
				SoftwareVendorId, 
				SoftwareVersionMajor, 
				SoftwareVersionMinor, 
				SoftwareVersionBuild, 
				MachineName, 
				Flags, 
				BindingId, 
				RecoveryForkId, 
				Collation, 
				FamilyGUID, 
				HasBulkLoggedData, 
				IsSnapshot, 
				IsReadOnly, 
				IsSingleUser, 
				HasBackupChecksums, 
				IsDamaged, 
				BeginsLogChain, 
				HasIncompleteMetadata, 
				IsForceOffline, 
				IsCopyOnly, 
				FirstRecoveryForkId, 
				ForkPointLSN, 
				RecoveryModel, 
				DifferentialBaseLSN, 
				DifferentialBaseGUID, 
				BackupTypeDescription, 
				BackupsetGUID, 
				CompressedBackupSize
			) 
			SELECT
				BackupName, 
				BackupDescription, 
				BackupType, 
				ExpirationDate, 
				Compressed, 
				Position, 
				DeviceType, 
				UserName, 
				ServerName, 
				DatabaseName, 
				DatabaseVersion, 
				DatabaseCreationDate, 
				BackupSize, 
				FirstLSN, 
				LastLSN, 
				CheckpointLSN, 
				DatabaseBackupLSN, 
				BackupStartDate, 
				BackupFinishDate, 
				SortOrder, 
				CodePage, 
				UnicodeLocaleId, 
				UnicodeComparisonStyle, 
				CompatibilityLevel, 
				SoftwareVendorId, 
				SoftwareVersionMajor, 
				SoftwareVersionMinor, 
				SoftwareVersionBuild, 
				MachineName, 
				Flags, 
				BindingId, 
				RecoveryForkId, 
				Collation, 
				FamilyGUID, 
				HasBulkLoggedData, 
				IsSnapshot, 
				IsReadOnly, 
				IsSingleUser, 
				HasBackupChecksums, 
				IsDamaged, 
				BeginsLogChain, 
				HasIncompleteMetadata, 
				IsForceOffline, 
				IsCopyOnly, 
				FirstRecoveryForkId, 
				ForkPointLSN, 
				RecoveryModel, 
				DifferentialBaseLSN, 
				DifferentialBaseGUID, 
				BackupTypeDescription, 
				BackupsetGUID, 
				CompressedBackupSize 
			FROM
				#backupheaderv11; 
		END; 
		ELSE 
		BEGIN
			IF ((@major_product_version >= 12) AND (@major_product_version < 16) AND (CAST(Serverproperty('ProductVersion') AS nvarchar(14)) <> '12.0.2000.8') AND (CAST(Serverproperty('ProductVersion') AS nvarchar(14)) NOT LIKE '12.0.22%')) 
			BEGIN
				TRUNCATE TABLE #backupheaderv12; 

				INSERT INTO #backupheaderv12 
				EXEC ('RESTORE HEADERONLY FROM DISK=''' + @backup_media + '''' 
				); 

				INSERT INTO #backupheader 
				(
					BackupName, 
					BackupDescription, 
					BackupType, 
					ExpirationDate, 
					Compressed, 
					Position, 
					DeviceType, 
					UserName, 
					ServerName, 
					DatabaseName, 
					DatabaseVersion, 
					DatabaseCreationDate, 
					BackupSize, 
					FirstLSN, 
					LastLSN, 
					CheckpointLSN, 
					DatabaseBackupLSN, 
					BackupStartDate, 
					BackupFinishDate, 
					SortOrder, 
					CodePage, 
					UnicodeLocaleId, 
					UnicodeComparisonStyle, 
					CompatibilityLevel, 
					SoftwareVendorId, 
					SoftwareVersionMajor, 
					SoftwareVersionMinor, 
					SoftwareVersionBuild, 
					MachineName, 
					Flags, 
					BindingId, 
					RecoveryForkId, 
					Collation, 
					FamilyGUID, 
					HasBulkLoggedData, 
					IsSnapshot, 
					IsReadOnly, 
					IsSingleUser, 
					HasBackupChecksums, 
					IsDamaged, 
					BeginsLogChain, 
					HasIncompleteMetadata, 
					IsForceOffline, 
					IsCopyOnly, 
					FirstRecoveryForkId, 
					ForkPointLSN, 
					RecoveryModel, 
					DifferentialBaseLSN, 
					DifferentialBaseGUID, 
					BackupTypeDescription, 
					BackupsetGUID, 
					CompressedBackupSize
				) 
				SELECT
					BackupName, 
					BackupDescription, 
					BackupType, 
					ExpirationDate, 
					Compressed, 
					Position, 
					DeviceType, 
					UserName, 
					ServerName, 
					DatabaseName, 
					DatabaseVersion, 
					DatabaseCreationDate, 
					BackupSize, 
					FirstLSN, 
					LastLSN, 
					CheckpointLSN, 
					DatabaseBackupLSN, 
					BackupStartDate, 
					BackupFinishDate, 
					SortOrder, 
					CodePage, 
					UnicodeLocaleId, 
					UnicodeComparisonStyle, 
					CompatibilityLevel, 
					SoftwareVendorId, 
					SoftwareVersionMajor, 
					SoftwareVersionMinor, 
					SoftwareVersionBuild, 
					MachineName, 
					Flags, 
					BindingId, 
					RecoveryForkId, 
					Collation, 
					FamilyGUID, 
					HasBulkLoggedData, 
					IsSnapshot, 
					IsReadOnly, 
					IsSingleUser, 
					HasBackupChecksums, 
					IsDamaged, 
					BeginsLogChain, 
					HasIncompleteMetadata, 
					IsForceOffline, 
					IsCopyOnly, 
					FirstRecoveryForkId, 
					ForkPointLSN, 
					RecoveryModel, 
					DifferentialBaseLSN, 
					DifferentialBaseGUID, 
					BackupTypeDescription, 
					BackupsetGUID, 
					CompressedBackupSize 
				FROM
					#backupheaderv12; 
			END 
			ELSE
			BEGIN
				IF (@major_product_version >= 16)
				BEGIN
					TRUNCATE TABLE #backupheaderv16; 

					INSERT INTO #backupheaderv16
					EXEC ('RESTORE HEADERONLY FROM DISK=''' + @backup_media + '''' 
					); 

					INSERT INTO #backupheader 
					(
						BackupName, 
						BackupDescription, 
						BackupType, 
						ExpirationDate, 
						Compressed, 
						Position, 
						DeviceType, 
						UserName, 
						ServerName, 
						DatabaseName, 
						DatabaseVersion, 
						DatabaseCreationDate, 
						BackupSize, 
						FirstLSN, 
						LastLSN, 
						CheckpointLSN, 
						DatabaseBackupLSN, 
						BackupStartDate, 
						BackupFinishDate, 
						SortOrder, 
						CodePage, 
						UnicodeLocaleId, 
						UnicodeComparisonStyle, 
						CompatibilityLevel, 
						SoftwareVendorId, 
						SoftwareVersionMajor, 
						SoftwareVersionMinor, 
						SoftwareVersionBuild, 
						MachineName, 
						Flags, 
						BindingId, 
						RecoveryForkId, 
						Collation, 
						FamilyGUID, 
						HasBulkLoggedData, 
						IsSnapshot, 
						IsReadOnly, 
						IsSingleUser, 
						HasBackupChecksums, 
						IsDamaged, 
						BeginsLogChain, 
						HasIncompleteMetadata, 
						IsForceOffline, 
						IsCopyOnly, 
						FirstRecoveryForkId, 
						ForkPointLSN, 
						RecoveryModel, 
						DifferentialBaseLSN, 
						DifferentialBaseGUID, 
						BackupTypeDescription, 
						BackupsetGUID, 
						CompressedBackupSize
					) 
					SELECT
						BackupName, 
						BackupDescription, 
						BackupType, 
						ExpirationDate, 
						Compressed, 
						Position, 
						DeviceType, 
						UserName, 
						ServerName, 
						DatabaseName, 
						DatabaseVersion, 
						DatabaseCreationDate, 
						BackupSize, 
						FirstLSN, 
						LastLSN, 
						CheckpointLSN, 
						DatabaseBackupLSN, 
						BackupStartDate, 
						BackupFinishDate, 
						SortOrder, 
						CodePage, 
						UnicodeLocaleId, 
						UnicodeComparisonStyle, 
						CompatibilityLevel, 
						SoftwareVendorId, 
						SoftwareVersionMajor, 
						SoftwareVersionMinor, 
						SoftwareVersionBuild, 
						MachineName, 
						Flags, 
						BindingId, 
						RecoveryForkId, 
						Collation, 
						FamilyGUID, 
						HasBulkLoggedData, 
						IsSnapshot, 
						IsReadOnly, 
						IsSingleUser, 
						HasBackupChecksums, 
						IsDamaged, 
						BeginsLogChain, 
						HasIncompleteMetadata, 
						IsForceOffline, 
						IsCopyOnly, 
						FirstRecoveryForkId, 
						ForkPointLSN, 
						RecoveryModel, 
						DifferentialBaseLSN, 
						DifferentialBaseGUID, 
						BackupTypeDescription, 
						BackupsetGUID, 
						CompressedBackupSize 
					FROM
						#backupheaderv16; 
				END 
				ELSE
				BEGIN
					INSERT INTO #backupheader 
					EXEC ('RESTORE HEADERONLY FROM DISK=''' + @backup_media + '''' 
					);
				END
			END
		END; 

		IF( @@ERROR <> 0 ) 
		BEGIN 
			RAISERROR (N'ERROR RESTORE HEADERONLY.',11,1) WITH log; 
		END; 

		INSERT INTO #completebackupheader 
		SELECT
			CAST(@backup_media AS nvarchar(max)), 
			bh.* 
		FROM   #backupheader bh; 

		TRUNCATE TABLE #backupheader; 

		FETCH next FROM c_backup_medium INTO @backup_media; 
	END; 

	CLOSE c_backup_medium; 

	DEALLOCATE c_backup_medium; 

	--Delete information which does not refers to the desired database backup 
	IF @original_dbname IS NOT NULL 
	BEGIN 
		DELETE FROM #completebackupheader WHERE  DatabaseName <> @original_dbname; 
	END; 

	--Retrieves information regarding what should be the only database whose backup files are located in the backup directory
	SELECT TOP 1
		@original_dbname = Isnull(@original_dbname, DatabaseName), 
		@binding_id = BindingId 
	FROM
		#completebackupheader 

	--Raise an error if there are some backups from several databases 
	IF EXISTS (SELECT TOP 1 1 FROM  #completebackupheader WHERE (DatabaseName <> @original_dbname OR BindingId <> @binding_id)) 
	BEGIN 
		RAISERROR ( 
		N'Error while running [p_restore_database_from_directory] : Backup directory contains backups from several databases.'
		,11,1) WITH log; 
	END; 

	------------------------------------------------------------------------ 
	------------------------------------------------------------------------ 
	--Lists the files' information backed up within the backup medium and stores the result in a temporary table
	------------------------------------------------------------------------ 
	IF Object_id('tempdb.dbo.##completebackupfileinformation') IS NOT NULL 
	BEGIN 
	DROP TABLE #completebackupfileinformation; 
	END; 

	CREATE TABLE #completebackupfileinformation 
	( 
		BackupMedia          nvarchar(max), 
		LogicalName          nvarchar(128), 
		PhysicalName         nvarchar(260), 
		Type                 char(1), 
		FileGroupName        nvarchar(128), 
		Size                 numeric(20, 0), 
		MaxSize              numeric(20, 0), 
		FileId               bigint, 
		CreateLSN            numeric(25, 0), 
		DropLSN              numeric(25, 0) NULL, 
		UniqueId             uniqueidentifier, 
		ReadOnlyLSN          numeric(25, 0) NULL, 
		ReadWriteLSN         numeric(25, 0) NULL, 
		BackupSizeInBytes    bigint, 
		SourceBlockSize      int, 
		FileGroupId          int, 
		LogGroupGUID         uniqueidentifier NULL, 
		DifferentialBaseLSN  numeric(25, 0) NULL, 
		DifferentialBaseGUID uniqueidentifier NULL, 
		IsReadOnly           bit, 
		IsPresent            bit, 
		TDEThumbprint        varbinary(32) 
	); 

	IF( @@ERROR <> 0 ) 
	BEGIN 
	RAISERROR ( 
	N'ERROR CREATE temporary table CompleteBackupFileInformation.', 
	11 
	,1) WITH log; 
	END; 

	IF Object_id('tempdb.dbo.#BackupFileInformation') IS NOT NULL 
	BEGIN 
	DROP TABLE #backupfileinformation; 
	END; 

	CREATE TABLE #backupfileinformation 
	( 
		LogicalName          nvarchar(128), 
		PhysicalName         nvarchar(260), 
		Type                 char(1), 
		FileGroupName        nvarchar(128), 
		Size                 numeric(20, 0), 
		MaxSize              numeric(20, 0), 
		FileId               bigint, 
		CreateLSN            numeric(25, 0), 
		DropLSN              numeric(25, 0) NULL, 
		UniqueId             uniqueidentifier, 
		ReadOnlyLSN          numeric(25, 0) NULL, 
		ReadWriteLSN         numeric(25, 0) NULL, 
		BackupSizeInBytes    bigint, 
		SourceBlockSize      int, 
		FileGroupId           int, 
		LogGroupGUID         uniqueidentifier NULL, 
		DifferentialBaseLSN  numeric(25, 0) NULL, 
		DifferentialBaseGUID uniqueidentifier NULL, 
		IsReadOnly           bit, 
		IsPresent            bit, 
		TDEThumbprint        varbinary(32) NULL
	); 

	IF Object_id('tempdb.dbo.#BackupFileInformationv13') IS NOT NULL 
	BEGIN 
	DROP TABLE #backupfileinformationv13; 
	END; 

	CREATE TABLE #backupfileinformationv13
	( 
		LogicalName          nvarchar(128), 
		PhysicalName         nvarchar(260), 
		Type                 char(1), 
		FileGroupName        nvarchar(128), 
		Size                 numeric(20, 0), 
		MaxSize              numeric(20, 0), 
		FileId               bigint, 
		CreateLSN            numeric(25, 0), 
		DropLSN              numeric(25, 0) NULL, 
		UniqueId             uniqueidentifier, 
		ReadOnlyLSN          numeric(25, 0) NULL, 
		ReadWriteLSN         numeric(25, 0) NULL, 
		BackupSizeInBytes    bigint, 
		SourceBlockSize      int, 
		FileGroupId           int, 
		LogGroupGUID         uniqueidentifier NULL, 
		DifferentialBaseLSN  numeric(25, 0) NULL, 
		DifferentialBaseGUID uniqueidentifier NULL, 
		IsReadOnly           bit, 
		IsPresent            bit, 
		TDEThumbprint        varbinary(32) NULL,
		SnapshotURL          nvarchar(360) NULL 
	); 

	IF( @@ERROR <> 0 ) 
	BEGIN 
		RAISERROR (N'ERROR CREATE temporary table BackupFileInformation.',11,1 
		) 
		WITH 
		log; 
	END; 

	DECLARE c_backup_media CURSOR fast_forward FOR 
	SELECT cbh.BackupMedia 
	FROM   #completebackupheader cbh; 

	OPEN c_backup_media; 

	FETCH next FROM c_backup_media INTO @backup_media; 

	WHILE @@FETCH_STATUS = 0 
	BEGIN
		IF(@major_product_version >= 13)
		BEGIN
			INSERT INTO #backupfileinformationv13 
			EXEC ('RESTORE FILELISTONLY FROM DISK=''' + @backup_media + ''''); 

			INSERT INTO #backupfileinformation(
				LogicalName,
				PhysicalName,
				Type,
				FileGroupName,
				Size,
				MaxSize,
				FileId,
				CreateLSN,
				DropLSN,
				UniqueId,
				ReadOnlyLSN,
				ReadWriteLSN,
				BackupSizeInBytes,
				SourceBlockSize,
				FileGroupId,
				LogGroupGUID,
				DifferentialBaseLSN,
				DifferentialBaseGUID,
				IsReadOnly,
				IsPresent,
				TDEThumbprint
			)
			SELECT
				LogicalName,
				PhysicalName,
				Type,
				FileGroupName,
				Size,
				MaxSize,
				FileId,
				CreateLSN,
				DropLSN,
				UniqueId,
				ReadOnlyLSN,
				ReadWriteLSN,
				BackupSizeInBytes,
				SourceBlockSize,
				FileGroupId,
				LogGroupGUID,
				DifferentialBaseLSN,
				DifferentialBaseGUID,
				IsReadOnly,
				IsPresent,
				TDEThumbprint
			FROM
				#backupfileinformationv13;
		END
		ELSE
		BEGIN
			INSERT INTO #backupfileinformation 
			EXEC ('RESTORE FILELISTONLY FROM DISK=''' + @backup_media + ''''); 
		END;

		IF( @@ERROR <> 0 ) 
		BEGIN 
			RAISERROR (N'ERROR RESTORE FILELISTONLY.',11,1) WITH log; 
		END; 

		INSERT INTO #completebackupfileinformation 
		SELECT @backup_media, 
		bh.* 
		FROM   #backupfileinformation bh; 

		TRUNCATE TABLE #backupfileinformation; 

		FETCH next FROM c_backup_media INTO @backup_media; 
	END; 

	CLOSE c_backup_media; 

	DEALLOCATE c_backup_media; 

	INSERT INTO #backupfileinformation 
	(
		LogicalName, 
		PhysicalName, 
		Type, 
		FileGroupName, 
		Size, 
		MaxSize, 
		FileId, 
		CreateLSN, 
		DropLSN, 
		UniqueId, 
		ReadOnlyLSN, 
		ReadWriteLSN, 
		BackupSizeInBytes, 
		SourceBlockSize, 
		FileGroupId, 
		LogGroupGUID, 
		DifferentialBaseLSN, 
		DifferentialBaseGUID, 
		IsReadOnly, 
		IsPresent, 
		TDEThumbprint
	) 
	SELECT DISTINCT
		cbfi.LogicalName, 
		cbfi.PhysicalName, 
		cbfi.Type, 
		cbfi.FileGroupName, 
		cbfi.Size, 
		cbfi.MaxSize, 
		cbfi.FileId, 
		cbfi.CreateLSN, 
		cbfi.DropLSN, 
		cbfi.UniqueId, 
		cbfi.ReadOnlyLSN, 
		cbfi.ReadWriteLSN, 
		cbfi.BackupSizeInBytes, 
		cbfi.SourceBlockSize, 
		cbfi.FileGroupId, 
		cbfi.LogGroupGUID, 
		cbfi.DifferentialBaseLSN, 
		cbfi.DifferentialBaseGUID, 
		cbfi.IsReadOnly, 
		cbfi.IsPresent, 
		cbfi.TDEThumbprint 
	FROM
		#completebackupfileinformation cbfi; 

	------------------------------------------------------------------------ 
	------------------------------------------------------------------------ 
	--Keep Only the useful backups in a dedicated table 
	------------------------------------------------------------------------ 
	IF Object_id('tempdb.dbo.#UsefulBackupHeader') IS NOT NULL 
	BEGIN 
		DROP TABLE #usefulbackupheader; 
	END; 

	CREATE TABLE #usefulbackupheader 
	( 
		row_id                 int IDENTITY(1, 1), 
		BackupMedia            nvarchar(max), 
		BackupName             nvarchar(128), 
		BackupDescription      nvarchar(255), 
		BackupType             smallint, 
		ExpirationDate         datetime, 
		Compressed             tinyint, 
		Position               smallint, 
		DeviceType             tinyint, 
		UserName               nvarchar(128), 
		ServerName             nvarchar(128), 
		DatabaseName           nvarchar(128), 
		DatabaseVersion        int, 
		DatabaseCreationDate   datetime, 
		BackupSize             numeric(20, 0), 
		FirstLSN               numeric(25, 0), 
		LastLSN                numeric(25, 0), 
		CheckpointLSN          numeric(25, 0), 
		DatabaseBackupLSN      numeric(25, 0), 
		BackupStartDate        datetime, 
		BackupFinishDate       datetime, 
		SortOrder              smallint, 
		CodePage               smallint, 
		UnicodeLocaleId        int, 
		UnicodeComparisonStyle int, 
		CompatibilityLevel     tinyint, 
		SoftwareVendorId       int, 
		SoftwareVersionMajor   int, 
		SoftwareVersionMinor   int, 
		SoftwareVersionBuild   int, 
		MachineName            nvarchar(128), 
		Flags                  int, 
		BindingId              uniqueidentifier, 
		RecoveryForkId         uniqueidentifier, 
		Collation              nvarchar(128), 
		FamilyGUID             uniqueidentifier, 
		HasBulkLoggedData      bit, 
		IsSnapshot             bit, 
		IsReadOnly             bit, 
		IsSingleUser           bit, 
		HasBackupChecksums     bit, 
		IsDamaged              bit, 
		BeginsLogChain         bit, 
		HasIncompleteMetadata  bit, 
		IsForceOffline         bit, 
		IsCopyOnly             bit, 
		FirstRecoveryForkId    uniqueidentifier, 
		ForkPointLSN           numeric(25, 0), 
		RecoveryModel          nvarchar(60), 
		DifferentialBaseLSN    numeric(25, 0), 
		DifferentialBaseGUID   uniqueidentifier, 
		BackupTypeDescription  nvarchar(60), 
		BackupsetGUID          uniqueidentifier, 
		CompressedBackupSize   numeric(20, 0) 
	); 

	IF( @@ERROR <> 0 ) 
	BEGIN 
		RAISERROR (N'ERROR CREATE temporary table UsefulBackupHeader.',11,1) 
		WITH 
		log; 
	END; 

	------------------------------------------------------------------------ 
	------------------------------------------------------------------------ 
	--Retrieve the necessary full backup 
	------------------------------------------------------------------------ 
	INSERT INTO #usefulbackupheader 
	SELECT TOP 1
		cbh.* 
	FROM
		#completebackupheader cbh 
	WHERE
		cbh.BackupType = 1 
	AND
		cbh.BackupStartDate <= @stop_at_time 
	ORDER BY
		cbh.BackupStartDate DESC 

	IF( @@ROWCOUNT = 0 ) 
	BEGIN 
		RAISERROR (N'ERROR: No usable full backup found.',11,1) WITH log; 
	END; 

	------------------------------------------------------------------------ 
	------------------------------------------------------------------------ 
	--Retrieve the most recent usable differential backup 
	------------------------------------------------------------------------ 
	INSERT INTO #usefulbackupheader 
	SELECT TOP 1 cbh.* 
	FROM   #completebackupheader cbh 
	INNER JOIN #usefulbackupheader ubh 
	ON cbh.DifferentialBaseGUID = ubh.BackupsetGUID 
	AND cbh.DatabaseBackupLSN = ubh.CheckpointLSN 
	WHERE  cbh.BackupType = 5 
	AND cbh.BackupStartDate <= @stop_at_time 
	ORDER  BY cbh.BackupStartDate DESC 

	------------------------------------------------------------------------ 
	------------------------------------------------------------------------ 
	--Retrieve all of the necessary log backups 
	------------------------------------------------------------------------ 
	DECLARE @earliest_log_last_LSN [numeric](25, 0); 

	SELECT @earliest_log_last_LSN = Max(ubh.[LastLSN]) 
	FROM   #usefulbackupheader ubh 

	SET @last_log_backup_start_date = (SELECT TOP 1 cbh.BackupStartDate 
	FROM   #completebackupheader cbh 
	WHERE 
	cbh.BackupStartDate > @stop_at_time 
	AND cbh.BackupType = 2 
	ORDER  BY cbh.BackupStartDate); 

	IF @last_log_backup_start_date IS NULL 
	BEGIN 
	SET @last_log_backup_start_date = (SELECT Max(cbh.BackupStartDate) 
	FROM   #completebackupheader cbh 
	WHERE  cbh.BackupType = 2) 
	END; 

	SET @first_log_backup_start_date = (SELECT Max(ubh.BackupStartDate) 
	FROM   #usefulbackupheader ubh); 

	INSERT INTO #usefulbackupheader 
	SELECT cbh.* 
	FROM   #completebackupheader cbh 
	INNER JOIN #usefulbackupheader ubh 
	ON cbh.DatabaseBackupLSN = ubh.CheckpointLSN 
	WHERE  cbh.BackupType = 2 
	AND cbh.BackupStartDate >= @first_log_backup_start_date 
	AND cbh.BackupStartDate <= @last_log_backup_start_date 
	AND cbh.[LastLSN] >= @earliest_log_last_LSN 
	ORDER  BY cbh.BackupStartDate; 

	------------------------------------------------------------------------ 
	------------------------------------------------------------------------ 
	--Create the script part for moving data and log files 
	------------------------------------------------------------------------ 
	IF( @old_path_part IS NOT NULL 
	AND @new_path_part IS NOT NULL ) 
	BEGIN 
	--Create paths from the database being restored 
	SELECT @move_data_files_script = Stuff((SELECT 
	', ' + 'MOVE N''' + bfid.[LogicalName] 
	+ N''' TO N''' 
	+ Replace(Substring(bfid.[PhysicalName], 
	1, Len(bfid.[PhysicalName]) 
	- Charindex 
	('\', Reverse(bfid.[PhysicalName]))), @old_path_part, 
	@new_path_part) 
	+ N'\' + @restored_dbname + CASE WHEN Row_number() OVER(ORDER 
	BY 
	bfid.[FileId]) 
	> 1 THEN N'_' + RIGHT('000' + Cast(Row_number() OVER(ORDER BY 
	bfid.[FileId]) AS 
	VARCHAR), 3) + '.ndf' ELSE '.mdf' END + N'''' 
	FROM   (SELECT DISTINCT bfi.[LogicalName], 
	bfi.[PhysicalName], 
	bfi.[FileId] 
	FROM   #backupfileinformation bfi 
	WHERE  bfi.[type] = 'D') bfid 
	FOR xml path ('')), 1, 1, ''); 

	SELECT @move_log_files_script = Stuff((SELECT 
				   ', ' + 
	'MOVE N''' + 
	bfil.[LogicalName] 
	+ N''' TO N''' 
	+ Replace(Substring(bfil.[PhysicalName], 
	1, 
	Len(bfil.[PhysicalName]) 
	- Charindex 
	('\', Reverse(bfil.[PhysicalName]))), @old_path_part, 
	@new_path_part) 
	+ N'\' + @restored_dbname + CASE WHEN Row_number() OVER(ORDER BY 
	bfil.[FileId]) 
	> 1 THEN N'_' + RIGHT('000' + Cast(Row_number() OVER(ORDER BY 
	bfil.[FileId]) AS 
	VARCHAR), 3) ELSE '' END + N'.ldf''' 
	FROM   (SELECT DISTINCT bfi.[LogicalName], 
	bfi.[PhysicalName], 
	bfi.[FileId] 
	FROM   #backupfileinformation bfi 
	WHERE  bfi.[Type] = 'L') bfil 
	FOR xml path ('')), 1, 1, ''); 
	END; 
	ELSE 
	BEGIN 
	--Create paths from default data path and log path 
	SELECT @move_data_files_script = Stuff( 
	(SELECT ', ' + 'MOVE N''' + 
	bfid.[LogicalName] 
	+ N''' TO N''' + 
	@data_directory 
	+ N'\' 
	+ @restored_dbname + CASE 
	WHEN 
	Row_number() OVER( 
	ORDER BY 
	bfid.[FileId]) 
	> 1 
	THEN N'_' + RIGHT('000' + 
	Cast( 
	Row_number() OVER( 
	ORDER BY 
	bfid.[FileId]) 
	AS 
	VARCHAR), 3) + '.ndf' ELSE 
	'.mdf' 
	END + 
	N'''' 
	FROM   (SELECT DISTINCT 
	bfi.[LogicalName], 
	bfi.[PhysicalName], 
	bfi.[FileId] 
	FROM   #backupfileinformation 
	bfi 
	WHERE  bfi.[Type] = 'D') bfid 
	FOR xml path ('')), 1, 1, ''); 

	SELECT @move_log_files_script = Stuff((SELECT ', ' + 'MOVE N''' + 
	bfil.[LogicalName] 
	+ N''' TO N''' + 
	@log_directory + 
	N'\' 
	+ @restored_dbname + 
	CASE 
	WHEN 
	Row_number 
		() OVER(ORDER BY 
	bfil.[FileId]) 
	> 1 
	THEN N'_' + RIGHT('000' + Cast(Row_number() OVER(ORDER BY 
	bfil.[FileId]) 
	AS 
	VARCHAR), 3) ELSE '' END + N'.ldf''' 
	FROM   (SELECT DISTINCT bfi.[LogicalName], 
	bfi.[PhysicalName], 
	bfi.[FileId] 
	FROM   #backupfileinformation bfi 
	WHERE  bfi.[Type] = 'L') bfil 
	FOR xml path ('')), 1, 1, ''); 
	END; 

	------------------------------------------------------------------------ 
	------------------------------------------------------------------------ 
	--Generate and execute restore scripts 
	------------------------------------------------------------------------ 
	IF ( @only_generate_restore_script = 0 ) 
	BEGIN 
	IF EXISTS (SELECT name 
	FROM   sys.databases 
	WHERE  name = @restored_dbname) 
	BEGIN 
	SET @stmt = N' USE [master]; ALTER DATABASE ' 
	+ Quotename(@restored_dbname) 
	+ ' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; ALTER DATABASE ' 
	+ Quotename(@restored_dbname) 
	+ ' SET OFFLINE WITH ROLLBACK IMMEDIATE; ALTER DATABASE ' 
	+ Quotename(@restored_dbname) 
	+ ' SET ONLINE WITH ROLLBACK IMMEDIATE; DROP DATABASE ' 
	+ Quotename(@restored_dbname) + ';'; 

	PRint @stmt 

	EXEC(@stmt); 
	END; 
	END; 

	SET @max_row_id = (SELECT Max(row_id) 
	FROM   #usefulbackupheader) 

	DECLARE c_stmt CURSOR read_only FOR 
	SELECT 
	N' RESTORE ' + CASE WHEN ubh.BackupType = 2 THEN N'LOG' ELSE N'DATABASE' END 
	+ 
	N' ' 
	+ Quotename(@restored_dbname) 
	+ N' FROM DISK = N''' + ubh.BackupMedia 
	+ N''' WITH FILE=' 
	+ Cast(ubh.Position AS nvarchar) 
	+ N', NOUNLOAD, STATS = 10, ' 
	+ @move_data_files_script + ', ' 
	+ @move_log_files_script + CASE WHEN ubh.BackupType <> 1 AND ubh.RecoveryModel <> 'SIMPLE' THEN 
	N', STOPAT = ''' 
	+ 
	CONVERT(nvarchar, @stop_at_time, 126) + N'''' ELSE N'' END 
	+ N', NORECOVERY;' 
	FROM   #usefulbackupheader ubh 
	ORDER  BY row_id; 

	OPEN c_stmt; 

	FETCH next FROM c_stmt INTO @stmt; 

	WHILE @@FETCH_STATUS = 0 
	BEGIN 
	PRint @stmt; 

	IF ( @only_generate_restore_script = 0 ) 
	BEGIN 
	EXEC(@stmt); 
	END; 

	FETCH next FROM c_stmt INTO @stmt; 
	END; 

	CLOSE c_stmt; 

	DEALLOCATE c_stmt; 

	IF(@recovery = 1)
	BEGIN
		SET @stmt = N' RESTORE DATABASE ' 
		+ Quotename(@restored_dbname) 
		+ N' WITH RECOVERY;'; 

		PRint @stmt;
		PRINT '
GO
'

		IF ( @only_generate_restore_script = 0 ) 
		BEGIN 
		EXEC(@stmt); 
		END; 
	END;

	------------------------------------------------------------------------ 
	------------------------------------------------------------------------ 
	--Change the owner of the restored database 
	------------------------------------------------------------------------ 
	--NB : Requires "GRANT IMPERSONATE ON LOGIN::sa to [xxxxxx]", assuming that the stored procedudre is being run by xxxxxx
	IF( @new_owner IS NOT NULL ) 
	BEGIN 
	SET @stmt = N' USE ' + Quotename(@restored_dbname) 
	+ 
	N' IF EXISTS (SELECT * FROM sys.database_principals WHERE name = N''' 
	+ @new_owner + N''') DROP USER ' 
	+ Quotename(@new_owner) 
	+ N' EXEC sp_changedbowner ''' + @new_owner + N''';'; 

	PRint @stmt;
	PRINT '
GO
'

	IF ( @only_generate_restore_script = 0 ) 
	BEGIN 
	EXECUTE AS login = 'sa'; 

	EXEC sp_executesql 
	@stmt; 

	EXEC(@stmt); 

	REVERT; 
	END; 
	ELSE 
	BEGIN 
	SELECT @stmt; 
	END; 
	END; 

	------------------------------------------------------------------------ 
	------------------------------------------------------------------------ 
	--Attach orphaned database users to existing server logins 
	------------------------------------------------------------------------ 
	IF ( @auto_fix_orphaned_users = 1 
	AND @only_generate_restore_script = 0 ) 
	BEGIN 
	IF Object_id( 
	'tempdb.dbo.##tmp_p_restore_database_from_directory_orphaned_users' 
	) 
	IS NOT NULL 
	BEGIN 
	DROP TABLE 
	##tmp_p_restore_database_from_directory_orphaned_users; 
	END; 

	SET @stmt = N' USE ' + Quotename(@restored_dbname) 
	+ 
	N'; SELECT sdp.[name] COLLATE French_CI_AI as [name] INTO ##tmp_p_restore_database_from_directory_orphaned_users FROM sys.database_principals sdp INNER JOIN sys.server_principals ssp_to_attach ON sdp.[name] COLLATE French_CI_AI = ssp_to_attach.[name] LEFT OUTER JOIN sys.server_principals ssp ON sdp.[sid] = ssp.[sid] WHERE sdp.Type = N''S'' AND ssp.[sid] IS NULL AND sdp.[name] COLLATE French_CI_AI NOT IN (N''guest'', N''INFORMATION_SCHEMA'', N''sys'');' 

	EXECUTE AS login = 'sa'; 

	EXEC(@stmt); 

	REVERT; 

	DECLARE c_orphaned_users CURSOR read_only FOR 
	SELECT tmp.[Name] 
	FROM   ##tmp_p_restore_database_from_directory_orphaned_users tmp; 

	OPEN c_orphaned_users; 

	FETCH next FROM c_orphaned_users INTO @orphaned_user; 

	WHILE @@FETCH_STATUS = 0 
	BEGIN 
	SET @stmt = N' USE ' + Quotename(@restored_dbname) 
	+ N'; EXEC sp_change_users_login N''update_one'', N''' 
	+ @orphaned_user + N''', N''' + @orphaned_user 
	+ N''''; 

	PRint @stmt 

	EXECUTE AS login = 'sa'; 

	EXEC(@stmt); 

	REVERT; 

	FETCH next FROM c_orphaned_users INTO @orphaned_user; 
	END; 

	CLOSE c_orphaned_users; 

	DEALLOCATE c_orphaned_users; 

	DROP TABLE ##tmp_p_restore_database_from_directory_orphaned_users; 
	END; 

	------------------------------------------------------------------------ 
	------------------------------------------------------------------------ 
	--Execute the post-restore script 
	------------------------------------------------------------------------ 
	IF ( @post_restore_script IS NOT NULL 
	AND @only_generate_restore_script = 0 ) 
	BEGIN 
	PRint @post_restore_script 

	EXECUTE AS login = 'sa'; 

	EXEC(@post_restore_script); 

	REVERT; 
	END; 
	------------------------------------------------------------------------ 
	END 

GO


