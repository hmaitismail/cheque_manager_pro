# Vendre Cheque Manager Pro : licences

## Principe

* Chaque nouvelle installation bénéficie de **30 jours d'essai gratuit** (complet).
* Après l'essai, l'application passe en **lecture seule** : le client voit toujours ses chèques,
  peut chercher et sauvegarder, mais ne peut plus saisir, modifier, changer un statut ni
  produire de rapports. Ses données ne sont jamais bloquées ni perdues.
* Pour débloquer, le client vous envoie son **code appareil** (Paramètres > Licence, bouton
  « Envoyer ») et vous lui renvoyez une **clé d'activation**.
* La clé est signée avec votre **clé privée** (algorithme Ed25519). L'application ne contient que
  la clé publique : personne ne peut fabriquer de clé sans votre fichier `cle_privee_vendeur.txt`.
* Une clé ne fonctionne que sur l'appareil dont elle porte le code.

## Formules disponibles

| Formule | Commande | Durée |
|---|---|---|
| Mensuelle | `mensuelle` | 31 jours |
| Annuelle | `annuelle` | 365 jours |
| À vie | `vie` | illimitée |
| Sur mesure | `annuelle --jours 90` | le nombre de jours voulu |

Le prix est libre : vous encaissez comme vous le souhaitez (virement, cash, CIH Pay, Orange Money...)
puis vous envoyez la clé.

## Générer une clé (sur PC)

```bat
pip install cryptography
python outils\generer_licence.py K7Q2-M9XD annuelle --cle C:\chemin\cle_privee_vendeur.txt
```

La clé affichée (environ 140 caractères, groupés par 6) se copie-colle dans WhatsApp.
Le client la colle dans Paramètres > Licence > Activer.

## Règles de sécurité

* **Ne mettez jamais `cle_privee_vendeur.txt` dans le dépôt GitHub**, ni dans un e-mail ou un
  groupe WhatsApp. Gardez-en deux copies (PC + clé USB ou coffre-fort de mots de passe).
* Si elle est perdue : les clés déjà vendues continuent de marcher, mais vous ne pourrez plus en
  créer. Il faudrait publier une version avec une nouvelle clé publique.
* Si elle est volée : quelqu'un pourrait fabriquer des clés. Prévenez-moi : on change la paire de
  clés dans une nouvelle version.

## Cas particuliers

* **Le client change de téléphone ou réinstalle l'application** : un nouveau code appareil est
  créé. Il restaure sa sauvegarde `.cmpbak`, vous envoie le nouveau code, et vous lui générez une
  nouvelle clé (geste commercial conseillé).
* **Fin d'abonnement** : l'application repasse en lecture seule à la date d'expiration ; une
  alerte apparaît 7 jours avant sur l'accueil.

## Play Store (plus tard)

Sur le Play Store, Google impose son propre système de paiement (abonnement ou achat intégré,
commission de 15 %). La version Play Store utilisera alors Google Play Billing ; les clés
d'activation restent valables pour les ventes directes (APK).
