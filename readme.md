# Gestion des environnements Dynamics AX 2012 R3

Outil centralisé de gestion des environnements de l'ERP **Microsoft Dynamics AX 2012 R3** de Daunat : production, préproduction, recette, développement et build.

> [!NOTE]
> **État du dépôt.** Le dépôt contient pour l'instant l'**existant** : les scripts SQL hérités (dossier [`scripts/`](scripts/)), qui servent de référence pour comprendre les environnements, les serveurs AOS et les bases. Ils seront remplacés par le nouvel outil. Le détail de ce qu'ils font est dans [docs/Existant-Scripts-Legacy.md](docs/Existant-Scripts-Legacy.md).

## Objectif

Remplacer les scripts SQL lancés à la main par un outil unique qui :

- connaît tous les environnements et leur topologie (bases, AOS, services, URL) grâce à une **configuration**, et non à des valeurs écrites en dur ;
- rafraîchit un environnement à partir d'un autre (copie des 3 bases, puis paramétrage AX propre à la cible) ;
- **vérifie avant d'agir** : espace disque disponible pour des bases qui peuvent atteindre **1,5 To**, existence et âge de la sauvegarde source, connexions actives, état des services ;
- suit les règles communes aux outils de la DSI (simulation par défaut, plan d'étapes, confirmation, journaux, profils d'accès), décrites dans [docs/Uniformite-Outils-DSI.md](docs/Uniformite-Outils-DSI.md).

## Environnements

| Env. | Rôle | Bases | AOS (instance) | Serveur AOS | `ENVIRONMENTTYPE` (EDI) | Alimenté depuis |
|---|---|---|---|---|---|---|
| **PROD** | Production | `AXPROD`, `AXPROD_model`, `AXPRODBaseline` | `01@DNTPRDAOS01` à `06`, batch `01@DNTPRDBAT01` et `02` | DNTPRDAOS01 à 06, DNTPRDBAT01 et 02 | (source) | — |
| **RECBIS** | Copie quotidienne de la production (prod à J-1) | `AXRECBIS`, `AXRECBIS_model`, `AXRECBISBaseline` | `01@DNTRECBIS` | DNTRECBIS | 2 | PROD (chaque jour) |
| **REC** | Recette | `AXREC`, `AXREC_model`, `AXRECBaseline` | `01@DNTRECAOS01` | DNTRECAOS01 | 2 | PROD |
| **RECTER** | Recette | `AXRECTER`, `AXRECTER_model`, `AXRECTERBaseline` | `01@DNTRECTER` | DNTRECTER | 2 | PROD |
| **DEV** | Développement | `AXDEV`, `AXDEV_model`, `AXDEVBaseline` | `01@DNTAXDEV01` | DNTAXDEV01 | 1 | REC (ou PROD) |
| **PPROD** | Préproduction | `AXPPROD`, `AXPPROD_model`, `AXPPRODBaseline` | `01@DNTPPRODAX01` | DNTPPRODAX01 | 3 | PROD |
| **BUILD** | Build lors des mises en production (MEP) | `AXBUILD`, `AXBUILD_model` (pas de Baseline dans le script actuel) | `01@DNTRECTER` dans le paramétrage, service `AOS60$02` | DNTRECTER (2ᵉ AOS) | 2 | PROD |

`ENVIRONMENTTYPE` est la valeur écrite dans `BISPARAMETERS` (module EDI) : **1** = développement, **2** = recette, **3** = préproduction.

### Les trois bases d'un environnement

| Base | Contenu |
|---|---|
| `AX<ENV>` | Données de l'ERP (transactions, paramétrage fonctionnel). C'est la plus volumineuse (jusqu'à 1,5 To). |
| `AX<ENV>_model` | Model store : code (couches SYS à USR) et paramétrage technique de Dynamics AX. |
| `AX<ENV>Baseline` | Code source de référence (ancienne version), utilisé pour comparer le code et résoudre les conflits lors des mises à niveau. |

### Infrastructure commune

| Élément | Valeur |
|---|---|
| Instance SQL de production | `DNTAXPROD\DNTAXPROD` |
| Instance SQL hors production (toutes les bases sauf PROD) | `DNTAXRECETTE\DNTAXRECETTE` |
| Fichiers de données / journaux hors production | `R:\MSSQL13.DNTAXRECETTE\MSSQL\DATA` / `S:\MSSQL13.DNTAXRECETTE\MSSQL\Data` |
| Sauvegardes de production | `\\Dntaxprod\L$\MSSQL13.DNTAXPROD\MSSQL\Backup` (backup devices `AXPROD`, `AXPROD_model`, `AXPRODBaseline`) |
| Service AOS | `AOS60$01` (`AOS60$02` pour BUILD) |
| Management Reporter (hors production) | DNTRECMR01 : `MR2012ProcessService`, `MR2012ApplicationService` |
| Reporting Services (production) | DNTPRDRS01 à 04, instance `RS_AXPROD` |
| Analysis Services (production) | `DNTAXAS01\DNTAXAS01` |
| Configurations client AX (`.axc`) | partage `\\dntclusql-ax01\axc$`, port AOS 2712 |
| Scripts de paramétrage appelés par les copies | `\\DNTPHYAX01\c$\scripts\` |
| Compte propriétaire des bases restaurées | `DAUNAT\svc_sql` |
| Utilisateur SQL en lecture seule | `axreader` (`db_datareader`) |

Les URL Enterprise Portal, serveur d'aide et Reporting Services de chaque environnement sont détaillées dans la [documentation de l'existant](docs/Existant-Scripts-Legacy.md#4-paramétrage-par-environnement).

## Organisation du dépôt

```
readme.md                          ce fichier
docs/
  Existant-Scripts-Legacy.md       ce que font les scripts hérités, fonction par fonction
  Uniformite-Outils-DSI.md         règles communes aux outils de la DSI (référence Gestion-VMCluster)
scripts/                           scripts SQL hérités (lecture seule, référence)
  Copy_*.sql                       rafraîchissement d'un environnement
  update_AX*_parameters*.sql       paramétrage AX après copie
  axreader_sur_ax0*.sql            droits de l'utilisateur en lecture seule
  Requetes SQL Analyses - Aides.sql  diagnostic des performances
  Fichiers de configuration AX/    fichiers .axc et raccourcis du client AX
  Save_scripts_anc_cluster/        maintenance et paramétrage de l'ancien cluster
  avant_/apres_modif_capdata_ticket_1040592/  versions avant/après l'intervention CapData
```

> [!WARNING]
> Les scripts du dossier `scripts/` suppriment et écrasent des bases sans sauvegarde préalable. Ils sont conservés **uniquement comme référence** : ne les exécutez pas tels quels.

## Documentation

- [Existant : scripts hérités](docs/Existant-Scripts-Legacy.md) : inventaire des fichiers, fonctions repérées, paramétrage par environnement, écarts et questions ouvertes.
- [Uniformité des outils DSI](docs/Uniformite-Outils-DSI.md) : règles d'interface, de sécurité, de configuration et de qualité que le nouvel outil doit suivre.
