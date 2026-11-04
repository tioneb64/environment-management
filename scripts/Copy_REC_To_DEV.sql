/*
--------------------------------------------------------------------
SYNOPSIS DU SCRIPT : COPIE DES BASES AX DE REC VERS DEV
--------------------------------------------------------------------

1. OBJET DU SCRIPT
   Ce script SQL Server permet de copier les bases de données 
   Microsoft Dynamics AX de l’environnement REC (recette) vers 
   l’environnement DEV (développement). 

   Il se base sur le dernier backup complet disponible des bases REC 
   et restaure ces sauvegardes sur les bases DEV correspondantes.
   ?? Aucune sauvegarde préalable des bases DEV n’est effectuée.

--------------------------------------------------------------------
2. BASES CONCERNÉES
   - AXREC         ? AXDEV
   - AXREC_model   ? AXDEV_model
   - AXRECBaseline ? AXDEVBaseline

--------------------------------------------------------------------
3. PRINCIPALES ÉTAPES DU SCRIPT

   a. Création des bases DEV si elles n’existent pas
      ? AXDEV, AXDEV_model, AXDEVBaseline

   b. Activation de la commande système xp_cmdshell
      (nécessaire pour exécuter des commandes Windows depuis SQL Server)

   c. (Optionnel) Arrêt des services AOS et Management Reporter
      !!! Les lignes correspondantes sont commentées.!!!

   d. Identification et coupure des connexions actives sur AXDEV
      - Exécution de sp_who2 pour lister les connexions
      - Passage temporaire en mode SINGLE_USER pour forcer la déconnexion

   e. Restauration de la base AXREC ? AXDEV
      - Recherche du dernier backup complet de AXREC
      - Restauration dans les répertoires DEV
      - Renommage logique des fichiers (.mdf / .ldf)
      - Passage en mode de récupération SIMPLE
      - Nettoyage du fichier journal (DBCC SHRINKFILE)
      - Ajustement de certaines vues spécifiques (DMFMODELELEMENT, SECURITYROLEALLTASKSVIEW, SECURITYFIELDSDENIEDACCESSSSOMEROLEVIEW)

   f. Restauration de la base AXREC_model ? AXDEV_model
      - Processus identique à la précédente restauration

   g. Restauration de la base AXRECBaseline ? AXDEVBaseline
      - Processus identique à la précédente restauration

   h. Mise à jour des paramètres spécifiques à l’environnement DEV
      !!!(exécution d’un script externe update_AXDEV_parameters_FROM_REC.sql — désactivée par défaut)!!!

   i. (Optionnel) Redémarrage des services de l’environnement REC
      Les commandes sont présentes mais commentées.

   j. Désactivation de xp_cmdshell après exécution

--------------------------------------------------------------------
4. REMARQUES ET PRÉCAUTIONS

   - Le script ne crée pas de sauvegarde préalable des bases DEV.
   - Les chemins d’accès aux fichiers .mdf et .ldf sont spécifiques 
     à l’environnement DNTAXRECETTE.
   - Certaines parties nécessitent des droits administratifs SQL.
   - Les commandes xp_cmdshell doivent être utilisées avec prudence.
   - Les parties "Arrêt" et "Démarrage" des services doivent être adaptés et activés 

--------------------------------------------------------------------
5. RÉSUMÉ TECHNIQUE

   Langage : T-SQL
   Serveur cible : SQL Server (environnement DNTAXRECETTE)
   Fonction principale : Restauration automatique des bases DEV 
   depuis les dernières sauvegardes REC.
   Risques : Écrasement des données DEV sans sauvegarde préalable

--------------------------------------------------------------------
FIN DU SYNOPSIS
--------------------------------------------------------------------

*/
/*--------------------------------------------------------------------*/
/*  Ce script copie les bases AX de REC en DEV                        */
/*  il se base sur le dernier backup de la REC                        */
/*  il ne fait pas de sauvegarde de la DEV                            */
/*--------------------------------------------------------------------*/
USE [master]
GO
-- CREATE DB IF NOT EXISTS (Target)
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name='AXDEV')	BEGIN CREATE DATABASE AXDEV END
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name='AXDEV_model')	BEGIN CREATE DATABASE AXDEV_model END
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name='AXDEVBaseline')	BEGIN CREATE DATABASE AXDEVBaseline END

-- To enable the feature.
EXEC sp_configure 'xp_cmdshell', 1;
GO
-- To update the currently configured value for this feature.
RECONFIGURE;
GO


/*--------------------------------------------------------------------*/
/*  ARRET des services                                                */
/*--------------------------------------------------------------------*/
--PRINT 'Arret des services de l''environnement REC'
--EXEC xp_cmdshell 'sc \\DNTREC stop AOS60$01', no_output

--EXEC xp_cmdshell 'sc \\DNTRECMR01 stop MR2012ProcessService', no_output
--EXEC xp_cmdshell 'sc \\DNTRECMR01 stop MR2012ApplicationService', no_output

/*--------------------------------------------------------------------*/
/*  Liste des connexions sur DEV                                   */
/*--------------------------------------------------------------------*/
Declare @dbName varchar(150)
set @dbName = 'AXDEV'

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

ALTER DATABASE [AXDEV] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
--ALTER DATABASE [AXDEV] SET  MULTI_USER
/**********************************************************/
/* Restaure database REC vers DEV                       */
/**********************************************************/

PRINT 'Restauration AXREC vers AXDEV'
USE [master]
GO

declare @backupfile as Varchar(255)

-- GET LAST FULL BACKUP FILE (Source)
SELECT TOP 1 @backupfile=mf.physical_device_name from msdb..backupset bk      
join msdb..backupmediafamily mf on bk.media_set_id = mf.media_set_id   
where database_name=N'AXREC' and bk.type='D' order by backup_set_id desc

PRINT 'FROM '+ @backupfile

RESTORE DATABASE [AXDEV] 
FROM  DISK = @backupfile
WITH  FILE = 1,  
MOVE N'AXREC' TO N'R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA\AXDEV.mdf',
MOVE N'AXREC_log' TO N'S:\MSSQL13.DNTAXRECETTE\MSSQL\Data\AXDEV_log.ldf',
NOUNLOAD,  REPLACE,  STATS = 1
GO

PRINT 'Paramétrage des fichiers de données'
ALTER DATABASE AXDEV MODIFY FILE (NAME=N'AXREC',NEWNAME=N'AXDEV')
ALTER DATABASE AXDEV MODIFY FILE (NAME=N'AXREC_log',NEWNAME=N'AXDEV_log')
ALTER DATABASE AXDEV SET RECOVERY SIMPLE;

USE AXDEV
GO
DBCC SHRINKFILE ('AXDEV_log')

PRINT 'Ajustement des vues DMFMODELELEMENT, SECURITYROLEALLTASKSVIEW et SECURITYFIELDSDENIEDACCESSSSOMEROLEVIEW'

DECLARE @SQL NVARCHAR(MAX)
DECLARE cur CURSOR FOR	SELECT REPLACE(REPLACE(m.definition,'AXREC_model','AXDEV_model'),'CREATE ','ALTER ')
						FROM sys.sql_modules m INNER JOIN sys.objects o ON o.object_id = m.object_id
						WHERE o.name in ('DMFMODELELEMENT','SECURITYROLEALLTASKSVIEW','SECURITYFIELDSDENIEDACCESSSSOMEROLEVIEW')
    OPEN cur
    FETCH NEXT FROM cur INTO @SQL
    WHILE @@FETCH_STATUS = 0
    BEGIN
		EXEC AXDEV.sys.sp_executesql @SQL
        FETCH NEXT FROM cur INTO @SQL
	END
    CLOSE cur
    DEALLOCATE cur


PRINT 'Restauration AXREC_model vers AXDEV_model'
USE [master]
GO
ALTER DATABASE [AXDEV_model] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE

declare @backupfile as Varchar(255)

-- GET LAST FULL BACKUP FILE (Source)
SELECT TOP 1 @backupfile=mf.physical_device_name from msdb..backupset bk      
join msdb..backupmediafamily mf on bk.media_set_id = mf.media_set_id   
where database_name=N'AXREC_model' and bk.type='D' order by backup_set_id desc

PRINT 'FROM '+ @backupfile

RESTORE DATABASE [AXDEV_model] 
FROM  DISK = @backupfile
WITH  FILE = 1,  
MOVE N'AXREC_model' TO N'R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA\AXDEV_model.mdf',
MOVE N'AXREC_model_log' TO N'S:\MSSQL13.DNTAXRECETTE\MSSQL\Data\AXDEV_model_log.ldf',
NOUNLOAD,  REPLACE,  STATS = 10
GO

PRINT 'Paramétrage des fichiers de données'
ALTER DATABASE AXDEV_model MODIFY FILE (NAME=N'AXREC_model',NEWNAME=N'AXDEV_model')
ALTER DATABASE AXDEV_model MODIFY FILE (NAME=N'AXREC_model_log',NEWNAME=N'AXDEV_model_log')
ALTER DATABASE AXDEV_model SET RECOVERY SIMPLE;

USE AXDEV_model
GO
DBCC SHRINKFILE ('AXDEV_model_log')


PRINT 'Restauration AXRECBaseline vers AXDEVBaseline'
USE [master]
GO

ALTER DATABASE [AXDEVBaseline] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE

declare @backupfile as Varchar(255)

-- GET LAST FULL BACKUP FILE (Source)
SELECT TOP 1 @backupfile=mf.physical_device_name from msdb..backupset bk      
join msdb..backupmediafamily mf on bk.media_set_id = mf.media_set_id   
where database_name=N'AXRECBaseline' and bk.type='D' order by backup_set_id desc

PRINT 'FROM '+ @backupfile

RESTORE DATABASE [AXDEVBaseline] 
FROM  DISK = @backupfile
WITH  FILE = 1,  
MOVE N'AXRECBaseline' TO N'R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA\AXDEVBaseline.mdf',
MOVE N'AXRECBaseline_log' TO N'S:\MSSQL13.DNTAXRECETTE\MSSQL\Data\AXDEVBaseline_log.ldf',
NOUNLOAD,  REPLACE,  STATS = 10
GO

PRINT 'Paramétrage des fichiers de données'
ALTER DATABASE AXDEVBaseline MODIFY FILE (NAME=N'AXRECBaseline',NEWNAME=N'AXDEVBaseline')
ALTER DATABASE AXDEVBaseline MODIFY FILE (NAME=N'AXRECBaseline_log',NEWNAME=N'AXDEVBaseline_log')
ALTER DATABASE AXDEVBaseline SET RECOVERY SIMPLE;

USE AXDEVBaseline
GO
DBCC SHRINKFILE ('AXDEVBaseline_log')

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
PRINT 'Mise à jour du paramétrage de l''environnement DEV'
--EXEC xp_cmdshell 'sqlcmd -E -SDNTAXRECETTE\DNTAXRECETTE -i\\DNTPHYAX01\c$\scripts\update_AXDEV_parameters_FROM_REC.sql'
-- le fichier existe (suffix à modifier) mais doit être adapté
GO 

USE [master]
GO
/*--------------------------------------------------------------------*/
/*  Demarrage des services */
/*--------------------------------------------------------------------*/

--PRINT 'Démarrage des services de l''environnement REC'
--EXEC xp_cmdshell 'sc \\DNTREC start AOS60$01', no_output

--EXEC xp_cmdshell 'sc \\DNTRECMR01 start MR2012ProcessService', no_output
--EXEC xp_cmdshell 'sc \\DNTRECMR01 start MR2012ApplicationService', no_output


-- To enable the feature.
EXEC sp_configure 'xp_cmdshell', 0;
GO
-- To update the currently configured value for this feature.
RECONFIGURE;
GO