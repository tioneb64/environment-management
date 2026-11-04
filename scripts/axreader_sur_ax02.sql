USE [AXDEV]
GO
DROP USER [axreader]
GO

USE [AXPPROD]
GO
DROP USER [axreader]
GO

USE [AXREC]
GO
DROP USER [axreader]
GO

USE [AXRECBIS]
GO
DROP USER [axreader]
GO


USE [AXDEV]
GO
CREATE USER [axreader] FOR LOGIN [axreader]
GO
USE [AXDEV]
GO
ALTER ROLE [db_datareader] ADD MEMBER [axreader]
GO

USE [AXPPROD]
GO
CREATE USER [axreader] FOR LOGIN [axreader]
GO
USE [AXPPROD]
GO
ALTER ROLE [db_datareader] ADD MEMBER [axreader]
GO

USE [AXREC]
GO
CREATE USER [axreader] FOR LOGIN [axreader]
GO
USE [AXREC]
GO
ALTER ROLE [db_datareader] ADD MEMBER [axreader]
GO

USE [AXRECBIS]
GO
CREATE USER [axreader] FOR LOGIN [axreader]
GO
USE [AXRECBIS]
GO
ALTER ROLE [db_datareader] ADD MEMBER [axreader]
GO