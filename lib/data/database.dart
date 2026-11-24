import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Base SQLite chiffrée (SQLCipher, AES-256). La clé est générée au premier
/// lancement et conservée dans le trousseau sécurisé (Keystore / Keychain).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _nomFichier = 'cheque_manager.db';
  static const _cleStockage = 'db_key_v1';
  static const version = 1;

  Database? _db;
  Database get db {
    final d = _db;
    if (d == null) throw StateError('Base non ouverte');
    return d;
  }

  Future<String> chemin() async =>
      p.join(await getDatabasesPath(), _nomFichier);

  Future<void> ouvrir() async {
    if (_db != null) return;
    const storage = FlutterSecureStorage();
    var cle = await storage.read(key: _cleStockage);
    if (cle == null) {
      final r = Random.secure();
      cle = base64UrlEncode(List<int>.generate(32, (_) => r.nextInt(256)));
      await storage.write(key: _cleStockage, value: cle);
    }
    _db = await openDatabase(
      await chemin(),
      password: cle,
      version: version,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async => _creer(db),
      onUpgrade: (db, oldV, newV) async => _migrer(db, oldV, newV),
    );
  }

  Future<void> fermer() async {
    await _db?.close();
    _db = null;
  }

  static Future<void> _creer(Database db) async {
    final b = db.batch();
    b.execute('''
      CREATE TABLE banques(
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        agence TEXT NOT NULL DEFAULT '',
        ville TEXT NOT NULL DEFAULT '',
        titulaire TEXT NOT NULL DEFAULT '',
        reference_compte TEXT NOT NULL DEFAULT '',
        infos TEXT NOT NULL DEFAULT '',
        archive INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');
    b.execute('''
      CREATE TABLE chequiers(
        id TEXT PRIMARY KEY,
        banque_id TEXT NOT NULL REFERENCES banques(id),
        numero TEXT NOT NULL,
        premier INTEGER NOT NULL,
        dernier INTEGER NOT NULL,
        largeur INTEGER NOT NULL DEFAULT 7,
        date_ouverture TEXT NOT NULL,
        statut TEXT NOT NULL DEFAULT 'actif',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK (dernier >= premier),
        UNIQUE (banque_id, numero)
      )''');
    b.execute('''
      CREATE TABLE cheques(
        id TEXT PRIMARY KEY,
        banque_id TEXT NOT NULL REFERENCES banques(id),
        chequier_id TEXT NOT NULL REFERENCES chequiers(id),
        numero INTEGER NOT NULL,
        montant INTEGER NOT NULL CHECK (montant > 0),
        date_edition TEXT NOT NULL,
        date_presentation TEXT NOT NULL,
        beneficiaire TEXT NOT NULL,
        ville TEXT NOT NULL DEFAULT '',
        objet TEXT NOT NULL DEFAULT '',
        observations TEXT NOT NULL DEFAULT '',
        statut TEXT NOT NULL DEFAULT 'en_attente',
        rappels_actifs INTEGER NOT NULL DEFAULT 1,
        motif_rejet TEXT NOT NULL DEFAULT '',
        frais_rejet INTEGER NOT NULL DEFAULT 0,
        date_statut TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        UNIQUE (banque_id, numero)
      )''');
    b.execute('CREATE INDEX idx_cheques_statut ON cheques(statut)');
    b.execute(
      'CREATE INDEX idx_cheques_presentation ON cheques(date_presentation)',
    );
    b.execute('CREATE INDEX idx_cheques_chequier ON cheques(chequier_id)');
    b.execute('''
      CREATE TABLE historique_statuts(
        id TEXT PRIMARY KEY,
        cheque_id TEXT NOT NULL REFERENCES cheques(id),
        ancien TEXT,
        nouveau TEXT NOT NULL,
        date TEXT NOT NULL,
        commentaire TEXT NOT NULL DEFAULT '',
        justificatif_id TEXT
      )''');
    b.execute('CREATE INDEX idx_hist_cheque ON historique_statuts(cheque_id)');
    b.execute('''
      CREATE TABLE pieces_jointes(
        id TEXT PRIMARY KEY,
        cheque_id TEXT NOT NULL REFERENCES cheques(id),
        type TEXT NOT NULL,
        nom TEXT NOT NULL,
        fichier TEXT NOT NULL,
        created_at TEXT NOT NULL,
        deleted_at TEXT,
        remplacee_par TEXT
      )''');
    b.execute('CREATE INDEX idx_pj_cheque ON pieces_jointes(cheque_id)');
    b.execute('''
      CREATE TABLE journal(
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        entite TEXT NOT NULL,
        entite_id TEXT NOT NULL,
        action TEXT NOT NULL,
        resume TEXT NOT NULL DEFAULT '',
        details TEXT NOT NULL DEFAULT '{}'
      )''');
    b.execute('CREATE INDEX idx_journal_date ON journal(date)');
    b.execute('CREATE INDEX idx_journal_entite ON journal(entite_id)');
    b.execute('''
      CREATE TABLE parametres(
        cle TEXT PRIMARY KEY,
        valeur TEXT NOT NULL
      )''');
    await b.commit(noResult: true);
  }

  static Future<void> _migrer(Database db, int oldV, int newV) async {
    // Les futures évolutions du schéma s'ajoutent ici, version par version,
    // sans jamais recréer la base (aucune perte de données).
  }

  static const tables = [
    'banques',
    'chequiers',
    'cheques',
    'historique_statuts',
    'pieces_jointes',
    'journal',
    'parametres',
  ];
}
