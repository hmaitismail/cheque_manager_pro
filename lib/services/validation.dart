import '../core/format.dart';
import '../models/models.dart';

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
      r.erreurs.add('Le numéro du chéquier est obligatoire.');
    }
    if (c.premier <= 0) {
      r.erreurs.add('Le numéro du premier chèque doit être positif.');
    }
    if (c.dernier < c.premier) {
      r.erreurs.add(
        'Le dernier numéro doit être supérieur ou égal au premier.',
      );
    } else if (c.total > maxChequesParChequier) {
      r.erreurs.add(
        'Un chéquier ne peut pas dépasser $maxChequesParChequier chèques (${c.total} saisis).',
      );
    }
    for (final e in existants) {
      if (e.id == c.id || e.banqueId != c.banqueId) continue;
      if (e.numero.trim().toLowerCase() == c.numero.trim().toLowerCase()) {
        r.erreurs.add('Le chéquier n° ${c.numero} existe déjà pour ce compte.');
      }
      final chevauche = c.premier <= e.dernier && e.premier <= c.dernier;
      if (chevauche) {
        r.erreurs.add(
          'La plage chevauche le chéquier n° ${e.numero} (${e.plage}).',
        );
      }
    }
    final horsPlage = numerosEmis.where((n) => !c.contient(n)).toList();
    if (horsPlage.isNotEmpty) {
      r.erreurs.add(
        '${horsPlage.length} chèque(s) déjà émis sortiraient de la plage '
        '(ex. n° ${c.formatNumero(horsPlage.first)}).',
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
      r.erreurs.add('Le montant doit être strictement positif.');
    }
    if (c.beneficiaire.trim().isEmpty) {
      r.erreurs.add('Le bénéficiaire est obligatoire.');
    }

    if (chequier == null) {
      r.erreurs.add('Sélectionnez un chéquier.');
    } else {
      if (chequier.banqueId != c.banqueId) {
        r.erreurs.add(
          'Le chéquier sélectionné n\'appartient pas à cette banque.',
        );
      }
      if (!chequier.contient(c.numero)) {
        r.erreurs.add(
          'Le n° ${chequier.formatNumero(c.numero)} n\'appartient pas au chéquier '
          'n° ${chequier.numero} (${chequier.plage}).',
        );
      }
      if (chequier.statut == StatutChequier.archive) {
        r.erreurs.add('Ce chéquier est archivé.');
      }
    }

    for (final o in chequesMemeBanque) {
      if (o.id == c.id) continue;
      if (o.numero == c.numero && o.banqueId == c.banqueId) {
        final ou = o.deletedAt != null ? ' (dans la corbeille)' : '';
        r.erreurs.add(
          'Le chèque n° ${chequier?.formatNumero(c.numero) ?? c.numero} existe déjà '
          'pour ce compte$ou.',
        );
      } else if (o.deletedAt == null &&
          o.montant == c.montant &&
          o.beneficiaire.trim().toLowerCase() ==
              c.beneficiaire.trim().toLowerCase() &&
          Fmt.jour(o.dateEdition) == Fmt.jour(c.dateEdition)) {
        r.avertissements.add(
          'Un chèque similaire existe déjà (n° ${o.numero}, même bénéficiaire, '
          'même montant, même date).',
        );
      }
    }

    final edition = Fmt.jour(c.dateEdition);
    final presentation = Fmt.jour(c.datePresentation);
    if (presentation.isBefore(edition)) {
      r.erreurs.add(
        'La date de présentation ne peut pas précéder la date d\'édition.',
      );
    }
    if (edition.isAfter(now)) {
      r.avertissements.add('La date d\'édition est dans le futur.');
    }
    if (now.difference(edition).inDays > 365) {
      r.avertissements.add('Le chèque a été édité il y a plus d\'un an.');
    }
    if (presentation.difference(edition).inDays > 365) {
      r.avertissements.add(
        'La présentation est prévue plus d\'un an après l\'édition.',
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
        'Passage de "${c.statut.libelle}" à "${nouveau.libelle}" non autorisé.',
      );
    }
    if (nouveau == Statut.impaye && motifRejet.trim().isEmpty) {
      r.erreurs.add('Indiquez le motif du rejet.');
    }
    if (c.statut == Statut.impaye &&
        nouveau == Statut.presente &&
        nouvelleDatePresentation == null) {
      r.erreurs.add('Indiquez la nouvelle date de présentation.');
    }
    return r;
  }
}
