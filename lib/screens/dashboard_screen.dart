import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/filtre.dart';
import '../models/models.dart';
import '../services/stats.dart';
import '../state/app_state.dart';
import '../widgets/communs.dart';
import '../widgets/graphiques.dart';
import 'cheque_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onVoirListe});
  final void Function(FiltreCheques) onVoirListe;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.stats;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tableau de bord'),
            Text(
              Fmt.dateLongue(DateTime.now()),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: app.rafraichir,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 96),
          children: [
            _Bandeau(s: s),
            const Section('Priorités du jour'),
            _Priorites(s: s, onVoirListe: onVoirListe),
            const Section('Indicateurs'),
            _Indicateurs(s: s, onVoirListe: onVoirListe),
            if (s.total.nombre > 0) ...[
              const Section('Analyses'),
              _Graphiques(s: s),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.s});
  final Stats s;
  @override
  Widget build(BuildContext context) {
    final engage =
        s.de(Statut.enAttente).montant + s.de(Statut.presente).montant;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.bleuNuit, AppColors.bleuNuitClair],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Montant engagé non encore débité',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              Fmt.mad(engage),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${s.de(Statut.enAttente).nombre} en attente · ${s.de(Statut.presente).nombre} présenté(s)',
            style: const TextStyle(
              color: Color(0xFF86EFAC),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Priorites extends StatelessWidget {
  const _Priorites({required this.s, required this.onVoirListe});
  final Stats s;
  final void Function(FiltreCheques) onVoirListe;

  @override
  Widget build(BuildContext context) {
    final blocs = <(String, IconData, Color, List<Cheque>)>[
      (
        'À présenter aujourd\'hui',
        Icons.today,
        const Color(0xFF2A78D6),
        s.aujourdhui,
      ),
      ('À présenter demain', Icons.event, const Color(0xFFEDA100), s.demain),
      (
        'En retard',
        Icons.warning_amber_rounded,
        const Color(0xFFDC2626),
        s.enRetard,
      ),
      (
        'Impayés à régulariser',
        Icons.error_outline,
        const Color(0xFFB91C1C),
        s.impayesASuivre,
      ),
    ];
    if (blocs.every((b) => b.$4.isEmpty)) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.check_circle, color: AppColors.vert),
          title: Text('Rien d\'urgent aujourd\'hui'),
          subtitle: Text('Aucun chèque à présenter, en retard ou impayé.'),
        ),
      );
    }
    return Column(
      children: [
        for (final b in blocs)
          if (b.$4.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      color: b.$3.withValues(alpha: 0.08),
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                      child: Row(
                        children: [
                          Icon(b.$2, color: b.$3, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${b.$1} (${b.$4.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: b.$3,
                              ),
                            ),
                          ),
                          Text(
                            Fmt.mad(b.$4.fold(0, (t, c) => t + c.montant)),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    for (final c in b.$4.take(3))
                      ChequeTile(
                        c,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChequeDetailScreen(chequeId: c.id),
                          ),
                        ),
                      ),
                    if (b.$4.length > 3)
                      TextButton(
                        onPressed: () => onVoirListe(
                          b.$1 == 'En retard'
                              ? FiltreCheques.retards()
                              : b.$1.startsWith('Impayés')
                              ? FiltreCheques.statuts({Statut.impaye})
                              : (FiltreCheques()
                                  ..statuts = {Statut.enAttente, Statut.impaye}
                                  ..du = b.$4.first.datePresentation
                                  ..au = b.$4.first.datePresentation),
                        ),
                        child: Text('Voir les ${b.$4.length}'),
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _Indicateurs extends StatelessWidget {
  const _Indicateurs({required this.s, required this.onVoirListe});
  final Stats s;
  final void Function(FiltreCheques) onVoirListe;

  @override
  Widget build(BuildContext context) {
    StatCard carte(Statut st, {bool montant = true}) => StatCard(
      titre: st.libelle,
      valeur: '${s.de(st).nombre}',
      sousTitre: montant ? Fmt.mad(s.de(st).montant) : null,
      icone: st.icone,
      couleur: st.couleur,
      onTap: () => onVoirListe(FiltreCheques.statuts({st})),
    );
    final cartes = [
      StatCard(
        titre: 'Total émis',
        valeur: '${s.total.nombre}',
        sousTitre: Fmt.mad(s.total.montant),
        icone: Icons.receipt_long,
        couleur: AppColors.bleuNuitClair,
        onTap: () => onVoirListe(FiltreCheques()),
      ),
      carte(Statut.enAttente),
      carte(Statut.presente),
      carte(Statut.paye),
      carte(Statut.impaye),
      carte(Statut.recupere),
      carte(Statut.detruit),
      StatCard(
        titre: 'Aujourd\'hui / demain',
        valeur: '${s.aujourdhui.length} / ${s.demain.length}',
        sousTitre: 'à présenter',
        icone: Icons.event_available,
        couleur: const Color(0xFF2A78D6),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final colonnes = c.maxWidth > 700 ? 4 : 2;
        return GridView.count(
          crossAxisCount: colonnes,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.3,
          children: cartes,
        );
      },
    );
  }
}

class _Graphiques extends StatelessWidget {
  const _Graphiques({required this.s});
  final Stats s;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final pal = palette(context);
    final etiquettes = s.mensuel.map((p) => Fmt.moisAnnee(p.mois)).toList();
    String k(double v) => Fmt.madCompact((v * 100).round());

    // Répartition par statut (couleurs des statuts + légende chiffrée).
    final statuts = Statut.values.where((st) => s.de(st).nombre > 0).toList();

    // Par banque / ville : 8 premières, le reste dans « Autres ».
    (List<String>, List<int>, List<Color>) top(
      Map<String, Agregat> m,
      String Function(String) nom,
    ) {
      final e = m.entries.toList()
        ..sort((a, b) => b.value.montant.compareTo(a.value.montant));
      final noms = <String>[], vals = <int>[], cols = <Color>[];
      for (var i = 0; i < e.length && i < 7; i++) {
        noms.add(nom(e[i].key));
        vals.add(e[i].value.montant);
        cols.add(pal[i]);
      }
      if (e.length > 7) {
        noms.add('Autres (${e.length - 7})');
        vals.add(e.skip(7).fold(0, (t, x) => t + x.value.montant));
        cols.add(couleurAutres);
      }
      return (noms, vals, cols);
    }

    final banques = top(s.parBanque, app.nomBanque);
    final villes = top(s.parVille, (v) => v);

    return Column(
      children: [
        CarteGraphique(
          titre: 'Répartition par statut',
          legende: Legende([
            for (final st in statuts)
              ElementLegende(st.libelle, st.couleur, '${s.de(st).nombre}'),
          ]),
          child: Anneau(
            valeurs: [for (final st in statuts) s.de(st).nombre.toDouble()],
            couleurs: [for (final st in statuts) st.couleur],
            centre: '${s.total.nombre}\nchèques',
          ),
        ),
        const SizedBox(height: 10),
        CarteGraphique(
          titre: 'Montants émis par mois (MAD)',
          child: Barres(
            etiquettes: etiquettes,
            series: [
              SerieBarres(
                'Émis',
                pal[0],
                s.mensuel.map((p) => p.emis / 100).toList(),
              ),
            ],
            formatValeur: k,
          ),
        ),
        const SizedBox(height: 10),
        CarteGraphique(
          titre: 'Payés et impayés par mois (MAD)',
          legende: Legende([
            ElementLegende(
              'Payés',
              Statut.paye.couleur,
              Fmt.mad(s.de(Statut.paye).montant),
            ),
            ElementLegende(
              'Impayés',
              Statut.impaye.couleur,
              Fmt.mad(s.de(Statut.impaye).montant),
            ),
          ]),
          child: Barres(
            etiquettes: etiquettes,
            series: [
              SerieBarres(
                'Payés',
                Statut.paye.couleur,
                s.mensuel.map((p) => p.payes / 100).toList(),
              ),
              SerieBarres(
                'Impayés',
                Statut.impaye.couleur,
                s.mensuel.map((p) => p.impayes / 100).toList(),
              ),
            ],
            formatValeur: k,
          ),
        ),
        const SizedBox(height: 10),
        CarteGraphique(
          titre: 'Nombre de chèques par mois',
          child: Courbe(
            etiquettes: etiquettes,
            valeurs: s.mensuel.map((p) => p.nombre.toDouble()).toList(),
            couleur: pal[0],
            nom: 'Chèques',
          ),
        ),
        const SizedBox(height: 10),
        CarteGraphique(
          titre: 'Répartition par banque',
          hauteur: banques.$1.length * 42.0,
          child: BarresHorizontales(
            libelles: banques.$1,
            valeurs: banques.$2,
            couleurs: banques.$3,
          ),
        ),
        const SizedBox(height: 10),
        CarteGraphique(
          titre: 'Répartition par ville',
          hauteur: villes.$1.length * 42.0,
          child: BarresHorizontales(
            libelles: villes.$1,
            valeurs: villes.$2,
            couleurs: villes.$3,
          ),
        ),
      ],
    );
  }
}
