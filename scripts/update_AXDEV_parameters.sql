--****************************************************
-- Ce script met à jour les paramètres AX pour AXDEV
--****************************************************

use AXDEV
go

--select * from SYSBCPROXYUSERACCOUNT
Declare @BCPACCOUNT varchar(20)
Declare @AOS_SERVERID varchar(20)
Declare @AOS_SERVERID_PROD varchar(20)
DECLARE @SP_INTERNAL_URL  varchar(100)
DECLARE @SP_EXTERNAL_URL  varchar(100)
DECLARE @RS_SERVERURL varchar(100)
DECLARE @RS_REPORTMANAGERURL varchar(100)
DECLARE @RS_SERVERID varchar(30)
DECLARE @RS_SERVERINSTANCE varchar(100)
DECLARE @DB_NAME varchar(100)
DECLARE @DB_SOURCE varchar(100)
DECLARE @HelpServerLocation varchar(100)
--SET @BCPACCOUNT = 'svc_bcp'

-- ***************************************
-- Déclaration des variables
-- ***************************************
-- Configuration de la base de données
SET @DB_SOURCE = 'DNTAXRECETTE\DNTAXRECETTE'
SET @DB_NAME = 'AXDEV'

-- Nom de l'instance AOS utilisée
SET @AOS_SERVERID = '01@DNTAXDEV01'
SET @AOS_SERVERID_PROD = '01@DNTPRDAOS01'

-- Configuration Enterprise Portal
SET @SP_INTERNAL_URL = 'http://dntaxdev01/sites/DynamicsAx'
SET @SP_EXTERNAL_URL = 'http://dntaxdev01/sites/DynamicsAx'

-- Configuration serveur d'aide
SET @HelpServerLocation = 'http://dntaxdev01:82/DynamicsAX6HelpServer/HelpService.svc'

-- Configuration Businesse Intelligence (RS + AS sur un serveur all in one)
SET @RS_SERVERID = 'DNTAXDEV01'
SET @RS_SERVERINSTANCE = 'MSSQLSERVER'
SET @RS_SERVERURL = 'http://DNTAXDEV01/ReportServer'
SET @RS_REPORTMANAGERURL = 'http://DNTAXDEV01/Reports'

-- ****************************************
-- Lancement du traitement de mises à jour 
-- ****************************************
--SELECT * FROM SYSBCPROXYUSERACCOUNT

-- Configuration des AOS et Batch server
-- ****************************************
--SELECT * FROM BATCH
UPDATE BATCH SET SERVERID = @AOS_SERVERID WHERE SERVERID <> ''
''SELECT * FROM BATCHHISTORY
UPDATE BATCHHISTORY SET SERVERID = @AOS_SERVERID WHERE SERVERID <> ''
--SELECT * FROM BATCHSERVERGROUP
-- DELETE FROM BATCHSERVERGROUP WHERE SERVERID <> @AOS_SERVERID_PROD
UPDATE BATCHSERVERGROUP SET SERVERID = @AOS_SERVERID WHERE SERVERID <> ''


-- Configuration Enterprise Portal
-- ****************************************
--SELECT * FROM EPWEBSITEPARAMETERS
UPDATE EPWEBSITEPARAMETERS SET INTERNALURL = @SP_INTERNAL_URL, EXTERNALURL = @SP_EXTERNAL_URL

-- Configuration Business Intelligence
-- ****************************************
--SELECT * FROM SRSSERVERS
-- DELETE FROM SRSSERVERS where AOSID <> @AOS_SERVERID_PROD AND ISDEFAULTREPORTLIBRARYSERVER = '0' 
UPDATE SRSSERVERS SET AOSID = @AOS_SERVERID,SERVERURL = @RS_SERVERURL, REPORTMANAGERURL = @RS_REPORTMANAGERURL,
	SERVERID = @RS_SERVERID,SERVERINSTANCE = @RS_SERVERINSTANCE, CONFIGURATIONID = @RS_SERVERID + @RS_SERVERINSTANCE

--SELECT * FROM BIANALYSISSERVER
-- DELETE FROM BIANALYSISSERVER WHERE ISDEFAULT = '0'
UPDATE BIANALYSISSERVER SET SERVERNAME = @RS_SERVERID + '\' + @RS_SERVERINSTANCE,DESCRIPTION = 'Dynamics AX Analysis Server ' +  @RS_SERVERINSTANCE
--SELECT * FROM BICONFIGURATION
UPDATE  BICONFIGURATION SET CONNECTIONSTRING =  
	'Provider=SQLNCLI10.1;Data Source=' + @DB_SOURCE +';Integrated Security=SSPI;Initial Catalog=' + @DB_NAME
--UPDATE  BICONFIGURATION SET CONNECTIONSTRING =  LEFT(CONNECTIONSTRING,CHARINDEX('Initial Catalog=',CONNECTIONSTRING)-1) + 'Initial Catalog=' + @DATABASENAME

-- Configuration Serveur d'aide
-- ****************************************
UPDATE SYSGLOBALCONFIGURATION SET VALUE = @HELPServerLocation WHERE NAME = 'HelpServerLocation'


-- Configuration Systeme AX
-- ****************************************
DELETE FROM SYSCLIENTSESSIONS
--SELECT * FROM SYSEMAILSMTPPASSWORD
--SELECT * FROM SYSLASTVALUE WHERE DESIGNNAME LIKE  '%AOS%'
--SELECT * FROM SYSSERVERCONFIG
-- DELETE FROM SYSSERVERCONFIG WHERE SERVERID <> @AOS_SERVERID_PROD
UPDATE SYSSERVERCONFIG SET SERVERID = @AOS_SERVERID
DELETE FROM SYSSERVERSESSIONS
--SELECT * FROM SYSWORKFLOWPARAMETERS
--SELECT * FROM SYSGLOBALCONFIGURATION
UPDATE SYSGLOBALCONFIGURATION SET VALUE = @AOS_SERVERID WHERE NAME = 'SCOMPERFORMANCEAOS'

update syssqmsettings set GLOBALGUID = '00000000-0000-0000-0000-000000000000'

-- desactivation des jobs 
UPDATE BATCHJOB SET STATUS = 0 WHERE STATUS IN (1,2,5)
UPDATE BATCH SET STATUS = 0 WHERE STATUS IN (1,2,5)
-- modification des répertoires EDI
update dbo.bisparameters set ENVIRONMENTTYPE = 1