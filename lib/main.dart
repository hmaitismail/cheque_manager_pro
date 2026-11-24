import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'screens/cheque_detail_screen.dart';
import 'screens/home_shell.dart';
import 'screens/verrou.dart';
import 'services/rappels.dart';
import 'services/securite.dart';
import 'state/app_state.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServiceSecurite.instance.charger();
  await ServiceRappels.instance.initialiser();
  final state = await AppState.demarrer();

  ServiceRappels.instance.surOuverture = (chequeId) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ChequeDetailScreen(chequeId: chequeId)),
    );
  };

  runApp(
    ChangeNotifierProvider.value(value: state, child: const ChequeManagerApp()),
  );

  // Après l'affichage : rappels et sauvegarde automatique quotidienne.
  unawaited(state.reprogrammerRappels());
  if (state.reglages.actifs) {
    unawaited(ServiceRappels.instance.demanderPermission());
  }
  unawaited(
    state.sauvegardes.sauvegardeAutoSiNecessaire().catchError((Object e) {
      debugPrint('Sauvegarde automatique impossible : $e');
    }),
  );
}

class ChequeManagerApp extends StatelessWidget {
  const ChequeManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<AppState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'Cheque Manager Pro',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.clair(),
      darkTheme: AppTheme.sombre(),
      themeMode: mode,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Le verrou est placé au-dessus du Navigator : il masque aussi les
      // écrans et boîtes de dialogue ouverts.
      builder: (context, child) => VerrouGate(child: child ?? const SizedBox()),
      home: const HomeShell(),
    );
  }
}
