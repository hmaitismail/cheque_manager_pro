import '../core/format.dart';
import '../models/models.dart';
import '../l10n/i18n.dart';

class Agregat {
  int nombre = 0;
  int montant = 0;
  void ajouter(Cheque c) {
    nombre++;
    montant += c.montant;
  }
}

class PointMensuel {
  final DateTime mois;
  int nombre = 0;
  int emis = 0;
  int payes = 0;
  int impayes = 0;
  PointMensuel(this.mois);
}

/// Tous les indicateurs du tableau de bord, calculés à partir des données
/// (aucune saisie manuelle). Chaque chèque est compté une seule fois,
/// les chèques de la corbeille sont exclus.
class Stats {
  final Agregat total = Agregat();
  final Map<Statut, Agregat> parStatut = {
    for (final s in Statut.values) s: Agregat(),
  };
  final Map<String, Agregat> parBanque = {};
  final Map<String, Agregat> parVille = {};
  final List<PointMensuel> mensuel;
  final List<Cheque> aujourdhui = [];
  final List<Cheque> demain = [];
  final List<Cheque> enRetard = [];
  final List<Cheque> impayesASuivre = [];
  int fraisRejetTotal = 0;

  Stats._(this.mensuel);

  factory Stats.calculer(
    Iterable<Cheque> cheques, {
    DateTime? maintenant,
    int nbMois = 12,
  }) {
    final now = Fmt.jour(maintenant ?? DateTime.now());
    final dem = now.add(const Duration(days: 1));
    final mois = List.generate(
      nbMois,
      (i) => DateTime(now.year, now.month - (nbMois - 1 - i), 1),
    );
    final s = Stats._(mois.map(PointMensuel.new).toList());
    final vus = <String>{};

    for (final c in cheques) {
      if (c.deletedAt != null || !vus.add(c.id)) continue;
      s.total.ajouter(c);
      s.parStatut[c.statut]!.ajouter(c);
      s.parBanque.putIfAbsent(c.banqueId, Agregat.new).ajouter(c);
      final ville = c.ville.trim().isEmpty
          ? tr('Non renseignée')
          : _capitaliser(c.ville.trim());
      s.parVille.putIfAbsent(ville, Agregat.new).ajouter(c);
      s.fraisRejetTotal += c.fraisRejet;

      final idx = s.mensuel.indexWhere(
        (p) =>
            p.mois.year == c.dateEdition.year &&
            p.mois.month == c.dateEdition.month,
      );
      if (idx >= 0) {
        final p = s.mensuel[idx];
        p.nombre++;
        p.emis += c.montant;
        if (c.statut == Statut.paye) p.payes += c.montant;
        if (c.statut == Statut.impaye) p.impayes += c.montant;
      }

      final aSuivre = c.statut == Statut.enAttente || c.statut == Statut.impaye;
      final jp = Fmt.jour(c.datePresentation);
      if (aSuivre && jp == now) s.aujourdhui.add(c);
      if (aSuivre && jp == dem) s.demain.add(c);
      if (c.estEnRetard(now)) s.enRetard.add(c);
      if (c.statut == Statut.impaye) s.impayesASuivre.add(c);
    }
    int parDate(Cheque a, Cheque b) =>
        a.datePresentation.compareTo(b.datePresentation);
    s.enRetard.sort(parDate);
    s.impayesASuivre.sort(parDate);
    return s;
  }

  Agregat de(Statut st) => parStatut[st]!;

  static String _capitaliser(String v) =>
      v.isEmpty ? v : v[0].toUpperCase() + v.substring(1).toLowerCase();
}
