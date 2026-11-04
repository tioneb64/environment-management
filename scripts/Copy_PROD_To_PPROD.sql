/*--------------------------------------------------------------------*/
/*  Ce script copie les bases AX de prod en PPROD                     */
/*  il se base sur les backup quotidiennes de la PROD                 */
/*  il ne fait pas de sauvegarde de la PPROD                          */
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
PRINT 'Arret des services de l''environnement PPROD'
EXEC xp_cmdshell 'sc \\DNTPPRODAX01 stop AOS60$01', no_output

EXEC xp_cmdshell 'sc \\DNTRECMR01 stop MR2012ProcessService', no_output
EXEC xp_cmdshell 'sc \\DNTRECMR01 stop MR2012ApplicationService', no_output

/*--------------------------------------------------------------------*/
/*  Liste des connexions sur PPROD                                   */
/*--------------------------------------------------------------------*/
Declare @dbName varchar(150)
set @dbName = 'AXPPROD'

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

--Drop Connections : ajout le 27/11/2018 (stoppé le 04/12/18 puis réactivé le 10/01/19
--ALTER DATABASE [AXPPROD] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE

/**********************************************************/
/* Restaure database PROD vers PPROD                      */
/**********************************************************/
USE [master]
GO

PRINT 'Restauration AXPROD vers AXPPROD'
/**********************************************************/
/* Début modification par CapData le 29/04/2026           */
/**********************************************************/
/*--Script de restauration avant modification par CapData le 29/04/2026
RESTORE DATABASE [AXPPROD] 
FROM  [AXPROD]
WITH  FILE = 1,  
MOVE N'AXPROD' TO N'R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA\AXPPROD.mdf',
MOVE N'AXPROD_log' TO N'S:\MSSQL13.DNTAXRECETTE\MSSQL\Data\AXPPROD_log.ldf',
NOUNLOAD,  REPLACE,  STATS = 10
GO*/

DECLARE @SQL AS NVARCHAR (1000);

IF EXISTS (SELECT 1
           FROM sys.databases
           WHERE [name] = N'AXPPROD')
BEGIN
    SET @SQL = N'USE [AXPPROD];

                ALTER DATABASE [AXPPROD] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
                USE [master];

                DROP DATABASE [AXPPROD];';
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
	,@restored_dbname = N'AXPPROD'
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
ALTER DATABASE AXPPROD MODIFY FILE (NAME=N'AXPROD',NEWNAME=N'AXPPROD')
ALTER DATABASE AXPPROD MODIFY FILE (NAME=N'AXPROD_log',NEWNAME=N'AXPPROD_log')
ALTER DATABASE AXPPROD SET RECOVERY SIMPLE;


USE AXPPROD
GO
DBCC SHRINKFILE ('AXPPROD_log')
-- test fait le 08/09/2017 : trop long
--DBCC SHRINKFILE ('AXPPROD')

USE [master]
GO
PRINT 'Restauration AXPROD_model vers AXPPROD_model'
/**********************************************************/
/* Début modification par CapData le 29/04/2026           */
/**********************************************************/
/*--Script de restauration avant modification par CapData le 29/04/2026
RESTORE DATABASE [AXPPROD_model] 
FROM  [AXPROD_model]
WITH  FILE = 1,  
MOVE N'AXPROD_model' TO N'R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA\AXPPROD_model.mdf',
MOVE N'AXPROD_model_log' TO N'S:\MSSQL13.DNTAXRECETTE\MSSQL\Data\AXPPROD_model_log.ldf',
NOUNLOAD,  REPLACE,  STATS = 10
GO*/

DECLARE @SQL AS NVARCHAR (1000);

IF EXISTS (SELECT 1
           FROM sys.databases
           WHERE [name] = N'AXPPROD_model')
BEGIN
    SET @SQL = N'USE [AXPPROD_model];

                ALTER DATABASE [AXPPROD_model] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
                USE [master];

                DROP DATABASE [AXPPROD_model];';
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
	,@restored_dbname = N'AXPPROD_model'
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
ALTER DATABASE AXPPROD_model MODIFY FILE (NAME=N'AXPROD_model',NEWNAME=N'AXPPROD_model')
ALTER DATABASE AXPPROD_model MODIFY FILE (NAME=N'AXPROD_model_log',NEWNAME=N'AXPPROD_model_log')
ALTER DATABASE AXPPROD_model SET RECOVERY SIMPLE;

--USE AXPPROD_model
--GO
--DBCC SHRINKFILE ('AXPPROD_model_log')

USE [master]
GO
PRINT 'Restauration AXPRODBaseline vers AXPPRODBaseline'
/**********************************************************/
/* Début modification par CapData le 29/04/2026           */
/**********************************************************/
/*--Script de restauration avant modification par CapData le 29/04/2026
RESTORE DATABASE [AXPPRODBaseline] 
FROM  [AXPRODBaseline]
WITH  FILE = 1,  
MOVE N'AXPRODBaseline' TO N'R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA\AXPPRODBaseline.mdf',
MOVE N'AXPRODBaseline_log' TO N'S:\MSSQL13.DNTAXRECETTE\MSSQL\Data\AXPPRODBaseline_log.ldf',
NOUNLOAD,  REPLACE,  STATS = 10
GO*/

DECLARE @SQL AS NVARCHAR (1000);

IF EXISTS (SELECT 1
           FROM sys.databases
           WHERE [name] = N'AXPPRODBaseline')
BEGIN
    SET @SQL = N'USE [AXPPRODBaseline];

                ALTER DATABASE [AXPPRODBaseline] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
                USE [master];

                DROP DATABASE [AXPPRODBaseline];';
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
	,@restored_dbname = N'AXPPRODBaseline'
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
ALTER DATABASE AXPPRODBaseline MODIFY FILE (NAME=N'AXPRODBaseline',NEWNAME=N'AXPPRODBaseline')
ALTER DATABASE AXPPRODBaseline MODIFY FILE (NAME=N'AXPRODBaseline_log',NEWNAME=N'AXPPRODBaseline_log')
ALTER DATABASE AXPPRODBaseline SET RECOVERY SIMPLE;

--USE AXPPRODBaseline
--GO
--DBCC SHRINKFILE ('AXPPRODBaseline_log')

USE [master]
GO

/*--------------------------------------------------------------------*/
/*  Mise a jour des parametres PPROD                                 */
/*--------------------------------------------------------------------*/
-- To enable the feature.
EXEC sp_configure 'xp_cmdshell', 1;
GO
-- To update the currently configured value for this feature.
RECONFIGURE;
GO
PRINT 'Mise à jour du paramétrage de l''environnement PPROD'
EXEC xp_cmdshell 'sqlcmd -E -SDNTAXRECETTE\DNTAXRECETTE -i\\DNTPHYAX01\c$\scripts\update_AXPPROD_parameters_FROM_PROD.sql'
GO 

USE [master]
GO
/*--------------------------------------------------------------------*/
/*  Demarrage des services                                            */
/*--------------------------------------------------------------------*/

PRINT 'Démarrage des services de l''environnement PPROD'
EXEC xp_cmdshell 'sc \\DNTPPRODAX01 start AOS60$01', no_output

EXEC xp_cmdshell 'sc \\DNTRECMR01 start MR2012ProcessService', no_output
EXEC xp_cmdshell 'sc \\DNTRECMR01 start MR2012ApplicationService', no_output


-- To enable the feature.
EXEC sp_configure 'xp_cmdshell', 0;
GO
-- To update the currently configured value for this feature.
RECONFIGURE;
GO