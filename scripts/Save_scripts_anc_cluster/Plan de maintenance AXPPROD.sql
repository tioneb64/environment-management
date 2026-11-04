USE [msdb]
GO

/****** Object:  Job [AX database Rebuild Index and update statistics AXPPROD]    Script Date: 04/11/2014 14:25:55 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 04/11/2014 14:25:55 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'AX database Rebuild Index and update statistics AXPPROD', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Pas de description disponible.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'DAUNAT\adminisatech', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [statistics maintenance]    Script Date: 04/11/2014 14:25:55 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'statistics maintenance', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--Script to automate statistics maintenance
                --Script 1 of 2: 
                --Update column statistics only. 
                --Statistics related to indexes are updated in step 2.

-- Ensure a USE <databasename> statement has been executed first.
SET NOCOUNT ON;
DECLARE @objectid int;
DECLARE @schemaname nvarchar(130); 
DECLARE @objectname nvarchar(130); 
DECLARE @statsname nvarchar(130); 
DECLARE @command nvarchar(4000); 

-- Populate a temp table with a list of all column statistics in the database (user tables only). 
SELECT [object_id], name
INTO #stats_work_to_do
FROM sys.stats
WHERE OBJECTPROPERTY([object_id], ''IsUserTable'') = 1
                AND (auto_created = 1 or user_created = 1) 

-- Declare the cursor for the list of stats to be processed.
DECLARE stats_cursor CURSOR FOR SELECT * FROM #stats_work_to_do;
-- Open the cursor.
OPEN stats_cursor;
-- Loop through the stats_cursor updating all column stats with a full scan.
WHILE (1=1)
    BEGIN;
        FETCH NEXT
           FROM stats_cursor
           INTO @objectid, @statsname;
        IF @@FETCH_STATUS < 0 BREAK;
                                SELECT @objectname = QUOTENAME(o.name), @schemaname = QUOTENAME(s.name)
        FROM sys.objects AS o
        JOIN sys.schemas as s ON s.schema_id = o.schema_id
        WHERE o.object_id = @objectid;
        SET @command = N''UPDATE STATISTICS '' + @schemaname + N''.'' + @objectname + N'' '' + @statsname + N'' WITH FULLSCAN'';
        EXEC (@command);
        PRINT N''Executed: '' + @command;
    END;
-- Close and deallocate the cursor.
CLOSE stats_cursor;
DEALLOCATE stats_cursor;

-- Drop the temporary table.
DROP TABLE #stats_work_to_do;
GO

', 
		@database_name=N'AXPPROD', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Index/statistics maintenance]    Script Date: 04/11/2014 14:25:55 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Index/statistics maintenance', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--Script to automate index/statistics maintenance.
                --Script 2 of 2: 
                --Reorganize indexes with 10% to 30% fragmentation. 
                --Rebuild indexes with greater than 30% fragmentation.
                --Update statistics on indexes with less than 30% fragmentation

-- Ensure a USE <databasename> statement has been executed first.
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @objectid int;
DECLARE @indexid int;
DECLARE @partitioncount bigint;
DECLARE @schemaname nvarchar(130); 
DECLARE @objectname nvarchar(130); 
DECLARE @indexname nvarchar(130); 
DECLARE @partitionnum bigint;
DECLARE @partitions bigint;
DECLARE @frag float;
DECLARE @command nvarchar(4000); 
-- Conditionally select tables and indexes from the sys.dm_db_index_physical_stats function 
-- and convert object and index IDs to names.
SELECT
    object_id AS objectid,
    index_id AS indexid,
    partition_number AS partitionnum,
    avg_fragmentation_in_percent AS frag
INTO #work_to_do
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL , NULL, ''LIMITED'')
WHERE avg_fragmentation_in_percent > 10.0 AND index_id > 0 and page_count > 0;
-- Declare the cursor for the list of partitions to be processed.
DECLARE partitions CURSOR FOR SELECT * FROM #work_to_do;
-- Open the cursor.
OPEN partitions;
-- Loop through the partitions.
WHILE (1=1)
    BEGIN;
        FETCH NEXT
           FROM partitions
           INTO @objectid, @indexid, @partitionnum, @frag;
        IF @@FETCH_STATUS < 0 BREAK;
        SELECT @objectname = QUOTENAME(o.name), @schemaname = QUOTENAME(s.name)
        FROM sys.objects AS o
        JOIN sys.schemas as s ON s.schema_id = o.schema_id
        WHERE o.object_id = @objectid;
        SELECT @indexname = QUOTENAME(name)
        FROM sys.indexes
        WHERE  object_id = @objectid AND index_id = @indexid;
        SELECT @partitioncount = count (*)
        FROM sys.partitions
        WHERE object_id = @objectid AND index_id = @indexid;
-- 30 is an arbitrary decision point at which to switch between reorganizing and rebuilding.
        IF @frag < 30.0
            SET @command = N''ALTER INDEX '' + @indexname + N'' ON '' + @schemaname + N''.'' + @objectname + N'' REORGANIZE'';
        IF @frag >= 30.0
            SET @command = N''ALTER INDEX '' + @indexname + N'' ON '' + @schemaname + N''.'' + @objectname + N'' REBUILD WITH (FILLFACTOR = 70)'';
        IF @partitioncount > 1
            SET @command = @command + N'' PARTITION='' + CAST(@partitionnum AS nvarchar(10));
        EXEC (@command);
        PRINT N''Executed: '' + @command;
        IF @frag < 30.0
                  SET @command = N''UPDATE STATISTICS '' + @schemaname + N''.'' + @objectname + N'' '' + @indexname + N'' WITH FULLSCAN'';
        EXEC (@command);
        PRINT N''Executed: '' + @command;
    END;
-- Close and deallocate the cursor.
CLOSE partitions;
DEALLOCATE partitions;
-- Drop the temporary table.
DROP TABLE #work_to_do;
GO
', 
		@database_name=N'AXPPROD', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO


