import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'banques_screen.dart';
import 'calendrier_screen.dart';
import 'cheque_form_screen.dart';
import 'cheques_screen.dart';
import 'corbeille_screen.dart';
import 'dashboard_screen.dart';
import 'journal_screen.dart';
import 'parametres_screen.dart';
import 'rapports_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _listeKey = GlobalKey<ChequesScreenState>();

  void allerA(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        onVoirListe: (filtre) {
          _listeKey.currentState?.appliquerFiltre(filtre);
          allerA(1);
        },
      ),
      ChequesScreen(key: _listeKey),
      const CalendrierScreen(),
      const RapportsScreen(),
      const _PlusScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: _index <= 2
          ? FloatingActionButton.extended(
              heroTag: 'nouveau',
              onPressed: () => nouveauCheque(context),
              icon: const Icon(Icons.add),
              label: const Text('Nouveau chèque'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: allerA,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Chèques',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendrier',
          ),
          NavigationDestination(
            icon: Icon(Icons.summarize_outlined),
            selectedIcon: Icon(Icons.summarize),
            label: 'Rapports',
          ),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Plus'),
        ],
      ),
    );
  }
}

Future<void> nouveauCheque(BuildContext context) async {
  final app = context.read<AppState>();
  if (app.chequiers.where((c) => c.statut.code == 'actif').isEmpty) {
    final aller = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aucun chéquier actif'),
        content: const Text(
          'Enregistrez d\'abord une banque et un chéquier avant de saisir un chèque.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Configurer'),
          ),
        ],
      ),
    );
    if (aller == true && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BanquesScreen()),
      );
    }
    return;
  }
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ChequeFormScreen()),
  );
}

class _PlusScreen extends StatelessWidget {
  const _PlusScreen();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    Widget item(IconData i, String t, String s, Widget page) => Card(
      child: ListTile(
        leading: Icon(i, color: Theme.of(context).colorScheme.primary),
        title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(s),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Plus')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          item(
            Icons.account_balance,
            'Banques et chéquiers',
            '${app.banques.length} compte(s) · ${app.chequiers.length} chéquier(s)',
            const BanquesScreen(),
          ),
          const SizedBox(height: 8),
          item(
            Icons.history,
            'Historique',
            'Journal de toutes les opérations',
            const JournalScreen(),
          ),
          const SizedBox(height: 8),
          item(
            Icons.delete_outline,
            'Corbeille',
            'Chèques supprimés, restaurables',
            const CorbeilleScreen(),
          ),
          const SizedBox(height: 8),
          item(
            Icons.settings,
            'Paramètres et sauvegardes',
            'Sécurité, rappels, thème, sauvegarde',
            const ParametresScreen(),
          ),
        ],
      ),
    );
  }
}
