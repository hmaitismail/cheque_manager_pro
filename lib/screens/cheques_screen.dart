import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../models/filtre.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/communs.dart';
import 'cheque_detail_screen.dart';
import '../l10n/i18n.dart';

class ChequesScreen extends StatefulWidget {
  const ChequesScreen({super.key});
  @override
  State<ChequesScreen> createState() => ChequesScreenState();
}

class ChequesScreenState extends State<ChequesScreen> {
  FiltreCheques _f = FiltreCheques();
  final _recherche = TextEditingController();

  void appliquerFiltre(FiltreCheques f) {
    setState(() {
      _f = f;
      _recherche.text = f.texte;
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final liste = _f.appliquer(
      app.cheques,
      numero: app.numero,
      banque: (c) => app.nomBanque(c.banqueId),
      chequier: (c) => app.chequier(c.chequierId)?.numero ?? '',
    );
    final total = liste.fold<int>(0, (s, c) => s + c.montant);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Chèques')),
        actions: [
          PopupMenuButton<Tri>(
            tooltip: tr('Trier'),
            icon: const Icon(Icons.sort),
            initialValue: _f.tri,
            onSelected: (t) => setState(() => _f.tri = t),
            itemBuilder: (_) => Tri.values
                .map((t) => PopupMenuItem(value: t, child: Text(t.libelle)))
                .toList(),
          ),
          IconButton(
            tooltip: tr('Filtres'),
            icon: Badge(
              isLabelVisible: _f.nbCriteres > 0,
              label: Text('${_f.nbCriteres}'),
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _ouvrirFiltres,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _recherche,
              onChanged: (v) => setState(() => _f.texte = v),
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: tr('N°, bénéficiaire, banque, montant, ville...'),
                prefixIcon: const Icon(Icons.search),
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _f.texte.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _recherche.clear();
                          _f.texte = '';
                        }),
                      ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(tr('En retard')),
                    selected: _f.retardSeulement,
                    onSelected: (v) => setState(() => _f.retardSeulement = v),
                  ),
                ),
                for (final st in Statut.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      avatar: Icon(st.icone, size: 16, color: st.couleur),
                      label: Text(st.libelle),
                      selected: _f.statuts.contains(st),
                      onSelected: (v) => setState(
                        () => v ? _f.statuts.add(st) : _f.statuts.remove(st),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                Text(
                  tr('{0} chèque(s)', [liste.length]),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  tr('Total : {0}', [Fmt.mad(total)]),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (_f.nbCriteres > 0 || _f.texte.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        appliquerFiltre(FiltreCheques()..tri = _f.tri),
                    child: Text(tr('Effacer')),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: liste.isEmpty
                ? Vide(
                    icone: Icons.search_off,
                    texte: tr('Aucun chèque ne correspond.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: liste.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 70),
                    itemBuilder: (ctx, i) => ChequeTile(
                      liste[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ChequeDetailScreen(chequeId: liste[i].id),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _ouvrirFiltres() async {
    final r = await showModalBottomSheet<FiltreCheques>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FeuilleFiltres(initial: _f),
    );
    if (r != null) appliquerFiltre(r);
  }
}

class _FeuilleFiltres extends StatefulWidget {
  const _FeuilleFiltres({required this.initial});
  final FiltreCheques initial;
  @override
  State<_FeuilleFiltres> createState() => _FeuilleFiltresState();
}

class _FeuilleFiltresState extends State<_FeuilleFiltres> {
  late FiltreCheques f;
  late final TextEditingController _min;
  late final TextEditingController _max;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    f = FiltreCheques()
      ..texte = i.texte
      ..statuts = {...i.statuts}
      ..banqueId = i.banqueId
      ..chequierId = i.chequierId
      ..ville = i.ville
      ..du = i.du
      ..au = i.au
      ..montantMin = i.montantMin
      ..montantMax = i.montantMax
      ..retardSeulement = i.retardSeulement
      ..tri = i.tri;
    _min = TextEditingController(
      text: i.montantMin == null ? '' : Fmt.montantSaisie(i.montantMin!),
    );
    _max = TextEditingController(
      text: i.montantMax == null ? '' : Fmt.montantSaisie(i.montantMax!),
    );
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final chequiers = app.chequiers
        .where((c) => f.banqueId == null || c.banqueId == f.banqueId)
        .toList();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Filtres'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: f.banqueId,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('Banque')),
              items: [
                DropdownMenuItem(value: null, child: Text(tr('Toutes'))),
                ...app.banques.map(
                  (b) => DropdownMenuItem(value: b.id, child: Text(b.libelle)),
                ),
              ],
              onChanged: (v) => setState(() {
                f.banqueId = v;
                f.chequierId = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: ValueKey('fch-${f.banqueId}-${f.chequierId}'),
              initialValue: chequiers.any((c) => c.id == f.chequierId)
                  ? f.chequierId
                  : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('Chéquier')),
              items: [
                DropdownMenuItem(value: null, child: Text(tr('Tous'))),
                ...chequiers.map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      tr('N° {0} · {1}', [c.numero, app.nomBanque(c.banqueId)]),
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => f.chequierId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: app.villesConnues.contains(f.ville)
                  ? f.ville
                  : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('Ville')),
              items: [
                DropdownMenuItem(value: null, child: Text(tr('Toutes'))),
                ...app.villesConnues.map(
                  (v) => DropdownMenuItem(value: v, child: Text(v)),
                ),
              ],
              onChanged: (v) => setState(() => f.ville = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(f.du == null ? tr('Du...') : Fmt.date(f.du)),
                    onPressed: () async {
                      final d = await choisirDate(
                        context,
                        f.du ?? DateTime.now(),
                      );
                      if (d != null) setState(() => f.du = d);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(f.au == null ? tr('Au...') : Fmt.date(f.au)),
                    onPressed: () async {
                      final d = await choisirDate(
                        context,
                        f.au ?? DateTime.now(),
                      );
                      if (d != null) setState(() => f.au = d);
                    },
                  ),
                ),
                if (f.du != null || f.au != null)
                  IconButton(
                    onPressed: () => setState(() {
                      f.du = null;
                      f.au = null;
                    }),
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                tr(
                  'Période appliquée aux dates d\'édition et de présentation.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _min,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: tr('Montant min.'),
                      suffixText: 'MAD',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _max,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: tr('Montant max.'),
                      suffixText: 'MAD',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Uniquement les chèques en retard')),
              value: f.retardSeulement,
              onChanged: (v) => setState(() => f.retardSeulement = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                f.montantMin = Fmt.parseMontant(_min.text);
                f.montantMax = Fmt.parseMontant(_max.text);
                Navigator.pop(context, f);
              },
              child: Text(tr('Appliquer')),
            ),
          ],
        ),
      ),
    );
  }
}
