import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/format.dart';
import '../models/models.dart';
import 'database.dart';

class RegleException implements Exception {
  final String message;
  RegleException(this.message);
  @override
  String toString() => message;
}

/// Accès aux données. Chaque écriture est faite en transaction et tracée
/// dans le journal (cahier des charges §9 et §12).
class Repository {
  Repository(this._database);
  final AppDatabase _database;
  Database get _db => _database.db;
  static const _uuid = Uuid();
  String nouvelId() => _uuid.v4();

  // ---------------------------------------------------------------- Journal
  Future<void> _log(
    DatabaseExecutor ex, {
    required String entite,
    required String entiteId,
    required String action,
    required String resume,
    Map<String, dynamic> details = const {},
  }) async {
    await ex.insert(
      'journal',
      EntreeJournal(
        id: nouvelId(),
        date: DateTime.now(),
        entite: entite,
        entiteId: entiteId,
        action: action,
        resume: resume,
        details: details,
      ).toMap(),
    );
  }

  Future<void> logSysteme(String action, String resume) => _log(
    _db,
    entite: 'systeme',
    entiteId: '-',
    action: action,
    resume: resume,
  );

  Future<List<EntreeJournal>> journal({
    String? entiteId,
    int limit = 500,
  }) async {
    final rows = await _db.query(
      'journal',
      where: entiteId == null ? null : 'entite_id = ?',
      whereArgs: entiteId == null ? null : [entiteId],
      orderBy: 'date DESC',
      limit: limit,
    );
    return rows.map(EntreeJournal.fromMap).toList();
  }

  // ---------------------------------------------------------------- Banques
  Future<List<Banque>> banques() async => (await _db.query(
    'banques',
    orderBy: 'archive, nom',
  )).map(Banque.fromMap).toList();

  Future<void> enregistrerBanque(Banque b, {required bool nouveau}) async {
    if (b.nom.trim().isEmpty) {
      throw RegleException('Le nom de la banque est obligatoire.');
    }
    b.updatedAt = DateTime.now();
    await _db.transaction((tx) async {
      if (nouveau) {
        await tx.insert('banques', b.toMap());
      } else {
        await tx.update(
          'banques',
          b.toMap(),
          where: 'id = ?',
          whereArgs: [b.id],
        );
      }
      await _log(
        tx,
        entite: 'banque',
        entiteId: b.id,
        action: nouveau ? 'creation' : 'modification',
        resume:
            '${nouveau ? 'Création' : 'Modification'} du compte ${b.libelle}',
      );
    });
  }

  // -------------------------------------------------------------- Chéquiers
  Future<List<Chequier>> chequiers() async {
    final rows = await _db.query('chequiers', orderBy: 'date_ouverture DESC');
    final counts = await _db.rawQuery(
      'SELECT chequier_id, COUNT(*) AS n FROM cheques GROUP BY chequier_id',
    );
    final map = {
      for (final r in counts) r['chequier_id'] as String: r['n'] as int,
    };
    return rows.map((r) {
      final c = Chequier.fromMap(r);
      c.utilises = map[c.id] ?? 0;
      return c;
    }).toList();
  }

  Future<List<int>> numerosEmis(String chequierId) async {
    final rows = await _db.query(
      'cheques',
      columns: ['numero'],
      where: 'chequier_id = ?',
      whereArgs: [chequierId],
    );
    return rows.map((r) => r['numero'] as int).toList();
  }

  Future<void> enregistrerChequier(Chequier c, {required bool nouveau}) async {
    c.updatedAt = DateTime.now();
    await _db.transaction((tx) async {
      if (nouveau) {
        await tx.insert('chequiers', c.toMap());
      } else {
        await tx.update(
          'chequiers',
          c.toMap(),
          where: 'id = ?',
          whereArgs: [c.id],
        );
      }
      await _log(
        tx,
        entite: 'chequier',
        entiteId: c.id,
        action: nouveau ? 'creation' : 'modification',
        resume:
            '${nouveau ? 'Création' : 'Modification'} du chéquier n° ${c.numero} '
            '(${c.plage}, statut ${c.statut.libelle})',
      );
    });
  }

  Future<void> _majStatutChequier(
    DatabaseExecutor tx,
    String chequierId,
  ) async {
    final rows = await tx.query(
      'chequiers',
      where: 'id = ?',
      whereArgs: [chequierId],
    );
    if (rows.isEmpty) return;
    final ch = Chequier.fromMap(rows.first);
    final res = await tx.rawQuery(
      'SELECT COUNT(*) AS n FROM cheques WHERE chequier_id = ?',
      [chequierId],
    );
    final n = (res.first['n'] as int?) ?? 0;
    StatutChequier? nouveau;
    if (ch.statut == StatutChequier.actif && n >= ch.total) {
      nouveau = StatutChequier.termine;
    }
    if (ch.statut == StatutChequier.termine && n < ch.total) {
      nouveau = StatutChequier.actif;
    }
    if (nouveau != null) {
      await tx.update(
        'chequiers',
        {
          'statut': nouveau.code,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [chequierId],
      );
      await _log(
        tx,
        entite: 'chequier',
        entiteId: chequierId,
        action: 'statut',
        resume:
            'Chéquier n° ${ch.numero} : ${ch.statut.libelle} → ${nouveau.libelle} (automatique)',
      );
    }
  }

  /// Prochain numéro libre d'un chéquier (pour pré-remplir la saisie).
  Future<int?> prochainNumero(Chequier c) async {
    final emis = (await numerosEmis(c.id)).toSet();
    for (var n = c.premier; n <= c.dernier; n++) {
      if (!emis.contains(n)) return n;
    }
    return null;
  }

  // ---------------------------------------------------------------- Chèques
  Future<List<Cheque>> cheques({bool corbeille = false}) async {
    final rows = await _db.query(
      'cheques',
      where: corbeille ? 'deleted_at IS NOT NULL' : 'deleted_at IS NULL',
      orderBy: 'date_presentation DESC, numero DESC',
    );
    return rows.map(Cheque.fromMap).toList();
  }

  /// Tous les chèques d'un compte, corbeille comprise (contrôle des doublons).
  Future<List<Cheque>> chequesDuCompte(String banqueId) async {
    final rows = await _db.query(
      'cheques',
      where: 'banque_id = ?',
      whereArgs: [banqueId],
    );
    return rows.map(Cheque.fromMap).toList();
  }

  Future<Cheque?> cheque(String id) async {
    final rows = await _db.query('cheques', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Cheque.fromMap(rows.first);
  }

  static const libellesChamps = {
    'banque_id': 'Banque',
    'chequier_id': 'Chéquier',
    'numero': 'Numéro',
    'montant': 'Montant',
    'date_edition': 'Date d\'édition',
    'date_presentation': 'Date de présentation',
    'beneficiaire': 'Bénéficiaire',
    'ville': 'Ville',
    'objet': 'Objet',
    'observations': 'Observations',
    'rappels_actifs': 'Rappels',
  };

  Future<void> enregistrerCheque(Cheque c, {required bool nouveau}) async {
    final now = DateTime.now();
    c.updatedAt = now;
    await _db.transaction((tx) async {
      if (nouveau) {
        await tx.insert('cheques', c.toMap());
        await tx.insert(
          'historique_statuts',
          ChangementStatut(
            id: nouvelId(),
            chequeId: c.id,
            ancien: null,
            nouveau: c.statut,
            date: now,
            commentaire: 'Enregistrement du chèque',
          ).toMap(),
        );
        await _log(
          tx,
          entite: 'cheque',
          entiteId: c.id,
          action: 'creation',
          resume:
              'Chèque n° ${c.numero} créé : ${Fmt.mad(c.montant)} à l\'ordre de ${c.beneficiaire}',
        );
        await _majStatutChequier(tx, c.chequierId);
      } else {
        final rows = await tx.query(
          'cheques',
          where: 'id = ?',
          whereArgs: [c.id],
        );
        if (rows.isEmpty) throw RegleException('Chèque introuvable.');
        final ancien = Cheque.fromMap(rows.first);
        if (ancien.statut.estCloture) {
          // Un chèque clôturé reste modifiable uniquement sur les champs
          // descriptifs, jamais sur le montant / numéro / compte.
          if (ancien.montant != c.montant ||
              ancien.numero != c.numero ||
              ancien.banqueId != c.banqueId ||
              ancien.chequierId != c.chequierId) {
            throw RegleException(
              'Un chèque ${ancien.statut.libelle.toLowerCase()} ne peut plus changer de montant, '
              'de numéro ni de compte.',
            );
          }
        }
        final avant = ancien.toMap();
        final apres = c.toMap();
        final diff = <String, dynamic>{};
        for (final k in libellesChamps.keys) {
          if (avant[k] != apres[k]) {
            diff[k] = {'avant': avant[k], 'apres': apres[k]};
          }
        }
        // Le statut ne change jamais par cette voie.
        c.statut = ancien.statut;
        await tx.update(
          'cheques',
          c.toMap(),
          where: 'id = ?',
          whereArgs: [c.id],
        );
        if (diff.isNotEmpty) {
          final champs = diff.keys.map((k) => libellesChamps[k]).join(', ');
          await _log(
            tx,
            entite: 'cheque',
            entiteId: c.id,
            action: 'modification',
            resume: 'Chèque n° ${c.numero} modifié : $champs',
            details: diff,
          );
        }
        if (ancien.chequierId != c.chequierId) {
          await _majStatutChequier(tx, ancien.chequierId);
          await _majStatutChequier(tx, c.chequierId);
        }
      }
    });
  }

  Future<void> changerStatut(
    Cheque c,
    Statut nouveau, {
    String commentaire = '',
    String? justificatifSource,
    String? justificatifNom,
    String motifRejet = '',
    int fraisRejet = 0,
    DateTime? nouvelleDatePresentation,
  }) async {
    if (!c.statut.peutPasserA(nouveau)) {
      throw RegleException(
        'Passage de "${c.statut.libelle}" à "${nouveau.libelle}" non autorisé.',
      );
    }
    final now = DateTime.now();
    String? justifId;
    if (justificatifSource != null) {
      final pj = await _copierPiece(c.id, justificatifSource, justificatifNom);
      justifId = pj.id;
      await _db.insert('pieces_jointes', pj.toMap());
    }
    await _db.transaction((tx) async {
      final ancien = c.statut;
      final maj = <String, Object?>{
        'statut': nouveau.code,
        'date_statut': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      if (nouveau == Statut.impaye) {
        maj['motif_rejet'] = motifRejet;
        maj['frais_rejet'] = fraisRejet;
        if (nouvelleDatePresentation != null) {
          maj['date_presentation'] = Fmt.isoDate(nouvelleDatePresentation);
        }
      }
      if (ancien == Statut.impaye &&
          nouveau == Statut.presente &&
          nouvelleDatePresentation != null) {
        maj['date_presentation'] = Fmt.isoDate(nouvelleDatePresentation);
      }
      await tx.update('cheques', maj, where: 'id = ?', whereArgs: [c.id]);
      final detailsCommentaire = [
        if (commentaire.trim().isNotEmpty) commentaire.trim(),
        if (nouveau == Statut.impaye) 'Motif : $motifRejet',
        if (nouveau == Statut.impaye && fraisRejet > 0)
          'Frais : ${Fmt.mad(fraisRejet)}',
        if (nouvelleDatePresentation != null)
          'Nouvelle présentation : ${Fmt.date(nouvelleDatePresentation)}',
      ].join(' | ');
      await tx.insert(
        'historique_statuts',
        ChangementStatut(
          id: nouvelId(),
          chequeId: c.id,
          ancien: ancien,
          nouveau: nouveau,
          date: now,
          commentaire: detailsCommentaire,
          justificatifId: justifId,
        ).toMap(),
      );
      await _log(
        tx,
        entite: 'cheque',
        entiteId: c.id,
        action: 'statut',
        resume:
            'Chèque n° ${c.numero} : ${ancien.libelle} → ${nouveau.libelle}'
            '${detailsCommentaire.isEmpty ? '' : ' ($detailsCommentaire)'}',
      );
    });
  }

  Future<List<ChangementStatut>> historique(String chequeId) async {
    final rows = await _db.query(
      'historique_statuts',
      where: 'cheque_id = ?',
      whereArgs: [chequeId],
      orderBy: 'date DESC',
    );
    return rows.map(ChangementStatut.fromMap).toList();
  }

  // -------------------------------------------------------------- Corbeille
  Future<void> mettreALaCorbeille(Cheque c, String motif) async {
    if (c.statut.suppressionInterdite) {
      throw RegleException(
        'Un chèque ${c.statut.libelle.toLowerCase()} ne peut pas être supprimé. '
        'Il reste conservé dans l\'historique.',
      );
    }
    await _db.transaction((tx) async {
      final now = DateTime.now().toIso8601String();
      await tx.update(
        'cheques',
        {'deleted_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [c.id],
      );
      await _log(
        tx,
        entite: 'cheque',
        entiteId: c.id,
        action: 'suppression',
        resume:
            'Chèque n° ${c.numero} (${Fmt.mad(c.montant)}) mis à la corbeille. Motif : $motif',
      );
    });
  }

  Future<void> restaurer(Cheque c) async {
    await _db.transaction((tx) async {
      await tx.update(
        'cheques',
        {'deleted_at': null, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [c.id],
      );
      await _log(
        tx,
        entite: 'cheque',
        entiteId: c.id,
        action: 'restauration',
        resume: 'Chèque n° ${c.numero} restauré depuis la corbeille',
      );
    });
  }

  /// Suppression définitive : uniquement depuis la corbeille, uniquement pour
  /// un chèque jamais présenté. Une trace complète reste dans le journal.
  Future<void> supprimerDefinitivement(Cheque c) async {
    if (c.deletedAt == null) {
      throw RegleException('Le chèque doit d\'abord être dans la corbeille.');
    }
    if (c.statut.suppressionInterdite) {
      throw RegleException('Suppression définitive interdite pour ce statut.');
    }
    final pieces = await piecesJointes(c.id, avecSupprimees: true);
    await _db.transaction((tx) async {
      await tx.delete(
        'historique_statuts',
        where: 'cheque_id = ?',
        whereArgs: [c.id],
      );
      await tx.delete(
        'pieces_jointes',
        where: 'cheque_id = ?',
        whereArgs: [c.id],
      );
      await tx.delete('cheques', where: 'id = ?', whereArgs: [c.id]);
      await _log(
        tx,
        entite: 'cheque',
        entiteId: c.id,
        action: 'suppression_definitive',
        resume: 'Chèque n° ${c.numero} supprimé définitivement',
        details: c.toMap(),
      );
      await _majStatutChequier(tx, c.chequierId);
    });
    final dossier = await dossierPieces();
    for (final pj in pieces) {
      final f = File(p.join(dossier.path, pj.fichier));
      if (await f.exists()) await f.delete();
    }
  }

  // --------------------------------------------------------- Pièces jointes
  Future<Directory> dossierPieces() async {
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(docs.path, 'pieces'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<PieceJointe> _copierPiece(
    String chequeId,
    String source,
    String? nom,
  ) async {
    final id = nouvelId();
    final ext = p.extension(source).toLowerCase();
    final type = ext == '.pdf' ? 'pdf' : 'photo';
    final fichier = '$id$ext';
    final dossier = await dossierPieces();
    await File(source).copy(p.join(dossier.path, fichier));
    return PieceJointe(
      id: id,
      chequeId: chequeId,
      type: type,
      nom: nom ?? p.basename(source),
      fichier: fichier,
      createdAt: DateTime.now(),
    );
  }

  Future<List<PieceJointe>> piecesJointes(
    String chequeId, {
    bool avecSupprimees = false,
  }) async {
    final rows = await _db.query(
      'pieces_jointes',
      where: avecSupprimees
          ? 'cheque_id = ?'
          : 'cheque_id = ? AND deleted_at IS NULL',
      whereArgs: [chequeId],
      orderBy: 'created_at DESC',
    );
    return rows.map(PieceJointe.fromMap).toList();
  }

  Future<String> cheminPiece(PieceJointe pj) async =>
      p.join((await dossierPieces()).path, pj.fichier);

  Future<void> ajouterPiece(
    String chequeId,
    String source, {
    String? nom,
    PieceJointe? remplace,
  }) async {
    final pj = await _copierPiece(chequeId, source, nom);
    await _db.transaction((tx) async {
      await tx.insert('pieces_jointes', pj.toMap());
      if (remplace != null) {
        await tx.update(
          'pieces_jointes',
          {
            'deleted_at': DateTime.now().toIso8601String(),
            'remplacee_par': pj.id,
          },
          where: 'id = ?',
          whereArgs: [remplace.id],
        );
      }
      await _log(
        tx,
        entite: 'piece',
        entiteId: chequeId,
        action: remplace == null ? 'ajout' : 'remplacement',
        resume: remplace == null
            ? 'Pièce jointe ajoutée : ${pj.nom}'
            : 'Pièce jointe remplacée : ${remplace.nom} → ${pj.nom}',
      );
    });
  }

  /// Suppression logique : le fichier est conservé pour la traçabilité.
  Future<void> supprimerPiece(PieceJointe pj) async {
    await _db.transaction((tx) async {
      await tx.update(
        'pieces_jointes',
        {'deleted_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [pj.id],
      );
      await _log(
        tx,
        entite: 'piece',
        entiteId: pj.chequeId,
        action: 'suppression',
        resume: 'Pièce jointe retirée : ${pj.nom}',
      );
    });
  }

  // ------------------------------------------------------------- Paramètres
  Future<String?> parametre(String cle) async {
    final rows = await _db.query(
      'parametres',
      where: 'cle = ?',
      whereArgs: [cle],
    );
    return rows.isEmpty ? null : rows.first['valeur'] as String;
  }

  Future<void> definirParametre(String cle, String valeur) async {
    await _db.insert('parametres', {
      'cle': cle,
      'valeur': valeur,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
