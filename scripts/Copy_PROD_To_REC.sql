/*--------------------------------------------------------------------*/
/*  Ce script copie les bases AX de prod en REC                    */
/*  il se base sur les backup quotidiennes de la PROD                 */
/*  il ne fait pas de sauvegarde de la REC                         */
/*--------------------------------------------------------------------*/

USE [master]
GO

-- To enable the feature.
EXEC sp_configure 'xp_cmdshell', 1;
GO
-- To update the currently configured value for this feature.
RECONFIGURE;
GO


/*--------------------------------------------------------------------*/
/*  ARRET des services                                                */
/*--------------------------------------------------------------------*/
PRINT 'Arret des services de l''environnement REC'
EXEC xp_cmdshell 'sc \\DNTRECAOS01 stop AOS60$01', no_output

--EXEC xp_cmdshell 'sc \\DNTRECMR01 stop MR2012ProcessService', no_output
--EXEC xp_cmdshell 'sc \\DNTRECMR01 stop MR2012ApplicationService', no_output

/*--------------------------------------------------------------------*/
/*  Liste des connexions sur REC                                   */
/*--------------------------------------------------------------------*/
Declare @dbName varchar(150)
set @dbName = 'AXREC'

--Available connections
DECLARE @SPWHO1 TABLE (DBName VARCHAR(1000) NULL, NoOfAvailableConnections VARCHAR(1000) NULL, LoginName VARCHAR(1000) NULL)
INSERT INTO @SPWHO1 
    SELECT db_name(dbid), count(dbid), loginame FROM sys.sysprocesses WHERE dbid > 0 GROUP BY dbid, loginame
SELECT * FROM @SPWHO1 WHERE DBName = @dbName

--Running connections
DECLARE @SPWHO2 TABLE (SPID VARCHAR(1000), [Status] VARCHAR(1000) NULL, [Login] VARCHAR(1000) NULL, HostName VARCHAR(1000) NULL, BlkBy VARCHAR(1000) NULL, DBName VARCHAR(1000) NULL, Command VARCHAR(1000) NULL, CPUTime VARCHAR(1000) NULL, DiskIO VARCHAR(1000) NULL, LastBatch VARCHAR(1000) NULL, ProgramName VARCHAR(1000) NULL, SPID2 VARCHAR(1000) NULL, Request VARCHAR(1000) NULL)
INSERT INTO @SPWHO2 
    EXEC sp_who2 'Active'
SELECT * FROM @SPWHO2 WHERE DBName = @dbName

/**********************************************************/
/* Restaure database PROD vers REC                     */
/**********************************************************/
USE [master]
GO

PRINT 'Restauration AXPROD vers AXREC'
/**********************************************************/
/* Début modification par CapData le 29/04/2026           */
/**********************************************************/
DECLARE @SQL AS NVARCHAR (1000);

IF EXISTS (SELECT 1
           FROM sys.databases
           WHERE [name] = N'AXREC')
BEGIN
    SET @SQL = N'USE [AXREC];

                ALTER DATABASE [AXREC] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
                USE [master];

                DROP DATABASE [AXREC];';
    EXECUTE (@SQL);
END

--Script de restauration après modification par CapData le 29/04/2026
DECLARE @backup_device nvarchar(520)
SET @backup_device = (SELECT TOP 1 physical_name FROM sys.backup_devices WHERE name = 'AXPROD')

DECLARE @backup_dir nvarchar(520)
SELECT @backup_dir = COALESCE(@backup_dir + '\', '') + [value]
FROM (SELECT ROW_NUMBER() OVER (ORDER BY [dummy]) AS [row_num], [value] FROM (SELECT NULL AS [dummy], * FROM STRING_SPLIT(@backup_device, '\')) split) t
WHERE [row_num] < (SELECT COUNT(*) FROM STRING_SPLIT(@backup_device, '\'))
SELECT @backup_dir

DECLARE @backup_file nvarchar(520)
SELECT @backup_file = [value]
FROM (SELECT ROW_NUMBER() OVER (ORDER BY [dummy]) AS [row_num], [value] FROM (SELECT NULL AS [dummy], * FROM STRING_SPLIT(@backup_device, '\')) split) t
WHERE [row_num] = (SELECT COUNT(*) FROM STRING_SPLIT(@backup_device, '\'))
SELECT @backup_file

DECLARE @backup_db sysname
SELECT TOP 1 @backup_db=[value] FROM STRING_SPLIT(@backup_file, '.')
SELECT @backup_db 

-- CAPDATA LPR Suite bascule je force en dur le backup_dir vers le noeud02
SELECT @backup_dir='\\Dntaxprod\L$\MSSQL13.DNTAXPROD\MSSQL\Backup'


EXEC [master].[dbo].[usp_restore_database_from_directory]
	@backup_directory = @backup_dir
	,@restored_dbname = N'AXREC'
	,@data_directory = N'R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA'
	,@log_directory = N'S:\MSSQL13.DNTAXRECETTE\MSSQL\Data'
	,@original_dbname = @backup_db
	,@new_owner                    = N'DAUNAT\svc_sql'
	,@auto_fix_orphaned_users      = 1
	,@recovery = 1
GO
/**********************************************************/
/* Fin modification par CapData le 29/04/2026             */
/**********************************************************/

PRINT 'Paramétrage des fichiers de données'
ALTER DATABASE AXREC MODIFY FILE (NAME=N'AXPROD',NEWNAME=N'AXREC')
ALTER DATABASE AXREC MODIFY FILE (NAME=N'AXPROD_log',NEWNAME=N'AXREC_log')
ALTER DATABASE AXREC SET RECOVERY SIMPLE;


USE AXREC
GO
DBCC SHRINKFILE ('AXREC_log')
-- test fait le 08/09/2017 : trop long
--DBCC SHRINKFILE ('AXREC')

USE [master]
GO
PRINT 'Restauration AXPROD_model vers AXREC_model'
/**********************************************************/
/* Début modification par CapData le 29/04/2026           */
/**********************************************************/
/*--Script de restauration avant modification par CapData le 29/04/2026
RESTORE DATABASE [AXREC_model] 
FROM  [AXPROD_model]
WITH  FILE = 1,  
MOVE N'AXPROD_model' TO N'R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA\AXREC_model.mdf',
MOVE N'AXPROD_model_log' TO N'S:\MSSQL13.DNTAXRECETTE\MSSQL\Data\AXREC_model_log.ldf',
NOUNLOAD,  REPLACE,  STATS = 10
GO*/

DECLARE @SQL AS NVARCHAR (1000);

IF EXISTS (SELECT 1
           FROM sys.databases
           WHERE [name] = N'AXREC_model')
BEGIN
    SET @SQL = N'USE [AXREC_model];

                ALTER DATABASE [AXREC_model] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
                USE [master];

                DROP DATABASE [AXREC_model];';
    EXECUTE (@SQL);
END

--Script de restauration après modification par CapData le 29/04/2026
DECLARE @backup_device nvarchar(520)
SET @backup_device = (SELECT TOP 1 physical_name FROM sys.backup_devices WHERE name = 'AXPROD_model')

DECLARE @backup_dir nvarchar(520)
SELECT @backup_dir = COALESCE(@backup_dir + '\', '') + [value]
FROM (SELECT ROW_NUMBER() OVER (ORDER BY [dummy]) AS [row_num], [value] FROM (SELECT NULL AS [dummy], * FROM STRING_SPLIT(@backup_device, '\')) split) t
WHERE [row_num] < (SELECT COUNT(*) FROM STRING_SPLIT(@backup_device, '\'))
SELECT @backup_dir

DECLARE @backup_file nvarchar(520)
SELECT @backup_file = [value]
FROM (SELECT ROW_NUMBER() OVER (ORDER BY [dummy]) AS [row_num], [value] FROM (SELECT NULL AS [dummy], * FROM STRING_SPLIT(@backup_device, '\')) split) t
WHERE [row_num] = (SELECT COUNT(*) FROM STRING_SPLIT(@backup_device, '\'))
SELECT @backup_file

DECLARE @backup_db sysname
SELECT TOP 1 @backup_db=[value] FROM STRING_SPLIT(@backup_file, '.')
SELECT @backup_db 

-- CAPDATA LPR Suite bascule je force en dur le backup_dir vers le noeud02
SELECT @backup_dir='\\Dntaxprod\L$\MSSQL13.DNTAXPROD\MSSQL\Backup'

EXEC [master].[dbo].[usp_restore_database_from_directory]
	@backup_directory = @backup_dir
	,@restored_dbname = N'AXREC_model'
	,@data_directory = N'R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA'
	,@log_directory = N'S:\MSSQL13.DNTAXRECETTE\MSSQL\Data'
	,@original_dbname = @backup_db
	,@new_owner                    = N'DAUNAT\svc_sql'
	,@auto_fix_orphaned_users      = 1
	,@recovery = 1
GO
/**********************************************************/
/* Fin modification par CapData le 29/04/2026             */
/**********************************************************/

PRINT 'Paramétrage des fichiers de données'
ALTER DATABASE AXREC_model MODIFY FILE (NAME=N'AXPROD_model',NEWNAME=N'AXREC_model')
ALTER DATABASE AXREC_model MODIFY FILE (NAME=N'AXPROD_model_log',NEWNAME=N'AXREC_model_log')
ALTER DATABASE AXREC_model SET RECOVERY SIMPLE;

--USE AXREC_model
--GO
--DBCC SHRINKFILE ('AXREC_model_log')

USE [master]
GO
PRINT 'Restauration AXPRODBaseline vers AXRECBaseline'
/**********************************************************/
/* Début modification par CapData le 29/04/2026           */
/**********************************************************/
/*--Script de restauration avant modification par CapData le 29/04/2026
RESTORE DATABASE [AXRECBaseline] 
FROM  [AXPRODBaseline]
WITH  FILE = 1,  
MOVE N'AXPRODBaseline' TO N'R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA\AXRECBaseline.mdf',
MOVE N'AXPRODBaseline_log' TO N'S:\MSSQL13.DNTAXRECETTE\MSSQL\Data\AXRECBaseline_log.ldf',
NOUNLOAD,  REPLACE,  STATS = 10
GO*/

DECLARE @SQL AS NVARCHAR (1000);

IF EXISTS (SELECT 1
           FROM sys.databases
           WHERE [name] = N'AXRECBaseline')
BEGIN
    SET @SQL = N'USE [AXRECBaseline];

                ALTER DATABASE [AXRECBaseline] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
                USE [master];

                DROP DATABASE [AXRECBaseline];';
    EXECUTE (@SQL);
END

--Script de restauration après modification par CapData le 29/04/2026
DECLARE @backup_device nvarchar(520)
SET @backup_device = (SELECT TOP 1 physical_name FROM sys.backup_devices WHERE name = 'AXPRODBaseline')

DECLARE @backup_dir nvarchar(520)
SELECT @backup_dir = COALESCE(@backup_dir + '\', '') + [value]
FROM (SELECT ROW_NUMBER() OVER (ORDER BY [dummy]) AS [row_num], [value] FROM (SELECT NULL AS [dummy], * FROM STRING_SPLIT(@backup_device, '\')) split) t
WHERE [row_num] < (SELECT COUNT(*) FROM STRING_SPLIT(@backup_device, '\'))
SELECT @backup_dir

DECLARE @backup_file nvarchar(520)
SELECT @backup_file = [value]
FROM (SELECT ROW_NUMBER() OVER (ORDER BY [dummy]) AS [row_num], [value] FROM (SELECT NULL AS [dummy], * FROM STRING_SPLIT(@backup_device, '\')) split) t
WHERE [row_num] = (SELECT COUNT(*) FROM STRING_SPLIT(@backup_device, '\'))
SELECT @backup_file

DECLARE @backup_db sysname
SELECT TOP 1 @backup_db=[value] FROM STRING_SPLIT(@backup_file, '.')
SELECT @backup_db 

-- CAPDATA LPR Suite bascule je force en dur le backup_dir vers le noeud02
SELECT @backup_dir='\\Dntaxprod\L$\MSSQL13.DNTAXPROD\MSSQL\Backup'

EXEC [master].[dbo].[usp_restore_database_from_directory]
	@backup_directory = @backup_dir
	,@restored_dbname = N'AXRECBaseline'
	,@data_directory = N'R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA'
	,@log_directory = N'S:\MSSQL13.DNTAXRECETTE\MSSQL\Data'
	,@original_dbname = @backup_db
	,@new_owner                    = N'DAUNAT\svc_sql'
	,@auto_fix_orphaned_users      = 1
	,@recovery = 1
GO
/**********************************************************/
/* Fin modification par CapData le 29/04/2026             */
/**********************************************************/

PRINT 'Paramétrage des fichiers de données'
ALTER DATABASE AXRECBaseline MODIFY FILE (NAME=N'AXPRODBaseline',NEWNAME=N'AXRECBaseline')
ALTER DATABASE AXRECBaseline MODIFY FILE (NAME=N'AXPRODBaseline_log',NEWNAME=N'AXRECBaseline_log')
ALTER DATABASE AXRECBaseline SET RECOVERY SIMPLE;

--USE AXRECBaseline
--GO
--DBCC SHRINKFILE ('AXRECBaseline_log')

USE [master]
GO

/*--------------------------------------------------------------------*/
/*  Mise a jour des parametres REC                                 */
/*--------------------------------------------------------------------*/
-- To enable the feature.
EXEC sp_configure 'xp_cmdshell', 1;
GO
-- To update the currently configured value for this feature.
RECONFIGURE;
GO
PRINT 'Mise à jour du paramétrage de l''environnement REC'
EXEC xp_cmdshell 'sqlcmd -E -SDNTAXRECETTE\DNTAXRECETTE -i\\DNTPHYAX01\c$\scripts\update_AXREC_parameters_FROM_PROD.sql'
GO 

USE [master]
GO
/*--------------------------------------------------------------------*/
/*  Demarrage des services                                            */
/*--------------------------------------------------------------------*/

PRINT 'Démarrage des services de l''environnement REC'
EXEC xp_cmdshell 'sc \\DNTRECAOS01 start AOS60$01', no_output

--EXEC xp_cmdshell 'sc \\DNTRECMR01 start MR2012ProcessService', no_output
--EXEC xp_cmdshell 'sc \\DNTRECMR01 start MR2012ApplicationService', no_output


-- To enable the feature.
EXEC sp_configure 'xp_cmdshell', 0;
GO
-- To update the currently configured value for this feature.
RECONFIGURE;
GO