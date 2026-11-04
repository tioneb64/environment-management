# Existant : scripts hérités de gestion des environnements AX 2012 R3

|  |  |
| :- | :- |
|Document|Inventaire et fonctionnement des scripts SQL hérités du dossier `scripts/`|
|Objectif|Servir de référence fonctionnelle pour concevoir le nouvel outil de gestion des environnements|
|Date|4 novembre 2026|
|Périmètre|Les 56 fichiers du dossier `scripts/` (scripts SQL, fichiers `.axc`, raccourcis)|

> [!NOTE]
> Ce document décrit **ce que font** les scripts, pas leurs défauts. Les écarts entre environnements et les questions à trancher sont regroupés en fin de document (sections 7 et 8), parce que le nouvel outil devra choisir un comportement unique.

## Sommaire

1. [Vue d'ensemble](#1-vue-densemble)
2. [Inventaire des fichiers](#2-inventaire-des-fichiers)
3. [Fonctions repérées](#3-fonctions-repérées)
4. [Paramétrage par environnement](#4-paramétrage-par-environnement)
5. [Déroulé d'un rafraîchissement par environnement](#5-déroulé-dun-rafraîchissement-par-environnement)
6. [Accès client AX](#6-accès-client-ax)
7. [Écarts entre environnements](#7-écarts-entre-environnements)
8. [Questions ouvertes](#8-questions-ouvertes)

## 1. Vue d'ensemble

Les scripts sont écrits en T-SQL et lancés depuis SSMS ou `sqlcmd` sur l'instance hors production `DNTAXRECETTE\DNTAXRECETTE`. Les actions sur Windows (arrêt et démarrage de services, appel d'un autre script) passent par `xp_cmdshell`, activé au début de chaque script et désactivé à la fin.

Le flux principal est le **rafraîchissement d'un environnement cible à partir des sauvegardes d'un environnement source** :

```
Arrêt des services cible (AOS, Management Reporter)
  → coupure des connexions sur la base cible
  → suppression puis restauration des 3 bases (données, _model, Baseline)
  → renommage des fichiers logiques, mode SIMPLE, réduction du journal
  → paramétrage AX propre à la cible (script update_AX<ENV>_parameters_FROM_PROD.sql)
  → redémarrage des services cible
```

Les autres scripts couvrent les droits en lecture seule, la maintenance des index et statistiques, le diagnostic des performances et l'accès des postes au client AX.

## 2. Inventaire des fichiers

### 2.1 Rafraîchissement (copie de bases)

| Fichier | Source → cible | Version en usage ? |
|---|---|---|
| `Copy_PROD_To_PPROD.sql` | PROD → PPROD | Oui (dossier de sauvegarde forcé vers le nœud 2) |
| `Copy_PROD_To_PPROD_2026-09-09.sql` | PROD → PPROD | Version datée, sans le dossier forcé |
| `Copy_PROD_To_REC.sql` | PROD → REC | Oui |
| `Copy_PROD_To_REC_save.sql` | PROD → REC | Sauvegarde d'une version précédente |
| `Copy_PROD_To_RECBIS.sql` | PROD → RECBIS | Oui |
| `Copy_PROD_To_RECBIS_save.sql` | PROD → RECBIS | Sauvegarde d'une version précédente |
| `Copy_PROD_To_RECTER.sql` | PROD → RECTER | Oui |
| `Copy_PROD_To_RECTER - Copie.sql` | PROD → RECTER | Ancienne méthode (`RESTORE` depuis un backup device) |
| `Copy_PROD_To_BUILD.sql` | PROD → BUILD | Oui, ancienne méthode (`RESTORE` depuis un backup device) |
| `Copy_REC_To_DEV.sql` | REC → DEV | Oui, avec paramétrage et services désactivés (en commentaire) |
| `avant_modif_capdata_ticket_1040592/Copy_PROD_To_*.sql` | PROD → PPROD, REC, RECBIS, RECTER | Archives : avant l'intervention CapData du 29/04/2026 |
| `apres_modif_capdata_ticket_1040592/Copy_PROD_To_*.sql` | PROD → PPROD, REC, RECBIS, RECTER | Archives : juste après l'intervention CapData |

### 2.2 Paramétrage AX après copie

Chaque environnement a deux variantes :

- **`update_AX<ENV>_parameters_FROM_PROD.sql`** : appelée après une copie de la production. Elle **supprime** les lignes qui désignent les serveurs de production puis met à jour le reste.
- **`update_AX<ENV>_parameters.sql`** : mise à jour seule, sans suppression (pour repasser le paramétrage sur une base déjà propre à l'environnement).

| Fichier | Environnement | Appelé par |
|---|---|---|
| `update_AXPPROD_parameters_FROM_PROD.sql` / `update_AXPPROD_parameters.sql` | PPROD | `Copy_PROD_To_PPROD.sql` |
| `update_AXREC_parameters_FROM_PROD.sql` / `update_AXREC_parameters.sql` | REC | `Copy_PROD_To_REC.sql` |
| `update_AXRECBIS_parameters_FROM_PROD.sql` / `update_AXRECBIS_parameters.sql` | RECBIS | `Copy_PROD_To_RECBIS.sql` |
| `update_AXRECTER_parameters_FROM_PROD.sql` / `update_AXRECTER_parameters.sql` | RECTER | `Copy_PROD_To_RECTER.sql` |
| `update_AXBUILD_parameters_FROM_PROD.sql` | BUILD | `Copy_PROD_To_BUILD.sql` |
| `update_AXDEV_parameters_FROM_PROD.sql` / `update_AXDEV_parameters.sql` | DEV | aucun |
| `update_AXDEV_parameters_FROM_REC a mofifier.sql` | DEV | aucun (appel en commentaire dans `Copy_REC_To_DEV.sql`) |
| `Save_scripts_anc_cluster/update_AXPROD_parameters.sql` | PROD | aucun (réinjection de la topologie de production) |

Les scripts de copie appellent la version présente sur `\\DNTPHYAX01\c$\scripts\`, pas celle du dépôt.

### 2.3 Autres scripts

| Fichier | Rôle |
|---|---|
| `usp_restore_database_from_directory.sql` | Procédure stockée CapData de restauration depuis un dossier de sauvegardes (installée dans `master` de l'instance hors production), voir F5 |
| `axreader_sur_ax01.sql` | Recrée l'utilisateur `axreader` (lecture seule) sur `AXPROD` |
| `axreader_sur_ax02.sql` | Recrée `axreader` sur `AXDEV`, `AXPPROD`, `AXREC`, `AXRECBIS` |
| `Requetes SQL Analyses - Aides.sql` | Requêtes de diagnostic des performances |
| `Save_scripts_anc_cluster/Plan de maintenance AX*.sql` | Jobs SQL Agent de maintenance des index et statistiques (AXDEV, AXFORM, AXPPROD, AXPROD, AXREC), ancien cluster |
| `Fichiers de configuration AX/*.axc` | Configurations du client AX par environnement et par couche |
| `Fichiers de configuration AX/*.lnk` | Raccourcis du client AX par environnement |

## 3. Fonctions repérées

Chaque fonction est décrite telle qu'elle existe aujourd'hui, avec les scripts où on la trouve.

### F1. Arrêt et démarrage des services d'un environnement

- **Ce que ça fait** : `sc \\<serveur> stop|start <service>` via `xp_cmdshell`, sans attendre ni vérifier l'état du service.
- **Services concernés** : AOS `AOS60$01` (ou `AOS60$02` pour BUILD) sur le serveur AOS de l'environnement ; Management Reporter `MR2012ProcessService` et `MR2012ApplicationService` sur `DNTRECMR01`.
- **Où** : début et fin de chaque `Copy_*.sql` (voir la matrice en section 5).

### F2. Inventaire des connexions sur une base

- **Ce que ça fait** : liste le nombre de connexions par connexion SQL (`sys.sysprocesses`) et les sessions actives (`sp_who2 'Active'`) sur la base cible. Résultat affiché, pas exploité.
- **Où** : tous les `Copy_*.sql`.

### F3. Coupure des connexions

- **Ce que ça fait** : `ALTER DATABASE [<base>] SET SINGLE_USER WITH ROLLBACK IMMEDIATE` (annule les transactions en cours).
- **Où** : explicitement dans `Copy_PROD_To_BUILD.sql` et `Copy_REC_To_DEV.sql` ; dans les autres, intégré à la suppression de la base (F4).

### F4. Suppression de la base cible

- **Ce que ça fait** : si la base existe, passage en `SINGLE_USER` puis `DROP DATABASE`. Aucune sauvegarde préalable.
- **Où** : `Copy_PROD_To_PPROD/REC/RECBIS/RECTER.sql` (méthode CapData), pour les 3 bases.

### F5. Restauration d'une base depuis une sauvegarde

Trois méthodes coexistent :

| Méthode | Principe | Où |
|---|---|---|
| **A. Backup device** | `RESTORE DATABASE [cible] FROM [AXPROD] WITH MOVE ... REPLACE` : le device logique `AXPROD` (ou `AXPROD_model`, `AXPRODBaseline`) pointe vers le fichier de sauvegarde quotidien | `Copy_PROD_To_BUILD.sql`, `Copy_PROD_To_RECTER - Copie.sql`, dossier `avant_modif_capdata…` |
| **B. Dernière sauvegarde complète connue de `msdb`** | Lecture de `msdb..backupset` / `backupmediafamily` (dernière sauvegarde `type = 'D'` de la base source), puis `RESTORE ... FROM DISK` | `Copy_REC_To_DEV.sql` |
| **C. Procédure CapData** | Déduction du dossier de sauvegarde à partir du chemin du backup device (`sys.backup_devices`), puis appel de `master.dbo.usp_restore_database_from_directory` avec : dossier de sauvegarde, nom de la base restaurée, dossiers des données et journaux, nom d'origine, nouveau propriétaire `DAUNAT\svc_sql`, correction des utilisateurs orphelins, `RECOVERY`. Restaure la dernière complète, la dernière différentielle et la chaîne des journaux (détail ci-dessous) | `Copy_PROD_To_PPROD/REC/RECBIS/RECTER.sql` |

Depuis la bascule du cluster, la méthode C **force le dossier de sauvegarde** à `\\Dntaxprod\L$\MSSQL13.DNTAXPROD\MSSQL\Backup` (commentaire « CAPDATA LPR Suite bascule »).

#### Fonctionnement de la procédure CapData (`scripts/usp_restore_database_from_directory.sql`)

1. **Exécution d'un script préalable** facultatif (`@pre_restore_script`).
2. **Liste de tous les fichiers du dossier** (`DIR /B` via `xp_cmdshell`, sans filtre sur l'extension).
3. **Lecture de l'en-tête de chaque fichier** (`RESTORE HEADERONLY`), puis conservation des seules sauvegardes de la base demandée (`@original_dbname`). Erreur si le dossier contient des sauvegardes d'une autre « incarnation » de la base (`BindingId` différent).
4. **Choix des sauvegardes à restaurer** :
   - la **dernière sauvegarde complète** commencée avant l'heure d'arrêt ;
   - la **dernière sauvegarde différentielle** basée sur cette complète, s'il y en a une ;
   - **toutes les sauvegardes de journal** qui suivent, dans l'ordre, jusqu'à la première commencée après l'heure d'arrêt.
5. **Heure d'arrêt** (`@stop_at_time`) : par défaut, l'heure de lancement de la procédure. La base restaurée reflète donc la production **au moment de la copie**, à 15 minutes près (la dernière sauvegarde de journal).
6. **Suppression de la base cible** si elle existe, puis **restauration** : `RESTORE DATABASE` (complète, puis différentielle) et `RESTORE LOG` pour chaque journal, avec `STOPAT` et `NORECOVERY`, fichiers déplacés vers `@data_directory` et `@log_directory`.
7. **Ouverture de la base** (`RESTORE ... WITH RECOVERY`) si `@recovery = 1`.
8. **Changement de propriétaire** (`@new_owner`, via `sp_changedbowner` en tant que `sa`).
9. **Rattachement des utilisateurs orphelins** aux connexions de même nom (`sp_change_users_login 'update_one'`) si `@auto_fix_orphaned_users = 1`.
10. **Exécution d'un script final** facultatif (`@post_restore_script`).

Avec `@only_generate_restore_script = 1`, la procédure **affiche les commandes de restauration sans rien exécuter** (ni suppression, ni restauration, ni scripts préalable et final). C'est un mode simulation utilisable sans risque.

#### Stratégie de sauvegarde de la production (déduite)

| Élément | Constat | Conclusion |
|---|---|---|
| Fichiers toutes les 15 minutes, de 10 Ko à plusieurs Go | La taille suit l'activité (quasi nulle la nuit, forte pendant les traitements) | Ce sont des **sauvegardes du journal de transactions**. Une différentielle grossit sans cesse depuis la dernière complète : elle ne peut pas retomber à 10 Ko sur une base de 1,5 To |
| Procédure qui enchaîne complète, différentielle et journaux | Conçue pour une chaîne de journaux | Les bases de production sont en mode de récupération **FULL** |
| Sauvegarde complète | Prise par la procédure quelle que soit sa date | Hebdomadaire (dimanche soir) d'après l'équipe, à confirmer avec `msdb` |
| Sauvegarde différentielle | Utilisée si elle existe | Présence non confirmée |

Conséquences pour le rafraîchissement :

- sans différentielle quotidienne, le nombre de journaux à rejouer **augmente au fil de la semaine** : jusqu'à environ 6 × 96 = 576 fichiers par base le samedi ;
- à chaque appel, la procédure lit l'en-tête de **tous** les fichiers du dossier, toutes bases et tous jours confondus, avant de commencer ;
- une coupure dans la chaîne des journaux (fichier manquant ou illisible) fait échouer la restauration.

Les fichiers restaurés vont dans `R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA\<base>.mdf` et `S:\MSSQL13.DNTAXRECETTE\MSSQL\Data\<base>_log.ldf`.

### F6. Préparation de la base restaurée

- Renommage des fichiers logiques : `ALTER DATABASE ... MODIFY FILE (NAME = N'AXPROD', NEWNAME = N'AXPPROD')`, idem pour le journal.
- Passage en mode de récupération `SIMPLE`.
- Réduction du journal (`DBCC SHRINKFILE ('<base>_log')`) : sur la base de données principale partout ; sur `_model` et `Baseline` seulement pour DEV. La réduction du fichier de données a été testée en 2017 puis abandonnée (« trop long »).

### F7. Création des bases cibles si elles n'existent pas

- `CREATE DATABASE` vide pour `AXDEV`, `AXDEV_model`, `AXDEVBaseline` avant la restauration.
- **Où** : `Copy_REC_To_DEV.sql` uniquement.

### F8. Réécriture des vues qui pointent vers la base `_model`

- **Pourquoi** : trois vues de la base de données AX font référence en dur au nom de la base `_model` de l'environnement source.
- **Ce que ça fait** : lit la définition de `DMFMODELELEMENT`, `SECURITYROLEALLTASKSVIEW` et `SECURITYFIELDSDENIEDACCESSSSOMEROLEVIEW` dans `sys.sql_modules`, remplace `AXREC_model` par `AXDEV_model` et `CREATE` par `ALTER`, puis exécute.
- **Où** : `Copy_REC_To_DEV.sql` uniquement. Une copie depuis la production (source `AXPROD_model`) n'en a pas besoin si les vues de production utilisent un nom générique, à vérifier (section 8).

### F9. Paramétrage AX propre à l'environnement

Appelé par `sqlcmd -E -SDNTAXRECETTE\DNTAXRECETTE -i\\DNTPHYAX01\c$\scripts\update_AX<ENV>_parameters_FROM_PROD.sql`.

| # | Domaine | Tables AX | Action (variante `_FROM_PROD`) |
|---|---|---|---|
| 1 | Serveurs AOS et batch | `BATCH`, `BATCHHISTORY` | `SERVERID` remplacé par l'AOS de l'environnement |
| 2 | Groupes de serveurs batch | `BATCHSERVERGROUP` | Suppression des serveurs autres que `01@DNTPRDAOS01`, puis `SERVERID` remplacé |
| 3 | Enterprise Portal | `EPWEBSITEPARAMETERS` | URL interne et externe remplacées (supprimées pour RECTER et BUILD) |
| 4 | Reporting Services | `SRSSERVERS` | Suppression des configurations autres que `RS01 AOS01` et celle de l'environnement, puis mise à jour de l'AOS, du serveur, de l'instance, des URL et de l'identifiant de configuration |
| 5 | Analysis Services | `BIANALYSISSERVER` | Suppression des serveurs non par défaut, puis nom et description mis à jour |
| 6 | Chaîne de connexion BI | `BICONFIGURATION` | `Provider=SQLNCLI10.1;Data Source=<instance>;Integrated Security=SSPI;Initial Catalog=<base>` |
| 7 | Serveur d'aide | `SYSGLOBALCONFIGURATION` (`HelpServerLocation`) | URL du serveur d'aide de l'environnement |
| 8 | Supervision SCOM | `SYSGLOBALCONFIGURATION` (`SCOMPERFORMANCEAOS`) | AOS de l'environnement |
| 9 | Sessions | `SYSCLIENTSESSIONS`, `SYSSERVERSESSIONS` | Vidées |
| 10 | Configuration des AOS | `SYSSERVERCONFIG` | Suppression des AOS autres que `01@DNTPRDAOS01`, puis `SERVERID` remplacé |
| 11 | Télémétrie | `SYSSQMSETTINGS` | `GLOBALGUID` remis à zéro |
| 12 | Traitements batch | `BATCHJOB`, `BATCH` | Statuts 1, 2 et 5 (en attente, en cours d'exécution, prêt) passés à 0 (retenu) : aucun traitement ne part au démarrage |
| 13 | Type d'environnement EDI | `BISPARAMETERS` | `ENVIRONMENTTYPE` = 1 (DEV), 2 (recettes, BUILD) ou 3 (PPROD) |
| 14 | Application web WMS | `WHSWORKUSERDISPLAYSETTINGS` | `CSS = 'DNT.css'` (PPROD seulement) |

La variante sans `_FROM_PROD` fait les mêmes mises à jour **sans** les suppressions des lignes 2, 4, 5 et 10.

### F10. Réinjection de la topologie de production

- **Ce que ça fait** : vide puis réécrit `BATCHSERVERGROUP` (2 serveurs batch, groupes vide et `DataUpdate`), `SRSSERVERS` (4 serveurs SSRS × 6 AOS) et `SYSSERVERCONFIG` (6 AOS + 2 serveurs batch, avec leur GUID), avec les RECID d'origine ; met à jour EP, aide, BI et SCOM pour la production.
- **Où** : `Save_scripts_anc_cluster/update_AXPROD_parameters.sql` (ancien cluster). C'est la seule description complète de la topologie de production dans le dépôt.

### F11. Droits de l'utilisateur en lecture seule

- **Ce que ça fait** : `DROP USER [axreader]`, `CREATE USER [axreader] FOR LOGIN [axreader]`, puis ajout au rôle `db_datareader`. À relancer après chaque restauration, car l'utilisateur de la base restaurée ne correspond plus à la connexion de l'instance cible.
- **Où** : `axreader_sur_ax01.sql` (AXPROD), `axreader_sur_ax02.sql` (AXDEV, AXPPROD, AXREC, AXRECBIS). Non appelé par les scripts de copie.

### F12. Maintenance des index et statistiques

- **Ce que ça fait** : crée un job SQL Agent par base (`AX database Rebuild Index and update statistics <base>`, propriétaire `DAUNAT\adminisatech`) en deux étapes :
  1. mise à jour des statistiques de colonnes (`UPDATE STATISTICS ... WITH FULLSCAN`) ;
  2. index fragmentés entre 10 et 30 % réorganisés, au-delà de 30 % reconstruits, statistiques des index peu fragmentés mises à jour.
- **Où** : `Save_scripts_anc_cluster/Plan de maintenance AX*.sql` (AXDEV, AXFORM, AXPPROD, AXPROD, AXREC). Aucune planification n'est créée par le script.

### F13. Diagnostic des performances

Requêtes sur `sys.dm_exec_query_stats`, avec ou sans plan d'exécution :

- requêtes exécutées pendant une période donnée ;
- 50 requêtes les plus coûteuses en CPU moyen ;
- 50 requêtes les plus récentes ;
- 50 requêtes les plus fréquentes ;
- 50 requêtes les plus coûteuses en lectures et écritures logiques ;
- 50 requêtes les plus lentes (temps d'attente moyen).

**Où** : `Requetes SQL Analyses - Aides.sql`.

### F14. Accès des postes au client AX

Voir section 6.

## 4. Paramétrage par environnement

Valeurs lues dans les scripts `update_AX<ENV>_parameters_FROM_PROD.sql` (et `Save_scripts_anc_cluster/update_AXPROD_parameters.sql` pour PROD).

| Env. | Instance SQL | Base | AOS (`SERVERID`) | Enterprise Portal | Serveur d'aide | Reporting Services (serveur / instance / URL) | `ENVIRONMENTTYPE` |
|---|---|---|---|---|---|---|---|
| PROD | `DNTAXPROD\DNTAXPROD` | AXPROD | `01@DNTPRDAOS01` à `06`, batch `01@DNTPRDBAT01` et `02` | `http://dntprdsp01:32843/sites/DynamicsAx` | `http://dntprdsp01:81/DynamicsAX6HelpServer/HelpService.svc` | DNTPRDRS01 à 04 / `RS_AXPROD` / `http://DNTPRDRS01/ReportServer_RS_AXPROD` ; AS `DNTAXAS01\DNTAXAS01` | — |
| RECBIS | `DNTAXRECETTE\DNTAXRECETTE` | AXRECBIS | `01@DNTRECBIS` | `http://dntrecbis/sites/DynamicsAx` | `http://dntrecbis:82/...` | DNTRECBIS / `RS_AXRECBIS` / `http://DNTRECBIS:90/ReportServer_RS_AXRECBIS` | 2 |
| REC | `DNTAXRECETTE\DNTAXRECETTE` | AXREC | `01@DNTRECAOS01` | `http://dntrecsp01/sites/DynamicsAx` | `http://dntrecsp01:82/...` | DNTRECSP01 / `MSSQLSERVER` / `http://DNTRECSP01/ReportServer` | 2 |
| RECTER | `DNTAXRECETTE\DNTAXRECETTE` | AXRECTER | `01@DNTRECTER` | supprimé | `http://dntrecter:82/...` | DNTRECTER / `MSSQLSERVER` / `http://dntrecter/ReportServer` | 2 |
| DEV | `DNTAXRECETTE\DNTAXRECETTE` | AXDEV | `01@DNTAXDEV01` | `http://dntaxdev01/sites/DynamicsAx` | `http://dntaxdev01:82/...` | DNTAXDEV01 / `MSSQLSERVER` / `http://DNTAXDEV01/ReportServer` | 1 |
| PPROD | `DNTAXRECETTE\DNTAXRECETTE` | AXPPROD | `01@DNTPPRODAX01` | `http://dntpprodax01/sites/DynamicsAx` | `http://dntpprodax01:82/...` | DNTPPRODAX01 / `MSSQLSERVER` / `http://DNTPPRODAX01/ReportServer` | 3 |
| BUILD | `DNTAXRECETTE\DNTAXRECETTE` | AXBUILD | `01@DNTRECTER` | supprimé | `http://dntrecter:82/...` | DNTRECTER / `MSSQLSERVER` / `http://dntrecter/ReportServer` | 2 |

Le chemin complet du serveur d'aide est `/DynamicsAX6HelpServer/HelpService.svc`. Hors production, Reporting Services et Analysis Services sont sur un même serveur (« all in one ») ; le serveur Analysis Services est `<serveur RS>\<instance RS>`. L'URL du gestionnaire de rapports suit le même modèle que celle du serveur, avec `Reports` au lieu de `ReportServer`.

## 5. Déroulé d'un rafraîchissement par environnement

| Étape | PPROD | REC | RECBIS | RECTER | BUILD | DEV |
|---|---|---|---|---|---|---|
| Source | PROD | PROD | PROD | PROD | PROD | REC |
| Arrêt AOS | DNTPPRODAX01 `AOS60$01` | DNTRECAOS01 `AOS60$01` | DNTRECBIS `AOS60$01` | DNTRECTER `AOS60$01` | DNTRECTER `AOS60$02` | en commentaire |
| Arrêt Management Reporter (DNTRECMR01) | oui | en commentaire | oui | oui | en commentaire | en commentaire |
| Méthode de restauration (F5) | C (CapData) | C | C | C | A (backup device) | B (`msdb`) |
| Bases restaurées | 3 | 3 | 3 | 3 | 2 (Baseline en commentaire) | 3 |
| Création des bases si absentes (F7) | non | non | non | non | non | oui |
| Réécriture des vues `_model` (F8) | non | non | non | non | non | oui |
| Paramétrage (F9) | `update_AXPPROD_parameters_FROM_PROD` | `update_AXREC_parameters_FROM_PROD` | `update_AXRECBIS_parameters_FROM_PROD` | `update_AXRECTER_parameters_FROM_PROD` | `update_AXBUILD_parameters_FROM_PROD` | en commentaire (« à adapter ») |
| Redémarrage des services | oui | AOS seul | oui | oui | AOS seul | en commentaire |

## 6. Accès client AX

### 6.1 Fichiers de configuration (`.axc`)

| Fichier | AOS | Couche | `dbserver` déclaré |
|---|---|---|---|
| `AXPROD.axc` | `AXPROD@DNTPRDAOS01` à `06`, port 2712 (répartition sur 6 AOS) | USR | DNTPRDAOS01 |
| `AXPPROD.axc` | `AXPPROD@DNTPPRODAX01:2712` | USR | DNTRDS05 |
| `AXREC.axc` | `DNTRECAOS01:2712` | USR | DNTRECRDS01 |
| `AXRECBIS.axc` | `DNTRECBIS:2712` | USR | DNTRECBIS |
| `AXRECTER.axc` | `AXRECTER@DNTRECTER:2712` | USR | DNTRECTER |
| `AXDEV - USR.axc` / `- CUS.axc` / `- VAR.axc` | `AXDEV@DNTAXDEV01:2712` | USR / CUS / VAR (avec code de couche) | DNTAXDEV01 |
| `AXBAC_CUS.axc` / `AXBAC_VAR.axc` | `AXDEMO@DNTAXBAC:2712` | CUS / VAR | DNTAXBAC (base `AXDB`) |

Le client AX est installé dans `C:\Program Files (x86)\Microsoft Dynamics AX\60\Client`.

### 6.2 Raccourcis

`AX PRODUCTION`, `AX PRE PRODUCTION`, `AX RECETTE`, `AX RECETTE BIS` et `AX DEVELOPPEMENT` lancent le client AX avec le fichier `.axc` correspondant, stocké sur le partage `\\dntclusql-ax01\axc$`. Il n'y a pas de raccourci pour RECTER ni pour BUILD.

## 7. Écarts entre environnements

Ces écarts sont factuels ; le nouvel outil devra soit les reproduire volontairement (dans la configuration de l'environnement), soit les corriger.

| # | Écart | Où |
|---|---|---|
| E1 | BUILD utilise le service `AOS60$02` sur DNTRECTER, mais son paramétrage écrit `01@DNTRECTER` comme identifiant d'AOS, le même que RECTER (on attendrait `02@DNTRECTER`) | `Copy_PROD_To_BUILD.sql`, `update_AXBUILD_parameters_FROM_PROD.sql` |
| E2 | BUILD ne restaure pas de base Baseline ; le bloc en commentaire vise `AXRECTERBaseline` | `Copy_PROD_To_BUILD.sql` |
| E3 | BUILD et DEV n'utilisent pas la même méthode de restauration que les autres environnements | section 5 |
| E4 | Management Reporter n'est pas arrêté pour REC ni pour BUILD, alors qu'il l'est pour PPROD, RECBIS et RECTER, sur le même serveur DNTRECMR01 | `Copy_PROD_To_*.sql` |
| E5 | Le paramétrage DEV depuis REC écrit `ENVIRONMENTTYPE = 2` au lieu de 1 et n'est pas appelé | `update_AXDEV_parameters_FROM_REC a mofifier.sql` |
| E6 | `Copy_REC_To_DEV.sql` cite le serveur `DNTREC` (en commentaire) qui n'apparaît nulle part ailleurs | `Copy_REC_To_DEV.sql` |
| E7 | Le dossier de sauvegarde de production est forcé vers le nœud 2 du cluster dans les scripts en usage | méthode C, section 3 |
| E8 | `axreader` n'est recréé ni sur RECTER ni sur BUILD | `axreader_sur_ax02.sql` |
| E9 | Le CSS de l'application WMS n'est modifié que pour PPROD | `update_AXPPROD_parameters_FROM_PROD.sql` |
| E10 | Les scripts de paramétrage exécutés sont ceux de `\\DNTPHYAX01\c$\scripts\`, qui peuvent différer de ceux du dépôt | tous les `Copy_*.sql` |

## 8. Questions ouvertes

À trancher avant de concevoir l'outil :

1. **Copie quotidienne de RECBIS** : comment est-elle planifiée aujourd'hui (job SQL Agent, tâche planifiée Windows, autre) et à quelle heure ? Aucun planificateur n'est dans le dépôt.
2. **Procédure CapData** `usp_restore_database_from_directory` (code récupéré, voir F5) : le nouvel outil doit-il l'appeler ou restaurer lui-même ? **Stratégie de sauvegarde** : jour et heure de la sauvegarde complète, existence de différentielles, durée de conservation des fichiers ; à confirmer par l'historique `msdb` de `DNTAXPROD`.
3. **BUILD** : quel est le bon identifiant d'AOS (E1), faut-il une base Baseline (E2), et partage-t-il vraiment le serveur de RECTER ?
4. **DEV** : la source normale est-elle REC (script actuel) ou PROD (script `update_AXDEV_parameters_FROM_PROD.sql`) ? Les deux doivent-ils être possibles ?
5. **Vues `_model`** (F8) : faut-il aussi les réécrire après une copie depuis la production ? À vérifier dans les définitions des vues de `AXPROD`.
6. **Environnements anciens** : AXFORM (formation) et AXBAC (démo, `DNTAXBAC`) existent-ils encore ? Faut-il les gérer ?
7. **Paramétrage de production** (F10) : le script de l'ancien cluster est-il encore juste pour la topologie actuelle ? Sert-il de référence pour les suppressions faites hors production ?
8. **Management Reporter** : son paramétrage (base MR, entreprise) doit-il être mis à jour après une copie ? Aucun script ne le fait aujourd'hui.
9. **Instances `ax01` / `ax02`** des scripts `axreader` : correspondent-elles à `DNTAXPROD` et `DNTAXRECETTE` ?
10. **Dossier `scripts` de `DNTPHYAX01`** : est-il identique au dépôt (E10) ?
