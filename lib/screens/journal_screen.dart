import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/communs.dart';
import 'cheque_detail_screen.dart';
import '../l10n/i18n.dart';

/// Historique global : journal de toutes les opérations (§9 journalisation).
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<EntreeJournal> _entrees = [];
  String _filtre = 'tout';
  String _q = '';
  bool _charge = false;

  static Map<String, String> get _filtres => {
    'tout': tr('Tout'),
    'cheque': tr('Chèques'),
    'piece': tr('Pièces jointes'),
    'chequier': tr('Chéquiers'),
    'banque': tr('Banques'),
    'systeme': tr('Système'),
  };

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final e = await context.read<AppState>().repo.journal(limit: 2000);
    if (mounted) {
      setState(() {
        _entrees = e;
        _charge = true;
      });
    }
  }

  IconData _icone(EntreeJournal e) => switch (e.action) {
    'creation' => Icons.add_circle_outline,
    'modification' => Icons.edit_outlined,
    'statut' => Icons.swap_horiz,
    'suppression' || 'suppression_definitive' => Icons.delete_outline,
    'restauration' => Icons.restore,
    'sauvegarde' => Icons.backup_outlined,
    'export' => Icons.file_download_outlined,
    _ => Icons.circle_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final liste = _entrees
        .where(
          (e) =>
              (_filtre == 'tout' || e.entite == _filtre) &&
              (q.isEmpty || e.resume.toLowerCase().contains(q)),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Historique des opérations'))),
      body: !_charge
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: tr('Rechercher dans l\'historique'),
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _q = v),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    children: _filtres.entries
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(f.value),
                              selected: _filtre == f.key,
                              onSelected: (_) =>
                                  setState(() => _filtre = f.key),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Expanded(
                  child: liste.isEmpty
                      ? Vide(
                          icone: Icons.history,
                          texte: tr('Aucune opération.'),
                        )
                      : RefreshIndicator(
                          onRefresh: _charger,
                          child: ListView.separated(
                            itemCount: liste.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, indent: 56),
                            itemBuilder: (ctx, i) {
                              final e = liste[i];
                              final ouvrable =
                                  e.entite == 'cheque' || e.entite == 'piece';
                              return ListTile(
                                leading: Icon(_icone(e)),
                                title: Text(e.resume),
                                subtitle: Text(Fmt.dateHeure(e.date)),
                                onTap:
                                    ouvrable &&
                                        e.action != 'suppression_definitive'
                                    ? () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChequeDetailScreen(
                                            chequeId: e.entiteId,
                                          ),
                                        ),
                                      )
                                    : null,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
