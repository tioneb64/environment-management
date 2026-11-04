/*--------------------------------------------------------------------*/
/*  Ce script copie les bases AX de prod en REC                     */
/*  il se base sur les backup quotidiennes de la PROD                 */
/*  il ne fait pas de sauvegarde de la REC                          */
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
EXEC xp_cmdshell 'sc \\DNTREC stop AOS60$01', no_output

EXEC xp_cmdshell 'sc \\DNTRECMR01 stop MR2012ProcessService', no_output
EXEC xp_cmdshell 'sc \\DNTRECMR01 stop MR2012ApplicationService', no_output

/*--------------------------------------------------------------------*/
/*  Liste des connexions sur REC                                    */
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

--Drop Connections : ajout le 27/11/2018 (stoppé le 04/12/18 puis réactivé le 10/01/19
ALTER DATABASE [AXREC] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE

/**********************************************************/
/* Restaure database PROD vers REC                       */
/**********************************************************/
USE [master]
GO

PRINT 'Restauration AXPROD vers AXREC'

RESTORE DATABASE [AXREC] 
FROM  [AXPROD]
WITH  FILE = 1,  
MOVE N'AXPROD' TO N'R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA\AXREC.mdf',
MOVE N'AXPROD_log' TO N'S:\MSSQL13.DNTAXRECETTE\MSSQL\Data\AXREC_log.ldf',
NOUNLOAD,  REPLACE,  STATS = 10
GO

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
RESTORE DATABASE [AXREC_model] 
FROM  [AXPROD_model]
WITH  FILE = 1,  
MOVE N'AXPROD_model' TO N'R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA\AXREC_model.mdf',
MOVE N'AXPROD_model_log' TO N'S:\MSSQL13.DNTAXRECETTE\MSSQL\Data\AXREC_model_log.ldf',
NOUNLOAD,  REPLACE,  STATS = 10
GO

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
RESTORE DATABASE [AXRECBaseline] 
FROM  [AXPRODBaseline]
WITH  FILE = 1,  
MOVE N'AXPRODBaseline' TO N'R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA\AXRECBaseline.mdf',
MOVE N'AXPRODBaseline_log' TO N'S:\MSSQL13.DNTAXRECETTE\MSSQL\Data\AXRECBaseline_log.ldf',
NOUNLOAD,  REPLACE,  STATS = 10
GO

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
/*  Mise a jour des parametres REC                                    */
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
/*  Demarrage des services */
/*--------------------------------------------------------------------*/

PRINT 'Démarrage des services de l''environnement REC'
EXEC xp_cmdshell 'sc \\DNTREC start AOS60$01', no_output

EXEC xp_cmdshell 'sc \\DNTRECMR01 start MR2012ProcessService', no_output
EXEC xp_cmdshell 'sc \\DNTRECMR01 start MR2012ApplicationService', no_output


-- To enable the feature.
EXEC sp_configure 'xp_cmdshell', 0;
GO
-- To update the currently configured value for this feature.
RECONFIGURE;
GO