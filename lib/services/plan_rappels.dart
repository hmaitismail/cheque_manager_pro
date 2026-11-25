import '../core/format.dart';
import '../models/models.dart';
import '../l10n/i18n.dart';

class ReglagesRappels {
  bool actifs;
  int heureVeille; // minutes depuis minuit
  int heureJour;
  bool alerteRetard;
  bool alerteImpayes;

  ReglagesRappels({
    this.actifs = true,
    this.heureVeille = 9 * 60,
    this.heureJour = 8 * 60,
    this.alerteRetard = true,
    this.alerteImpayes = true,
  });

  Map<String, String> toParams() => {
    'rappels_actifs': actifs ? '1' : '0',
    'rappels_heure_veille': '$heureVeille',
    'rappels_heure_jour': '$heureJour',
    'rappels_retard': alerteRetard ? '1' : '0',
    'rappels_impayes': alerteImpayes ? '1' : '0',
  };

  factory ReglagesRappels.fromParams(Map<String, String?> p) => ReglagesRappels(
    actifs: (p['rappels_actifs'] ?? '1') == '1',
    heureVeille: int.tryParse(p['rappels_heure_veille'] ?? '') ?? 9 * 60,
    heureJour: int.tryParse(p['rappels_heure_jour'] ?? '') ?? 8 * 60,
    alerteRetard: (p['rappels_retard'] ?? '1') == '1',
    alerteImpayes: (p['rappels_impayes'] ?? '1') == '1',
  );
}

class PlanRappel {
  final int id;
  final DateTime date;
  final String titre;
  final String corps;
  final String? chequeId;
  PlanRappel(this.id, this.date, this.titre, this.corps, this.chequeId);
}

/// Calcul pur du plan de notifications (testé unitairement).
class PlanificateurRappels {
  PlanificateurRappels._();

  /// iOS limite à 64 notifications en attente : on garde les 60 plus proches.
  static const maxPlanifiees = 60;
  static const _idRetardGroupe = 1;
  static const _idImpayesGroupe = 2;

  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h & 0x0FFFFFFF;
  }

  static int idPour(String chequeId, int type) =>
      10 + _hash(chequeId) * 4 + type;

  static DateTime _a(DateTime jour, int minutes) =>
      DateTime(jour.year, jour.month, jour.day, minutes ~/ 60, minutes % 60);

  /// Calcul pur du plan de notifications (testé unitairement).
  static List<PlanRappel> planifier(
    Iterable<Cheque> cheques,
    ReglagesRappels r, {
    required DateTime maintenant,
    String Function(Cheque)? libelleNumero,
  }) {
    if (!r.actifs) return [];
    final plan = <PlanRappel>[];
    final aujourdhui = Fmt.jour(maintenant);
    final String Function(Cheque) numero =
        libelleNumero ?? ((Cheque c) => '${c.numero}');
    final retards = <Cheque>[];
    final impayes = <Cheque>[];

    for (final c in cheques) {
      if (c.deletedAt != null) continue;
      final suivi = c.statut == Statut.enAttente || c.statut == Statut.impaye;
      if (!suivi) continue;
      if (c.estEnRetard(maintenant)) retards.add(c);
      if (c.statut == Statut.impaye) impayes.add(c);
      if (!c.rappelsActifs) continue;

      final jp = Fmt.jour(c.datePresentation);
      final details = tr('Chèque n° {0} - {1}\nBénéficiaire : {2}', [
        numero(c),
        Fmt.mad(c.montant),
        c.beneficiaire,
      ]);
      final veille = _a(jp.subtract(const Duration(days: 1)), r.heureVeille);
      if (veille.isAfter(maintenant)) {
        plan.add(
          PlanRappel(
            idPour(c.id, 0),
            veille,
            tr('Présentation demain'),
            tr('Attention, ce chèque sera présenté demain.\n{0}', [details]),
            c.id,
          ),
        );
      }
      final jour = _a(jp, r.heureJour);
      if (jour.isAfter(maintenant)) {
        plan.add(
          PlanRappel(
            idPour(c.id, 1),
            jour,
            tr('Présentation aujourd\'hui'),
            tr('Rappel, ce chèque doit être présenté aujourd\'hui.\n{0}', [
              details,
            ]),
            c.id,
          ),
        );
      }
      if (r.alerteRetard &&
          c.statut == Statut.enAttente &&
          !jp.isBefore(aujourdhui)) {
        final retard = _a(jp.add(const Duration(days: 1)), r.heureJour);
        plan.add(
          PlanRappel(
            idPour(c.id, 2),
            retard,
            tr('Chèque en retard'),
            tr(
              'Ce chèque est toujours en attente après sa date de présentation.\n{0}',
              [details],
            ),
            c.id,
          ),
        );
      }
    }

    var prochain = _a(aujourdhui, r.heureJour);
    if (!prochain.isAfter(maintenant)) {
      prochain = _a(aujourdhui.add(const Duration(days: 1)), r.heureJour);
    }
    if (r.alerteRetard && retards.isNotEmpty) {
      final total = retards.fold<int>(0, (s, c) => s + c.montant);
      plan.add(
        PlanRappel(
          _idRetardGroupe,
          prochain,
          tr('{0} chèque(s) en retard', [retards.length]),
          tr('Montant total : {0}. Pensez à mettre à jour leur statut.', [
            Fmt.mad(total),
          ]),
          null,
        ),
      );
    }
    if (r.alerteImpayes && impayes.isNotEmpty) {
      final total = impayes.fold<int>(0, (s, c) => s + c.montant);
      plan.add(
        PlanRappel(
          _idImpayesGroupe,
          prochain.add(const Duration(minutes: 1)),
          tr('{0} chèque(s) impayé(s) à régulariser', [impayes.length]),
          tr('Montant total : {0}.', [Fmt.mad(total)]),
          null,
        ),
      );
    }

    plan.sort((a, b) => a.date.compareTo(b.date));
    return plan.take(maxPlanifiees).toList();
  }
}
