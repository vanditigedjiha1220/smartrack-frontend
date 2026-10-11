# App Flutter — Gestion de Notes (client)

Ce dossier contient uniquement le **code source** (`lib/` + `pubspec.yaml`).
Il manque volontairement les fichiers de plateforme (`android/`, `windows/`, etc.)
qui se génèrent automatiquement à la création du projet — voir étape 1 ci-dessous.

## Prérequis

- **Flutter SDK** installé (`flutter --version` doit répondre). Si ce n'est pas fait :
  https://docs.flutter.dev/get-started/install — choisis Windows si tu es sur le même
  PC que le backend.
- Le **backend doit déjà tourner** (voir `note-backend`), et tu dois connaître
  son adresse IP locale (pas juste `localhost` si tu testes depuis un autre appareil —
  voir section "Trouver l'IP du serveur" plus bas).

## Installation (première fois)

1. Crée un nouveau projet Flutter vide à côté de ce dossier, puis copie ce `lib/`
   et ce `pubspec.yaml` par-dessus :

   ```bash
   flutter create note_app_shell
   cd note_app_shell
   # Remplace le lib/ et pubspec.yaml générés par ceux fournis ici
   ```

   (Sur Windows, copie simplement le contenu du dossier `lib` fourni dans
   `note_app_shell\lib`, en écrasant ce qui existe, et fais pareil pour `pubspec.yaml`.)

2. Installe les dépendances :

   ```bash
   flutter pub get
   ```

3. Lance l'app sur le device de ton choix — le plus simple pour un premier test
   est **Chrome** (aucune configuration Android/iOS nécessaire) :

   ```bash
   flutter run -d chrome
   ```

   Ou sur un émulateur/téléphone Android connecté :

   ```bash
   flutter run
   ```

## Trouver l'IP du serveur backend

Sur la machine où tourne le backend (Windows), dans un terminal :

```
ipconfig
```

Cherche la ligne "Adresse IPv4" sous ton adaptateur WiFi actif (souvent du type
`192.168.1.XX`). C'est cette adresse, suivie de `:3000`, qu'il faut renseigner
dans l'app (icône ⚙️ en haut à droite de l'écran de login) — remplace la valeur
par défaut `http://192.168.1.100:3000`.

**Cas particulier — test dans Chrome sur la MÊME machine que le backend** :
tu peux directement utiliser `http://localhost:3000`, pas besoin de l'IP réseau.

## Comptes de test (déjà créés par `npm run seed` côté backend)

| Rôle | Email | Mot de passe |
|---|---|---|
| Admin | admin@lycee.cm | ChangeMoi123! |
| Enseignant | jean.mbarga@lycee.cm | Enseignant123! |
| Superviseur | proviseur@lycee.cm | Superviseur123! |

## Ce qui est fonctionnel à ce stade

- Écran de login partagé, avec validation de formulaire
- Configuration de l'adresse serveur (persistée localement)
- Appel réel à `POST /auth/login`, gestion des erreurs (mauvais mot de passe,
  serveur injoignable)
- Stockage sécurisé du token JWT (`flutter_secure_storage`)
- Redirection automatique vers l'écran d'accueil correspondant au rôle reçu
  (Admin / Enseignant / Superviseur) — actuellement des écrans "squelette"
  qui confirment juste la connexion, à développer ensuite un par un.

## Prochaines étapes

- Écran admin : gestion salles/matières/enseignants, octroi d'accès, bulletins
- Écran enseignant : demande d'accès, saisie de notes, déverrouillage biométrique
- Écran superviseur : flux d'alertes temps réel (WebSocket), historique des notes
