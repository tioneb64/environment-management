# Uniformité des outils DSI - guide et prompts pour un nouvel outil

|  |  |
| :- | :- |
|Document|Comment construire un nouvel outil PowerShell de la DSI en gardant la même interface et les mêmes règles que Gestion-VMCluster|
|Premier cas d'usage|Outil de gestion des environnements|
|Date|31 octobre 2026|
|Sources|Projet Gestion-VMCluster v2.0.0 (`CLAUDE.md`, `Docs\`, `Gui\`), échanges avec le responsable applicatif|

> [!IMPORTANT]
> **Ce document ne décrit pas l'apparence.** L'apparence est celle du dossier `gui-exemple` : Claude Code la reproduit en prenant ses fichiers pour modèle (styles, fenêtre principale, onglets, boîtes de dialogue, comportements). Ce guide fixe **tout le reste** : ce qui doit être identique d'un outil à l'autre, ce qui peut différer, les décisions à prendre, et les prompts à coller.
>
> **Limite.** Je n'ai pas le contenu du dossier `Gui\` sous les yeux : les noms de fichiers cités viennent de `Docs\Fichiers-et-fonctions.md` du projet Gestion-VMCluster. Le prompt U1 demande à Claude Code de **vérifier** ce que contient réellement la copie avant de s'y fier.

## 1. Principe

Un outil de la DSI doit se reconnaître au premier coup d'œil **et** se comporter de la même façon : même sécurité (simulation, confirmation), même gestion des environnements, mêmes journaux, mêmes lanceurs, mêmes conventions de code. Pour cela :

1. **L'apparence vient de la référence** : on la reproduit, on ne la réinvente pas, et on ne la décrit pas dans les prompts.
2. **Le comportement est écrit** dans ce document (section 3) et vérifié par des tests automatiques (U8).
3. **Les écarts sont tracés** : ce qui est copié de la référence est empreinte (SHA-256) dans un fichier de provenance, et un test signale toute dérive.

## 2. Mise en place

Dans le **nouveau projet**, créez un dossier de référence **hors du code livré** (par exemple `_reference\`, ajouté au `.gitignore` ; seul le fichier de provenance est versionné) et copiez-y, depuis le projet Gestion-VMCluster :

|**Dossier à créer**|**Contenu à copier (lecture seule)**|**Pourquoi**|
| :- | :- | :- |
|`_reference\gui-exemple\`|Tout le dossier `Gui\` (module, vues, `Xaml\`, `Assets\`)|L'apparence et la mécanique de l'interface (**votre demande**)|
|`_reference\core-exemple\`|`Modules\Daunat.VMCluster.Core\` et `Config\Schema.psd1`|**L'interface appelle le socle** : contexte, événements, tâches en arrière-plan, plan, accès. Sans lui, la copie de `Gui\` ne s'exécute pas et Claude Code devrait deviner ces contrats|
|`_reference\racine-exemple\`|`CLAUDE.md`, `.editorconfig`, `.gitattributes` (s'il existe), lanceurs (`Gestion-VMCluster-GUI.ps1`, `Lancer-GestionVM.cmd`), `Installer-RaccourciGestionVM.ps1`, `Config\Local\`, `Config\Preprod\` (structure seulement)|Lancement, déploiement, environnements, règles de code|
|`_reference\outillage-exemple\`|`Tests\Run-Tests.ps1`, `Tests\PesterConfiguration.ps1`, `Tests\PSScriptAnalyzerSettings.psd1`, `Tests\Tools\Find-HardcodedValue.ps1` et ses fichiers de base, `Tests\Fixtures\Import-TestPaths.ps1`|Qualité identique dans tous les outils|
|`_reference\docs-exemple\`|`Docs\Specifications.md`, `Docs\Fichiers-et-fonctions.md`, `Docs\Prompts-Claude-Code.md`, `Docs\Questions-Claude-Code.md`|La méthode de documentation et de développement assisté|

Règles pour ces dossiers :

- **Ils ne sont jamais modifiés** et le code du nouvel outil **ne les lit jamais à l'exécution** (ils seront supprimés en fin de projet, U9).
- Notez dans `_reference\PROVENANCE.md` : projet source, version, **hash du commit** et date de la copie. C'est la seule façon de savoir, dans six mois, de quelle version de la référence on est parti.
- Si le dossier `gui-exemple` contient des fichiers propres aux VM (onglets, assistants de création, etc.), ils servent d'**exemples de construction** : Claude Code ne les importe pas.

## 3. Ce qui doit être identique

La colonne « Source de vérité » dit où lire la règle : ce document, ou un fichier de la référence. Je ne recopie pas ici ce que la référence contient déjà.

### 3.1 Interface

|**Règle**|**Source de vérité**|**Contrôle**|
| :- | :- | :- |
|Apparence : styles, couleurs, polices, disposition générale, boîtes de dialogue, onglets|Fichiers de `gui-exemple\Xaml\` et `gui-exemple\Assets\`|Test de dérive des styles (U8) ; comparaison visuelle côte à côte|
|Éléments nommés de la fenêtre principale (zones de journal, de progression, d'annulation, de statut, de mode, de l'environnement)|`MainWindow.xaml` de la référence : **U1 en extrait la liste exacte**|Test qui charge la fenêtre et vérifie la présence de chaque élément (U8)|
|Les styles de la référence ne sont **jamais modifiés** : un style propre à l'outil va dans un dictionnaire d'extension séparé|Principe : base + extension|Hash de la base (U5, U8)|
|Mécanique des boîtes de dialogue (message, saisie, choix, confirmation)|Fonctions privées de la référence (`Dialogs.ps1` d'après la doc)|Mêmes noms et mêmes paramètres|
|Titre de la fenêtre, indication de l'environnement, indicateur de mode|`Startup.ps1`, `Window.ps1` de la référence|Test (U8)|
|Textes : français, ton et vocabulaire de la référence, libellés des boutons standard (Actualiser, Annuler, etc.)|Textes de la référence|Relecture (checklist, section 8)|
|Taille et position de la fenêtre|Fonction de la référence qui les gère|Checklist|
|Navigation au clavier, ordre de tabulation, raccourcis|À relever **dans la référence** par U1 (je ne les connais pas)|Checklist|

### 3.2 Comportement et sécurité

|**Règle**|**Détail**|**Contrôle**|
| :- | :- | :- |
|**Simulation par défaut**|L'outil démarre toujours en SIMULATION ; aucune étape à effet n'est exécutée|Test|
|**Passage en réel**|Saisie explicite du mot `REEL` ; retour en simulation immédiat|Test|
|**Confirmation**|En réel, saisie de `OUI` (majuscules) devant le plan affiché ; retape du nom exact pour toute suppression|Test|
|**Plan puis exécution**|Toute action est un plan d'étapes avec annulation ; construire un plan n'a aucun effet|Tests du moteur de plan|
|**Retour arrière**|Échec ou annulation : annulations jouées en ordre inverse ; étapes irréversibles signalées comme telles|Tests|
|**Une opération à la fois**, interface toujours active, bouton Annuler à deux niveaux, refus de fermer la fenêtre pendant une tâche|Comportement de la référence|Checklist + tests|
|**Profils d'accès** Lecture, Opérateur, Admin issus de groupes AD, table action → profil minimal dans `Acces.psd1`|Même mécanique (`Get-DaunatAccessProfile`, `Assert-DaunatAccess`)|Tests|
|**Erreurs de démarrage** : journal de démarrage + message d'erreur fatal, jamais une fenêtre qui disparaît sans rien dire|`Startup.ps1`|Test|
|Aucune action destructrice sans profil Admin ; les suppressions passent par une étape de récupération (quarantaine) quand c'est possible|Principe du projet VM Cluster|Revue|

### 3.3 Architecture et code

|**Règle**|**Détail**|
| :- | :- |
|Front-end sans accès direct au système géré ; **back-end sans interaction** (ni `Read-Host`, ni `Write-Host`, ni boîte de dialogue)|Règle 1 de `CLAUDE.md`|
|Contexte et état **passés en paramètres** ; aucune variable `$Script:` partagée entre modules|Règle 2|
|Modules à dépendances montantes uniquement ; fichier par fonction publique ; manifeste avec liste d'export explicite|Règles de `CLAUDE.md`|
|Fonctions publiques `Verbe-Daunat<Nom>` avec verbes approuvés ; aide en français|Voir la décision N3 sur les préfixes|
|Windows PowerShell 5.1 (cible), compatible PowerShell 7 ; WPF en STA|Compatibilité|
|UTF-8 **avec BOM** pour `.ps1`, `.psm1`, `.psd1` ; CRLF ; `.cmd` en ASCII|`.editorconfig` de la référence|
|Objets plutôt que du texte ; `PSCustomObject` avec `PSTypeName`, pas de classes PowerShell|Règle du projet|

### 3.4 Configuration et environnements

|**Règle**|**Détail**|
| :- | :- |
|Un dossier par environnement : `Config\Prod\`, `Config\Preprod\` (la recette), `Config\Local\` (poste de développement, valeurs de test valides) ; fichiers `Infra.psd1`, `Politiques.psd1`, `Integrations.psd1`, `Acces.psd1`, `Tests.psd1` ; schéma `Config\Schema.psd1`|Même structure, mêmes noms de fichiers|
|`-Environnement` sur tous les lanceurs ; `Local` refusé hors tests ; indication visuelle de l'environnement comme dans la référence|Comportement de la référence|
|**Aucune valeur en dur** (chemins, noms de serveurs, seuils, délais, conventions de nommage), tests compris ; un chemin cité en commentaire est admis|`CLAUDE.md` du projet VM Cluster, règle « Aucune valeur en dur »|
|Aucun secret dans les fichiers : références (`SecretRef`) résolues par un compte de service ou un magasin de secrets|Règle de sécurité|
|Valeur à renseigner marquée `# A RENSEIGNER` (et `# A RENSEIGNER PREPROD`) ; valeur inventée marquée `# A VALIDER`|Convention du projet|
|`Config\Schema.psd1` valide chaque fichier ; l'outil refuse de démarrer si la configuration est invalide|Même `Test-DaunatConfig`|

### 3.5 Journaux, événements, lancement

|**Règle**|**Détail**|
| :- | :- |
|Format de ligne de journal `date [utilisateur] [SIMU\|REEL] message` ; journal de session + journal central ; purge selon la configuration|Même format (voir décision N6 sur le journal central)|
|Types d'événements du back-end : Titre, Ok, Info, Alerte, Erreur, Etape, Progression|Même contrat, lu par l'interface par une file d'événements|
|Tâches en arrière-plan dans un runspace, annulation à deux niveaux|Même mécanique|
|Lanceurs : script mince `.ps1` (relance en STA, import des modules), `.cmd` d'élévation, installateur de raccourcis par environnement sans écraser celui de production|Fichiers de `racine-exemple\`|
|Icône propre à l'outil, **même famille graphique** ; icône de préproduction selon le même principe de repli|Voir décision N7|

### 3.6 Qualité, documentation, méthode

|**Règle**|**Détail**|
| :- | :- |
|Pester **5.x uniquement** (borne haute), PSScriptAnalyzer avec le même fichier de paramètres, `Run-Tests.ps1 -Environnement Local\|Preprod -Shell Desktop\|Core\|Both`|Outillage de `outillage-exemple\`|
|Scanner de valeurs en dur + test « à cliquet »|`Find-HardcodedValue.ps1` repris tel quel|
|Tests unitaires **sans** accès au système réel ; tests `Lab` tagués, jamais exécutés par Claude Code|Règle du projet|
|Documents : `README.md`, `CHANGELOG.md`, `Docs\Specifications.md`, `Docs\Fichiers-et-fonctions.md`, `Docs\Questions-Claude-Code.md`, `Docs\Prompts-Claude-Code.md`|Même plan que la référence|
|`CLAUDE.md` à la racine, avec les mêmes sections|Copie adaptée (U0)|
|Un prompt = un commit en français (`feat(module): ...`), revue à la fin de chaque phase, prompts « complexes » précédés d'un plan|Méthode du projet|
|Version SemVer dans les manifestes ; numéro du premier livrable : voir N8|Manifestes|

## 4. Ce qui peut différer

|**Élément**|**Libre**|
| :- | :- |
|Nom de l'outil, noms des modules et des fonctions métier|Oui (voir N3)|
|Onglets, vues, assistants, fonctions du back-end|Oui : c'est le contenu de l'outil|
|Clés de configuration propres à l'outil|Oui, mais dans les mêmes fichiers et validées par le schéma|
|Intégrations (AD, DNS, outils tiers)|Oui, mêmes principes : désactivées par défaut, aucun secret|
|Icône|Oui, dans la même famille graphique|

## 5. Décisions à prendre avant de commencer

|**ID**|**Question**|**Options**|**Recommandation**|
| :- | :- | :- | :- |
|N1|**Copie ou socle partagé ?** Le socle (contexte, journal, événements, plan, tâches, accès, configuration) et la base de l'interface seront identiques dans tous vos outils.|a. **Copie contrôlée** (ce que vous prévoyez) : on copie, on adapte, on suit la provenance par hash. b. **Socle partagé** : un module versionné (par exemple `Daunat.Socle`, dans son propre dépôt) utilisé par tous les outils.|**a pour démarrer, b dès le deuxième outil en production.** Avec la copie, une correction faite dans un outil n'arrive jamais seule dans l'autre : les deux divergent. Le fichier de provenance et le test de dérive (U8) limitent le risque ; le socle partagé le supprime. Si vous choisissez b d'emblée, le prompt U2 le proposera.|
|N2|Interfaces de l'outil|a. Interface graphique seule ; b. Graphique + lignes de commande (`Cli\Invoke-Tache.ps1`) ; c. + menu console de secours|**b** : les lignes de commande servent aux tâches planifiées et aux tickets ; le menu console est une porte de secours coûteuse à maintenir (dans Gestion-VMCluster elle reprend seulement les fonctions de la v1).|
|N3|Préfixes et noms de modules|a. Modules `Daunat.<Outil>.*`, fonctions `Verbe-Daunat<Nom>` (comme la référence) ; b. un préfixe par outil (`Verbe-DaunatEnv<Nom>`)|**a si le socle est partagé (N1-b), b si on copie** : deux copies d'un même module qui exportent des fonctions de même nom entrent en collision dès qu'un poste charge les deux outils dans une même session.|
|N4|Profils d'accès|a. Mêmes groupes AD que Gestion-VMCluster ; b. groupes propres à l'outil|**b** : le droit de gérer des environnements n'est pas celui de gérer des VM. La mécanique (`Acces.psd1`) reste la même.|
|N5|Environnements|Prod, Preprod, Local comme la référence|**Identique.** Vérifiez seulement que « recette » = `Preprod` pour ce projet aussi.|
|N6|Journal central|a. Commun aux outils (même dossier de données, même fichier mensuel) ; b. un journal par outil|**b**, mais avec le même format de ligne et un champ outil dans le nom de fichier, pour pouvoir les regrouper plus tard.|
|N7|Icône|a. Vous la fournissez ; b. Claude Code en génère une provisoire ; c. repli sur l'icône de la référence|**a** (c'est votre identité visuelle). **c** en attendant : rien à modifier dans le code quand le fichier arrive.|
|N8|Numérotation de version|a. Premier livrable en 1.0.0 ; b. 2.0.0|**a** : `2.0.0` du projet VM Cluster vient de la refonte d'un outil existant.|

## 6. Autres points à fixer pour garder l'uniformité

Vous m'avez demandé si je voyais d'autres éléments. Voici ceux qui, à mon avis, font dériver les outils au fil du temps, et que ce guide traite :

|**#**|**Point**|**Pourquoi c'est important**|**Où c'est traité**|
| :- | :- | :- | :- |
|1|**Le socle d'abord, l'interface ensuite**|La base de l'interface appelle le contexte, les événements, les tâches et les plans du projet source ; copier seulement `Gui\` donnerait une interface sans moteur.|Section 2 (`core-exemple`), U4|
|2|**Provenance et dérive**|Sans trace de la version copiée, impossible de savoir quels correctifs manquent.|U3, U5, U8|
|3|**Styles en couches** (base + extension)|Modifier la base pour un besoin local casse l'uniformité de façon invisible.|U5, U8|
|4|**Contrat de fenêtre vérifié par test**|Si un élément nommé disparaît ou change de nom, le journal, la progression ou l'annulation cassent sans bruit.|U1, U8|
|5|**Rétroportage**|Un défaut corrigé dans la copie doit être remonté au projet source, sinon il revient dans l'outil suivant.|Section 7|
|6|**Règles de code communes** (`CLAUDE.md`)|Les règles apprises sur le projet VM Cluster (aucune valeur en dur, plan puis exécution, PowerShell 5.1, encodage) coûtent cher à redécouvrir.|U0|
|7|**Outillage de qualité identique**|Même Pester, même analyse, même scanner de valeurs en dur, même `Run-Tests.ps1` : sinon « tout est vert » ne veut pas dire la même chose.|U3|
|8|**Environnements dès le premier jour**|Dans le projet VM Cluster, 149 valeurs en dur (surtout dans les tests) ont dû être reprises après coup : le démarrage s'était fait sans environnement `Local` ni `Tests.psd1`.|U3, U7|
|9|**Documentation et méthode**|Même découpage en phases, mêmes prompts de revue, mêmes documents : l'équipe peut passer d'un outil à l'autre.|U0, U2|
|10|**Fin de la dépendance au dossier de référence**|Le code ne doit jamais lire `_reference\` à l'exécution.|U9|

## 7. Rétroportage (processus)

Quand vous corrigez ou améliorez un fichier de **base** (copié de la référence) :

1. Corrigez-le **dans le projet source** d'abord ; mettez à jour son `CHANGELOG`.
2. Recopiez-le dans l'autre projet et mettez à jour la provenance (hash, version).
3. Si la correction est faite dans la copie par urgence, créez immédiatement une ligne dans `Docs\Retroportage.md` du nouveau projet (fichier, raison, date) : c'est une dette à rapporter à la source.

Ce processus disparaît si vous passez au socle partagé (N1-b).

## 8. Checklist de conformité (à cocher)

À faire avec **les deux outils lancés côte à côte**. Les points qui renvoient à la référence se vérifient en comparant, pas en lisant un cahier des charges.

|**Contrôle**|**Fait**|
| :- | :- |
|L'apparence générale est indiscernable de la référence (styles, disposition, boîtes de dialogue)|☐|
|Le titre de la fenêtre et l'indication de l'environnement suivent la même règle|☐|
|Au démarrage, l'outil est en simulation ; le passage en réel exige la saisie du mot attendu|☐|
|Une action réelle demande la confirmation attendue et affiche d'abord le plan|☐|
|Une tâche longue ne fige pas la fenêtre ; le bouton Annuler propose les deux niveaux|☐|
|La fenêtre ne se ferme pas pendant une tâche|☐|
|Le journal affiché, le fichier de journal et le journal central contiennent les mêmes lignes au même format|☐|
|Un démarrage en erreur (configuration invalide, module absent) produit un message clair et une trace|☐|
|Un profil Lecture ne voit aucun bouton d'action|☐|
|Le raccourci de préproduction porte un nom distinct de celui de production|☐|
|`Run-Tests.ps1 -Environnement Local -Shell Both` passe ; le scanner de valeurs en dur ne trouve rien|☐|
|La navigation au clavier et l'ordre de tabulation sont ceux de la référence|☐|
|Aucun fichier du projet ne lit `_reference\`|☐|

## 9. Prompts pour le nouvel outil

Ils se collent **dans l'ordre**, dans Claude Code lancé à la racine du **nouveau projet**, une fois la section 2 faite. Chaque prompt est un commit. Les prompts marqués **complexe** demandent un plan avant de coder. **Aucun prompt ne décrit l'apparence** : ils renvoient à `_reference\gui-exemple\`.

> [!CAUTION]
> Les prompts ne contiennent rien de fonctionnel sur l'outil de gestion des environnements : je n'en connais pas le périmètre. U2 oblige Claude Code à **vous interroger** avant de définir les onglets et le back-end.

### U0 - Contexte permanent (`CLAUDE.md`)

```text
Lis `_reference\racine-exemple\CLAUDE.md` (règles du projet Gestion-VMCluster) et `_reference\PROVENANCE.md`.

Crée `CLAUDE.md` à la racine du nouveau projet : reprends **toutes** les règles communes (compatibilité PowerShell 5.1 et 7, UTF-8 avec BOM et CRLF, architecture front-end / back-end, contexte et état passés en paramètres, plan puis exécution, simulation par défaut, aucune valeur en dur y compris dans les tests, environnements Prod / Preprod / Local, conventions de code, tests Pester 5.x, interdits, méthode un prompt = un commit). Adapte seulement ce qui est propre au projet source (nom, cluster, VM, modules `Daunat.VMCluster.*`).
Ajoute une section « Référence d'interface » : l'apparence et la mécanique de l'interface sont celles de `_reference\gui-exemple\` ; elles ne sont jamais décrites ni réinventées ; les fichiers de base copiés de la référence ne sont **jamais modifiés** (les extensions vont dans des fichiers séparés) ; `_reference\` n'est jamais lu à l'exécution.
Ajoute une section « Rétroportage » (corriger d'abord dans le projet source, voir Docs\Retroportage.md).
Ne crée aucun autre fichier. Enregistre ces règles dans ta mémoire de projet.
Commit : « docs: CLAUDE.md du nouvel outil (règles communes DSI) ».
```

### U1 - Inventaire de la référence (lecture seule)

```text
Lis CLAUDE.md. Aucune modification de code dans ce prompt.

Fais l'inventaire de `_reference\gui-exemple\` et de `_reference\core-exemple\` et écris `Docs\Analyse-reference.md` :
1. Liste de tous les fichiers de `gui-exemple`, avec leur rôle (cadre générique réutilisable, ou propre aux VM : vues, assistants, onglets) et leurs fonctions.
2. Pour chaque fichier XAML : les éléments nommés (`x:Name`) et les clés de style qu'il définit ou utilise. **Pour la fenêtre principale, dresse la liste exacte et complète des éléments nommés** : elle devient le « contrat de fenêtre » vérifié par test (U8).
3. Le contrat entre l'interface et le socle : toutes les fonctions du socle (contexte, événements, tâches, plans, accès, configuration, journal) que `gui-exemple` appelle, avec leurs paramètres.
4. Les comportements à reproduire : démarrage, titre de la fenêtre, indication de l'environnement, indicateur de mode, passage en réel, confirmation, annulation, refus de fermeture pendant une tâche, gestion des erreurs de démarrage, navigation au clavier, raccourcis, ordre de tabulation, taille et position de la fenêtre.
5. Les dépendances cachées : chemins, noms de l'outil source, clés de configuration, ressources (icônes), ce qui est propre au projet VM Cluster et doit être **remplacé** dans le nouvel outil.
6. Les écarts entre ce que tu trouves et `Docs\Fichiers-et-fonctions.md` de `_reference\docs-exemple\`.
**Ne décris pas l'apparence** (couleurs, polices, dimensions) : renvoie au fichier. Termine par la liste de tes questions. Commit : « docs: analyse de la référence d'interface ».
```

### U2 - Cadrage et plan de reprise (complexe)

```text
Lis CLAUDE.md, Docs\Analyse-reference.md et les documents de `_reference\docs-exemple\`.

**Tâche complexe : propose d'abord ton plan et n'écris rien avant mon accord.**

1. Pose-moi les questions sur l'outil de gestion des environnements : ce qu'il gère, pour qui, quelles actions, quels systèmes, quels profils, quelles intégrations, quelles données. **Ne devine rien.** Propose les onglets de l'interface une fois mes réponses reçues.
2. Fais valider les décisions N1 à N8 du document `Docs\Uniformite-Outils-DSI.md` (copie ou socle partagé, interfaces, préfixes, profils, environnements, journal central, icône, version). Tant que N1 n'est pas tranchée, ne copie rien.
3. Propose l'arborescence du nouveau projet (identique à celle du projet source pour `Config\`, `Modules\`, `Gui\`, `Cli\`, `Templates\`, `Tests\`, `Docs\`), la liste des modules, et pour chaque fichier de la référence : **copié tel quel** (base), **copié puis adapté** (nom, clés), **réécrit** (propre à l'outil) ou **non repris** (propre aux VM).
4. Propose les phases et le nombre de prompts, avec une revue à la fin de chaque phase, sur le modèle du projet source.
Commit du seul document `Docs\Plan-de-reprise.md` après mon accord.
```

### U3 - Squelette, environnements et outillage

```text
Lis CLAUDE.md, Docs\Plan-de-reprise.md et `_reference\outillage-exemple\`, `_reference\racine-exemple\`.

Crée :
1. L'arborescence validée, `.gitignore` (dont `_reference\` sauf `PROVENANCE.md`), `.editorconfig` et `.gitattributes` repris de la référence, `CHANGELOG.md`.
2. Les environnements `Config\Prod\`, `Config\Preprod\` et `Config\Local\` avec leurs fichiers (Infra, Politiques, Integrations, Acces, Tests), valides pour `Config\Schema.psd1` repris de la référence et adapté. Les valeurs inconnues sont marquées `# A RENSEIGNER` ; aucune n'est devinée.
3. L'outillage de qualité **repris tel quel** de la référence : `Tests\Run-Tests.ps1` (avec `-Environnement` et `-Shell`), `PesterConfiguration.ps1`, `PSScriptAnalyzerSettings.psd1`, `Tests\Tools\Find-HardcodedValue.ps1` avec sa base et ses exceptions vides, `Tests\Fixtures\Import-TestPaths.ps1`.
4. `Docs\PROVENANCE.md` : pour chaque fichier copié, son chemin source, la version et le hash du commit de `_reference\PROVENANCE.md`, et son **SHA-256** (`Get-FileHash -Algorithm SHA256`).
5. `Docs\Retroportage.md` (vide, avec son principe).
Vérifie : `.\Tests\Run-Tests.ps1 -Environnement Local` passe (0 test métier pour l'instant) ; le scanner ne trouve rien.
Commit : « chore: squelette, environnements et outillage communs ».
```

### U4 - Socle (complexe)

```text
Lis CLAUDE.md, Docs\Plan-de-reprise.md et `_reference\core-exemple\`.

**Tâche complexe : propose d'abord ton plan et n'écris rien avant mon accord.**

Reprends le socle de la référence selon la décision N1 (copie adaptée, ou référence au module partagé) : configuration (chargement, validation, environnements), contexte, journal de session et central, événements, plan et étapes avec retour arrière, tâches en arrière-plan avec annulation, profils d'accès. Renomme les modules et les fonctions selon la décision N3. Pour chaque fichier repris : tests Pester repris et adaptés (aucun chemin littéral, `Get-TestPath` et `Get-TestConfig`), entrée dans `Docs\PROVENANCE.md`, aucune valeur propre au projet VM Cluster.
Ne reprends **pas** ce qui est propre aux VM (placement, PRA, règles d'affinité, quarantaine, etc.).
Commit par groupe cohérent de fichiers. Fin : `Run-Tests.ps1 -Environnement Local -Shell Both` passe.
```

### U5 - Base de l'interface (copie contrôlée)

```text
Lis CLAUDE.md, Docs\Analyse-reference.md et Docs\Plan-de-reprise.md.

Copie dans `Gui\Base\` les fichiers que le plan classe « copié tel quel » (styles, cadre de la fenêtre principale, boîtes de dialogue génériques, aides de démarrage, de fenêtre, de tâches, de rafraîchissement). **Ne modifie rien dans ces copies**, pas même un commentaire. Enregistre chacune dans `Docs\PROVENANCE.md` avec son SHA-256.
Pour ce qui doit être adapté (nom de l'outil, icône, titre, noms de modules), crée un **fichier d'extension séparé** : par exemple un dictionnaire de styles propre à l'outil chargé **après** la base, et un fichier de paramètres de l'outil lu par les fonctions de démarrage. Si une adaptation te semble impossible sans toucher à la base, **arrête-toi et demande-moi** : la correction se fera dans le projet source (voir Docs\Retroportage.md).
Écris le test de dérive `Tests\Unit\UiBaseDrift.Tests.ps1` : il recalcule le SHA-256 des fichiers de `Gui\Base\` et le compare à `Docs\PROVENANCE.md`.
Commit : « feat(gui): base de l'interface copiée de la référence ».
```

### U6 - Fenêtre principale et onglets de l'outil (complexe)

```text
Lis CLAUDE.md, Docs\Analyse-reference.md, Docs\Plan-de-reprise.md (liste des onglets validée) et les fichiers de `_reference\gui-exemple\`.

**Tâche complexe : propose d'abord ton plan et attends mon accord.**

Construis la fenêtre principale et les onglets de l'outil de gestion des environnements **en prenant comme modèle les fichiers de `_reference\gui-exemple\`** : mêmes fichiers de base, même manière de construire un onglet (un fichier XAML et un fichier de vue par onglet), mêmes boutons standard, mêmes boîtes de dialogue, même mécanique de tâches, de confirmation et d'annulation. **N'invente aucune apparence et n'en décris aucune** : en cas de doute sur un élément, ouvre le fichier correspondant de la référence et reproduis-le.
Les actions de chaque onglet appellent des fonctions du back-end de l'outil (plan, confirmation, `Invoke-GuiTask`) ; elles ne touchent jamais directement au système géré. Les fonctions du back-end sont écrites dans les prompts de la phase fonctionnelle : ici, branche des **appels** vers des fonctions dont tu poses le contrat (paramètres, retour) dans `Docs\Fichiers-et-fonctions.md`, avec des tests sur des doublures.
Les éléments nommés de la fenêtre principale sont **ceux de la référence** (liste de `Docs\Analyse-reference.md`).
Commit par onglet. Fin : lance la fenêtre quelques secondes avec des données de test, ferme-la proprement et décris ce que tu as vu (sans dire que cela « ressemble » à la référence : c'est moi qui compare).
```

### U7 - Lanceurs, installateur et icône

```text
Lis CLAUDE.md et `_reference\racine-exemple\` (lanceurs, installateur de raccourcis).

Crée les lanceurs de l'outil sur le modèle de la référence : script mince de lancement de l'interface (`-Environnement`, relance en STA, import des modules), `.cmd` d'élévation avec choix de l'environnement, installateur de raccourcis par environnement (le raccourci de production n'est jamais écrasé par celui de préproduction), et `Cli\` si la décision N2 le prévoit. Aucun chemin, nom d'outil ni nom de raccourci en dur : tout vient de la configuration ou d'un fichier de paramètres de l'outil.
Icône : selon la décision N7 (le code retombe sur l'icône de la référence si le fichier de l'outil manque).
Tests : refus de `-Environnement Local` par les lanceurs ; l'installateur avec des doublures.
Commit : « feat: lanceurs, installateur et icône ».
```

### U8 - Contrôle de conformité automatique

```text
Lis CLAUDE.md, Docs\Analyse-reference.md et Docs\PROVENANCE.md.

Écris `Tests\Unit\UiConformity.Tests.ps1` et `Docs\Checklist-Conformite-UI.md` :
1. Contrat de fenêtre : la fenêtre principale de l'outil contient **tous** les éléments nommés listés dans Docs\Analyse-reference.md (liste lue dans un fichier de données `Tests\Fixtures\ContratFenetre.psd1`, pas écrite dans le test).
2. Styles : toutes les clés de style de la base de la référence existent dans la fenêtre de l'outil, avec le même contenu (comparaison du fichier de base par son hash, voir UiBaseDrift).
3. Comportements, avec des doublures (aucun système réel) : démarrage en simulation, passage en réel par le mot attendu, confirmation attendue avant exécution, annulation à deux niveaux, refus de fermeture pendant une tâche, erreur de démarrage journalisée.
4. Aucun fichier du projet ne contient la chaîne `_reference` (hors Docs\ et .gitignore).
La checklist reprend la section 8 de Docs\Uniformite-Outils-DSI.md, complétée des points propres à l'outil.
Commit : « test: conformité de l'interface avec la référence ».
```

### U9 - Revue de conformité et fin de la dépendance

```text
Lis CLAUDE.md, Docs\Uniformite-Outils-DSI.md, Docs\PROVENANCE.md, Docs\Retroportage.md et Docs\Checklist-Conformite-UI.md.

Revue de fin de phase d'interface. Sans rien ajouter de nouveau :
1. `.\Tests\Run-Tests.ps1 -Environnement Local -Shell Both` passe ; PSScriptAnalyzer ne relève rien ; le scanner de valeurs en dur est à zéro.
2. Les tests UiBaseDrift et UiConformity passent. Liste tous les fichiers de base et confirme qu'aucun n'a été modifié.
3. Recherche toute lecture de `_reference\` dans le code : il ne doit y en avoir aucune.
4. Les documents du projet existent et sont à jour : README.md, CHANGELOG.md, Docs\Specifications.md, Docs\Fichiers-et-fonctions.md, Docs\Questions-Claude-Code.md.
5. Liste ce qui reste `# A RENSEIGNER`, et ce que **je** dois vérifier à la main (checklist de conformité, comparaison côte à côte).
6. Propose le prompt qui supprimera le dossier `_reference\` à la fin du projet (je le lancerai moi-même).
Termine par un rapport : conforme, corrigé, à décider par moi. Commit : « chore: revue de conformité de l'interface ».
```

## 10. Annexe : modèle de `_reference\PROVENANCE.md`

```text
# Provenance de la référence

Projet source : Gestion-VMCluster
Version : <version du projet source, par exemple 2.0.0>
Commit : <hash complet du commit copié>
Date de la copie : <date>
Copié par : <nom>

| Dossier de référence | Chemin source | Remarque |
| gui-exemple | Gui\ | |
| core-exemple | Modules\Daunat.VMCluster.Core\ et Config\Schema.psd1 | |
| racine-exemple | CLAUDE.md, .editorconfig, lanceurs, installateur, Config\Local\ | |
| outillage-exemple | Tests\ (outillage uniquement) | |
| docs-exemple | Docs\ | |
```
