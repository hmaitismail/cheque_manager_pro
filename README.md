# Cheque Manager Pro

Application mobile Android / iOS de gestion, suivi et contrôle des chèques émis.
Flutter · SQLite chiffrée (SQLCipher) · 100 % en français · montants en MAD.

**Version 1.0.0 · Phase 1 : fonctionnement local complet (hors connexion).**

---

## 1. Ce que contient la phase 1

| Cahier des charges | État |
|---|---|
| §2 Banques, comptes, chéquiers multiples, contrôle des plages et doublons | ✅ |
| §3 Formulaire chèque complet, photo (appareil / galerie), PDF, remplacement tracé | ✅ |
| §3 OCR (lecture automatique du chèque) | ⏳ Phase 3 |
| §4 Six statuts, transitions contrôlées, historique, impayé (motif, frais, nouvelle date), confirmations | ✅ |
| §5 Rappels veille / jour J / retard / impayés, application fermée, réglables, désactivables par chèque | ✅ (notifications locales) |
| §5 Notifications push | ⏳ Phase 2 (avec le cloud) |
| §6 Tableau de bord : 13 indicateurs, 6 graphiques, priorités du jour | ✅ |
| §7 Recherche multicritère, filtres, tri, fiche détaillée avec historique | ✅ |
| §8 Rapports PDF / Excel (.xlsx) / CSV, impression, 9 types de rapports | ✅ |
| §9 PIN, biométrie, chiffrement AES-256, verrouillage auto, journal, corbeille, sauvegarde quotidienne, restauration | ✅ |
| §9 Synchronisation multi-appareils et gestion des conflits | ⏳ Phase 2 (Supabase, schéma prêt : `supabase/schema.sql`) |
| §11 Design bleu nuit / blanc / vert, mode clair et sombre | ✅ |
| §12 Contrôles et règles de gestion | ✅ (testés, voir `test/`) |

---

## 2. Installation de l'environnement (une seule fois, sous Windows)

1. **Flutter SDK** (version stable récente, 3.38 ou plus) : https://docs.flutter.dev/get-started/install/windows
   Décompressez-le par exemple dans `C:\flutter` et ajoutez `C:\flutter\bin` au PATH.
2. **Android Studio** : installez-le, puis dans *SDK Manager* installez :
   *Android SDK Platform 37*, *Android SDK Command-line Tools*, *Android SDK Build-Tools*.
3. **Python 3** (déjà présent sur votre poste normalement), pour le script de configuration.
4. Vérifiez dans un terminal :
   ```
   flutter doctor
   flutter doctor --android-licenses
   ```
   Toutes les lignes Android doivent être vertes.

## 3. Compiler l'application Android

Dans le dossier du projet (`cheque_manager_pro`) :

```bat
:: 1) Générer les dossiers Android et iOS (ne touche pas au code dans lib/)
flutter create --org ma.chequemanager --project-name cheque_manager_pro --platforms android,ios .

:: 2) Appliquer la configuration (permissions, notifications, biométrie, SDK)
python outils\configurer_plateformes.py

:: 3) Télécharger les dépendances
flutter pub get

:: 4) Lancer les tests des règles de gestion (32 tests)
flutter test

:: 5) Compiler l'APK installable
flutter build apk --release
```

L'APK se trouve dans `build\app\outputs\flutter-apk\app-release.apk`.
Copiez-le sur le téléphone et installez-le (autorisez « sources inconnues »).

Pour tester directement sur un téléphone branché en USB (mode développeur activé) : `flutter run`.

Pour le Play Store : `flutter build appbundle` (fichier `.aab`), après avoir créé une clé de
signature : https://docs.flutter.dev/deployment/android#sign-the-app

> Si `flutter pub get` signale une version introuvable, lancez
> `flutter pub upgrade --major-versions` puis `flutter analyze` et transmettez-moi les messages.

## 4. Compiler pour iPhone

La compilation iOS exige un **Mac** avec Xcode et un compte Apple Developer.
Sur le Mac, depuis le même dossier : `flutter create ...` (étape 1), `python3 outils/configurer_plateformes.py`,
`flutter pub get`, `cd ios && pod install`, puis `flutter build ipa`.
Ouvrez ensuite `ios/Runner.xcworkspace` dans Xcode pour la signature et la publication (TestFlight / App Store).

## 5. Structure du code

```
lib/
  main.dart                 Démarrage, thème, verrou de sécurité
  core/                     Formatage MAD et dates, thème bleu nuit / vert
  models/                   Banque, Chéquier, Chèque, Statut, historique, pièces, journal, filtres
  data/database.dart        Schéma SQLite chiffré + migrations
  data/repository.dart      Accès aux données, transactions, journalisation
  services/validation.dart  Règles de gestion (§12)
  services/stats.dart       Indicateurs du tableau de bord
  services/plan_rappels.dart  Calcul des rappels
  services/rappels.dart     Programmation des notifications système
  services/rapports.dart    Rapports PDF / Excel / CSV
  services/xlsx.dart        Générateur Excel natif (sans dépendance)
  services/sauvegarde.dart  Sauvegarde / restauration (.cmpbak)
  services/securite.dart    PIN haché, biométrie, anti-force brute
  state/app_state.dart      État global, recalcul automatique
  screens/                  Tous les écrans
  widgets/                  Composants réutilisables, graphiques
test/regles_test.dart       Tests des règles, calculs, recherche et rappels
supabase/schema.sql         Schéma cloud pour la phase 2
outils/configurer_plateformes.py  Configuration Android / iOS
docs/                       Architecture et guide utilisateur
```

## 6. Maintenance

* **Mises à jour** : réinstaller un nouvel APK par-dessus l'ancien conserve toutes les données
  (même `applicationId`, même clé de signature). Ne désinstallez jamais l'application sans
  avoir exporté une sauvegarde.
* **Évolutions du schéma** : chaque nouvelle version de la base ajoute une étape dans
  `AppDatabase._migrer` (jamais de recréation de la base).
* **Sauvegardes** : une sauvegarde automatique est créée chaque jour (10 conservées sur le
  téléphone). Exportez-en une régulièrement (Plus > Paramètres > Créer et exporter).
* **Dépendances** : `flutter pub outdated` pour voir les mises à jour, puis `flutter test`
  avant toute nouvelle livraison.
* **Avertissements `material.dart`** : sur Flutter 3.47 et plus, `flutter analyze` signale que
  `package:flutter/material.dart` est déprécié au profit de `material_ui`. Ce n'est qu'un
  avertissement, l'application compile et fonctionne. La migration est prévue dans une phase suivante.
