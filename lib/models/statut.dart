import '../l10n/i18n.dart';
import 'package:flutter/material.dart';

/// Statuts d'un chèque et transitions autorisées (cahier des charges §4).
enum Statut {
  enAttente('en_attente', 'En attente', Color(0xFFF59E0B), Icons.schedule),
  presente('presente', 'Présenté', Color(0xFF3B82F6), Icons.account_balance),
  paye('paye', 'Payé', Color(0xFF16A34A), Icons.check_circle),
  impaye('impaye', 'Impayé', Color(0xFFDC2626), Icons.error),
  recupere('recupere', 'Récupéré', Color(0xFF8B5CF6), Icons.assignment_return),
  detruit('detruit', 'Détruit', Color(0xFF64748B), Icons.delete_forever);

  const Statut(this.code, this._libelle, this.couleur, this.icone);
  final String code;
  final String _libelle;
  String get libelle => tr(_libelle);
  final Color couleur;
  final IconData icone;

  static Statut fromCode(String code) => Statut.values.firstWhere(
    (s) => s.code == code,
    orElse: () => Statut.enAttente,
  );

  /// Un chèque clôturé ne peut plus évoluer (sauf récupéré -> détruit).
  bool get estCloture => this == paye || this == recupere || this == detruit;

  /// Ne peut jamais être supprimé de la base.
  bool get suppressionInterdite => this != enAttente;

  /// Opération sensible : confirmation renforcée.
  bool get sensible => this == detruit || this == paye || this == recupere;

  /// Transitions autorisées. "Payé" exige toujours une confirmation explicite
  /// et n'est possible qu'après présentation (présenté ≠ débité).
  List<Statut> get suivantsPossibles {
    switch (this) {
      case enAttente:
        return [presente, recupere, detruit];
      case presente:
        return [paye, impaye];
      case impaye:
        return [presente, paye, recupere, detruit];
      case recupere:
        return [detruit];
      case paye:
      case detruit:
        return const [];
    }
  }

  bool peutPasserA(Statut s) => suivantsPossibles.contains(s);
}
