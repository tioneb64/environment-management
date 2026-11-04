--====================================================================================== 
 --> Pour une période donnée, obtenir les requêtes exécutées et leurs contextes d'éxécutions  
 --====================================================================================== 
  
 DECLARE @DateHeureDebut varchar(20) -- Date et heure de début  
 ,@DateHeureFin varchar(20); -- Date et heure de fin  
-- Période :  
 SET @DateHeureDebut = '2015-12-2 15:25:00'  
 SET @DateHeureFin = '2015-12-2 15:40:00'   
 BEGIN  
 SELECT convert(varchar(19),creation_time,120)AS [Dateheure],   
 total_worker_time/execution_count AS [Avg CPU Time],  
 total_logical_reads,   
 execution_count,   
 (total_elapsed_time - total_worker_time) / qs.execution_count AS [Avg Blocked],   
 SUBSTRING(st.text, (qs.statement_start_offset/2)+1,((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)   
 ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS statement_text ,query_plan   
 FROM sys.dm_exec_query_stats AS qs   
 CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st   
 CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle)  
 WHERE creation_time >= CONVERT(datetime,@DateHeureDebut,120) AND creation_time <= CONVERT(datetime,@DateHeureFin,120)  
 ORDER BY creation_time DESC;  
 END  
  
 --====================================================================================== 
 --> Afficher les 50 dernières requêtes les plus consommatrices de CPU 
 --====================================================================================== 
  
 SELECT TOP 50 total_worker_time/execution_count AS [Avg CPU Time],   
 SUBSTRING(st.text, (qs.statement_start_offset/2)+1,((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)   
 ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS statement_text   
 FROM sys.dm_exec_query_stats AS qs   
 CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st   
 ORDER BY total_worker_time/execution_count DESC;  
  
 --====================================================================================== 
 --> Afficher les 50 dernières requêtes les plus consommatrices de CPU et les plans d'éxécutions correspondants 
 --====================================================================================== 
  
 SELECT TOP 50 total_worker_time/execution_count AS [Avg CPU Time],  
 SUBSTRING(st.text, (qs.statement_start_offset/2)+1,((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)   
 ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS statement_text,query_plan   
 FROM sys.dm_exec_query_stats AS qs   
 CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st   
 CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle)  
 ORDER BY total_worker_time/execution_count DESC; 
  
 --====================================================================================== 
 --> Afficher les 50 dernières requêtes exécutées 
 --====================================================================================== 
  
 SELECT TOP 50 creation_time,  
 total_worker_time/execution_count AS [Avg CPU Time],   
 SUBSTRING(st.text, (qs.statement_start_offset/2)+1,((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)   
 ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS statement_text   
 FROM sys.dm_exec_query_stats AS qs   
 CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st   
 ORDER BY creation_time DESC; 
  
 --====================================================================================== 
 --> Afficher les 50 dernières requêtes exécutées et les plans d'éxécutions correspondants 
 --====================================================================================== 
  
 SELECT TOP 50 creation_time,   
 total_worker_time/execution_count AS [Avg CPU Time],   
 SUBSTRING(st.text, (qs.statement_start_offset/2)+1,((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)   
 ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS statement_text ,query_plan   
 FROM sys.dm_exec_query_stats AS qs   
 CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st   
 CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle)  
 ORDER BY creation_time DESC; 
  
 --====================================================================================== 
 --> Afficher les 50 requêtes les + fréquemment exécutées  
 --====================================================================================== 
  
 SELECT TOP 50 creation_time,   
 execution_count,  
 total_worker_time/execution_count AS [Avg CPU Time],  
 total_logical_reads,  
 SUBSTRING(st.text, (qs.statement_start_offset/2)+1,((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)   
 ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS statement_text   
 FROM sys.dm_exec_query_stats AS qs   
 CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st   
 ORDER BY execution_count DESC; 
  
 --====================================================================================== 
 --> Afficher les 50 requêtes les + fréquemment exécutées et les plans d'éxécutions correspondants  
 --====================================================================================== 
  
 SELECT TOP 50 creation_time,   
 execution_count,   
 total_worker_time/execution_count AS [Avg CPU Time],   
 total_logical_reads,   
 SUBSTRING(st.text, (qs.statement_start_offset/2)+1,((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)   
 ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS statement_text,query_plan   
 FROM sys.dm_exec_query_stats AS qs   
 CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st   
 CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle)  
 ORDER BY execution_count DESC; 
  
 --====================================================================================== 
 --> Afficher les 50 requêtes les + coûteuses en I/O logique (Lecture/Ecriture de données en mémoire)  
 --====================================================================================== 
  
 SELECT TOP 50 creation_time,   
 (total_logical_reads + total_logical_writes)AS [Total IO Logique] ,  
 (total_logical_reads + total_logical_writes) / qs.execution_count AS [Avg IO Logique],  
 total_worker_time/execution_count AS [Avg CPU Time],   
 SUBSTRING(st.text, (qs.statement_start_offset/2)+1,((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)   
 ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS statement_text   
 FROM sys.dm_exec_query_stats AS qs   
 CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st   
 ORDER BY [Avg IO Logique] DESC; 
  
 --====================================================================================== 
 --> Afficher les 50 requêtes les + coûteuses en I/O logique (Lecture/Ecriture de données en mémoire) et les plans d'éxécutions correspondants  
 --====================================================================================== 
  
 SELECT TOP 50 creation_time,   
 (total_logical_reads + total_logical_writes)AS [Total IO Logique] ,   
 (total_logical_reads + total_logical_writes) / qs.execution_count AS [Avg IO Logique],   
 total_worker_time/execution_count AS [Avg CPU Time],   
 SUBSTRING(st.text, (qs.statement_start_offset/2)+1,((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)   
 ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS statement_text,query_plan   
 FROM sys.dm_exec_query_stats AS qs   
 CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st   
 CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle)  
 ORDER BY [Avg IO Logique] DESC; 
  
 --====================================================================================== 
 --> Afficher les 50 requêtes les + lentes (les moins performantes)  
 --====================================================================================== 
  
 SELECT TOP 50 creation_time,   
 (total_elapsed_time - total_worker_time)AS [Total Blocked] ,  
 (total_elapsed_time - total_worker_time) / qs.execution_count AS [Avg Blocked],  
 total_worker_time/execution_count AS [Avg CPU Time],   
 SUBSTRING(st.text, (qs.statement_start_offset/2)+1,((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)   
 ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS statement_text   
 FROM sys.dm_exec_query_stats AS qs   
 CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st   
 ORDER BY [Avg Blocked] DESC;  
  
 --====================================================================================== 
 --> Afficher les 50 requêtes les + lentes (les moins performantes) et les plans d'éxécutions correspondants  
 --====================================================================================== 
  
 SELECT TOP 50 creation_time,   
 (total_elapsed_time - total_worker_time)AS [Total Blocked] ,   
 (total_elapsed_time - total_worker_time) / qs.execution_count AS [Avg Blocked],   
 total_worker_time/execution_count AS [Avg CPU Time],   
 SUBSTRING(st.text, (qs.statement_start_offset/2)+1,((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)   
 ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS statement_text,query_plan   
 FROM sys.dm_exec_query_stats AS qs   
 CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st   
 CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle)  
 ORDER BY [Avg Blocked] DESC