import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../data/repository.dart';
import '../models/filtre.dart';
import '../models/models.dart';
import '../services/validation.dart';
import '../state/app_state.dart';
import '../widgets/communs.dart';
import 'cheque_detail_screen.dart';

/// Module banques, comptes et chéquiers (§2).
class BanquesScreen extends StatelessWidget {
  const BanquesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Banques et chéquiers')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'banque',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BanqueFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Compte bancaire'),
      ),
      body: app.banques.isEmpty
          ? Vide(
              icone: Icons.account_balance,
              texte:
                  'Aucune banque enregistrée.\nCommencez par ajouter votre compte bancaire, puis vos chéquiers.',
              action: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BanqueFormScreen()),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une banque'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
              children: [
                for (final b in app.banques) ...[
                  _CarteBanque(banque: b),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _CarteBanque extends StatelessWidget {
  const _CarteBanque({required this.banque});
  final Banque banque;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final chequiers = app.chequiers
        .where((c) => c.banqueId == banque.id)
        .toList();
    final cheques = app.chequesDe(banqueId: banque.id);
    final total = cheques.fold<int>(0, (s, c) => s + c.montant);
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: !banque.archive,
        shape: const Border(),
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            Icons.account_balance,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          banque.nom + (banque.archive ? ' (archivé)' : ''),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${[banque.referenceCompte, banque.agence, banque.ville].where((e) => e.isNotEmpty).join(' · ')}\n${cheques.length} chèque(s) · ${Fmt.mad(total)}',
          style: t.bodySmall,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (banque.titulaire.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Titulaire : ${banque.titulaire}',
                style: t.bodySmall,
              ),
            ),
          const SizedBox(height: 6),
          for (final c in chequiers) _LigneChequier(chequier: c),
          if (chequiers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Aucun chéquier.', style: t.bodySmall),
            ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChequierFormScreen(banqueId: banque.id),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Chéquier'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BanqueFormScreen(banque: banque),
                  ),
                ),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Modifier'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LigneChequier extends StatelessWidget {
  const _LigneChequier({required this.chequier});
  final Chequier chequier;

  @override
  Widget build(BuildContext context) {
    final c = chequier;
    final ratio = c.total == 0 ? 0.0 : c.utilises / c.total;
    final couleur = switch (c.statut) {
      StatutChequier.actif => Colors.green,
      StatutChequier.termine => Colors.blueGrey,
      StatutChequier.archive => Colors.grey,
    };
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChequierDetailScreen(chequierId: c.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.book, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Chéquier n° ${c.numero}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    c.statut.libelle,
                    style: TextStyle(
                      color: couleur,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${c.plage} · ouvert le ${Fmt.date(c.dateOuverture)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  color: couleur,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${c.utilises} utilisé(s) · ${c.disponibles} disponible(s) / ${c.total}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Banque
class BanqueFormScreen extends StatefulWidget {
  const BanqueFormScreen({super.key, this.banque});
  final Banque? banque;
  @override
  State<BanqueFormScreen> createState() => _BanqueFormScreenState();
}

class _BanqueFormScreenState extends State<BanqueFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.banque?.nom);
  late final _agence = TextEditingController(text: widget.banque?.agence);
  late final _ville = TextEditingController(text: widget.banque?.ville);
  late final _titulaire = TextEditingController(text: widget.banque?.titulaire);
  late final _ref = TextEditingController(text: widget.banque?.referenceCompte);
  late final _infos = TextEditingController(text: widget.banque?.infos);
  late bool _archive = widget.banque?.archive ?? false;

  @override
  void dispose() {
    for (final c in [_nom, _agence, _ville, _titulaire, _ref, _infos]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_form.currentState!.validate()) return;
    final app = context.read<AppState>();
    final now = DateTime.now();
    final b =
        (widget.banque == null
            ? null
            : Banque.fromMap(widget.banque!.toMap())) ??
        Banque(
          id: app.repo.nouvelId(),
          nom: '',
          createdAt: now,
          updatedAt: now,
        );
    b
      ..nom = _nom.text.trim()
      ..agence = _agence.text.trim()
      ..ville = _ville.text.trim()
      ..titulaire = _titulaire.text.trim()
      ..referenceCompte = _ref.text.trim()
      ..infos = _infos.text.trim()
      ..archive = _archive;
    final doublon = app.banques.any(
      (x) =>
          x.id != b.id &&
          x.nom.toLowerCase() == b.nom.toLowerCase() &&
          x.referenceCompte.toLowerCase() == b.referenceCompte.toLowerCase(),
    );
    if (doublon) {
      notifier(
        context,
        'Ce compte existe déjà (même banque et même référence).',
        erreur: true,
      );
      return;
    }
    try {
      await app.ecrire(
        (r) => r.enregistrerBanque(b, nouveau: widget.banque == null),
      );
      if (!mounted) return;
      notifier(context, 'Compte enregistré');
      Navigator.pop(context);
    } on RegleException catch (e) {
      notifier(context, e.message, erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration d(String l, IconData i) =>
        InputDecoration(labelText: l, prefixIcon: Icon(i));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.banque == null
              ? 'Nouveau compte bancaire'
              : 'Modifier le compte',
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nom,
              textCapitalization: TextCapitalization.words,
              decoration: d('Nom de la banque *', Icons.account_balance),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _agence,
              textCapitalization: TextCapitalization.words,
              decoration: d('Agence', Icons.store),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ville,
              textCapitalization: TextCapitalization.words,
              decoration: d('Ville', Icons.location_city),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titulaire,
              textCapitalization: TextCapitalization.words,
              decoration: d('Titulaire du compte', Icons.person),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ref,
              decoration: d('Référence / désignation du compte', Icons.numbers),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _infos,
              maxLines: 3,
              decoration: d('Informations complémentaires', Icons.notes),
            ),
            if (widget.banque != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Compte archivé'),
                subtitle: const Text(
                  'Masqué lors de la saisie de nouveaux chèques',
                ),
                value: _archive,
                onChanged: (v) => setState(() => _archive = v),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _enregistrer,
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Chéquier
class ChequierFormScreen extends StatefulWidget {
  const ChequierFormScreen({super.key, required this.banqueId, this.chequier});
  final String banqueId;
  final Chequier? chequier;
  @override
  State<ChequierFormScreen> createState() => _ChequierFormScreenState();
}

class _ChequierFormScreenState extends State<ChequierFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _numero = TextEditingController(text: widget.chequier?.numero);
  late final _premier = TextEditingController(
    text: widget.chequier == null
        ? ''
        : widget.chequier!.formatNumero(widget.chequier!.premier),
  );
  late final _dernier = TextEditingController(
    text: widget.chequier == null
        ? ''
        : widget.chequier!.formatNumero(widget.chequier!.dernier),
  );
  late DateTime _date =
      widget.chequier?.dateOuverture ?? Fmt.jour(DateTime.now());
  late StatutChequier _statut = widget.chequier?.statut ?? StatutChequier.actif;

  @override
  void initState() {
    super.initState();
    _premier.addListener(() => setState(() {}));
    _dernier.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_numero, _premier, _dernier]) {
      c.dispose();
    }
    super.dispose();
  }

  int? get _nbCheques {
    final a = int.tryParse(_premier.text.trim());
    final b = int.tryParse(_dernier.text.trim());
    if (a == null || b == null || b < a) return null;
    return b - a + 1;
  }

  Future<void> _enregistrer() async {
    if (!_form.currentState!.validate()) return;
    final app = context.read<AppState>();
    final now = DateTime.now();
    final premierTxt = _premier.text.trim();
    final c =
        (widget.chequier == null
            ? null
            : Chequier.fromMap(widget.chequier!.toMap())) ??
        Chequier(
          id: app.repo.nouvelId(),
          banqueId: widget.banqueId,
          numero: '',
          premier: 0,
          dernier: 0,
          largeur: 7,
          dateOuverture: _date,
          createdAt: now,
          updatedAt: now,
        );
    c
      ..numero = _numero.text.trim()
      ..premier = int.parse(premierTxt)
      ..dernier = int.parse(_dernier.text.trim())
      ..largeur = premierTxt.length > _dernier.text.trim().length
          ? premierTxt.length
          : _dernier.text.trim().length
      ..dateOuverture = _date
      ..statut = _statut;
    final emis = widget.chequier == null
        ? <int>[]
        : await app.repo.numerosEmis(c.id);
    final ctrl = Regles.chequier(
      c,
      existants: app.chequiers,
      numerosEmis: emis,
    );
    if (!mounted) return;
    if (!ctrl.ok) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Chéquier invalide'),
          content: Text(ctrl.erreurs.map((e) => '• $e').join('\n')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Corriger'),
            ),
          ],
        ),
      );
      return;
    }
    await app.ecrire(
      (r) => r.enregistrerChequier(c, nouveau: widget.chequier == null),
    );
    if (!mounted) return;
    notifier(context, 'Chéquier enregistré');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final nb = _nbCheques;
    String? chiffres(String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return 'Obligatoire';
      if (!RegExp(r'^\d+$').hasMatch(t)) return 'Chiffres uniquement';
      return null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.chequier == null ? 'Nouveau chéquier' : 'Modifier le chéquier',
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              app.nomBanque(widget.banqueId),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _numero,
              decoration: const InputDecoration(
                labelText: 'Numéro du chéquier *',
                prefixIcon: Icon(Icons.book),
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _premier,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Premier chèque *',
                    ),
                    validator: chiffres,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _dernier,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Dernier chèque *',
                    ),
                    validator: chiffres,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                nb == null
                    ? 'Saisissez la plage de numéros'
                    : 'Nombre total de chèques : $nb',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: nb == null
                      ? Theme.of(context).hintColor
                      : Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final d = await choisirDate(context, _date);
                if (d != null) setState(() => _date = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date d\'ouverture / enregistrement',
                  prefixIcon: Icon(Icons.event),
                ),
                child: Text(Fmt.date(_date)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<StatutChequier>(
              initialValue: _statut,
              decoration: const InputDecoration(
                labelText: 'Statut',
                prefixIcon: Icon(Icons.flag),
              ),
              items: StatutChequier.values
                  .map(
                    (s) => DropdownMenuItem(value: s, child: Text(s.libelle)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _statut = v ?? _statut),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _enregistrer,
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

class ChequierDetailScreen extends StatelessWidget {
  const ChequierDetailScreen({super.key, required this.chequierId});
  final String chequierId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = app.chequier(chequierId);
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Vide(icone: Icons.book, texte: 'Chéquier introuvable'),
      );
    }
    final cheques = FiltreCheques()..tri = Tri.numero;
    final liste = cheques.appliquer(
      app.chequesDe(chequierId: c.id),
      numero: app.numero,
      banque: (x) => app.nomBanque(x.banqueId),
      chequier: (_) => c.numero,
    );
    final emis = {for (final x in liste) x.numero};
    final libres = [
      for (var n = c.premier; n <= c.dernier; n++)
        if (!emis.contains(n)) n,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('Chéquier n° ${c.numero}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ChequierFormScreen(banqueId: c.banqueId, chequier: c),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.nomBanque(c.banqueId),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('Plage ${c.plage} · ${c.statut.libelle}'),
                  Text(
                    '${c.total} chèques · ${c.utilises} utilisé(s) · ${c.disponibles} disponible(s)',
                  ),
                  Text(
                    'Montant émis : ${Fmt.mad(liste.fold(0, (s, x) => s + x.montant))}',
                  ),
                ],
              ),
            ),
          ),
          if (libres.isNotEmpty) ...[
            const Section('Numéros disponibles'),
            Text(
              libres.length > 40
                  ? '${libres.take(40).map(c.formatNumero).join(', ')}... (+${libres.length - 40})'
                  : libres.map(c.formatNumero).join(', '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          Section('Chèques émis (${liste.length})'),
          Card(
            child: Column(
              children: [
                for (final x in liste)
                  ChequeTile(
                    x,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChequeDetailScreen(chequeId: x.id),
                      ),
                    ),
                  ),
                if (liste.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucun chèque émis.'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
