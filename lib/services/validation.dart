import '../core/format.dart';
import '../models/models.dart';
import '../l10n/i18n.dart';

/// Résultat d'un contrôle : les erreurs bloquent l'enregistrement,
/// les avertissements demandent une confirmation.
class Controle {
  final List<String> erreurs = [];
  final List<String> avertissements = [];
  bool get ok => erreurs.isEmpty;
}

/// Règles de gestion (cahier des charges §2 et §12). Fonctions pures,
/// couvertes par les tests unitaires (test/validation_test.dart).
class Regles {
  Regles._();

  static const maxChequesParChequier = 500;

  static Controle chequier(
    Chequier c, {
    required List<Chequier> existants,
    List<int> numerosEmis = const [],
  }) {
    final r = Controle();
    if (c.numero.trim().isEmpty) {
      r.erreurs.add(tr('Le numéro du chéquier est obligatoire.'));
    }
    if (c.premier <= 0) {
      r.erreurs.add(tr('Le numéro du premier chèque doit être positif.'));
    }
    if (c.dernier < c.premier) {
      r.erreurs.add(
        tr('Le dernier numéro doit être supérieur ou égal au premier.'),
      );
    } else if (c.total > maxChequesParChequier) {
      r.erreurs.add(
        tr('Un chéquier ne peut pas dépasser {0} chèques ({1} saisis).', [
          maxChequesParChequier,
          c.total,
        ]),
      );
    }
    for (final e in existants) {
      if (e.id == c.id || e.banqueId != c.banqueId) continue;
      if (e.numero.trim().toLowerCase() == c.numero.trim().toLowerCase()) {
        r.erreurs.add(
          tr('Le chéquier n° {0} existe déjà pour ce compte.', [c.numero]),
        );
      }
      final chevauche = c.premier <= e.dernier && e.premier <= c.dernier;
      if (chevauche) {
        r.erreurs.add(
          tr('La plage chevauche le chéquier n° {0} ({1}).', [
            e.numero,
            e.plage,
          ]),
        );
      }
    }
    final horsPlage = numerosEmis.where((n) => !c.contient(n)).toList();
    if (horsPlage.isNotEmpty) {
      r.erreurs.add(
        tr('{0} chèque(s) déjà émis sortiraient de la plage (ex. n° {1}).', [
          horsPlage.length,
          c.formatNumero(horsPlage.first),
        ]),
      );
    }
    return r;
  }

  static Controle cheque(
    Cheque c, {
    required Chequier? chequier,
    required List<Cheque> chequesMemeBanque,
    DateTime? aujourdhui,
  }) {
    final r = Controle();
    final now = Fmt.jour(aujourdhui ?? DateTime.now());

    if (c.montant <= 0) {
      r.erreurs.add(tr('Le montant doit être strictement positif.'));
    }
    if (c.beneficiaire.trim().isEmpty) {
      r.erreurs.add(tr('Le bénéficiaire est obligatoire.'));
    }

    if (chequier == null) {
      r.erreurs.add(tr('Sélectionnez un chéquier.'));
    } else {
      if (chequier.banqueId != c.banqueId) {
        r.erreurs.add(
          tr('Le chéquier sélectionné n\'appartient pas à cette banque.'),
        );
      }
      if (!chequier.contient(c.numero)) {
        r.erreurs.add(
          tr('Le n° {0} n\'appartient pas au chéquier n° {1} ({2}).', [
            chequier.formatNumero(c.numero),
            chequier.numero,
            chequier.plage,
          ]),
        );
      }
      if (chequier.statut == StatutChequier.archive) {
        r.erreurs.add(tr('Ce chéquier est archivé.'));
      }
    }

    for (final o in chequesMemeBanque) {
      if (o.id == c.id) continue;
      if (o.numero == c.numero && o.banqueId == c.banqueId) {
        final ou = o.deletedAt != null ? tr(' (dans la corbeille)') : '';
        r.erreurs.add(
          tr('Le chèque n° {0} existe déjà pour ce compte{1}.', [
            chequier?.formatNumero(c.numero) ?? c.numero,
            ou,
          ]),
        );
      } else if (o.deletedAt == null &&
          o.montant == c.montant &&
          o.beneficiaire.trim().toLowerCase() ==
              c.beneficiaire.trim().toLowerCase() &&
          Fmt.jour(o.dateEdition) == Fmt.jour(c.dateEdition)) {
        r.avertissements.add(
          tr(
            'Un chèque similaire existe déjà (n° {0}, même bénéficiaire, même montant, même date).',
            [o.numero],
          ),
        );
      }
    }

    final edition = Fmt.jour(c.dateEdition);
    final presentation = Fmt.jour(c.datePresentation);
    if (presentation.isBefore(edition)) {
      r.erreurs.add(
        tr('La date de présentation ne peut pas précéder la date d\'édition.'),
      );
    }
    if (edition.isAfter(now)) {
      r.avertissements.add(tr('La date d\'édition est dans le futur.'));
    }
    if (now.difference(edition).inDays > 365) {
      r.avertissements.add(tr('Le chèque a été édité il y a plus d\'un an.'));
    }
    if (presentation.difference(edition).inDays > 365) {
      r.avertissements.add(
        tr('La présentation est prévue plus d\'un an après l\'édition.'),
      );
    }
    return r;
  }

  /// Contrôle d'un changement de statut.
  static Controle changementStatut(
    Cheque c,
    Statut nouveau, {
    DateTime? nouvelleDatePresentation,
    String motifRejet = '',
  }) {
    final r = Controle();
    if (!c.statut.peutPasserA(nouveau)) {
      r.erreurs.add(
        tr('Passage de "{0}" à "{1}" non autorisé.', [
          c.statut.libelle,
          nouveau.libelle,
        ]),
      );
    }
    if (nouveau == Statut.impaye && motifRejet.trim().isEmpty) {
      r.erreurs.add(tr('Indiquez le motif du rejet.'));
    }
    if (c.statut == Statut.impaye &&
        nouveau == Statut.presente &&
        nouvelleDatePresentation == null) {
      r.erreurs.add(tr('Indiquez la nouvelle date de présentation.'));
    }
    return r;
  }
}
