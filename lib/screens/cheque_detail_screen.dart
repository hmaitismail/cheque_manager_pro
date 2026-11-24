import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../data/repository.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/communs.dart';
import '../widgets/pieces.dart';
import 'cheque_form_screen.dart';
import 'statut_sheet.dart';

/// Fiche détaillée : informations, actions de statut, pièces jointes,
/// historique des statuts et journal des modifications (§7).
class ChequeDetailScreen extends StatefulWidget {
  const ChequeDetailScreen({super.key, required this.chequeId});
  final String chequeId;
  @override
  State<ChequeDetailScreen> createState() => _ChequeDetailScreenState();
}

class _ChequeDetailScreenState extends State<ChequeDetailScreen> {
  Cheque? _c;
  List<ChangementStatut> _hist = [];
  List<PieceJointe> _pieces = [];
  List<PieceJointe> _piecesRetirees = [];
  List<EntreeJournal> _journal = [];
  final Map<String, String> _chemins = {};
  bool _charge = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final repo = context.read<AppState>().repo;
    final c = await repo.cheque(widget.chequeId);
    if (c == null) {
      if (mounted) setState(() => _charge = true);
      return;
    }
    final hist = await repo.historique(c.id);
    final toutes = await repo.piecesJointes(c.id, avecSupprimees: true);
    final journal = await repo.journal(entiteId: c.id, limit: 100);
    for (final p in toutes) {
      _chemins[p.id] = await repo.cheminPiece(p);
    }
    if (!mounted) return;
    setState(() {
      _c = c;
      _hist = hist;
      _pieces = toutes.where((p) => p.deletedAt == null).toList();
      _piecesRetirees = toutes.where((p) => p.deletedAt != null).toList();
      _journal = journal;
      _charge = true;
    });
  }

  Future<void> _statut(Statut s) async {
    if (await changerStatut(context, _c!, s)) {
      await _charger();
      if (mounted) notifier(context, 'Statut mis à jour : ${s.libelle}');
    }
  }

  Future<void> _corbeille() async {
    final motif = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mettre à la corbeille ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Le chèque pourra être restauré depuis la corbeille. L\'opération est tracée.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motif,
              decoration: const InputDecoration(
                labelText: 'Motif (ex. erreur de saisie)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    final texte = motif.text.trim();
    motif.dispose();
    if (ok != true || !mounted) return;
    try {
      await context.read<AppState>().ecrire(
        (r) => r.mettreALaCorbeille(_c!, texte.isEmpty ? 'non précisé' : texte),
      );
      if (mounted) {
        notifier(context, 'Chèque placé dans la corbeille');
        Navigator.pop(context);
      }
    } on RegleException catch (e) {
      if (mounted) notifier(context, e.message, erreur: true);
    }
  }

  Future<void> _ajouterPiece({PieceJointe? remplace}) async {
    final f = await choisirPiece(
      context,
      titre: remplace == null
          ? 'Ajouter une pièce jointe'
          : 'Remplacer la pièce',
    );
    if (f == null || !mounted) return;
    await context.read<AppState>().repo.ajouterPiece(
      _c!.id,
      f.chemin,
      nom: f.nom,
      remplace: remplace,
    );
    await _charger();
  }

  Future<void> _ouvrir(PieceJointe p) async {
    final chemin = _chemins[p.id];
    if (chemin == null) return;
    if (p.estPhoto) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _Visionneuse(chemin: chemin, titre: p.nom),
        ),
      );
    } else {
      await OpenFilex.open(chemin);
    }
  }

  Future<void> _menuPiece(PieceJointe p) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Ouvrir'),
              onTap: () => Navigator.pop(ctx, 'o'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Remplacer'),
              onTap: () => Navigator.pop(ctx, 'r'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Retirer'),
              onTap: () => Navigator.pop(ctx, 's'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'o':
        await _ouvrir(p);
      case 'r':
        await _ajouterPiece(remplace: p);
      case 's':
        if (await confirmer(
          context,
          titre: 'Retirer la pièce jointe ?',
          message: 'Le fichier reste archivé pour la traçabilité.',
          ok: 'Retirer',
          danger: true,
        )) {
          if (!mounted) return;
          await context.read<AppState>().repo.supprimerPiece(p);
          await _charger();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!_charge) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final c = _c;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Vide(icone: Icons.search_off, texte: 'Chèque introuvable.'),
      );
    }
    final t = Theme.of(context).textTheme;
    final banque = app.banque(c.banqueId);
    final ch = app.chequier(c.chequierId);
    final retard = c.estEnRetard(DateTime.now());

    Widget info(String l, String v, {IconData? i}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              l,
              style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor),
            ),
          ),
          Expanded(
            child: Text(
              v.isEmpty ? '-' : v,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Chèque n° ${app.numero(c)}'),
        actions: [
          if (c.deletedAt == null)
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final r = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChequeFormScreen(cheque: c),
                  ),
                );
                if (r == true) await _charger();
              },
            ),
          if (c.deletedAt == null && !c.statut.suppressionInterdite)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: _corbeille,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatutChip(c.statut),
                        if (retard) ...[
                          const SizedBox(width: 6),
                          const Chip(
                            label: Text(
                              'En retard',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: Colors.red,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                        const Spacer(),
                        if (c.deletedAt != null)
                          const Text(
                            'Dans la corbeille',
                            style: TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Fmt.mad(c.montant),
                        style: t.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'À l\'ordre de ${c.beneficiaire}',
                      style: t.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            if (c.statut.suivantsPossibles.isNotEmpty &&
                c.deletedAt == null) ...[
              const Section('Changer le statut'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in c.statut.suivantsPossibles)
                    ActionChip(
                      avatar: Icon(s.icone, color: s.couleur, size: 18),
                      label: Text(
                        c.statut == Statut.impaye && s == Statut.presente
                            ? 'Représenter'
                            : s.libelle,
                      ),
                      onPressed: () => _statut(s),
                    ),
                ],
              ),
            ],
            const Section('Informations'),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    info('Banque', banque?.nom ?? '?'),
                    info('Compte', banque?.referenceCompte ?? ''),
                    info(
                      'Agence',
                      [
                        banque?.agence ?? '',
                        banque?.ville ?? '',
                      ].where((e) => e.isNotEmpty).join(' - '),
                    ),
                    info(
                      'Chéquier',
                      ch == null ? '?' : 'N° ${ch.numero} (${ch.plage})',
                    ),
                    info('Date d\'édition', Fmt.date(c.dateEdition)),
                    info('Présentation prévue', Fmt.date(c.datePresentation)),
                    info('Ville', c.ville),
                    info('Objet', c.objet),
                    info('Observations', c.observations),
                    info('Rappels', c.rappelsActifs ? 'Activés' : 'Désactivés'),
                    if (c.statut == Statut.impaye ||
                        c.motifRejet.isNotEmpty) ...[
                      info('Motif du rejet', c.motifRejet),
                      info('Frais de rejet', Fmt.mad(c.fraisRejet)),
                    ],
                    info('Créé le', Fmt.dateHeure(c.createdAt)),
                    info('Modifié le', Fmt.dateHeure(c.updatedAt)),
                  ],
                ),
              ),
            ),
            Section(
              'Pièces jointes (${_pieces.length})',
              action: c.deletedAt == null
                  ? TextButton.icon(
                      onPressed: _ajouterPiece,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter'),
                    )
                  : null,
            ),
            if (_pieces.isEmpty)
              Text('Aucune pièce jointe.', style: t.bodySmall)
            else
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pieces.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (ctx, i) {
                    final p = _pieces[i];
                    final chemin = _chemins[p.id];
                    return GestureDetector(
                      onTap: () => _ouvrir(p),
                      onLongPress: () => _menuPiece(p),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: p.estPhoto && chemin != null
                                ? Image.file(
                                    File(chemin),
                                    width: 110,
                                    height: 90,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const SizedBox(
                                      width: 110,
                                      height: 90,
                                      child: Icon(Icons.broken_image),
                                    ),
                                  )
                                : Container(
                                    width: 110,
                                    height: 90,
                                    color: Colors.red.withValues(alpha: 0.08),
                                    child: const Icon(
                                      Icons.picture_as_pdf,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 110,
                            child: Text(
                              p.nom,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (_pieces.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Appui long sur une pièce pour la remplacer ou la retirer.',
                  style: t.bodySmall,
                ),
              ),
            if (_piecesRetirees.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${_piecesRetirees.length} pièce(s) retirée(s) ou remplacée(s), conservée(s) dans les archives.',
                  style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            const Section('Historique des statuts'),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _hist.length; i++)
                    _LigneHistorique(
                      h: _hist[i],
                      dernier: i == _hist.length - 1,
                      pieces: [..._pieces, ..._piecesRetirees],
                      ouvrir: _ouvrir,
                    ),
                ],
              ),
            ),
            if (_journal.isNotEmpty) ...[
              const Section('Journal des modifications'),
              Card(
                child: Column(
                  children: [
                    for (final j in _journal)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.edit_note, size: 20),
                        title: Text(j.resume),
                        subtitle: Text(Fmt.dateHeure(j.date)),
                        onTap: j.details.isEmpty || j.action != 'modification'
                            ? null
                            : () => _voirDetails(j),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _voirDetails(EntreeJournal j) {
    String v(dynamic x) {
      if (x == null) return '-';
      return x.toString();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Détail de la modification'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in j.details.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Repository.libellesChamps[e.key] ?? e.key,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        e.key == 'montant'
                            ? '${Fmt.mad((e.value['avant'] as num).toInt())} → ${Fmt.mad((e.value['apres'] as num).toInt())}'
                            : '${v(e.value['avant'])} → ${v(e.value['apres'])}',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

class _LigneHistorique extends StatelessWidget {
  const _LigneHistorique({
    required this.h,
    required this.dernier,
    required this.pieces,
    required this.ouvrir,
  });
  final ChangementStatut h;
  final bool dernier;
  final List<PieceJointe> pieces;
  final void Function(PieceJointe) ouvrir;

  @override
  Widget build(BuildContext context) {
    final trouvees = pieces.where((p) => p.id == h.justificatifId).toList();
    final justif = trouvees.isEmpty ? null : trouvees.first;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Icon(h.nouveau.icone, color: h.nouveau.couleur, size: 20),
                if (!dernier)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.ancien == null
                        ? h.nouveau.libelle
                        : '${h.ancien!.libelle} → ${h.nouveau.libelle}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    Fmt.dateHeure(h.date),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (h.commentaire.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(h.commentaire),
                    ),
                  if (justif != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => ouvrir(justif),
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: Text(justif.nom),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Visionneuse extends StatelessWidget {
  const _Visionneuse({required this.chemin, required this.titre});
  final String chemin;
  final String titre;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      title: Text(titre, overflow: TextOverflow.ellipsis),
    ),
    body: InteractiveViewer(
      maxScale: 6,
      child: Center(child: Image.file(File(chemin))),
    ),
  );
}
