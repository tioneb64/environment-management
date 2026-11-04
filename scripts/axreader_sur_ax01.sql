

USE [AXPROD]
GO
DROP USER [axreader]
GO



USE [AXPROD]
GO
CREATE USER [axreader] FOR LOGIN [axreader]
GO
USE [AXPROD]
GO
ALTER ROLE [db_datareader] ADD MEMBER [axreader]
GO
