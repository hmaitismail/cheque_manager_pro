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
import 'banques_screen.dart';
import 'cheque_detail_screen.dart';
import 'home_shell.dart';
import 'licence_screen.dart';
import 'parametres_screen.dart';
import 'statistiques_screen.dart';
import '../l10n/i18n.dart';

/// Accueil : situation en un coup d'œil, actions rapides, chèques à traiter.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onVoirListe,
    required this.onOnglet,
  });
  final void Function(FiltreCheques) onVoirListe;
  final void Function(int) onOnglet;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.stats;
    final premierLancement = app.banques.isEmpty;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: app.rafraichir,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _EnTete(s: s, onOnglet: onOnglet),
            Transform.translate(
              offset: const Offset(0, -34),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ActionsRapides(onOnglet: onOnglet),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: premierLancement
                  ? const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [BandeauLicence(), _Bienvenue()],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const BandeauLicence(),
                        Section(tr('À traiter')),
                        _ATraiter(s: s, onVoirListe: onVoirListe),
                        Section(tr('Ce mois-ci')),
                        _CeMois(s: s),
                        Section(
                          tr('Par statut'),
                          action: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StatistiquesScreen(),
                              ),
                            ),
                            child: Text(tr('Analyses')),
                          ),
                        ),
                        _ParStatut(s: s, onVoirListe: onVoirListe),
                        Section(tr('Activité récente')),
                        const _Recents(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- En-tête
class _EnTete extends StatelessWidget {
  const _EnTete({required this.s, required this.onOnglet});
  final Stats s;
  final void Function(int) onOnglet;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final haut = MediaQuery.of(context).padding.top;
    final engage =
        s.de(Statut.enAttente).montant + s.de(Statut.presente).montant;
    final alertes =
        s.aujourdhui.length + s.enRetard.length + s.impayesASuivre.length;
    final heure = DateTime.now().hour;
    final salut = heure < 18 ? tr('Bonjour') : tr('Bonsoir');

    return Container(
      padding: EdgeInsets.fromLTRB(20, haut + 14, 12, 58),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.bleuNuit, Color(0xFF173A6B)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      salut,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      app.entreprise.isEmpty
                          ? tr('Cheque Manager Pro')
                          : app.entreprise,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr('Rappels'),
                onPressed: () => onOnglet(2),
                icon: Badge(
                  isLabelVisible: alertes > 0,
                  label: Text('$alertes'),
                  backgroundColor: const Color(0xFFEF4444),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('Paramètres'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ParametresScreen()),
                ),
                icon: const Icon(
                  Icons.settings_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          Text(
            Fmt.dateLongue(DateTime.now()),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 22),
          Text(
            tr('Encours non débité'),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              Fmt.mad(engage),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Pastille(
                libelle: tr('En attente'),
                a: s.de(Statut.enAttente),
                couleur: const Color(0xFFFBBF24),
              ),
              const SizedBox(width: 8),
              _Pastille(
                libelle: tr('Présentés'),
                a: s.de(Statut.presente),
                couleur: const Color(0xFF93C5FD),
              ),
              const SizedBox(width: 8),
              _Pastille(
                libelle: tr('Impayés'),
                a: s.de(Statut.impaye),
                couleur: const Color(0xFFFCA5A5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({
    required this.libelle,
    required this.a,
    required this.couleur,
  });
  final String libelle;
  final Agregat a;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: couleur,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  libelle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${a.nombre}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              tr('{0} MAD', [Fmt.madCompact(a.montant)]),
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ),
        ],
      ),
    ),
  );
}

// ------------------------------------------------------ Actions rapides
class _ActionsRapides extends StatelessWidget {
  const _ActionsRapides({required this.onOnglet});
  final void Function(int) onOnglet;

  @override
  Widget build(BuildContext context) {
    Widget action(
      IconData icone,
      String libelle,
      VoidCallback onTap, {
      bool principal = false,
    }) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: principal
                      ? AppColors.vert
                      : AppColors.vert.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icone,
                  color: principal ? Colors.white : AppColors.vert,
                  size: 24,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Material(
      elevation: 6,
      shadowColor: Colors.black26,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            action(
              Icons.add_rounded,
              tr('Nouveau'),
              () => nouveauCheque(context),
              principal: true,
            ),
            action(Icons.search_rounded, tr('Chercher'), () => onOnglet(1)),
            action(
              Icons.calendar_month_outlined,
              tr('Calendrier'),
              () => onOnglet(2),
            ),
            action(
              Icons.picture_as_pdf_outlined,
              tr('Rapports'),
              () => onOnglet(3),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ À traiter
class _ATraiter extends StatefulWidget {
  const _ATraiter({required this.s, required this.onVoirListe});
  final Stats s;
  final void Function(FiltreCheques) onVoirListe;
  @override
  State<_ATraiter> createState() => _ATraiterState();
}

class _ATraiterState extends State<_ATraiter> {
  int? _choix;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final onglets = <(String, Color, List<Cheque>, FiltreCheques Function())>[
      (
        tr('Aujourd\'hui'),
        const Color(0xFF2A78D6),
        s.aujourdhui,
        () => _jour(s.aujourdhui),
      ),
      (tr('Demain'), const Color(0xFFD97706), s.demain, () => _jour(s.demain)),
      (
        tr('En retard'),
        const Color(0xFFDC2626),
        s.enRetard,
        FiltreCheques.retards,
      ),
      (
        tr('Impayés'),
        const Color(0xFF9F1239),
        s.impayesASuivre,
        () => FiltreCheques.statuts({Statut.impaye}),
      ),
    ];
    final choix =
        _choix ?? onglets.indexWhere((o) => o.$3.isNotEmpty).clamp(0, 3);
    final o = onglets[choix];
    final liste = o.$3;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
            child: Row(
              children: [
                for (var i = 0; i < onglets.length; i++)
                  Expanded(
                    child: _Onglet(
                      libelle: onglets[i].$1,
                      nombre: onglets[i].$3.length,
                      couleur: onglets[i].$2,
                      actif: i == choix,
                      onTap: () => setState(() => _choix = i),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (liste.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.vert,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('Rien à signaler pour « {0} ».', [o.$1]),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            for (final c in liste.take(4))
              ChequeTile(
                c,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChequeDetailScreen(chequeId: c.id),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 8, 6),
              child: Row(
                children: [
                  Text(
                    tr('Total : {0}', [
                      Fmt.mad(liste.fold(0, (t, c) => t + c.montant)),
                    ]),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (liste.length > 4)
                    TextButton(
                      onPressed: () => widget.onVoirListe(o.$4()),
                      child: Text(tr('Voir les {0}', [liste.length])),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static FiltreCheques _jour(List<Cheque> l) {
    final f = FiltreCheques.statuts({Statut.enAttente, Statut.impaye});
    if (l.isNotEmpty) {
      f.du = l.first.datePresentation;
      f.au = l.first.datePresentation;
    }
    return f;
  }
}

class _Onglet extends StatelessWidget {
  const _Onglet({
    required this.libelle,
    required this.nombre,
    required this.couleur,
    required this.actif,
    required this.onTap,
  });
  final String libelle;
  final int nombre;
  final Color couleur;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: actif ? couleur.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$nombre',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: nombre == 0 ? Theme.of(context).disabledColor : couleur,
            ),
          ),
          Text(
            libelle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

// ------------------------------------------------------------ Ce mois-ci
class _CeMois extends StatelessWidget {
  const _CeMois({required this.s});
  final Stats s;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final m = s.mensuel.last;
    final prec = s.mensuel[s.mensuel.length - 2];
    final variation = prec.emis == 0
        ? null
        : (m.emis - prec.emis) * 100 / prec.emis;
    final six = s.mensuel.sublist(s.mensuel.length - 6);
    final pal = palette(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Émis en {0}', [Fmt.moisLongs[m.mois.month - 1]]),
                        style: t.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          Fmt.mad(m.emis),
                          style: t.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(tr('{0} chèque(s)', [m.nombre]), style: t.bodySmall),
                    ],
                  ),
                ),
                if (variation != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (variation > 0 ? Colors.orange : AppColors.vert)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          variation > 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 16,
                          color: variation > 0
                              ? Colors.orange.shade800
                              : AppColors.vert,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${variation > 0 ? '+' : ''}${variation.toStringAsFixed(0)} %',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: variation > 0
                                ? Colors.orange.shade800
                                : AppColors.vert,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: Barres(
                etiquettes: six.map((p) => Fmt.moisAnnee(p.mois)).toList(),
                series: [
                  SerieBarres(
                    tr('Émis'),
                    pal[0],
                    six.map((p) => p.emis / 100).toList(),
                  ),
                ],
                formatValeur: (v) => Fmt.madCompact((v * 100).round()),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _MiniChiffre(tr('Payés'), m.payes, Statut.paye.couleur),
                _MiniChiffre(tr('Impayés'), m.impayes, Statut.impaye.couleur),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChiffre extends StatelessWidget {
  const _MiniChiffre(this.libelle, this.montant, this.couleur);
  final String libelle;
  final int montant;
  final Color couleur;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: couleur,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            tr('{0} : {1} MAD', [libelle, Fmt.madCompact(montant)]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}

// ------------------------------------------------------------ Par statut
class _ParStatut extends StatelessWidget {
  const _ParStatut({required this.s, required this.onVoirListe});
  final Stats s;
  final void Function(FiltreCheques) onVoirListe;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cartes = [
      (
        tr('Tous'),
        Icons.receipt_long_rounded,
        AppColors.bleuNuitClair,
        s.total,
        FiltreCheques.new,
      ),
      for (final st in Statut.values)
        (
          st.libelle,
          st.icone,
          st.couleur,
          s.de(st),
          () => FiltreCheques.statuts({st}),
        ),
    ];
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cartes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final c = cartes[i];
          return SizedBox(
            width: 128,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onVoirListe(c.$5()),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(c.$2, color: c.$3, size: 22),
                      const Spacer(),
                      Text(
                        '${c.$4.nombre}',
                        style: t.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        c.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall,
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          Fmt.mad(c.$4.montant),
                          style: t.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.$3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------- Récents
class _Recents extends StatelessWidget {
  const _Recents();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final recents = [...app.cheques]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (recents.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.edit_note_rounded),
          title: Text(tr('Aucun chèque pour l\'instant')),
          subtitle: Text(
            tr('Touchez « Nouveau » pour saisir votre premier chèque.'),
          ),
          onTap: () => nouveauCheque(context),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final c in recents.take(5))
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
    );
  }
}

// ------------------------------------------------------------ Bienvenue
class _Bienvenue extends StatelessWidget {
  const _Bienvenue();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget etape(int n, String titre, String texte) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.vert,
            child: Text(
              '$n',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(texte, style: t.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Bienvenue'),
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('Trois étapes pour commencer à suivre vos chèques.'),
                  style: t.bodyMedium,
                ),
                const SizedBox(height: 18),
                etape(
                  1,
                  tr('Ajoutez votre banque'),
                  tr('Nom, agence, titulaire et référence du compte.'),
                ),
                etape(
                  2,
                  tr('Ajoutez un chéquier'),
                  tr(
                    'Premier et dernier numéro : les contrôles sont automatiques.',
                  ),
                ),
                etape(
                  3,
                  tr('Saisissez vos chèques'),
                  tr(
                    'Les rappels et le tableau de bord se mettent à jour seuls.',
                  ),
                ),
                const SizedBox(height: 4),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BanquesScreen()),
                  ),
                  icon: const Icon(Icons.account_balance_rounded),
                  label: Text(tr('Ajouter ma banque')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ParametresScreen()),
          ),
          icon: const Icon(Icons.settings_backup_restore_rounded),
          label: Text(tr('J\'ai déjà une sauvegarde : restaurer mes données')),
        ),
      ],
    );
  }
}
