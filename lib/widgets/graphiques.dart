import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/format.dart';

/// Palette catégorielle validée (ordre fixe, jamais cyclée : au-delà de 8
/// séries, le reste est regroupé dans « Autres »).
const paletteClair = [
  Color(0xFF2A78D6),
  Color(0xFFEB6834),
  Color(0xFF1BAF7A),
  Color(0xFFEDA100),
  Color(0xFFE87BA4),
  Color(0xFF008300),
  Color(0xFF6250D6),
  Color(0xFFE34948),
];
const paletteSombre = [
  Color(0xFF3987E5),
  Color(0xFFD95926),
  Color(0xFF199E70),
  Color(0xFFC98500),
  Color(0xFFD55181),
  Color(0xFF0CA30C),
  Color(0xFF9085E9),
  Color(0xFFE66767),
];
const couleurAutres = Color(0xFF9E9E99);

List<Color> palette(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? paletteSombre : paletteClair;

class CarteGraphique extends StatelessWidget {
  const CarteGraphique({
    super.key,
    required this.titre,
    required this.child,
    this.legende,
    this.hauteur = 200,
  });
  final String titre;
  final Widget child;
  final Widget? legende;
  final double hauteur;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (legende != null) ...[const SizedBox(height: 8), legende!],
          const SizedBox(height: 12),
          SizedBox(height: hauteur, child: child),
        ],
      ),
    ),
  );
}

class ElementLegende {
  final String libelle;
  final Color couleur;
  final String? valeur;
  ElementLegende(this.libelle, this.couleur, [this.valeur]);
}

class Legende extends StatelessWidget {
  const Legende(this.elements, {super.key});
  final List<ElementLegende> elements;
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: elements
          .map(
            (e) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: e.couleur,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  e.valeur == null ? e.libelle : '${e.libelle} · ${e.valeur}',
                  style: style,
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

/// Anneau de répartition (statuts, banques, villes).
class Anneau extends StatefulWidget {
  const Anneau({
    super.key,
    required this.valeurs,
    required this.couleurs,
    required this.centre,
  });
  final List<double> valeurs;
  final List<Color> couleurs;
  final String centre;
  @override
  State<Anneau> createState() => _AnneauState();
}

class _AnneauState extends State<Anneau> {
  int _touche = -1;
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 54,
            startDegreeOffset: -90,
            borderData: FlBorderData(show: false),
            pieTouchData: PieTouchData(
              touchCallback: (e, r) {
                setState(
                  () => _touche =
                      (!e.isInterestedForInteractions ||
                          r?.touchedSection == null)
                      ? -1
                      : r!.touchedSection!.touchedSectionIndex,
                );
              },
            ),
            sections: [
              for (var i = 0; i < widget.valeurs.length; i++)
                PieChartSectionData(
                  value: widget.valeurs[i],
                  color: widget.couleurs[i],
                  radius: i == _touche ? 30 : 24,
                  title: '',
                ),
            ],
          ),
        ),
        Text(
          widget.centre,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class SerieBarres {
  final String nom;
  final Color couleur;
  final List<double> valeurs;
  SerieBarres(this.nom, this.couleur, this.valeurs);
}

/// Barres groupées sur un seul axe, infobulle au toucher.
class Barres extends StatelessWidget {
  const Barres({
    super.key,
    required this.etiquettes,
    required this.series,
    this.formatValeur,
  });
  final List<String> etiquettes;
  final List<SerieBarres> series;
  final String Function(double)? formatValeur;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final muted = t.textTheme.bodySmall?.copyWith(
      fontSize: 10,
      color: t.hintColor,
    );
    final String Function(double) fmt =
        formatValeur ?? ((double v) => v.toStringAsFixed(0));
    final maxV = series.expand((s) => s.valeurs).fold<double>(0, math.max);
    final largeur = series.length == 1 ? 12.0 : 7.0;
    return BarChart(
      BarChartData(
        maxY: maxV == 0 ? 1 : maxV * 1.15,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: t.dividerColor.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) => (v == meta.max)
                  ? const SizedBox()
                  : Text(fmt(v), style: muted, textAlign: TextAlign.right),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= etiquettes.length) return const SizedBox();
                // Une étiquette sur deux si l'espace manque.
                if (etiquettes.length > 8 && i.isOdd) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(etiquettes[i], style: muted),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
              '${etiquettes[g.x]}\n${series[ri].nom} : ${fmt(rod.toY)}',
              const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < etiquettes.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                for (final s in series)
                  BarChartRodData(
                    toY: s.valeurs[i],
                    color: s.couleur,
                    width: largeur,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Barres horizontales simples (banques, villes) : lisibles avec des noms longs.
class BarresHorizontales extends StatelessWidget {
  const BarresHorizontales({
    super.key,
    required this.libelles,
    required this.valeurs,
    required this.couleurs,
  });
  final List<String> libelles;
  final List<int> valeurs; // centimes
  final List<Color> couleurs;

  @override
  Widget build(BuildContext context) {
    final maxV = valeurs.fold<int>(0, math.max);
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        for (var i = 0; i < libelles.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        libelles[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall,
                      ),
                    ),
                    Text(
                      Fmt.mad(valeurs[i]),
                      style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LayoutBuilder(
                  builder: (ctx, c) => Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 8,
                      width: maxV == 0
                          ? 0
                          : math.max(4, c.maxWidth * valeurs[i] / maxV),
                      decoration: BoxDecoration(
                        color: couleurs[i],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Courbe simple (nombre de chèques par mois) avec infobulle.
class Courbe extends StatelessWidget {
  const Courbe({
    super.key,
    required this.etiquettes,
    required this.valeurs,
    required this.couleur,
    required this.nom,
  });
  final List<String> etiquettes;
  final List<double> valeurs;
  final Color couleur;
  final String nom;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final muted = t.textTheme.bodySmall?.copyWith(
      fontSize: 10,
      color: t.hintColor,
    );
    final maxV = valeurs.fold<double>(0, math.max);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxV == 0 ? 1 : (maxV * 1.2).ceilToDouble(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: t.dividerColor.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) =>
                  (v == meta.max || v != v.roundToDouble())
                  ? const SizedBox()
                  : Text(v.toInt().toString(), style: muted),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 22,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (v != i.toDouble() || i < 0 || i >= etiquettes.length) {
                  return const SizedBox();
                }
                if (etiquettes.length > 8 && i.isOdd) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(etiquettes[i], style: muted),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map(
                  (s) => LineTooltipItem(
                    '${etiquettes[s.x.toInt()]}\n$nom : ${s.y.toInt()}',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < valeurs.length; i++)
                FlSpot(i.toDouble(), valeurs[i]),
            ],
            isCurved: true,
            preventCurveOverShooting: true,
            color: couleur,
            barWidth: 2,
            dotData: FlDotData(
              getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                radius: 4,
                color: couleur,
                strokeWidth: 2,
                strokeColor: t.colorScheme.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: couleur.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}
