import 'package:flutter/material.dart';

import '../data/database.dart';
import '../l10n/i18n.dart';
import '../data/repository.dart';
import '../models/models.dart';
import '../services/rappels.dart';
import '../services/rapports.dart';
import '../services/sauvegarde.dart';
import '../services/stats.dart';

/// État global de l'application : données en mémoire, recalcul automatique
/// des indicateurs et reprogrammation des rappels après chaque écriture.
class AppState extends ChangeNotifier {
  AppState(this.repo, this.sauvegardes);
  final Repository repo;
  final ServiceSauvegarde sauvegardes;

  List<Banque> banques = [];
  List<Chequier> chequiers = [];
  List<Cheque> cheques = [];
  Stats stats = Stats.calculer(const []);
  ReglagesRappels reglages = ReglagesRappels();
  ThemeMode themeMode = ThemeMode.system;
  Langue langue = Langue.fr;
  String entreprise = '';
  bool charge = false;

  Map<String, Banque> get banquesParId => {for (final b in banques) b.id: b};
  Map<String, Chequier> get chequiersParId => {
    for (final c in chequiers) c.id: c,
  };

  Banque? banque(String id) => banquesParId[id];
  Chequier? chequier(String id) => chequiersParId[id];
  String numero(Cheque c) =>
      chequier(c.chequierId)?.formatNumero(c.numero) ?? '${c.numero}';
  String nomBanque(String id) => banque(id)?.libelle ?? '?';

  ServiceRapports get rapports => ServiceRapports(
    banques: banquesParId,
    chequiers: chequiersParId,
    entreprise: entreprise,
  );

  static Future<AppState> demarrer() async {
    await AppDatabase.instance.ouvrir();
    final repo = Repository(AppDatabase.instance);
    final s = AppState(repo, ServiceSauvegarde(AppDatabase.instance, repo));
    await s._chargerParametres();
    await s.rafraichir(reprogrammer: false);
    return s;
  }

  Future<void> _chargerParametres() async {
    final cles = ReglagesRappels().toParams().keys;
    final p = <String, String?>{
      for (final k in cles) k: await repo.parametre(k),
    };
    reglages = ReglagesRappels.fromParams(p);
    themeMode = switch (await repo.parametre('theme')) {
      'clair' => ThemeMode.light,
      'sombre' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    entreprise = await repo.parametre('entreprise') ?? '';
    langue = Langue.fromCode(await repo.parametre('langue'));
    I18n.langue = langue;
  }

  Future<void> rafraichir({bool reprogrammer = true}) async {
    banques = await repo.banques();
    chequiers = await repo.chequiers();
    cheques = await repo.cheques();
    stats = Stats.calculer(cheques);
    charge = true;
    notifyListeners();
    if (reprogrammer) await reprogrammerRappels();
  }

  void licenceChangee() => notifyListeners();

  Future<void> reprogrammerRappels() => ServiceRappels.instance.reprogrammer(
    cheques,
    reglages,
    libelleNumero: numero,
  );

  Future<void> enregistrerReglages(ReglagesRappels r) async {
    reglages = r;
    for (final e in r.toParams().entries) {
      await repo.definirParametre(e.key, e.value);
    }
    notifyListeners();
    await reprogrammerRappels();
  }

  Future<void> definirTheme(ThemeMode m) async {
    themeMode = m;
    await repo.definirParametre('theme', switch (m) {
      ThemeMode.light => 'clair',
      ThemeMode.dark => 'sombre',
      ThemeMode.system => 'systeme',
    });
    notifyListeners();
  }

  Future<void> definirLangue(Langue l) async {
    langue = l;
    I18n.langue = l;
    await repo.definirParametre('langue', l.code);
    notifyListeners();
    await reprogrammerRappels();
  }

  Future<void> definirEntreprise(String v) async {
    entreprise = v.trim();
    await repo.definirParametre('entreprise', entreprise);
    notifyListeners();
  }

  /// Exécute une écriture puis recharge les données et les rappels.
  Future<T> ecrire<T>(Future<T> Function(Repository r) action) async {
    final res = await action(repo);
    await rafraichir();
    return res;
  }

  List<Cheque> chequesDe({String? chequierId, String? banqueId}) => cheques
      .where(
        (c) =>
            (chequierId == null || c.chequierId == chequierId) &&
            (banqueId == null || c.banqueId == banqueId),
      )
      .toList();

  List<String> get villesConnues {
    final s = <String>{
      for (final c in cheques)
        if (c.ville.trim().isNotEmpty) c.ville.trim(),
    };
    return s.toList()..sort();
  }

  List<String> get beneficiairesConnus {
    final s = <String>{for (final c in cheques) c.beneficiaire.trim()};
    return s.toList()..sort();
  }
}
