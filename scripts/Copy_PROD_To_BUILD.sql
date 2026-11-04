/*--------------------------------------------------------------------*/
/*  Ce script copie les bases AX de prod sur BUILD                    */
/*  il se base sur les backup quotidiennes de la PROD                 */
/*  il ne fait pas de sauvegarde de la BUILD                         */
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
PRINT 'Arret des services de l''environnement BUILD'
EXEC xp_cmdshell 'sc \\DNTRECTER stop AOS60$02', no_output

--EXEC xp_cmdshell 'sc \\DNTRECMR01 stop MR2012ProcessService', no_output
--EXEC xp_cmdshell 'sc \\DNTRECMR01 stop MR2012ApplicationService', no_output

/*--------------------------------------------------------------------*/
/*  Liste des connexions sur BUILD                                    */
/*--------------------------------------------------------------------*/
Declare @dbName varchar(150)
set @dbName = 'AXBUILD'

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

--Drop Connections : 
ALTER DATABASE [AXBUILD] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE

/**********************************************************/
/* Restaure database PROD vers BUILD                      */
/**********************************************************/
USE [master]
GO

PRINT 'Restauration AXPROD vers AXBUILD'

RESTORE DATABASE [AXBUILD] 
FROM  [AXPROD]
WITH  FILE = 1,  
MOVE N'AXPROD' TO N'R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA\AXBUILD.mdf',
MOVE N'AXPROD_log' TO N'S:\MSSQL13.DNTAXRECETTE\MSSQL\Data\AXBUILD_log.ldf',
NOUNLOAD,  REPLACE,  STATS = 10
GO

PRINT 'Paramétrage des fichiers de données'
ALTER DATABASE AXBUILD MODIFY FILE (NAME=N'AXPROD',NEWNAME=N'AXBUILD')
ALTER DATABASE AXBUILD MODIFY FILE (NAME=N'AXPROD_log',NEWNAME=N'AXBUILD_log')
ALTER DATABASE AXBUILD SET RECOVERY SIMPLE;


USE AXBUILD
GO
DBCC SHRINKFILE ('AXBUILD_log')
-- test fait le 08/09/2017 : trop long
--DBCC SHRINKFILE ('AXBUILD')

USE [master]
GO
PRINT 'Restauration AXPROD_model vers AXBUILD_model'
RESTORE DATABASE [AXBUILD_model] 
FROM  [AXPROD_model]
WITH  FILE = 1,  
MOVE N'AXPROD_model' TO N'R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA\AXBUILD_model.mdf',
MOVE N'AXPROD_model_log' TO N'S:\MSSQL13.DNTAXRECETTE\MSSQL\Data\AXBUILD_model_log.ldf',
NOUNLOAD,  REPLACE,  STATS = 10
GO

PRINT 'Paramétrage des fichiers de données'
ALTER DATABASE AXBUILD_model MODIFY FILE (NAME=N'AXPROD_model',NEWNAME=N'AXBUILD_model')
ALTER DATABASE AXBUILD_model MODIFY FILE (NAME=N'AXPROD_model_log',NEWNAME=N'AXBUILD_model_log')
ALTER DATABASE AXBUILD_model SET RECOVERY SIMPLE;

--USE AXBUILD_model
--GO
--DBCC SHRINKFILE ('AXBUILD_model_log')

--USE [master]
--GO
--PRINT 'Restauration AXPRODBaseline vers AXRECTERBaseline'
--RESTORE DATABASE [AXRECTERBaseline] 
--FROM  [AXPRODBaseline]
--WITH  FILE = 1,  
--MOVE N'AXPRODBaseline' TO N'R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA\AXRECTERBaseline.mdf',
--MOVE N'AXPRODBaseline_log' TO N'S:\MSSQL13.DNTAXRECETTE\MSSQL\Data\AXRECTERBaseline_log.ldf',
--NOUNLOAD,  REPLACE,  STATS = 10
--GO

--PRINT 'Paramétrage des fichiers de données'
--ALTER DATABASE AXRECTERBaseline MODIFY FILE (NAME=N'AXPRODBaseline',NEWNAME=N'AXRECTERBaseline')
--ALTER DATABASE AXRECTERBaseline MODIFY FILE (NAME=N'AXPRODBaseline_log',NEWNAME=N'AXRECTERBaseline_log')
--ALTER DATABASE AXRECTERBaseline SET RECOVERY SIMPLE;

--USE AXRECTERBaseline
--GO
--DBCC SHRINKFILE ('AXRECTERBaseline_log')

USE [master]
GO

/*--------------------------------------------------------------------*/
/*  Mise a jour des parametres BUILD                                  */
/*--------------------------------------------------------------------*/
-- To enable the feature.
EXEC sp_configure 'xp_cmdshell', 1;
GO
-- To update the currently configured value for this feature.
RECONFIGURE;
GO
PRINT 'Mise à jour du paramétrage de l''environnement BUILD'
EXEC xp_cmdshell 'sqlcmd -E -SDNTAXRECETTE\DNTAXRECETTE -i\\DNTPHYAX01\c$\scripts\update_AXBUILD_parameters_FROM_PROD.sql'
GO 

USE [master]
GO
/*--------------------------------------------------------------------*/
/*  Demarrage des services */
/*--------------------------------------------------------------------*/

PRINT 'Démarrage des services de l''environnement BUILD'
EXEC xp_cmdshell 'sc \\DNTRECTER start AOS60$02', no_output

--EXEC xp_cmdshell 'sc \\DNTRECMR01 start MR2012ProcessService', no_output
--EXEC xp_cmdshell 'sc \\DNTRECMR01 start MR2012ApplicationService', no_output


-- To enable the feature.
EXEC sp_configure 'xp_cmdshell', 0;
GO
-- To update the currently configured value for this feature.
RECONFIGURE;
GO