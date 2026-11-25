import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/database.dart';
import '../data/repository.dart';
import '../l10n/i18n.dart';

class InfoSauvegarde {
  final File fichier;
  final DateTime date;
  final int taille;
  InfoSauvegarde(this.fichier, this.date, this.taille);
}

/// Sauvegarde complète (données + pièces jointes) dans une archive .cmpbak
/// (zip), restauration avec sauvegarde de sécurité préalable.
class ServiceSauvegarde {
  ServiceSauvegarde(this._database, this._repo);
  final AppDatabase _database;
  final Repository _repo;

  static const format = 'cheque_manager_pro';
  static const extension = '.cmpbak';
  static const conserver = 10;

  Future<Directory> dossier() async {
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(docs.path, 'sauvegardes'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> creer({String prefixe = 'sauvegarde'}) async {
    final db = _database.db;
    final data = <String, dynamic>{};
    for (final t in AppDatabase.tables) {
      data[t] = await db.query(t);
    }
    final manifeste = {
      'format': format,
      'schema': AppDatabase.version,
      'date': DateTime.now().toIso8601String(),
      'nb_cheques': (data['cheques'] as List).length,
    };
    final archive = Archive();
    void ajouter(String nom, List<int> octets) =>
        archive.addFile(ArchiveFile(nom, octets.length, octets));
    ajouter('manifeste.json', utf8.encode(jsonEncode(manifeste)));
    ajouter('donnees.json', utf8.encode(jsonEncode(data)));

    final pieces = await _repo.dossierPieces();
    await for (final e in pieces.list()) {
      if (e is File) {
        ajouter('pieces/${p.basename(e.path)}', await e.readAsBytes());
      }
    }
    final zip = ZipEncoder().encode(archive);

    final n = DateTime.now();
    String d2(int v) => v.toString().padLeft(2, '0');
    final nom =
        '${prefixe}_${n.year}${d2(n.month)}${d2(n.day)}_${d2(n.hour)}${d2(n.minute)}${d2(n.second)}$extension';
    final f = File(p.join((await dossier()).path, nom));
    await f.writeAsBytes(zip, flush: true);
    await _repo.definirParametre('derniere_sauvegarde', n.toIso8601String());
    await _repo.logSysteme('sauvegarde', tr('Sauvegarde créée : {0}', [nom]));
    await _purger();
    return f;
  }

  Future<List<InfoSauvegarde>> lister() async {
    final d = await dossier();
    final res = <InfoSauvegarde>[];
    await for (final e in d.list()) {
      if (e is File && e.path.endsWith(extension)) {
        final st = await e.stat();
        res.add(InfoSauvegarde(e, st.modified, st.size));
      }
    }
    res.sort((a, b) => b.date.compareTo(a.date));
    return res;
  }

  Future<void> _purger() async {
    final toutes = await lister();
    final auto = toutes
        .where((s) => p.basename(s.fichier.path).startsWith('auto_'))
        .toList();
    for (final s in auto.skip(conserver)) {
      await s.fichier.delete();
    }
  }

  /// Sauvegarde automatique quotidienne (appelée au démarrage).
  Future<void> sauvegardeAutoSiNecessaire() async {
    final derniere = DateTime.tryParse(
      await _repo.parametre('derniere_sauvegarde') ?? '',
    );
    if (derniere == null || DateTime.now().difference(derniere).inHours >= 20) {
      await creer(prefixe: 'auto');
    }
  }

  /// Vérifie une archive et renvoie son manifeste (sans rien modifier).
  Future<Map<String, dynamic>> lireManifeste(File f) async {
    final archive = ZipDecoder().decodeBytes(await f.readAsBytes());
    final m = archive.findFile('manifeste.json');
    if (m == null) throw Exception(tr('Fichier de sauvegarde invalide.'));
    final manifeste =
        jsonDecode(utf8.decode(m.content)) as Map<String, dynamic>;
    if (manifeste['format'] != format) {
      throw Exception(
        tr('Ce fichier n\'est pas une sauvegarde Cheque Manager Pro.'),
      );
    }
    if ((manifeste['schema'] as int) > AppDatabase.version) {
      throw Exception(
        tr('Sauvegarde créée par une version plus récente de l\'application.'),
      );
    }
    return manifeste;
  }

  /// Restauration complète. Une sauvegarde de sécurité est créée avant.
  Future<void> restaurer(File f) async {
    await lireManifeste(f);
    final archive = ZipDecoder().decodeBytes(await f.readAsBytes());
    final donnees = archive.findFile('donnees.json');
    if (donnees == null) {
      throw Exception(tr('Données absentes de la sauvegarde.'));
    }
    final data =
        jsonDecode(utf8.decode(donnees.content)) as Map<String, dynamic>;

    await creer(prefixe: 'avant_restauration');

    final db = _database.db;
    await db.transaction((tx) async {
      for (final t in AppDatabase.tables.reversed) {
        await tx.delete(t);
      }
      for (final t in AppDatabase.tables) {
        final rows = (data[t] as List?) ?? const [];
        for (final r in rows) {
          await tx.insert(t, Map<String, Object?>.from(r as Map));
        }
      }
    });

    final pieces = await _repo.dossierPieces();
    for (final e in archive) {
      if (e.isFile && e.name.startsWith('pieces/')) {
        final cible = File(p.join(pieces.path, p.basename(e.name)));
        await cible.writeAsBytes(e.content, flush: true);
      }
    }
    await _repo.logSysteme(
      'restauration',
      tr('Restauration depuis {0}', [p.basename(f.path)]),
    );
  }
}
