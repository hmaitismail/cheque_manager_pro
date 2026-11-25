import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../models/models.dart';
import '../services/rappels.dart';
import '../state/app_state.dart';
import '../widgets/communs.dart';
import 'cheque_detail_screen.dart';
import 'parametres_screen.dart';
import '../l10n/i18n.dart';

/// Calendrier des présentations et rappels programmés (§5).
class CalendrierScreen extends StatefulWidget {
  const CalendrierScreen({super.key});
  @override
  State<CalendrierScreen> createState() => _CalendrierScreenState();
}

class _CalendrierScreenState extends State<CalendrierScreen> {
  DateTime _mois = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _jour = Fmt.jour(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final parJour = <DateTime, List<Cheque>>{};
    for (final c in app.cheques) {
      parJour.putIfAbsent(Fmt.jour(c.datePresentation), () => []).add(c);
    }
    final duJour = parJour[_jour] ?? [];
    final plan = PlanificateurRappels.planifier(
      app.cheques,
      app.reglages,
      maintenant: DateTime.now(),
      libelleNumero: app.numero,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Calendrier et rappels')),
        actions: [
          IconButton(
            tooltip: tr('Réglages des rappels'),
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReglagesRappelsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => setState(
                          () => _mois = DateTime(_mois.year, _mois.month - 1),
                        ),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          '${Fmt.moisLongs[_mois.month - 1]} ${_mois.year}'
                              .replaceFirstMapped(
                                RegExp(r'^.'),
                                (m) => m[0]!.toUpperCase(),
                              ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(
                          () => _mois = DateTime(_mois.year, _mois.month + 1),
                        ),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  _Grille(
                    mois: _mois,
                    selection: _jour,
                    parJour: parJour,
                    onJour: (d) => setState(() => _jour = d),
                  ),
                ],
              ),
            ),
          ),
          Section(
            tr('{0} · {1} chèque(s)', [Fmt.dateLongue(_jour), duJour.length]),
          ),
          if (duJour.isEmpty)
            Text(
              tr('Aucune présentation prévue ce jour.'),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Card(
              child: Column(
                children: [
                  for (final c in duJour)
                    ChequeTile(
                      c,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChequeDetailScreen(chequeId: c.id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Section(tr('Prochains rappels programmés ({0})', [plan.length])),
          if (!app.reglages.actifs)
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_off),
                title: Text(tr('Rappels désactivés')),
              ),
            )
          else if (plan.isEmpty)
            Text(
              tr('Aucun rappel à venir.'),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Card(
              child: Column(
                children: [
                  for (final p in plan.take(15))
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.notifications, size: 20),
                      title: Text(
                        p.titre,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${Fmt.dateHeure(p.date)}\n${p.corps.split('\n').skip(1).join(' · ')}',
                      ),
                      isThreeLine: true,
                      onTap: p.chequeId == null
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ChequeDetailScreen(chequeId: p.chequeId!),
                              ),
                            ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Grille extends StatelessWidget {
  const _Grille({
    required this.mois,
    required this.selection,
    required this.parJour,
    required this.onJour,
  });
  final DateTime mois;
  final DateTime selection;
  final Map<DateTime, List<Cheque>> parJour;
  final ValueChanged<DateTime> onJour;

  @override
  Widget build(BuildContext context) {
    final premier = DateTime(mois.year, mois.month, 1);
    final decalage = premier.weekday - 1; // lundi = 0
    final nbJours = DateTime(mois.year, mois.month + 1, 0).day;
    final aujourdhui = Fmt.jour(DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    final cases = <Widget>[
      for (final j in Fmt.joursInitiales)
        Center(
          child: Text(
            j,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
      for (var i = 0; i < decalage; i++) const SizedBox(),
      for (var d = 1; d <= nbJours; d++)
        Builder(
          builder: (ctx) {
            final jour = DateTime(mois.year, mois.month, d);
            final liste = parJour[jour] ?? const <Cheque>[];
            final selectionne = jour == selection;
            final statuts = liste.map((c) => c.statut).toSet().take(3).toList();
            final retard = liste.any((c) => c.estEnRetard(aujourdhui));
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onJour(jour),
              child: Container(
                decoration: BoxDecoration(
                  color: selectionne ? scheme.primary : null,
                  borderRadius: BorderRadius.circular(10),
                  border: jour == aujourdhui && !selectionne
                      ? Border.all(color: scheme.primary)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$d',
                      style: TextStyle(
                        color: selectionne
                            ? scheme.onPrimary
                            : (retard ? Colors.red : null),
                        fontWeight: liste.isEmpty
                            ? FontWeight.w400
                            : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final s in statuts)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: s.couleur,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: cases,
    );
  }
}
