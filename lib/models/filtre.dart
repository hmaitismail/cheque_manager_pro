import '../l10n/i18n.dart';
import '../core/format.dart';
import 'models.dart';

enum Tri {
  presentationDesc('Présentation (récent)'),
  presentationAsc('Présentation (ancien)'),
  editionDesc('Édition (récent)'),
  montantDesc('Montant décroissant'),
  montantAsc('Montant croissant'),
  numero('Numéro de chèque'),
  banque('Banque');

  const Tri(this._libelle);
  final String _libelle;
  String get libelle => tr(_libelle);
}

/// Critères de recherche (cahier des charges §7).
class FiltreCheques {
  String texte = '';
  Set<Statut> statuts = {};
  String? banqueId;
  String? chequierId;
  String? ville;
  DateTime? du;
  DateTime? au;
  int? montantMin;
  int? montantMax;
  bool retardSeulement = false;
  Tri tri = Tri.presentationDesc;

  FiltreCheques();
  FiltreCheques.statuts(Set<Statut> s) {
    statuts = s;
  }
  FiltreCheques.retards() {
    retardSeulement = true;
  }

  int get nbCriteres =>
      (statuts.isNotEmpty ? 1 : 0) +
      (banqueId != null ? 1 : 0) +
      (chequierId != null ? 1 : 0) +
      (ville != null ? 1 : 0) +
      (du != null || au != null ? 1 : 0) +
      (montantMin != null || montantMax != null ? 1 : 0) +
      (retardSeulement ? 1 : 0);

  /// [numero] et [banque] fournissent les libellés pour la recherche texte.
  List<Cheque> appliquer(
    List<Cheque> source, {
    required String Function(Cheque) numero,
    required String Function(Cheque) banque,
    required String Function(Cheque) chequier,
  }) {
    final q = texte.trim().toLowerCase();
    final qMontant = Fmt.parseMontant(texte);
    final now = DateTime.now();
    final res = source.where((c) {
      if (statuts.isNotEmpty && !statuts.contains(c.statut)) return false;
      if (banqueId != null && c.banqueId != banqueId) return false;
      if (chequierId != null && c.chequierId != chequierId) return false;
      if (ville != null &&
          c.ville.trim().toLowerCase() != ville!.toLowerCase()) {
        return false;
      }
      final dp = Fmt.jour(c.datePresentation);
      final de = Fmt.jour(c.dateEdition);
      // Période : chèque dont l'édition OU la présentation tombe dans l'intervalle.
      if (du != null || au != null) {
        bool dans(DateTime d) =>
            (du == null || !d.isBefore(Fmt.jour(du!))) &&
            (au == null || !d.isAfter(Fmt.jour(au!)));
        if (!dans(dp) && !dans(de)) return false;
      }
      if (montantMin != null && c.montant < montantMin!) return false;
      if (montantMax != null && c.montant > montantMax!) return false;
      if (retardSeulement && !c.estEnRetard(now)) return false;
      if (q.isEmpty) return true;
      if (numero(c).contains(q) || '${c.numero}'.contains(q)) return true;
      if (c.beneficiaire.toLowerCase().contains(q)) return true;
      if (banque(c).toLowerCase().contains(q)) return true;
      if (chequier(c).toLowerCase().contains(q)) return true;
      if (c.ville.toLowerCase().contains(q)) return true;
      if (c.objet.toLowerCase().contains(q)) return true;
      if (qMontant != null && qMontant == c.montant) return true;
      return false;
    }).toList();

    int cmp(Cheque a, Cheque b) {
      switch (tri) {
        case Tri.presentationDesc:
          return b.datePresentation.compareTo(a.datePresentation);
        case Tri.presentationAsc:
          return a.datePresentation.compareTo(b.datePresentation);
        case Tri.editionDesc:
          return b.dateEdition.compareTo(a.dateEdition);
        case Tri.montantDesc:
          return b.montant.compareTo(a.montant);
        case Tri.montantAsc:
          return a.montant.compareTo(b.montant);
        case Tri.numero:
          return a.numero.compareTo(b.numero);
        case Tri.banque:
          final r = banque(a).compareTo(banque(b));
          return r != 0 ? r : a.numero.compareTo(b.numero);
      }
    }

    res.sort(cmp);
    return res;
  }
}
