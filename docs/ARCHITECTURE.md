# Architecture technique - Cheque Manager Pro

## Choix techniques

| Besoin | Choix | Raison |
|---|---|---|
| Android + iOS | Flutter (Dart) | Un seul code, performances natives, gratuit |
| Stockage local | SQLite chiffrée (sqflite_sqlcipher, AES-256) | Fiable, hors connexion, transactions ACID |
| Clé de chiffrement, PIN | flutter_secure_storage (Keystore / Keychain) | Jamais en clair sur le téléphone |
| Rappels | flutter_local_notifications + timezone (Africa/Casablanca) | Programmés dans le système, application fermée |
| Biométrie | local_auth | Empreinte / Face ID |
| Graphiques | fl_chart | Interactifs, légers |
| PDF / impression | pdf + printing | Rapports professionnels |
| Excel | générateur interne (services/xlsx.dart) | Vrai .xlsx, montants numériques, aucun conflit de dépendances |
| Cloud (phase 2) | Supabase (PostgreSQL + Auth + Storage) | Open source, offre gratuite, SQL identique au local |

Aucun abonnement payant n'est nécessaire en phase 1.

## Données

Tous les montants sont stockés en **centimes (entiers)** : aucune erreur d'arrondi.
Tous les identifiants sont des **UUID** et chaque ligne porte `created_at` / `updated_at`
(et `deleted_at` pour les chèques) : la synchronisation de la phase 2 se branchera sans
modifier le schéma.

```
banques 1───n chequiers 1───n cheques 1───n historique_statuts
                                     └──n pieces_jointes
journal (toutes les opérations)   parametres (clé / valeur)
```

Contraintes en base (en plus des contrôles de l'application) :
* `UNIQUE (banque_id, numero)` sur les chèques : pas de doublon dans un compte ;
* `UNIQUE (banque_id, numero)` sur les chéquiers ;
* `CHECK (montant > 0)`, `CHECK (dernier >= premier)`, clés étrangères actives.

## Règles de gestion (services/validation.dart, models/statut.dart)

* Numéro de chèque compris dans la plage du chéquier sélectionné, chéquier de la même banque.
* Plages de chéquiers sans chevauchement dans un même compte ; une plage ne peut pas être
  réduite sous des chèques déjà émis ; maximum 500 chèques par chéquier.
* Transitions de statut limitées (tableau du guide utilisateur) ; *Payé* uniquement depuis
  *Présenté* (ou *Impayé* régularisé) avec confirmation explicite.
* Chèque payé, récupéré ou détruit : jamais supprimable ; montant, numéro et compte figés.
* Toute écriture est faite en transaction avec une entrée de journal (avant / après).
* Le tableau de bord exclut la corbeille et déduplique les chèques par identifiant.

## Rappels

`PlanificateurRappels.planifier` (fonction pure, testée) calcule le plan ; `ServiceRappels`
annule et reprogramme toutes les notifications au démarrage et après chaque modification.
Les 60 plus proches sont gardées (limite iOS de 64). Identifiants stables (hachage FNV de l'UUID).

## Sauvegarde

Archive `.cmpbak` (zip) : `manifeste.json` (format, version du schéma, date), `donnees.json`
(toutes les tables), `pieces/` (photos et PDF). Restauration transactionnelle précédée d'une
sauvegarde de sécurité. Sauvegarde automatique quotidienne, 10 conservées.

## Feuille de route

* **Phase 2** : compte utilisateur Supabase, synchronisation bidirectionnelle (envoi des lignes
  modifiées depuis la dernière synchro, réception des lignes distantes plus récentes, conflits
  résolus à la date de modification la plus récente avec trace dans le journal), envoi des
  pièces jointes dans le Storage, notifications push, sauvegarde chiffrée par mot de passe.
* **Phase 3** : OCR du chèque (Google ML Kit, sur l'appareil) avec écran de validation
  obligatoire ; migration vers `material_ui`.
