import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/communs.dart';
import '../l10n/i18n.dart';

/// Corbeille : chèques supprimés par erreur, restaurables (§9).
class CorbeilleScreen extends StatefulWidget {
  const CorbeilleScreen({super.key});
  @override
  State<CorbeilleScreen> createState() => _CorbeilleScreenState();
}

class _CorbeilleScreenState extends State<CorbeilleScreen> {
  List<Cheque> _liste = [];
  bool _charge = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final l = await context.read<AppState>().repo.cheques(corbeille: true);
    if (mounted) {
      setState(() {
        _liste = l;
        _charge = true;
      });
    }
  }

  Future<void> _restaurer(Cheque c) async {
    await context.read<AppState>().ecrire((r) => r.restaurer(c));
    await _charger();
    if (mounted) notifier(context, tr('Chèque restauré'));
  }

  Future<void> _supprimer(Cheque c) async {
    final app = context.read<AppState>();
    final ok = await confirmer(
      context,
      titre: tr('Suppression définitive'),
      message: tr(
        'Le chèque n° {0} sera supprimé définitivement. Une trace complète restera dans le journal. Cette action est irréversible.',
        [app.numero(c)],
      ),
      ok: tr('Supprimer définitivement'),
      danger: true,
    );
    if (!ok) return;
    try {
      await app.ecrire((r) => r.supprimerDefinitivement(c));
      await _charger();
      if (mounted) notifier(context, tr('Chèque supprimé définitivement'));
    } on RegleException catch (e) {
      if (mounted) notifier(context, e.message, erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Corbeille'))),
      body: !_charge
          ? const Center(child: CircularProgressIndicator())
          : _liste.isEmpty
          ? Vide(
              icone: Icons.delete_outline,
              texte: tr('La corbeille est vide.'),
            )
          : ListView.separated(
              itemCount: _liste.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final c = _liste[i];
                return Column(
                  children: [
                    ChequeTile(c),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _restaurer(c),
                          icon: const Icon(Icons.restore),
                          label: Text(tr('Restaurer')),
                        ),
                        TextButton.icon(
                          onPressed: () => _supprimer(c),
                          icon: const Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                          ),
                          label: Text(
                            tr('Supprimer'),
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }
}
