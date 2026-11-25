# Guide utilisateur - Cheque Manager Pro

## 1. Premier lancement

1. Créez votre **code de sécurité** (4 à 6 chiffres), puis confirmez-le.
   Si le téléphone le permet, l'empreinte digitale ou Face ID est activée automatiquement.
2. Autorisez les **notifications** : elles servent aux rappels de présentation.
3. Allez dans **Plus > Banques et chéquiers** :
   * **+ Compte bancaire** : nom de la banque, agence, ville, titulaire, référence du compte.
   * Dans la carte de la banque, **+ Chéquier** : numéro du chéquier, premier et dernier numéro
     de chèque (ex. 0000125 → 0000149). Le nombre de chèques est calculé automatiquement.

L'application refuse un chéquier dont le numéro existe déjà dans le compte ou dont la plage
chevauche un autre chéquier du même compte.

## 2. Enregistrer un chèque

Bouton vert **Nouveau chèque** (accueil, liste ou calendrier).

* La banque et le chéquier sont présélectionnés, et le **prochain numéro libre** est proposé.
* Saisissez le montant (ex. `15000` ou `15 000,50`), le bénéficiaire, la ville, l'objet, les dates.
* Les bénéficiaires et villes déjà saisis sont proposés automatiquement.
* **Pièces jointes** : photographiez le chèque, importez une photo ou joignez un PDF.

Contrôles automatiques :
* **bloquants** : montant nul ou négatif, numéro hors du chéquier, numéro déjà utilisé dans le
  compte (même dans la corbeille), présentation avant l'édition, chéquier archivé ;
* **avertissements** (vous pouvez confirmer) : chèque similaire (même bénéficiaire, même montant,
  même date), date d'édition dans le futur ou de plus d'un an.

## 3. Suivre les statuts

Ouvrez la fiche du chèque puis **Changer le statut** :

| Statut actuel | Passages possibles |
|---|---|
| En attente | Présenté, Récupéré, Détruit |
| Présenté | Payé, Impayé |
| Impayé | Représenter (nouvelle date obligatoire), Payé, Récupéré, Détruit |
| Récupéré | Détruit |
| Payé, Détruit | définitifs |

* **Payé** demande de confirmer que le débit a bien été constaté sur le compte :
  un chèque présenté n'est jamais considéré comme payé automatiquement.
* **Impayé** : motif du rejet obligatoire, frais et nouvelle date de présentation facultatifs.
* Chaque changement peut recevoir un commentaire et un justificatif (photo ou PDF).
* Tout est conservé dans l'**historique des statuts** de la fiche.

## 4. Rappels

Pour chaque chèque en attente (ou impayé à représenter) :
* la **veille** de la date de présentation (9 h par défaut) ;
* le **jour même** (8 h par défaut) ;
* le **lendemain** s'il est toujours en attente (alerte de retard) ;
* une alerte quotidienne regroupe les chèques **en retard** et les **impayés** à régulariser.

Les rappels fonctionnent application fermée. Réglages : **Calendrier > icône cloche** ou
**Plus > Paramètres > Réglages des rappels** (heures, alertes, notification de test).
Pour couper les rappels d'un seul chèque : **Modifier > Rappels de présentation**.

## 5. Tableau de bord

* **Montant engagé non encore débité** (en attente + présentés).
* **Priorités du jour** : à présenter aujourd'hui et demain, en retard, impayés.
* **Indicateurs** par statut (nombre et montant). Touchez une carte pour voir la liste filtrée.
* **Graphiques** : répartition par statut, montants émis par mois, payés / impayés,
  nombre de chèques par mois, répartition par banque et par ville. Touchez un graphique pour
  afficher la valeur.

## 6. Rechercher

Onglet **Chèques** : la barre de recherche trouve un numéro, un bénéficiaire, une banque, un
chéquier, une ville, un objet ou un montant exact. Les puces filtrent par statut ou retard ;
le bouton **Filtres** ajoute banque, chéquier, ville, période et fourchette de montant ;
le bouton **Trier** classe par date, montant, numéro ou banque.

## 7. Rapports

Onglet **Rapports** : choisissez le type (en attente, présentés, payés, impayés, récupérés,
détruits, situation par banque, situation mensuelle, journal complet) et la période, puis :
* **Aperçu et impression PDF** ;
* **PDF**, **Excel** ou **CSV** : le fichier est proposé au partage (WhatsApp, e-mail, Drive...).

## 8. Sécurité et sauvegardes

* **Verrouillage automatique** après inactivité (5 minutes par défaut, réglable, ou immédiat).
* Après 5 codes faux, l'accès est bloqué temporairement (30 s, puis plus longtemps).
* Les données sont **chiffrées** sur le téléphone.
* **Sauvegarde automatique** chaque jour. Pour mettre une copie à l'abri :
  **Plus > Paramètres > Créer et exporter une sauvegarde** puis enregistrez le fichier
  `.cmpbak` sur Drive, par e-mail ou sur un PC.
* **Restaurer** : même écran, *Restaurer depuis un fichier*. Une sauvegarde de sécurité des
  données actuelles est faite automatiquement avant.

## 9. Corbeille et traçabilité

* Seul un chèque **en attente** peut être supprimé : il va dans la **corbeille**
  (Plus > Corbeille) d'où il peut être restauré.
* La suppression définitive se fait uniquement depuis la corbeille, avec confirmation, et
  laisse une trace complète dans l'historique.
* **Plus > Historique** liste toutes les opérations : créations, modifications (avec l'ancienne
  et la nouvelle valeur), changements de statut, pièces jointes, sauvegardes, exports.

## 10. Langue

**Paramètres > Affichage > Langue** : français, العربية (affichage de droite à gauche) ou English.
Les rapports PDF et les notifications suivent la langue choisie.

## 11. Licence

* 30 jours d'essai gratuit, avec toutes les fonctions.
* **Paramètres > Licence** affiche l'état de la licence et le **code de l'appareil**.
  Le bouton « Envoyer » transmet ce code au vendeur, qui vous renvoie une clé d'activation.
  Collez-la puis touchez **Activer la licence**.
* Sans licence active, l'application passe en lecture seule : vos chèques restent visibles,
  la recherche et les sauvegardes restent possibles.
