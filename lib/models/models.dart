import '../l10n/i18n.dart';
import 'dart:convert';

import '../core/format.dart';
import 'statut.dart';

export 'statut.dart';

/// Champs communs pour la synchronisation future (Supabase, phase 2) :
/// id UUID, created_at, updated_at, deleted_at (suppression logique).

class Banque {
  final String id;
  String nom;
  String agence;
  String ville;
  String titulaire;
  String referenceCompte;
  String infos;
  bool archive;
  final DateTime createdAt;
  DateTime updatedAt;

  Banque({
    required this.id,
    required this.nom,
    this.agence = '',
    this.ville = '',
    this.titulaire = '',
    this.referenceCompte = '',
    this.infos = '',
    this.archive = false,
    required this.createdAt,
    required this.updatedAt,
  });

  String get libelle =>
      referenceCompte.isEmpty ? nom : '$nom - $referenceCompte';

  Map<String, Object?> toMap() => {
    'id': id,
    'nom': nom,
    'agence': agence,
    'ville': ville,
    'titulaire': titulaire,
    'reference_compte': referenceCompte,
    'infos': infos,
    'archive': archive ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Banque.fromMap(Map<String, Object?> m) => Banque(
    id: m['id'] as String,
    nom: m['nom'] as String,
    agence: (m['agence'] as String?) ?? '',
    ville: (m['ville'] as String?) ?? '',
    titulaire: (m['titulaire'] as String?) ?? '',
    referenceCompte: (m['reference_compte'] as String?) ?? '',
    infos: (m['infos'] as String?) ?? '',
    archive: (m['archive'] as int? ?? 0) == 1,
    createdAt: DateTime.parse(m['created_at'] as String),
    updatedAt: DateTime.parse(m['updated_at'] as String),
  );
}

enum StatutChequier {
  actif('actif', 'Actif'),
  termine('termine', 'Terminé'),
  archive('archive', 'Archivé');

  const StatutChequier(this.code, this._libelle);
  final String code;
  final String _libelle;
  String get libelle => tr(_libelle);
  static StatutChequier fromCode(String c) => StatutChequier.values.firstWhere(
    (s) => s.code == c,
    orElse: () => StatutChequier.actif,
  );
}

class Chequier {
  final String id;
  String banqueId;
  String numero;
  int premier;
  int dernier;

  /// Nombre de chiffres pour l'affichage (ex. 7 -> 0000125)
  int largeur;
  DateTime dateOuverture;
  StatutChequier statut;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Calculé (non stocké) : nombre de chèques émis sur ce chéquier.
  int utilises = 0;

  Chequier({
    required this.id,
    required this.banqueId,
    required this.numero,
    required this.premier,
    required this.dernier,
    required this.largeur,
    required this.dateOuverture,
    this.statut = StatutChequier.actif,
    required this.createdAt,
    required this.updatedAt,
  });

  int get total => dernier - premier + 1;
  int get disponibles => (total - utilises).clamp(0, total);
  bool contient(int n) => n >= premier && n <= dernier;
  String formatNumero(int n) => n.toString().padLeft(largeur, '0');
  String get plage => '${formatNumero(premier)} → ${formatNumero(dernier)}';

  Map<String, Object?> toMap() => {
    'id': id,
    'banque_id': banqueId,
    'numero': numero,
    'premier': premier,
    'dernier': dernier,
    'largeur': largeur,
    'date_ouverture': Fmt.isoDate(dateOuverture),
    'statut': statut.code,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Chequier.fromMap(Map<String, Object?> m) => Chequier(
    id: m['id'] as String,
    banqueId: m['banque_id'] as String,
    numero: m['numero'] as String,
    premier: m['premier'] as int,
    dernier: m['dernier'] as int,
    largeur: (m['largeur'] as int?) ?? 7,
    dateOuverture: DateTime.parse(m['date_ouverture'] as String),
    statut: StatutChequier.fromCode(m['statut'] as String),
    createdAt: DateTime.parse(m['created_at'] as String),
    updatedAt: DateTime.parse(m['updated_at'] as String),
  );
}

class Cheque {
  final String id;
  String banqueId;
  String chequierId;
  int numero;

  /// Montant en centimes de MAD (jamais de flottant en comptabilité).
  int montant;
  DateTime dateEdition;
  DateTime datePresentation;
  String beneficiaire;
  String ville;
  String objet;
  String observations;
  Statut statut;
  bool rappelsActifs;
  // Impayé
  String motifRejet;
  int fraisRejet;
  DateTime? dateStatut;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;

  Cheque({
    required this.id,
    required this.banqueId,
    required this.chequierId,
    required this.numero,
    required this.montant,
    required this.dateEdition,
    required this.datePresentation,
    required this.beneficiaire,
    this.ville = '',
    this.objet = '',
    this.observations = '',
    this.statut = Statut.enAttente,
    this.rappelsActifs = true,
    this.motifRejet = '',
    this.fraisRejet = 0,
    this.dateStatut,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Cheque copy() => Cheque.fromMap(toMap());

  Map<String, Object?> toMap() => {
    'id': id,
    'banque_id': banqueId,
    'chequier_id': chequierId,
    'numero': numero,
    'montant': montant,
    'date_edition': Fmt.isoDate(dateEdition),
    'date_presentation': Fmt.isoDate(datePresentation),
    'beneficiaire': beneficiaire,
    'ville': ville,
    'objet': objet,
    'observations': observations,
    'statut': statut.code,
    'rappels_actifs': rappelsActifs ? 1 : 0,
    'motif_rejet': motifRejet,
    'frais_rejet': fraisRejet,
    'date_statut': dateStatut?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  factory Cheque.fromMap(Map<String, Object?> m) => Cheque(
    id: m['id'] as String,
    banqueId: m['banque_id'] as String,
    chequierId: m['chequier_id'] as String,
    numero: m['numero'] as int,
    montant: m['montant'] as int,
    dateEdition: DateTime.parse(m['date_edition'] as String),
    datePresentation: DateTime.parse(m['date_presentation'] as String),
    beneficiaire: m['beneficiaire'] as String,
    ville: (m['ville'] as String?) ?? '',
    objet: (m['objet'] as String?) ?? '',
    observations: (m['observations'] as String?) ?? '',
    statut: Statut.fromCode(m['statut'] as String),
    rappelsActifs: (m['rappels_actifs'] as int? ?? 1) == 1,
    motifRejet: (m['motif_rejet'] as String?) ?? '',
    fraisRejet: (m['frais_rejet'] as int?) ?? 0,
    dateStatut: m['date_statut'] == null
        ? null
        : DateTime.parse(m['date_statut'] as String),
    createdAt: DateTime.parse(m['created_at'] as String),
    updatedAt: DateTime.parse(m['updated_at'] as String),
    deletedAt: m['deleted_at'] == null
        ? null
        : DateTime.parse(m['deleted_at'] as String),
  );

  /// En retard : toujours en attente après la date prévue de présentation.
  bool estEnRetard(DateTime aujourdhui) =>
      statut == Statut.enAttente &&
      Fmt.jour(datePresentation).isBefore(Fmt.jour(aujourdhui));
}

class ChangementStatut {
  final String id;
  final String chequeId;
  final Statut? ancien;
  final Statut nouveau;
  final DateTime date;
  final String commentaire;
  final String? justificatifId;

  ChangementStatut({
    required this.id,
    required this.chequeId,
    required this.ancien,
    required this.nouveau,
    required this.date,
    this.commentaire = '',
    this.justificatifId,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'cheque_id': chequeId,
    'ancien': ancien?.code,
    'nouveau': nouveau.code,
    'date': date.toIso8601String(),
    'commentaire': commentaire,
    'justificatif_id': justificatifId,
  };

  factory ChangementStatut.fromMap(Map<String, Object?> m) => ChangementStatut(
    id: m['id'] as String,
    chequeId: m['cheque_id'] as String,
    ancien: m['ancien'] == null ? null : Statut.fromCode(m['ancien'] as String),
    nouveau: Statut.fromCode(m['nouveau'] as String),
    date: DateTime.parse(m['date'] as String),
    commentaire: (m['commentaire'] as String?) ?? '',
    justificatifId: m['justificatif_id'] as String?,
  );
}

class PieceJointe {
  final String id;
  final String chequeId;

  /// 'photo' ou 'pdf'
  final String type;
  final String nom;

  /// Chemin relatif au dossier "pieces" de l'application.
  final String fichier;
  final DateTime createdAt;
  DateTime? deletedAt;
  String? remplaceePar;

  PieceJointe({
    required this.id,
    required this.chequeId,
    required this.type,
    required this.nom,
    required this.fichier,
    required this.createdAt,
    this.deletedAt,
    this.remplaceePar,
  });

  bool get estPhoto => type == 'photo';

  Map<String, Object?> toMap() => {
    'id': id,
    'cheque_id': chequeId,
    'type': type,
    'nom': nom,
    'fichier': fichier,
    'created_at': createdAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
    'remplacee_par': remplaceePar,
  };

  factory PieceJointe.fromMap(Map<String, Object?> m) => PieceJointe(
    id: m['id'] as String,
    chequeId: m['cheque_id'] as String,
    type: m['type'] as String,
    nom: m['nom'] as String,
    fichier: m['fichier'] as String,
    createdAt: DateTime.parse(m['created_at'] as String),
    deletedAt: m['deleted_at'] == null
        ? null
        : DateTime.parse(m['deleted_at'] as String),
    remplaceePar: m['remplacee_par'] as String?,
  );
}

class EntreeJournal {
  final String id;
  final DateTime date;
  final String entite; // banque, chequier, cheque, piece, systeme
  final String entiteId;
  final String
  action; // creation, modification, statut, suppression, restauration...
  final String resume;
  final Map<String, dynamic> details;

  EntreeJournal({
    required this.id,
    required this.date,
    required this.entite,
    required this.entiteId,
    required this.action,
    required this.resume,
    this.details = const {},
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'entite': entite,
    'entite_id': entiteId,
    'action': action,
    'resume': resume,
    'details': jsonEncode(details),
  };

  factory EntreeJournal.fromMap(Map<String, Object?> m) => EntreeJournal(
    id: m['id'] as String,
    date: DateTime.parse(m['date'] as String),
    entite: m['entite'] as String,
    entiteId: m['entite_id'] as String,
    action: m['action'] as String,
    resume: (m['resume'] as String?) ?? '',
    details: (jsonDecode((m['details'] as String?) ?? '{}') as Map)
        .cast<String, dynamic>(),
  );
}
