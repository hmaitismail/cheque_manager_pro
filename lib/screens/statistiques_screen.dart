import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../models/models.dart';
import '../services/stats.dart';
import '../state/app_state.dart';
import '../widgets/communs.dart';
import '../widgets/graphiques.dart';
import '../l10n/i18n.dart';

/// Analyses détaillées (§6 graphiques) : accessible depuis l'accueil.
class StatistiquesScreen extends StatelessWidget {
  const StatistiquesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().stats;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Analyses'))),
      body: s.total.nombre == 0
          ? Vide(
              icone: Icons.insights,
              texte: tr(
                'Les graphiques apparaîtront après la saisie des premiers chèques.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
              children: [GraphiquesAnalyse(s: s)],
            ),
    );
  }
}

class GraphiquesAnalyse extends StatelessWidget {
  const GraphiquesAnalyse({super.key, required this.s});
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
        noms.add(tr('Autres ({0})', [e.length - 7]));
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
          titre: tr('Répartition par statut'),
          legende: Legende([
            for (final st in statuts)
              ElementLegende(st.libelle, st.couleur, '${s.de(st).nombre}'),
          ]),
          child: Anneau(
            valeurs: [for (final st in statuts) s.de(st).nombre.toDouble()],
            couleurs: [for (final st in statuts) st.couleur],
            centre: tr('{0}\nchèques', [s.total.nombre]),
          ),
        ),
        const SizedBox(height: 10),
        CarteGraphique(
          titre: tr('Montants émis par mois (MAD)'),
          child: Barres(
            etiquettes: etiquettes,
            series: [
              SerieBarres(
                tr('Émis'),
                pal[0],
                s.mensuel.map((p) => p.emis / 100).toList(),
              ),
            ],
            formatValeur: k,
          ),
        ),
        const SizedBox(height: 10),
        CarteGraphique(
          titre: tr('Payés et impayés par mois (MAD)'),
          legende: Legende([
            ElementLegende(
              tr('Payés'),
              Statut.paye.couleur,
              Fmt.mad(s.de(Statut.paye).montant),
            ),
            ElementLegende(
              tr('Impayés'),
              Statut.impaye.couleur,
              Fmt.mad(s.de(Statut.impaye).montant),
            ),
          ]),
          child: Barres(
            etiquettes: etiquettes,
            series: [
              SerieBarres(
                tr('Payés'),
                Statut.paye.couleur,
                s.mensuel.map((p) => p.payes / 100).toList(),
              ),
              SerieBarres(
                tr('Impayés'),
                Statut.impaye.couleur,
                s.mensuel.map((p) => p.impayes / 100).toList(),
              ),
            ],
            formatValeur: k,
          ),
        ),
        const SizedBox(height: 10),
        CarteGraphique(
          titre: tr('Nombre de chèques par mois'),
          child: Courbe(
            etiquettes: etiquettes,
            valeurs: s.mensuel.map((p) => p.nombre.toDouble()).toList(),
            couleur: pal[0],
            nom: tr('Chèques'),
          ),
        ),
        const SizedBox(height: 10),
        CarteGraphique(
          titre: tr('Répartition par banque'),
          hauteur: banques.$1.length * 42.0,
          child: BarresHorizontales(
            libelles: banques.$1,
            valeurs: banques.$2,
            couleurs: banques.$3,
          ),
        ),
        const SizedBox(height: 10),
        CarteGraphique(
          titre: tr('Répartition par ville'),
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
