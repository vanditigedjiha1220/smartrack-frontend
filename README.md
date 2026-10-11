# SmartTrack — Application de gestion de notes scolaires

## Présentation du projet

**SmartTrack** est une application conçue pour faciliter la gestion des notes scolaires tout en renforçant la sécurité et la transparence des opérations effectuées sur les résultats des élèves.

Le projet vise à proposer un espace de travail adapté aux différents acteurs d'un établissement scolaire. Chaque utilisateur dispose d'un accès correspondant à son rôle, afin de séparer les responsabilités et de mieux contrôler les opérations liées aux notes.

L'application est développée avec **Flutter**, ce qui permet de concevoir une interface utilisable sur plusieurs plateformes à partir d'une même base de code.

## Objectifs de SmartTrack

Le projet a pour objectifs de :

- Simplifier les interactions entre les différents acteurs impliqués dans la gestion des notes.
- Organiser les accès selon les responsabilités de chaque utilisateur.
- Renforcer la sécurité des connexions et des opérations sensibles.
- Favoriser la traçabilité des actions afin de faciliter le contrôle et la détection d'activités inhabituelles.
- Préparer une gestion plus fiable et plus transparente des résultats scolaires.

## Les utilisateurs de l'application

SmartTrack prévoit trois profils principaux.

### 1. Administrateur

L'administrateur est chargé de l'organisation générale du système. Son espace est destiné notamment à la gestion des comptes, des salles de classe et des matières, ainsi qu'à l'attribution des autorisations nécessaires.

### 2. Enseignant

L'enseignant utilise l'application dans le cadre de ses activités pédagogiques. Son espace est destiné à la consultation des informations qui le concernent, aux demandes d'accès nécessaires et, à terme, à la saisie des notes dans un cadre autorisé.

### 3. Superviseur

Le superviseur est chargé du contrôle et du suivi des opérations. Son espace est destiné à la consultation de l'historique des activités et au suivi des alertes permettant de repérer d'éventuelles anomalies.

**Important :** ces espaces correspondent aux fonctionnalités prévues du système. Toutes les fonctions de gestion, de saisie et de supervision ne sont pas encore entièrement développées dans la version actuelle.

## Comment fonctionne l'application ?

SmartTrack repose sur deux éléments complémentaires :

- **Le frontend**, développé avec Flutter, constitue l'interface que l'utilisateur consulte et utilise.
- **Le backend**, développé séparément, traite les demandes, vérifie les identifiants et les autorisations, et communique avec la base de données.

Lorsqu'un utilisateur se connecte, l'application transmet ses informations au backend. Si l'authentification réussit, l'utilisateur est dirigé vers l'espace correspondant à son rôle.

Cette séparation permet de faire évoluer l'interface et les services du système de manière indépendante.

## Fonctionnalités déjà disponibles

La version actuelle comprend :

- Un écran de connexion commun aux différents profils.
- La vérification des champs du formulaire de connexion.
- La configuration de l'adresse du serveur auquel l'application se connecte.
- La communication avec le backend pour l'authentification.
- La gestion des erreurs de connexion, notamment lorsque les identifiants sont incorrects ou que le serveur est indisponible.
- Le stockage sécurisé du jeton d'authentification.
- La redirection vers un écran d'accueil adapté au rôle de l'utilisateur.

Les écrans d'accueil des différents profils constituent actuellement une première base de travail. Ils seront enrichis progressivement avec les fonctionnalités propres à chaque utilisateur.

## Technologies utilisées

- **Flutter et Dart** : création de l'interface utilisateur.
- **API REST** : communication entre l'application et le backend.
- **Authentification par jeton JWT** : maintien de la session après une connexion réussie.
- **flutter_secure_storage** : stockage sécurisé des informations de session prises en charge par la plateforme.

Le backend et ses technologies de traitement sont documentés dans leur dépôt respectif.

## Installation et démarrage

### Prérequis

Avant de lancer l'application, il faut disposer de :

- Flutter installé et correctement configuré.
- Un environnement de développement compatible, par exemple Visual Studio Code.
- Le backend SmartTrack installé et démarré.
- L'adresse du serveur backend accessible depuis l'appareil utilisé pour tester l'application.

Pour installer Flutter, consulte la documentation officielle :  
https://docs.flutter.dev/get-started/install

### Récupérer les dépendances

Après avoir récupéré le projet, ouvre un terminal à la racine du dossier frontend et exécute :

```bash
flutter pub get
```

### Lancer l'application dans Chrome

Pour effectuer un premier test sur ordinateur, exécute :

```bash
flutter run -d chrome
```

### Lancer l'application sur Android

Connecte un téléphone Android configuré pour le développement ou démarre un émulateur, puis exécute :

```bash
flutter run
```

Selon la plateforme, certaines configurations supplémentaires peuvent être nécessaires.

## Configurer la connexion au backend

Pour que la connexion fonctionne, le frontend doit pouvoir joindre le serveur backend.

Dans l'environnement de développement :

- Si l'application fonctionne dans Chrome sur le même ordinateur que le backend, l'adresse peut être `http://localhost:3000`.
- Si l'application fonctionne sur un téléphone, utilise l'adresse IP locale de l'ordinateur qui héberge le backend, suivie du port `3000`. Les deux appareils doivent pouvoir communiquer sur le réseau.

Sur Windows, la commande suivante permet de rechercher l'adresse IP locale :

```bash
ipconfig
```

Dans l'application, utilise le bouton de configuration du serveur sur l'écran de connexion pour renseigner l'adresse appropriée.

Pour plus d'informations sur l'installation, le démarrage du serveur et les comptes de démonstration, consulte le dépôt du backend :

https://github.com/vanditigedjiha1220/smartrack-backend

## Évolutions prévues

Le développement se poursuivra autour de plusieurs axes :

- **Espace administrateur :** gestion des classes, des matières, des comptes et des autorisations.
- **Espace enseignant :** demandes d'accès, saisie des notes et mécanismes de sécurisation des opérations sensibles.
- **Espace superviseur :** consultation de l'historique, suivi des alertes et surveillance des opérations en temps réel.
- **Sécurité :** amélioration des contrôles d'accès et des mécanismes de protection contre les manipulations non autorisées.

## État du projet

SmartTrack est actuellement en cours de développement. La version publiée constitue une première base fonctionnelle centrée sur l'authentification, la communication avec le backend et la séparation des espaces utilisateurs.

Les autres fonctionnalités seront intégrées progressivement et testées au fur et à mesure de leur développement.

## Contribution

Les suggestions, les remarques et les contributions sont les bienvenues pour améliorer l'ergonomie, la sécurité et les fonctionnalités de SmartTrack.

## Licence

Aucune licence n'est définie pour le moment. Les conditions de réutilisation et de distribution du code pourront être précisées ultérieurement.
