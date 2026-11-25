// Captures d'écran automatiques (vérification visuelle sur la CI).
// flutter test --update-goldens captures/captures_test.dart
import 'dart:io';

import 'package:cheque_manager_pro/core/format.dart';
import 'package:cheque_manager_pro/core/theme.dart';
import 'package:cheque_manager_pro/data/database.dart';
import 'package:cheque_manager_pro/data/repository.dart';
import 'package:cheque_manager_pro/l10n/i18n.dart';
import 'package:cheque_manager_pro/models/models.dart';
import 'package:cheque_manager_pro/screens/home_shell.dart';
import 'package:cheque_manager_pro/screens/licence_screen.dart';
import 'package:cheque_manager_pro/services/licence.dart';
import 'package:cheque_manager_pro/services/sauvegarde.dart';
import 'package:cheque_manager_pro/services/stats.dart';
import 'package:cheque_manager_pro/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<void> _police(String famille, String chemin) async {
  final octets = File(chemin).readAsBytesSync();
  final l = FontLoader(famille)
    ..addFont(Future.value(ByteData.view(octets.buffer)));
  await l.load();
}

String _icones() {
  final racine = Platform.environment['FLUTTER_ROOT'];
  if (racine != null) {
    return '$racine/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  }
  // .../bin/cache/artifacts/engine/linux-x64/flutter_tester
  final cache = File(Platform.resolvedExecutable).parent.parent.parent.path;
  return '$cache/material_fonts/MaterialIcons-Regular.otf';
}

AppState _etat({bool vide = false}) {
  final repo = Repository(AppDatabase.instance);
  final app = AppState(repo, ServiceSauvegarde(AppDatabase.instance, repo));
  final now = DateTime.now();
  DateTime j(int d) => Fmt.jour(now.add(Duration(days: d)));
  if (!vide) {
    app.entreprise = 'Société Atlas Distribution';
    app.banques = [
      Banque(
        id: 'b1',
        nom: 'Bank of Africa',
        referenceCompte: '011 450',
        ville: 'Agadir',
        createdAt: now,
        updatedAt: now,
      ),
      Banque(
        id: 'b2',
        nom: 'Attijariwafa bank',
        referenceCompte: '007 810',
        ville: 'Marrakech',
        createdAt: now,
        updatedAt: now,
      ),
    ];
    app.chequiers = [
      Chequier(
        id: 'c1',
        banqueId: 'b1',
        numero: 'A-2026',
        premier: 1250,
        dernier: 1299,
        largeur: 7,
        dateOuverture: j(-90),
        createdAt: now,
        updatedAt: now,
      )..utilises = 14,
      Chequier(
        id: 'c2',
        banqueId: 'b2',
        numero: 'B-07',
        premier: 400,
        dernier: 424,
        largeur: 7,
        dateOuverture: j(-60),
        createdAt: now,
        updatedAt: now,
      )..utilises = 6,
    ];
    final donnees = <(int, String, int, int, int, Statut, String)>[
      (1250, 'Société ABC', 1500000, -20, 0, Statut.enAttente, 'Agadir'),
      (1251, 'Marjane Holding', 845000, -15, 1, Statut.enAttente, 'Agadir'),
      (1252, 'Garage Atlas', 320050, -30, -3, Statut.enAttente, 'Inezgane'),
      (1253, 'Lydec', 125000, -40, -10, Statut.paye, 'Casablanca'),
      (1254, 'Imprimerie Souss', 560000, -35, -5, Statut.impaye, 'Agadir'),
      (1255, 'Transport Tiznit', 230000, -25, -2, Statut.presente, 'Tiznit'),
      (1256, 'Cabinet Benali', 980000, -70, -50, Statut.paye, 'Marrakech'),
      (1257, 'Office Pro', 410000, -100, -80, Statut.paye, 'Agadir'),
      (400, 'Société ABC', 2200000, -130, -110, Statut.paye, 'Marrakech'),
      (
        401,
        'Menara Services',
        670000,
        -160,
        -140,
        Statut.recupere,
        'Marrakech',
      ),
      (402, 'Atlas Bureautique', 150000, -10, 6, Statut.enAttente, 'Marrakech'),
      (403, 'Souk Matériaux', 1890000, -190, -170, Statut.paye, 'Marrakech'),
    ];
    app.cheques = [
      for (final d in donnees)
        Cheque(
          id: 'q${d.$1}',
          banqueId: d.$1 >= 1250 ? 'b1' : 'b2',
          chequierId: d.$1 >= 1250 ? 'c1' : 'c2',
          numero: d.$1,
          montant: d.$3,
          dateEdition: j(d.$4),
          datePresentation: j(d.$5),
          beneficiaire: d.$2,
          ville: d.$7,
          statut: d.$6,
          motifRejet: d.$6 == Statut.impaye ? 'Provision insuffisante' : '',
          createdAt: now,
          updatedAt: now.subtract(Duration(minutes: d.$1)),
        ),
    ];
  }
  app.stats = Stats.calculer(app.cheques);
  return app;
}

Widget _app(AppState app, Widget home, {ThemeMode mode = ThemeMode.light}) =>
    ChangeNotifierProvider.value(
      value: app,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.clair(),
        darkTheme: AppTheme.sombre(),
        themeMode: mode,
        locale: I18n.langue.locale,
        supportedLocales: [for (final l in Langue.values) l.locale],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    );

Future<void> _capture(
  WidgetTester tester,
  String nom,
  Widget w, {
  Future<void> Function(WidgetTester t)? action,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
  await tester.pump(const Duration(milliseconds: 400));
  if (action != null) {
    await action(tester);
    await tester.pump(const Duration(milliseconds: 600));
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('png/$nom.png'),
  );
}

void main() {
  setUpAll(() async {
    await _police('Roboto', 'captures/polices/Roboto.ttf');
    await _police('NotoSansArabic', 'captures/polices/NotoSansArabic.ttf');
    await _police('MaterialIcons', _icones());
    AppTheme.policesSecours = const ['NotoSansArabic'];
    ServiceLicence.instance.initialiserPourTests();
  });

  for (final l in Langue.values) {
    testWidgets('accueil ${l.code}', (t) async {
      I18n.langue = l;
      await _capture(t, 'accueil_${l.code}', _app(_etat(), const HomeShell()));
    });
  }

  testWidgets('accueil sombre', (t) async {
    I18n.langue = Langue.fr;
    await _capture(
      t,
      'accueil_sombre',
      _app(_etat(), const HomeShell(), mode: ThemeMode.dark),
    );
  });

  testWidgets('accueil défilé', (t) async {
    I18n.langue = Langue.fr;
    await _capture(
      t,
      'accueil_bas',
      _app(_etat(), const HomeShell()),
      action: (t) async {
        await t.drag(find.byType(ListView).first, const Offset(0, -900));
      },
    );
  });

  testWidgets('premier lancement', (t) async {
    I18n.langue = Langue.fr;
    await _capture(t, 'bienvenue', _app(_etat(vide: true), const HomeShell()));
  });

  testWidgets('liste des chèques', (t) async {
    I18n.langue = Langue.fr;
    await _capture(
      t,
      'liste',
      _app(_etat(), const HomeShell()),
      action: (t) async {
        await t.tap(find.byIcon(Icons.receipt_long_outlined));
      },
    );
  });

  testWidgets('licence', (t) async {
    I18n.langue = Langue.fr;
    await _capture(t, 'licence', _app(_etat(), const LicenceScreen()));
  });
}
