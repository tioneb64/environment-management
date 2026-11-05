/*=====================================================================
  Recensement des connecteurs et adresses dans une base Dynamics AX 2012
  ---------------------------------------------------------------------
  Objet    : trouver les tables et champs AX qui contiennent des chemins
             de fichiers, des URL, des adresses e-mail ou des noms de
             serveurs et bases de production.
             Sert à construire la liste des connecteurs à neutraliser
             après une restauration (fonctions DAU-03, DAU-15, DAU-25).

  Où       : sur une COPIE récente de la production, par exemple
             AXRECBIS sur DNTAXRECETTE\DNTAXRECETTE.
             Ouvrir le script dans SSMS avec la base AX sélectionnée.

  Effet    : LECTURE SEULE. Aucune écriture dans la base AX : seules des
             tables temporaires (#) sont créées. Lecture sans verrou
             (READ UNCOMMITTED).
             Refuse de s'exécuter sur AXPROD (voir @AllowProduction).

  Durée    : quelques minutes ; dépend de @MaxRowsPerTable.
             La progression s'affiche dans l'onglet Messages.

  Résultats (6 jeux) :
    1. Détail : une ligne par table, champ et catégorie trouvée,
       avec le nombre de lignes concernées et deux exemples de valeur.
    2. Synthèse par table.
    3. Tables connues (standard AX ou spécifiques) sans résultat.
    4. Grandes tables non parcourues dont un champ a un nom évocateur
       (PATH, FOLDER, URL, EMAIL...) : à examiner à part.
    5. Tables en erreur.
    6. Statistiques d'exécution.
  Pour transmettre : clic droit sur chaque grille, « Copier avec en-têtes »,
  puis coller dans Excel.
=====================================================================*/

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;   -- requis par les méthodes XML (désactivé par défaut sous sqlcmd)
SET ANSI_NULLS ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

/*---------------------------------------------------------------------
  Paramètres
---------------------------------------------------------------------*/
DECLARE @MaxRowsPerTable      bigint = 10000;    -- tables plus grandes ignorées (sauf tables connues)
DECLARE @MaxRowsKnownTable    bigint = 2000000;  -- limite pour les tables connues
DECLARE @MinColumnLength      int    = 10;       -- champs plus courts ignorés (codes)
DECLARE @SampleLength         int    = 300;      -- longueur des exemples de valeur
DECLARE @AllowProduction      bit    = 0;        -- 1 pour autoriser l'exécution sur AXPROD (déconseillé)

/* Noms de serveurs et de bases de production recherchés
   (recherche « contient », insensible à la casse). À compléter. */
DECLARE @ProductionNames TABLE (Name nvarchar(100) NOT NULL);
INSERT INTO @ProductionNames (Name) VALUES
     (N'DNTPRD')      -- DNTPRDAOS0x, DNTPRDBAT0x, DNTPRDRS0x, DNTPRDSP01
    ,(N'DNTAXPROD')   -- instance SQL et partage de sauvegarde de production
    ,(N'DNTPHYAX')    -- serveur des scripts
    ,(N'DNTCLUSQL')   -- cluster SQL (partage des fichiers .axc)
    ,(N'DNTAXAS')     -- Analysis Services de production
    ,(N'AXPROD');     -- nom de la base de production

/*---------------------------------------------------------------------
  Garde-fous
---------------------------------------------------------------------*/
IF DB_NAME() = N'AXPROD' AND @AllowProduction = 0
BEGIN
    RAISERROR(N'Exécution refusée sur AXPROD : lancez ce script sur une copie (AXRECBIS par exemple).', 16, 1);
    RETURN;
END;

IF OBJECT_ID(N'dbo.SYSSERVERCONFIG', N'U') IS NULL
BEGIN
    RAISERROR(N'La base courante ne semble pas être une base de données AX 2012 (table SYSSERVERCONFIG absente). Sélectionnez la base AX.', 16, 1);
    RETURN;
END;

DECLARE @StartTime datetime2(0) = SYSDATETIME();
DECLARE @Msg nvarchar(400);
SET @Msg = CONCAT(N'Recensement sur la base ', DB_NAME(), N' de ', @@SERVERNAME, N', début ', CONVERT(nvarchar(19), @StartTime, 120));
RAISERROR(@Msg, 0, 1) WITH NOWAIT;

/*---------------------------------------------------------------------
  Motifs recherchés, par catégorie
---------------------------------------------------------------------*/
IF OBJECT_ID(N'tempdb..#Patterns')      IS NOT NULL DROP TABLE #Patterns;
IF OBJECT_ID(N'tempdb..#Categories')    IS NOT NULL DROP TABLE #Categories;
IF OBJECT_ID(N'tempdb..#KnownTables')   IS NOT NULL DROP TABLE #KnownTables;
IF OBJECT_ID(N'tempdb..#TableRows')     IS NOT NULL DROP TABLE #TableRows;
IF OBJECT_ID(N'tempdb..#Columns')       IS NOT NULL DROP TABLE #Columns;
IF OBJECT_ID(N'tempdb..#TablesToScan')  IS NOT NULL DROP TABLE #TablesToScan;
IF OBJECT_ID(N'tempdb..#Hits')          IS NOT NULL DROP TABLE #Hits;
IF OBJECT_ID(N'tempdb..#Errors')        IS NOT NULL DROP TABLE #Errors;

/* COLLATE DATABASE_DEFAULT : les tables temporaires prennent la collation
   de la base AX, pour éviter les conflits de collation avec tempdb. */
CREATE TABLE #Patterns
(
     Priority  tinyint       NOT NULL
    ,Category  nvarchar(60)  COLLATE DATABASE_DEFAULT NOT NULL
    ,Pattern   nvarchar(200) COLLATE DATABASE_DEFAULT NOT NULL
);

/* Priorité 1 : noms de serveurs et bases de production (ajoutés plus bas) */
INSERT INTO #Patterns (Priority, Category, Pattern) VALUES
     (2, N'Chemin réseau (UNC)',           N'%\\[A-Za-z0-9]%')
    ,(3, N'Chemin local (lecteur)',        N'%[A-Za-z]:\%')
    ,(4, N'URL',                           N'%http://%')
    ,(4, N'URL',                           N'%https://%')
    ,(4, N'URL',                           N'%ftp://%')
    ,(4, N'URL',                           N'%sftp://%')
    ,(4, N'URL',                           N'%net.tcp://%')
    ,(5, N'Adresse e-mail',                N'%_@_%._%');

INSERT INTO #Patterns (Priority, Category, Pattern)
SELECT 1, N'Serveur ou base de production', N'%' + Name + N'%'
FROM @ProductionNames;

SELECT DISTINCT Priority, Category
INTO #Categories
FROM #Patterns;

/*---------------------------------------------------------------------
  Tables connues (standard AX 2012 et spécifiques Daunat)
  Elles sont parcourues même si elles dépassent @MaxRowsPerTable.
  Liste à compléter au fil du recensement.
---------------------------------------------------------------------*/
CREATE TABLE #KnownTables
(
     TableName   sysname       COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY
    ,Domain      nvarchar(60)  COLLATE DATABASE_DEFAULT NOT NULL
    ,Description nvarchar(200) COLLATE DATABASE_DEFAULT NOT NULL
);

INSERT INTO #KnownTables (TableName, Domain, Description) VALUES
     (N'SYSEMAILPARAMETERS',         N'Messagerie',             N'Serveur SMTP, port et compte d''envoi')
    ,(N'SYSEMAILSMTPPASSWORD',       N'Messagerie',             N'Mot de passe SMTP')
    ,(N'SYSOUTGOINGEMAILTABLE',      N'Messagerie',             N'File d''attente des e-mails sortants (à vider hors production)')
    ,(N'DOCUPARAMETERS',             N'Gestion documentaire',   N'Dossier d''archive des documents')
    ,(N'DOCUTYPE',                   N'Gestion documentaire',   N'Dossier de stockage par type de document')
    ,(N'DOCUVALUE',                  N'Gestion documentaire',   N'Emplacement des fichiers joints')
    ,(N'AIFCHANNEL',                 N'AIF',                    N'Adresses de transport des canaux')
    ,(N'AIFINBOUNDPORT',             N'AIF',                    N'Ports entrants')
    ,(N'AIFOUTBOUNDPORT',            N'AIF',                    N'Ports sortants')
    ,(N'AIFWEBSITES',                N'AIF',                    N'Sites web des services')
    ,(N'DMFPARAMETERS',              N'Import / export (DMF)',  N'Dossier partagé de travail')
    ,(N'DMFDEFINITIONGROUPENTITY',   N'Import / export (DMF)',  N'Fichiers source des imports')
    ,(N'EPWEBSITEPARAMETERS',        N'Enterprise Portal',      N'URL interne et externe')
    ,(N'SRSSERVERS',                 N'Reporting Services',     N'Serveurs et URL de rapports')
    ,(N'BIANALYSISSERVER',           N'Analysis Services',      N'Serveur Analysis Services')
    ,(N'BICONFIGURATION',            N'Analysis Services',      N'Chaîne de connexion')
    ,(N'SYSGLOBALCONFIGURATION',     N'Système',                N'Serveur d''aide, AOS de supervision')
    ,(N'SYSSERVERCONFIG',            N'AOS et batch',           N'Configuration des AOS')
    ,(N'BATCHSERVERGROUP',           N'AOS et batch',           N'Serveurs des groupes batch')
    ,(N'SYSBCPROXYUSERACCOUNT',      N'Système',                N'Compte proxy du Business Connector')
    ,(N'SYSCORPNETPRINTERS',         N'Impression',             N'Imprimantes réseau')
    ,(N'BISPARAMETERS',              N'EDI (spécifique)',       N'Paramètres EDI, type d''environnement')
    ,(N'WHSWORKUSERDISPLAYSETTINGS', N'WMS',                    N'Feuille de style de l''application web WMS');

/*---------------------------------------------------------------------
  Nombre de lignes par table et champs texte candidats
---------------------------------------------------------------------*/
SELECT ps.object_id AS ObjectId, SUM(ps.row_count) AS RowsCount
INTO #TableRows
FROM sys.dm_db_partition_stats AS ps
WHERE ps.index_id IN (0, 1)
GROUP BY ps.object_id;

SELECT
     t.object_id   AS ObjectId
    ,t.name        AS TableName
    ,c.name        AS ColumnName
    ,ty.name       AS TypeName
INTO #Columns
FROM sys.tables  AS t
JOIN sys.schemas AS s  ON s.schema_id = t.schema_id
JOIN sys.columns AS c  ON c.object_id = t.object_id
JOIN sys.types   AS ty ON ty.user_type_id = c.user_type_id
WHERE s.name = N'dbo'
  AND t.is_ms_shipped = 0
  AND ty.name IN (N'nvarchar', N'varchar', N'nchar', N'char', N'ntext', N'text')
  AND c.is_computed = 0
  AND c.name NOT IN (N'DATAAREAID', N'CREATEDBY', N'MODIFIEDBY', N'DEL_CREATEDBY', N'DEL_MODIFIEDBY')
  AND (    c.max_length = -1
        OR ty.name IN (N'ntext', N'text')
        OR c.max_length / CASE WHEN ty.name IN (N'nvarchar', N'nchar') THEN 2 ELSE 1 END >= @MinColumnLength );

SELECT DISTINCT
     col.ObjectId
    ,col.TableName
    ,tr.RowsCount
    ,CASE WHEN kt.TableName IS NULL THEN 0 ELSE 1 END AS IsKnown
INTO #TablesToScan
FROM #Columns AS col
JOIN #TableRows AS tr ON tr.ObjectId = col.ObjectId
LEFT JOIN #KnownTables AS kt ON kt.TableName = col.TableName
WHERE tr.RowsCount > 0
  AND (    tr.RowsCount <= @MaxRowsPerTable
        OR (kt.TableName IS NOT NULL AND tr.RowsCount <= @MaxRowsKnownTable) );

/*---------------------------------------------------------------------
  Parcours des tables
---------------------------------------------------------------------*/
CREATE TABLE #Hits
(
     TableName  sysname        COLLATE DATABASE_DEFAULT NOT NULL
    ,ColumnName sysname        COLLATE DATABASE_DEFAULT NOT NULL
    ,Category   nvarchar(60)   COLLATE DATABASE_DEFAULT NOT NULL
    ,MatchCount bigint         NOT NULL
    ,SampleMin  nvarchar(4000) COLLATE DATABASE_DEFAULT NULL
    ,SampleMax  nvarchar(4000) COLLATE DATABASE_DEFAULT NULL
    ,TableRows  bigint         NOT NULL
);

CREATE TABLE #Errors
(
     TableName    sysname        COLLATE DATABASE_DEFAULT NOT NULL
    ,ErrorMessage nvarchar(4000) COLLATE DATABASE_DEFAULT NULL
);

DECLARE @TableId   int;
DECLARE @TableName sysname;
DECLARE @Rows      bigint;
DECLARE @Values    nvarchar(max);
DECLARE @Sql       nvarchar(max);
DECLARE @Done      int = 0;
DECLARE @Total     int = (SELECT COUNT(*) FROM #TablesToScan);

SET @Msg = CONCAT(@Total, N' tables à parcourir.');
RAISERROR(@Msg, 0, 1) WITH NOWAIT;

DECLARE c_tables CURSOR LOCAL FAST_FORWARD FOR
    SELECT ObjectId, TableName, RowsCount
    FROM #TablesToScan
    ORDER BY TableName;

OPEN c_tables;
FETCH NEXT FROM c_tables INTO @TableId, @TableName, @Rows;

WHILE @@FETCH_STATUS = 0
BEGIN
    /* Une ligne (nom du champ, valeur) par champ texte de la table */
    SET @Values = STUFF((
        SELECT N',(N' + QUOTENAME(c.ColumnName, N'''')
             + N',CONVERT(nvarchar(max),t.' + QUOTENAME(c.ColumnName) + N'))'
        FROM #Columns AS c
        WHERE c.ObjectId = @TableId
        ORDER BY c.ColumnName
        FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 1, N'');

    SET @Sql = N'
INSERT INTO #Hits (TableName, ColumnName, Category, MatchCount, SampleMin, SampleMax, TableRows)
SELECT @t, v.ColumnName, cat.Category, COUNT(*),
       MIN(LEFT(v.Val, @len)), MAX(LEFT(v.Val, @len)), @r
FROM dbo.' + QUOTENAME(@TableName) + N' AS t WITH (NOLOCK)
CROSS APPLY (VALUES ' + @Values + N') AS v(ColumnName, Val)
CROSS JOIN #Categories AS cat
WHERE v.Val IS NOT NULL
  AND EXISTS (SELECT 1 FROM #Patterns AS p
              WHERE p.Category = cat.Category AND v.Val LIKE p.Pattern)
GROUP BY v.ColumnName, cat.Category;';

    BEGIN TRY
        EXEC sys.sp_executesql
             @Sql
            ,N'@t sysname, @r bigint, @len int'
            ,@t = @TableName, @r = @Rows, @len = @SampleLength;
    END TRY
    BEGIN CATCH
        INSERT INTO #Errors (TableName, ErrorMessage) VALUES (@TableName, ERROR_MESSAGE());
    END CATCH;

    SET @Done += 1;
    IF @Done % 200 = 0
    BEGIN
        SET @Msg = CONCAT(N'... ', @Done, N' / ', @Total, N' tables parcourues');
        RAISERROR(@Msg, 0, 1) WITH NOWAIT;
    END;

    FETCH NEXT FROM c_tables INTO @TableId, @TableName, @Rows;
END;

CLOSE c_tables;
DEALLOCATE c_tables;

/*---------------------------------------------------------------------
  1. Détail
---------------------------------------------------------------------*/
SELECT
     cat.Category                       AS [Catégorie]
    ,h.TableName                        AS [Table]
    ,h.ColumnName                       AS [Champ]
    ,ISNULL(kt.Domain, N'')             AS [Domaine connu]
    ,h.MatchCount                       AS [Lignes concernées]
    ,h.TableRows                        AS [Lignes de la table]
    ,h.SampleMin                        AS [Exemple 1]
    ,CASE WHEN h.SampleMax = h.SampleMin THEN N'' ELSE h.SampleMax END AS [Exemple 2]
FROM #Hits AS h
JOIN #Categories AS cat ON cat.Category = h.Category
LEFT JOIN #KnownTables AS kt ON kt.TableName = h.TableName
ORDER BY cat.Priority, h.TableName, h.ColumnName;

/*---------------------------------------------------------------------
  2. Synthèse par table
---------------------------------------------------------------------*/
SELECT
     h.TableName                        AS [Table]
    ,ISNULL(kt.Domain, N'')             AS [Domaine connu]
    ,MAX(h.TableRows)                   AS [Lignes de la table]
    ,COUNT(DISTINCT h.ColumnName)       AS [Champs concernés]
    ,STUFF((SELECT DISTINCT N', ' + h2.Category
            FROM #Hits AS h2
            WHERE h2.TableName = h.TableName
            FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, N'') AS [Catégories]
    ,MAX(CASE WHEN h.Category = N'Serveur ou base de production' THEN 1 ELSE 0 END) AS [Référence la production]
FROM #Hits AS h
LEFT JOIN #KnownTables AS kt ON kt.TableName = h.TableName
GROUP BY h.TableName, kt.Domain
ORDER BY [Référence la production] DESC, h.TableName;

/*---------------------------------------------------------------------
  3. Tables connues sans résultat
---------------------------------------------------------------------*/
SELECT
     kt.TableName   AS [Table]
    ,kt.Domain      AS [Domaine]
    ,kt.Description AS [Description]
    ,CASE
        WHEN OBJECT_ID(N'dbo.' + QUOTENAME(kt.TableName), N'U') IS NULL THEN N'Table absente de la base'
        WHEN tr.RowsCount = 0                                        THEN N'Table vide'
        WHEN tr.RowsCount > @MaxRowsKnownTable                       THEN N'Non parcourue (trop grande)'
        ELSE N'Parcourue, aucune valeur trouvée'
     END            AS [Constat]
    ,tr.RowsCount   AS [Lignes de la table]
FROM #KnownTables AS kt
LEFT JOIN #TableRows AS tr ON tr.ObjectId = OBJECT_ID(N'dbo.' + QUOTENAME(kt.TableName), N'U')
WHERE NOT EXISTS (SELECT 1 FROM #Hits AS h WHERE h.TableName = kt.TableName)
ORDER BY kt.Domain, kt.TableName;

/*---------------------------------------------------------------------
  4. Grandes tables non parcourues avec des champs au nom évocateur
---------------------------------------------------------------------*/
SELECT
     c.TableName   AS [Table]
    ,MAX(tr.RowsCount) AS [Lignes de la table]
    ,STUFF((SELECT N', ' + c2.ColumnName
            FROM #Columns AS c2
            WHERE c2.ObjectId = c.ObjectId
              AND (   c2.ColumnName LIKE N'%PATH%'      OR c2.ColumnName LIKE N'%FOLDER%'
                   OR c2.ColumnName LIKE N'%DIRECTORY%' OR c2.ColumnName LIKE N'%URL%'
                   OR c2.ColumnName LIKE N'%URI%'       OR c2.ColumnName LIKE N'%FILE%'
                   OR c2.ColumnName LIKE N'%EMAIL%'     OR c2.ColumnName LIKE N'%SERVER%'
                   OR c2.ColumnName LIKE N'%HOST%'      OR c2.ColumnName LIKE N'%REPERTOIRE%'
                   OR c2.ColumnName LIKE N'%CHEMIN%'    OR c2.ColumnName LIKE N'%DOSSIER%')
            ORDER BY c2.ColumnName
            FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, N'') AS [Champs évocateurs]
FROM #Columns AS c
JOIN #TableRows AS tr ON tr.ObjectId = c.ObjectId
WHERE NOT EXISTS (SELECT 1 FROM #TablesToScan AS ts WHERE ts.ObjectId = c.ObjectId)
  AND tr.RowsCount > 0
  AND (   c.ColumnName LIKE N'%PATH%'      OR c.ColumnName LIKE N'%FOLDER%'
       OR c.ColumnName LIKE N'%DIRECTORY%' OR c.ColumnName LIKE N'%URL%'
       OR c.ColumnName LIKE N'%URI%'       OR c.ColumnName LIKE N'%FILE%'
       OR c.ColumnName LIKE N'%EMAIL%'     OR c.ColumnName LIKE N'%SERVER%'
       OR c.ColumnName LIKE N'%HOST%'      OR c.ColumnName LIKE N'%REPERTOIRE%'
       OR c.ColumnName LIKE N'%CHEMIN%'    OR c.ColumnName LIKE N'%DOSSIER%')
GROUP BY c.ObjectId, c.TableName
ORDER BY c.TableName;

/*---------------------------------------------------------------------
  5. Tables en erreur
---------------------------------------------------------------------*/
SELECT TableName AS [Table], ErrorMessage AS [Erreur]
FROM #Errors
ORDER BY TableName;

/*---------------------------------------------------------------------
  6. Statistiques
---------------------------------------------------------------------*/
SELECT
     DB_NAME()                                              AS [Base]
    ,@@SERVERNAME                                           AS [Instance]
    ,@StartTime                                             AS [Début]
    ,DATEDIFF(SECOND, @StartTime, SYSDATETIME())            AS [Durée (s)]
    ,@Total                                                 AS [Tables parcourues]
    ,(SELECT COUNT(*) FROM #Errors)                         AS [Tables en erreur]
    ,(SELECT COUNT(DISTINCT TableName) FROM #Hits)          AS [Tables avec résultat]
    ,(SELECT COUNT(*) FROM #Hits)                           AS [Lignes de détail]
    ,@MaxRowsPerTable                                       AS [Limite lignes par table]
    ,(SELECT COUNT(*) FROM #TableRows AS tr
      WHERE tr.RowsCount > @MaxRowsPerTable
        AND EXISTS (SELECT 1 FROM #Columns AS c WHERE c.ObjectId = tr.ObjectId)
        AND NOT EXISTS (SELECT 1 FROM #TablesToScan AS ts WHERE ts.ObjectId = tr.ObjectId))
                                                            AS [Grandes tables non parcourues];

SET @Msg = CONCAT(N'Terminé en ', DATEDIFF(SECOND, @StartTime, SYSDATETIME()), N' s.');
RAISERROR(@Msg, 0, 1) WITH NOWAIT;
