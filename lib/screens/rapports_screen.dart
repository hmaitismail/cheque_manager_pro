import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../services/rapports.dart';
import '../state/app_state.dart';
import '../widgets/communs.dart';
import 'licence_screen.dart';
import '../l10n/i18n.dart';

/// Rapports et exportations PDF / Excel / CSV (§8).
class RapportsScreen extends StatefulWidget {
  const RapportsScreen({super.key});
  @override
  State<RapportsScreen> createState() => _RapportsScreenState();
}

class _RapportsScreenState extends State<RapportsScreen> {
  TypeRapport _type = TypeRapport.enAttente;
  DateTime? _du;
  DateTime? _au;
  bool _enCours = false;

  Future<void> _executer(
    Future<void> Function(ServiceRapports s, Rapport r) action,
  ) async {
    if (!await exigerLicence(context)) return;
    if (!mounted) return;
    final app = context.read<AppState>();
    setState(() => _enCours = true);
    try {
      final s = app.rapports;
      final r = s.construire(_type, app.cheques, du: _du, au: _au);
      await action(s, r);
      await app.repo.logSysteme(
        'export',
        tr('Rapport généré : {0} ({1})', [r.titre, r.periode]),
      );
    } catch (e) {
      if (mounted) {
        notifier(
          context,
          tr('Erreur lors de la génération : {0}', [e]),
          erreur: true,
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  void _periodeRapide(String code) {
    final n = Fmt.jour(DateTime.now());
    setState(() {
      switch (code) {
        case 'mois':
          _du = DateTime(n.year, n.month, 1);
          _au = DateTime(n.year, n.month + 1, 0);
        case 'mois_prec':
          _du = DateTime(n.year, n.month - 1, 1);
          _au = DateTime(n.year, n.month, 0);
        case 'annee':
          _du = DateTime(n.year, 1, 1);
          _au = DateTime(n.year, 12, 31);
        default:
          _du = null;
          _au = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final apercu = app.rapports.construire(
      _type,
      app.cheques,
      du: _du,
      au: _au,
    );
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Rapports'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 40),
        children: [
          Section(tr('Type de rapport')),
          Card(
            child: RadioGroup<TypeRapport>(
              groupValue: _type,
              onChanged: (v) => setState(() => _type = v ?? _type),
              child: Column(
                children: [
                  for (final ty in TypeRapport.values)
                    RadioListTile<TypeRapport>(
                      dense: true,
                      value: ty,
                      title: Text(ty.titre),
                    ),
                ],
              ),
            ),
          ),
          Section(tr('Période (date d\'édition)')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: Text(tr('Tout')),
                onPressed: () => _periodeRapide('tout'),
              ),
              ActionChip(
                label: Text(tr('Ce mois')),
                onPressed: () => _periodeRapide('mois'),
              ),
              ActionChip(
                label: Text(tr('Mois précédent')),
                onPressed: () => _periodeRapide('mois_prec'),
              ),
              ActionChip(
                label: Text(tr('Cette année')),
                onPressed: () => _periodeRapide('annee'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(_du == null ? tr('Du...') : Fmt.date(_du)),
                  onPressed: () async {
                    final d = await choisirDate(context, _du ?? DateTime.now());
                    if (d != null) setState(() => _du = d);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(_au == null ? tr('Au...') : Fmt.date(_au)),
                  onPressed: () async {
                    final d = await choisirDate(context, _au ?? DateTime.now());
                    if (d != null) setState(() => _au = d);
                  },
                ),
              ),
            ],
          ),
          Section(tr('Aperçu')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    apercu.titre,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(apercu.periode, style: t.bodySmall),
                  const SizedBox(height: 8),
                  Text(tr('{0} ligne(s)', [apercu.lignes.length])),
                  Text(
                    tr('Total : {0}', [Fmt.mad(apercu.totalGeneral)]),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_enCours) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _enCours
                ? null
                : () => _executer((s, r) => s.imprimer(r)),
            icon: const Icon(Icons.print),
            label: Text(tr('Aperçu et impression PDF')),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _enCours
                      ? null
                      : () => _executer(
                          (s, r) => s.partager(r, FormatExport.pdf),
                        ),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(tr('PDF')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _enCours
                      ? null
                      : () => _executer(
                          (s, r) => s.partager(r, FormatExport.xlsx),
                        ),
                  icon: const Icon(Icons.table_chart),
                  label: Text(tr('Excel')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _enCours
                      ? null
                      : () => _executer(
                          (s, r) => s.partager(r, FormatExport.csv),
                        ),
                  icon: const Icon(Icons.description),
                  label: Text(tr('CSV')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'Les fichiers sont proposés au partage (e-mail, WhatsApp, Drive, enregistrement...).',
            ),
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
