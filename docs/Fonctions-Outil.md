# Catalogue des fonctions de l'outil de gestion des environnements

|  |  |
| :- | :- |
|Document|Liste des fonctions attendues d'un outil de gestion des environnements|
|Statut|**Document de travail**, à compléter et à valider|
|Date|4 novembre 2026|
|Contexte|ERP Microsoft Dynamics AX 2012 R3, hébergé sur site, avec briques connexes (EDI, WMS, APS, Management Reporter)|
|Documents liés|[Existant : scripts hérités](Existant-Scripts-Legacy.md), [Uniformité des outils DSI](Uniformite-Outils-DSI.md)|

## Mode d'emploi

- Ce document décrit **ce que doit savoir faire un bon outil de gestion des environnements**, indépendamment de la société. Le spécifique à la société (environnements, serveurs, règles, priorités) sera ajouté en section 14.
- Chaque fonction a un **identifiant stable** (par exemple `DAT-03`), qui servira dans les spécifications, les prompts et les tests. On ne renumérote pas : une fonction abandonnée est marquée « Abandonnée ».
- Colonne **Origine** :
  - **Liste initiale** : fonctions de la liste fournie par le responsable applicatif ;
  - **Complément** : fonctions ajoutées lors de l'analyse, en général propres à AX 2012 ou au fonctionnement sur site ;
  - **Existant** : fonction déjà assurée (même partiellement) par les scripts hérités, avec la référence `F<n>` de la [documentation de l'existant](Existant-Scripts-Legacy.md#3-fonctions-repérées).
- Colonne **Lot** : à renseigner lors de la priorisation (1 = indispensable pour remplacer les scripts, 2 = important, 3 = plus tard).

## Sommaire

1. [Provisionnement et cycle de vie](#1-provisionnement-et-cycle-de-vie)
2. [Bases de données et données](#2-bases-de-données-et-données)
3. [Contrôles avant action](#3-contrôles-avant-action)
4. [Préparation de l'environnement après copie](#4-préparation-de-lenvironnement-après-copie)
5. [Configuration et parité](#5-configuration-et-parité)
6. [Promotion et mises en production](#6-promotion-et-mises-en-production)
7. [Exploitation des environnements](#7-exploitation-des-environnements)
8. [Planification, réservation et communication](#8-planification-réservation-et-communication)
9. [Inventaire et tableau de bord](#9-inventaire-et-tableau-de-bord)
10. [Gouvernance, sécurité et audit](#10-gouvernance-sécurité-et-audit)
11. [Capacité, stockage et coûts](#11-capacité-stockage-et-coûts)
12. [Robustesse de l'exécution](#12-robustesse-de-lexécution)
13. [Postes de travail](#13-postes-de-travail)
14. [Spécifique à la société](#14-spécifique-à-la-société)
15. [Adaptations au contexte AX 2012 sur site](#15-adaptations-au-contexte-ax-2012-sur-site)
16. [Historique du document](#16-historique-du-document)

## 1. Provisionnement et cycle de vie

| ID | Fonction | Description | Origine | Lot |
|---|---|---|---|---|
| PRV-01 | Création d'environnement à la demande | Créer un environnement complet de façon automatisée. Objectif cible : mise à disposition en moins de 10 minutes (voir section 15). | Liste initiale | |
| PRV-02 | Libre-service | Déclencher une création par ligne de commande, API ou portail. L'outil valide les entrées, estime le coût, applique la configuration, injecte les données et lance les tests de bon fonctionnement. | Liste initiale | |
| PRV-03 | Environnements éphémères | Créer des environnements jetables (développement, non-régression, démonstration) et les détruire automatiquement après une période d'inactivité (par exemple 7 jours). | Liste initiale | |
| PRV-04 | Arborescence des répertoires | Créer et maintenir l'arborescence de chaque environnement : installation, travail, journaux, scripts, zones de dépôt EDI, etc. | Liste initiale | |
| PRV-05 | Répertoires applicatifs par brique | Créer et synchroniser les répertoires propres à chaque brique : programmes de l'ERP (binaires, sources, correctifs), configuration de l'APS, échanges entrants et sortants de l'EDI, etc. | Liste initiale | |
| PRV-06 | Suppression d'environnement | Supprimer proprement un environnement (bases, services, répertoires, configuration client), avec quarantaine avant suppression définitive. | Complément | |
| PRV-07 | Réutilisation de l'existant d'infrastructure | S'appuyer sur les outils existants pour la création des machines virtuelles (outil Gestion-VMCluster) plutôt que de la refaire. | Complément | |

## 2. Bases de données et données

| ID | Fonction | Description | Origine | Lot |
|---|---|---|---|---|
| DAT-01 | Clonage et rafraîchissement | Copier les bases d'un environnement source (en général la production) vers un environnement cible, et rafraîchir régulièrement les environnements hors production. | Liste initiale, Existant F4 à F6 | |
| DAT-02 | Restauration à une heure précise | Restaurer la source à une date et une heure données, à partir de la chaîne de sauvegardes (complète, différentielle, journaux). | Complément, Existant F5 | |
| DAT-03 | Traitement des 3 bases AX ensemble | Restaurer de façon cohérente la base de données, la base `_model` et la base `Baseline`, avec la même heure de référence quand c'est pertinent. | Complément, Existant F5 | |
| DAT-04 | Anonymisation et masquage | Appliquer des règles de masquage (aléatoire, substitution) sur les données personnelles et financières, pour respecter le RGPD. Règle par environnement : masqué ou non (voir section 15). | Liste initiale | |
| DAT-05 | Amorçage de données | Définir un état initial fiable pour un environnement hors production, en distinguant données de référence (devises, taxes), données de configuration (plan comptable, entrepôts) et données de test ou de démonstration. | Liste initiale | |
| DAT-06 | Synchronisation sélective | Promouvoir certaines données de configuration ou de référence d'un environnement à un autre sans tout écraser. | Liste initiale | |
| DAT-07 | Réduction des bases hors production | Purger les historiques volumineux et sans intérêt pour les tests (historique batch, journal des modifications, journaux EDI, anciennes transactions) pour réduire la taille et la durée des copies. | Complément | |
| DAT-08 | Cohérence entre applications | Rafraîchir ensemble, au même instant, les bases liées : AX, Management Reporter, EDI, WMS, APS. | Complément | |
| DAT-09 | Droits SQL après restauration | Recréer les utilisateurs SQL propres à l'environnement (lecture seule, comptes de service), rattacher les utilisateurs orphelins, fixer le propriétaire de la base. | Complément, Existant F5, F11 | |
| DAT-10 | Maintenance des bases | Planifier et suivre la maintenance des index et des statistiques de chaque base. | Complément, Existant F12 | |
| DAT-11 | Diagnostic des performances | Fournir les requêtes de diagnostic (requêtes coûteuses en CPU, en lectures, les plus lentes, les plus fréquentes). | Complément, Existant F13 | |

## 3. Contrôles avant action

Aucun contrôle n'est fait par les scripts hérités. Chaque action à effet commence par ces contrôles et produit un rapport « prêt / pas prêt » avant la demande de confirmation.

| ID | Fonction | Description | Origine | Lot |
|---|---|---|---|---|
| CTL-01 | Espace disque | Vérifier l'espace libre sur les volumes de données et de journaux de la cible, à partir de la taille réelle des fichiers lue dans la sauvegarde (`RESTORE FILELISTONLY`), avec une marge configurable. | Complément | |
| CTL-02 | Sauvegarde source | Vérifier que la sauvegarde existe, qu'elle est lisible (`RESTORE HEADERONLY` / `VERIFYONLY`), assez récente, et que la sauvegarde en cours est terminée. | Complément | |
| CTL-03 | Chaîne des journaux | Vérifier que la chaîne complète, différentielle et journaux est continue jusqu'à l'heure demandée, sans fichier manquant. | Complément | |
| CTL-04 | État de la cible | Vérifier l'état des services, les sessions AX et SQL ouvertes, l'absence de mise en production en cours et de réservation par un autre utilisateur. | Complément | |
| CTL-05 | Compatibilité source / cible | Vérifier la version de SQL Server, la version du noyau AX et la mise à jour cumulative des deux environnements. | Complément | |
| CTL-06 | Estimation de durée | Estimer la durée de l'opération à partir de la taille des sauvegardes et de l'historique des opérations précédentes. | Complément | |

## 4. Préparation de l'environnement après copie

Une base copiée depuis la production doit être neutralisée avant d'être ouverte aux utilisateurs.

| ID | Fonction | Description | Origine | Lot |
|---|---|---|---|---|
| PRP-01 | Topologie AX de la cible | Réaffecter les serveurs AOS et batch, les groupes batch, Enterprise Portal, Reporting Services, Analysis Services, serveur d'aide, supervision ; purger les sessions. | Complément, Existant F9 | |
| PRP-02 | Neutralisation des envois sortants | Rediriger ou couper tout ce qui sort de l'environnement : SMTP vers une boîte de test, ports AIF, chemins EDI, fichiers bancaires, services web externes. | Complément | |
| PRP-03 | Traitements batch, workflows et alertes | Mettre en attente les traitements batch, désactiver workflows et alertes, puis réactiver une liste de traitements propre à l'environnement. | Complément, Existant F9 | |
| PRP-04 | Chemins de fichiers | Remplacer les chemins de production : gestion documentaire, dossiers d'import et d'export, répertoires d'échange. | Complément | |
| PRP-05 | Imprimantes et états | Remplacer les imprimantes et destinations d'états de production. | Complément | |
| PRP-06 | Conservation du paramétrage de la cible | Exporter avant écrasement ce qui est propre à la cible (utilisateurs, rôles, alias réseau, paramètres) et le réappliquer après la copie, au lieu de réécrire des valeurs en dur. | Complément | |
| PRP-07 | Vues liées à la base `_model` | Réécrire les vues qui contiennent le nom de la base `_model` de la source. | Complément, Existant F8 | |
| PRP-08 | Type d'environnement | Positionner les indicateurs propres à l'environnement (par exemple le type d'environnement EDI). | Complément, Existant F9 | |
| PRP-09 | Tests de bon fonctionnement | Après préparation : AOS joignable, serveur batch actif, Reporting Services, Enterprise Portal, Management Reporter et AIF qui répondent ; rapport de validation. | Liste initiale (smoke tests), Complément | |

## 5. Configuration et parité

| ID | Fonction | Description | Origine | Lot |
|---|---|---|---|---|
| CFG-01 | Environnement décrit par la configuration | Décrire chaque environnement (serveurs, bases, services, URL, chemins, paramètres AX) dans des fichiers versionnés, et non par des modifications manuelles. | Liste initiale (Infrastructure as Code) | |
| CFG-02 | Variables par environnement | Gérer les jeux de valeurs propres à chaque environnement (chaînes de connexion, URL, points d'échange EDI), pour empêcher toute valeur de production dans un environnement de test. | Liste initiale | |
| CFG-03 | Détection de dérive | Comparer l'état réel d'un environnement avec l'état décrit et alerter en cas de modification manuelle non tracée. | Liste initiale | |
| CFG-04 | Comparaison entre environnements | Comparer deux environnements : versions, modèles installés, paramètres, topologie. | Complément | |
| CFG-05 | Gestion des secrets | Aucun mot de passe dans les fichiers : références vers un magasin de secrets ou un compte de service. | Complément | |

## 6. Promotion et mises en production

| ID | Fonction | Description | Origine | Lot |
|---|---|---|---|---|
| PRM-01 | Circuit de promotion | Gérer le flux de livraison : développement, build, recette, préproduction, production. | Liste initiale | |
| PRM-02 | Regroupement des modifications | Regrouper les modifications (code, données de configuration, paramètres) en lots appliqués de façon atomique. En AX 2012 : modèles et model store. | Liste initiale | |
| PRM-03 | Gestion du model store | Exporter et importer le model store (avec schéma temporaire pour réduire l'arrêt), installer des modèles `.axmodel`. | Complément | |
| PRM-04 | Chaîne de build AX | Compilation, génération CIL, synchronisation de la base, déploiement des états Reporting Services, purge des caches. | Complément | |
| PRM-05 | Retour arrière | Sauvegarder le model store et les bases avant toute mise en production, et pouvoir revenir à l'état précédent. | Liste initiale, Complément | |
| PRM-06 | Déploiement progressif | Stratégies de type Blue-Green ou Canary pour les briques critiques (EDI, WMS). Portée limitée en AX 2012 (voir section 15). | Liste initiale | |

## 7. Exploitation des environnements

| ID | Fonction | Description | Origine | Lot |
|---|---|---|---|---|
| EXP-01 | Arrêt, démarrage, redémarrage | Piloter chaque brique (AOS, batch, Reporting Services, Management Reporter, Enterprise Portal) en attendant l'état voulu, avec délai maximal. | Complément, Existant F1 | |
| EXP-02 | Sessions utilisateurs | Voir les utilisateurs connectés (AX et SQL), leur envoyer un message, les déconnecter. | Complément, Existant F2, F3 | |
| EXP-03 | Mode maintenance | Fermer un environnement aux utilisateurs pendant une intervention. | Complément | |
| EXP-04 | Santé de l'environnement | Contrôler à la demande l'état de toutes les briques (même contrôles que PRP-09). | Complément | |

## 8. Planification, réservation et communication

| ID | Fonction | Description | Origine | Lot |
|---|---|---|---|---|
| PLN-01 | Tâches planifiées | Planifier les opérations récurrentes (par exemple le rafraîchissement quotidien), avec dépendance à la fin de la sauvegarde source, nouvelle tentative et alerte en cas d'échec. | Complément | |
| PLN-02 | Réservation des environnements | Calendrier : qui utilise quel environnement et quand, périodes de gel, créneaux de mise en production. | Complément | |
| PLN-03 | Information des utilisateurs | Prévenir avant une opération (mail ou Teams) et annoncer la remise à disposition. | Complément | |
| PLN-04 | Notifications d'exploitation | Avertir l'équipe en cas d'échec, de dérive ou de seuil de capacité atteint. | Complément | |

## 9. Inventaire et tableau de bord

| ID | Fonction | Description | Origine | Lot |
|---|---|---|---|---|
| INV-01 | Fiche d'environnement | Pour chaque environnement : rôle, serveurs, bases, versions (noyau, mise à jour cumulative, modèles), propriétaire, réservation. | Complément | |
| INV-02 | Fraîcheur des données | Date des données (« production du 03/11 à 23 h 00 ») et date du dernier rafraîchissement. | Complément | |
| INV-03 | Tableau de bord | Vue d'ensemble : état des services, taille des bases, espace disque, dernières opérations et leur résultat. | Complément | |
| INV-04 | Historique des opérations | Liste des opérations passées avec durée, résultat et détail des étapes. | Complément | |

## 10. Gouvernance, sécurité et audit

| ID | Fonction | Description | Origine | Lot |
|---|---|---|---|---|
| GOV-01 | Contrôle d'accès par environnement | Définir qui peut faire quoi sur quel environnement (pas de développeur en production). | Liste initiale | |
| GOV-02 | Accès d'urgence | Accès exceptionnel à la production (« break-glass ») avec circuit d'approbation et traçabilité renforcée. | Liste initiale | |
| GOV-03 | Journalisation et audit | Tracer toutes les actions : qui a copié quoi, quand, qui a modifié un paramètre. | Liste initiale | |
| GOV-04 | Simulation, plan et confirmation | Mode simulation par défaut, plan d'étapes affiché avant exécution, confirmation explicite, retape du nom pour une suppression. | Complément (règles DSI) | |
| GOV-05 | Preuve de restaurabilité | Enregistrer chaque restauration réussie depuis la production comme preuve que les sauvegardes sont exploitables (audit, plan de reprise). | Complément | |

## 11. Capacité, stockage et coûts

| ID | Fonction | Description | Origine | Lot |
|---|---|---|---|---|
| CAP-01 | Mise en veille et suppression des inutilisés | Arrêter ou supprimer automatiquement les environnements hors production inutilisés. | Liste initiale (FinOps) | |
| CAP-02 | Suivi et prévision du stockage | Suivre l'occupation des volumes et la croissance des bases, prévoir les besoins. | Complément | |
| CAP-03 | Purge des sauvegardes et fichiers | Nettoyer les anciennes sauvegardes, copies de sécurité et fichiers temporaires selon une durée de conservation. | Complément | |
| CAP-04 | Performance des copies | Réglages de sauvegarde et de restauration (compression, fichiers multiples, tampons) pour réduire les durées. | Complément | |
| CAP-05 | Suivi des licences | Suivre les licences consommées par les environnements (SQL Server, AX). | Complément | |

## 12. Robustesse de l'exécution

| ID | Fonction | Description | Origine | Lot |
|---|---|---|---|---|
| ROB-01 | Reprise sur étape | Reprendre une opération à l'étape qui a échoué, sans tout relancer. | Complément | |
| ROB-02 | Copie de sécurité de la cible | Avant écrasement, sauvegarder la cible (optionnel, avec durée de conservation) pour pouvoir annuler un rafraîchissement. | Complément | |
| ROB-03 | Une opération à la fois par environnement | Verrou par environnement pour empêcher deux opérations simultanées. | Complément | |
| ROB-04 | Annulation | Annuler une opération en cours et jouer les étapes de retour arrière. | Complément (règles DSI) | |

## 13. Postes de travail

| ID | Fonction | Description | Origine | Lot |
|---|---|---|---|---|
| PST-01 | Configurations client AX | Générer les fichiers `.axc` et les raccourcis à partir de la configuration, les publier sur le partage. | Complément, Existant F14 | |
| PST-02 | Repère visuel des environnements | Distinguer clairement un environnement hors production (bannière, couleur, message au démarrage) pour éviter les erreurs en production. | Complément | |

## 14. Spécifique à la société

> [!NOTE]
> Section en cours de rédaction. La section 14.1 reprend les grandes fonctions **demandées par le responsable applicatif** (validées). La section 14.2 liste des **propositions à valider**. La section 14.3 liste les décisions à prendre.

### 14.1 Grandes fonctions demandées

| ID | Fonction | Exigences | Fonctions du catalogue |
|---|---|---|---|
| DAU-01 | **Droits selon l'Active Directory** | Seules certaines personnes peuvent lancer le rafraîchissement d'un environnement ou exécuter certaines fonctions. Les niveaux de droits viennent de groupes AD. | GOV-01, GOV-02 |
| DAU-02 | **Restauration de la production vers un autre environnement** | Source toujours la production, cible n'importe quel autre environnement, **jamais l'inverse**. L'utilisateur choisit la sauvegarde de départ dans la **liste des sauvegardes disponibles**. Dossier des sauvegardes paramétrable (aujourd'hui `\\Dntaxprod\L$\MSSQL13.DNTAXPROD\MSSQL\Backup`). | DAT-01, DAT-02, DAT-03 |
| DAU-03 | **Neutralisation de l'environnement restauré** | Après la restauration : désactivation de tous les traitements AX et remplacement des chemins des connecteurs. Objectifs : l'environnement ne doit ni lire des fichiers de production, ni écrire dans les dossiers de production, et ne doit pas consommer de ressources inutilement. | PRP-01 à PRP-05, PRP-08 |
| DAU-04 | **Dossiers des connecteurs par environnement** | Au lancement d'une restauration, l'utilisateur peut choisir les dossiers de chaque connecteur. Des dossiers par défaut sont définis pour chaque environnement dans un fichier de paramétrage. | PRV-04, PRV-05, CFG-02 |
| DAU-05 | **Activation des services pour les tests** | Possibilité d'activer les services et traitements voulus pour les besoins des tests. | PRP-03, EXP-01 |
| DAU-06 | **Pilotage de la copie de fichiers planifiée (Jenkins)** | Activer le processus Python ordonnancé dans Jenkins qui copie des fichiers d'un dossier à un autre à intervalle régulier (par exemple les fichiers de commandes de la production vers un environnement de test). | Nouvelle fonction |
| DAU-07 | **Contrôles à chaque étape et copie par l'outil de la DSI** | Vérifications pour chaque processus et chaque étape. Les copies de fichiers passent par l'**outil de copie de la DSI**, qui contrôle l'espace disque et la somme de contrôle après copie, et qui peut être appelé seul (par exemple pour copier les fichiers de sauvegarde). Il journalise dans un format standard remonté dans **Grafana**, qui centralise les informations d'exploitation de la DSI. | CTL-01 à CTL-06, GOV-03 |
| DAU-08 | **Interface de paramétrage et de suivi** | Une interface pour le paramétrage et le suivi des fonctions : planning des environnements, opérations en cours, historique. | PLN-02, INV-01 à INV-04 |
| DAU-09 | **Notification Teams** | Message dans un canal Teams de la DSI, avec mention de la personne qui a lancé l'opération (identité issue de l'AD), en cas de succès ou d'échec. | PLN-03, PLN-04 |
| DAU-25 | **Isolation entre environnements** | Les traitements d'un environnement (développement, test, recette, préproduction, build) ne doivent interférer ni entre eux, ni avec la production. Contrôles à chaque restauration, à chaque activation de service et à la demande. Voir le détail en 14.4. | CFG-02, CFG-03, PRP-01 à PRP-05 |
| DAU-26 | **Model store et intégration CI/CD** | Les opérations sur le model store (export, import, installation de modèles, compilation, synchronisation) font partie de l'outil. L'outil est une brique de la chaîne CI/CD en construction. | PRM-01 à PRM-05 |
| DAU-27 | **Commandes appelables par d'autres outils** | Chaque fonction est une commande PowerShell utilisable en ligne de commande, donc appelable par Jenkins, SSIS, Python ou PowerShell, en plus de l'interface. | GOV-04 |

### 14.2 Propositions complémentaires (à valider)

| ID | Proposition | Pourquoi | Statut |
|---|---|---|---|
| DAU-10 | **Exécution par un service central, pas depuis le poste** | Une restauration de 1,5 To dure des heures : elle ne doit pas dépendre d'un poste resté allumé. L'interface demande, un service central exécute avec un compte de service. Les droits AD de l'utilisateur ne servent qu'à autoriser la demande. Permet aussi de supprimer `xp_cmdshell`. | À valider |
| DAU-11 | **Production protégée par construction** | Refus codé en dur de toute opération dont la cible est la production, en plus des droits AD. Le compte de service n'a que des droits de lecture sur les sauvegardes et aucun droit d'écriture sur l'instance de production. | À valider |
| DAU-12 | **Choix d'un point de restauration, pas d'un fichier** | Avec des journaux toutes les 15 minutes, on peut restaurer à n'importe quelle heure. L'outil affiche les points disponibles (complète, différentielle, journaux), vérifie que la chaîne est continue et indique les fichiers à rejouer. | À valider |
| DAU-13 | **Choix des bases restaurées** | Restaurer les 3 bases (données, `_model`, `Baseline`) ou seulement certaines, avec contrôle de cohérence entre la base de données et la base `_model`. | À valider |
| DAU-14 | **Copie locale des sauvegardes avant restauration** | Copier les fichiers par l'outil de copie de la DSI (espace disque, somme de contrôle), puis restaurer depuis un disque local. Moins de charge sur le partage de production, contrôle d'intégrité avant de supprimer la cible. | À valider |
| DAU-15 | **Recherche des chemins de production résiduels** | Après la neutralisation, parcourir les tables de paramétrage AX à la recherche de noms de serveurs et de chemins de production. L'environnement n'est ouvert que si rien n'est trouvé. | À valider |
| DAU-16 | **Contrôle des dossiers des connecteurs** | Création des dossiers s'ils n'existent pas, droits d'écriture du compte AOS, refus de tout dossier de production et de tout dossier déjà utilisé par un autre environnement. | À valider |
| DAU-17 | **Profils d'activation pour les tests** | Ensembles prédéfinis de services et traitements à activer (par exemple « EDI entrant », « WMS ») plutôt qu'un choix un par un. | À valider |
| DAU-18 | **Copies Jenkins encadrées** | Sens production vers test uniquement, filtres sur les fichiers, date de fin obligatoire, arrêt automatique lors d'un nouveau rafraîchissement de l'environnement. | À valider |
| DAU-19 | **Journalisation de l'outil au format DSI** | L'outil lui-même journalise au même format que l'outil de copie (durée et résultat de chaque étape, tailles), pour que ses opérations apparaissent dans les mêmes tableaux Grafana. | À valider |
| DAU-20 | **Conservation du paramétrage propre à la cible** | Exporter avant la restauration ce qui est propre à l'environnement cible (utilisateurs et droits des développeurs, `axreader`, paramètres) et le réappliquer après. | À valider |
| DAU-21 | **Rafraîchissement planifié de RECBIS** | Le rafraîchissement quotidien est une opération planifiée de l'outil, avec la même chaîne de contrôles et les mêmes notifications. | À valider |
| DAU-22 | **Réservation et verrou par environnement** | Une seule opération à la fois par environnement ; impossible de rafraîchir un environnement réservé sans l'accord de celui qui l'a réservé. | À valider |
| DAU-23 | **Notification des utilisateurs de l'environnement** | En plus de celui qui lance l'opération, prévenir les utilisateurs de l'environnement avant la coupure et à la remise à disposition. | À valider |
| DAU-24 | **Tests de bon fonctionnement et rapport** | Contrôle final de l'environnement (AOS, batch, Reporting Services, connecteurs) et rapport joint à la notification Teams. | À valider |

### 14.3 Décisions

| # | Question | Décision | Date |
|---|---|---|---|
| D1 | Où s'exécutent les opérations ? | **Tâches Jenkins.** L'équipe maîtrise l'outil et dispose déjà de bibliothèques de journalisation (sorties normales et erreurs). | 05/11/2026 |
| D2 | Type d'interface | **WPF pour commencer**, comme les autres outils de la DSI. Une interface web sera étudiée ensuite ; elle s'appuiera sur la base de données de l'outil. | 05/11/2026 |
| D3 | Forme des commandes et de l'outil de copie | **PowerShell**, natif sous Windows, appelable en ligne de commande depuis SSIS, Python ou PowerShell. L'interface WPF lance les opérations **en arrière-plan**, sans dépendre de la session de l'utilisateur. Toutes les actions sont journalisées et les anomalies donnent lieu à des avertissements. | 05/11/2026 |
| D4 | Chaîne Grafana | Grafana lit les journaux dans **Loki**. | 05/11/2026 |
| D5 | Notification Teams | **Message dans un canal Teams existant de la DSI, avec mention de la personne.** L'identité de la personne vient de l'AD. | 05/11/2026 |
| D6 | Liste des connecteurs AX | **Recensement à faire** des tables et paramètres AX qui contiennent des chemins, adresses ou serveurs. Script de recensement en lecture seule : [`analyse/Recensement-Connecteurs-AX.sql`](../analyse/Recensement-Connecteurs-AX.sql), à lancer sur AXRECBIS. | 05/11/2026 |
| D7 | Masquage des données | En discussion. | — |
| D8 | Mises en production | **Dans le périmètre** : le model store et BUILD font partie de l'outil, qui s'intègre à la chaîne CI/CD (DAU-26). | 05/11/2026 |

Point à confirmer suite à D1 et D3 : l'interface WPF déclenche les tâches Jenkins (API Jenkins), qui exécutent les commandes PowerShell. L'opération ne dépend ainsi ni du poste ni de la session de l'utilisateur.

### 14.4 Isolation entre environnements (DAU-25)

Ressources qui ne doivent jamais être partagées entre deux environnements, et contrôle associé :

| Ressource | Risque | Contrôle |
|---|---|---|
| Identifiant d'AOS et serveurs batch (`SYSSERVERCONFIG`, `BATCHSERVERGROUP`, `BATCH`) | Un AOS d'un environnement exécute les traitements d'un autre | Chaque environnement a ses identifiants d'AOS ; aucune ligne ne référence un AOS d'un autre environnement. Aujourd'hui BUILD et RECTER écrivent tous deux `01@DNTRECTER` (écart E1 de l'existant). |
| Dossiers des connecteurs (EDI, imports, exports, gestion documentaire) | Un environnement consomme ou dépose les fichiers d'un autre | Dossier propre à chaque environnement, refus d'un dossier de production ou déjà affecté à un autre environnement. |
| Ports AIF, services web, adresses d'échange | Messages reçus ou envoyés au mauvais environnement | Adresses propres à chaque environnement, vérifiées après restauration. |
| Messagerie (SMTP, adresses d'envoi) | Mails envoyés à de vrais clients ou fournisseurs | Serveur SMTP de test ou envoi coupé hors production. |
| Copies de fichiers Jenkins | Fichiers copiés vers le mauvais environnement, ou vers la production | Sens production vers hors production uniquement, cible contrôlée contre la liste des dossiers de l'environnement. |
| Services partagés (Management Reporter sur DNTRECMR01, Reporting Services, instance SQL hors production) | L'arrêt ou le rafraîchissement d'un environnement coupe les autres | Inventaire des services partagés ; avertissement listant les environnements touchés avant toute action. |
| Bases de données | Une base pointe vers la base `_model` ou la base d'un autre environnement | Contrôle des vues et des chaînes de connexion (`BICONFIGURATION`) après restauration. |

Le contrôle d'isolation est lancé après chaque restauration (DAU-15), avant chaque activation de service ou de traitement (DAU-05), et à la demande sur l'ensemble des environnements.

## 15. Adaptations au contexte AX 2012 sur site

Points de la liste initiale qui ne s'appliquent pas tels quels et doivent être tranchés.

| Fonction | Point d'attention | Piste |
|---|---|---|
| PRV-01 Création en moins de 10 minutes | Une restauration classique de 1,5 To ne tient pas ce délai. | Instantanés ou clones côté baie de stockage, ou bases réduites (DAT-07) pour les environnements éphémères. Décision d'architecture à prendre tôt. |
| CFG-01 Infrastructure as Code (Terraform, CloudFormation) | Outils pensés pour le cloud ; l'infrastructure est sur site. | Configuration PowerShell versionnée (`.psd1`) validée par un schéma, comme les autres outils de la DSI ; machines virtuelles via Gestion-VMCluster. |
| PRV-03 Environnements éphémères | Chaque environnement AX demande sa propre instance AOS et son propre model store. | Réserve d'emplacements AOS préinstallés, bases réduites. |
| CAP-01 FinOps | Pas de facturation cloud. | Il s'agit de capacité : stockage, mémoire SQL, licences (édition Developer possible hors production). |
| PRM-06 Blue-Green / Canary | Pas d'équivalent réel en AX 2012. | Import du model store dans un schéma temporaire puis bascule, sauvegarde pour retour arrière. |
| DAT-04 Masquage | Un environnement « production à J-1 » sert souvent à reproduire des incidents avec les vraies données. | Décider environnement par environnement si les données sont masquées. |

## 16. Historique du document

| Date | Modification |
|---|---|
| 04/11/2026 | Création : liste initiale du responsable applicatif, compléments issus de l'analyse de l'existant, adaptations au contexte. |
| 05/11/2026 | Section 14 : grandes fonctions demandées (DAU-01 à DAU-09), propositions à valider (DAU-10 à DAU-24), décisions à prendre (D1 à D8). |
| 05/11/2026 | Ajout de DAU-25 (isolation entre environnements, détail en 14.4), DAU-26 (model store et CI/CD), DAU-27 (commandes appelables) ; décisions D1 à D6 et D8 prises. |
