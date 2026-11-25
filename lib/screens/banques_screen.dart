import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../data/repository.dart';
import '../models/filtre.dart';
import '../models/models.dart';
import '../services/validation.dart';
import '../state/app_state.dart';
import '../widgets/communs.dart';
import 'licence_screen.dart';
import 'cheque_detail_screen.dart';
import '../l10n/i18n.dart';

/// Module banques, comptes et chéquiers (§2).
class BanquesScreen extends StatelessWidget {
  const BanquesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Banques et chéquiers'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'banque',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BanqueFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text(tr('Compte bancaire')),
      ),
      body: app.banques.isEmpty
          ? Vide(
              icone: Icons.account_balance,
              texte: tr(
                'Aucune banque enregistrée.\nCommencez par ajouter votre compte bancaire, puis vos chéquiers.',
              ),
              action: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BanqueFormScreen()),
                ),
                icon: const Icon(Icons.add),
                label: Text(tr('Ajouter une banque')),
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
          banque.nom + (banque.archive ? tr(' (archivé)') : ''),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          tr('{0}\n{1} chèque(s) · {2}', [
            [
              banque.referenceCompte,
              banque.agence,
              banque.ville,
            ].where((e) => e.isNotEmpty).join(' · '),
            cheques.length,
            Fmt.mad(total),
          ]),
          style: t.bodySmall,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (banque.titulaire.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr('Titulaire : {0}', [banque.titulaire]),
                style: t.bodySmall,
              ),
            ),
          const SizedBox(height: 6),
          for (final c in chequiers) _LigneChequier(chequier: c),
          if (chequiers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(tr('Aucun chéquier.'), style: t.bodySmall),
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
                label: Text(tr('Chéquier')),
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
                label: Text(tr('Modifier')),
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
                      tr('Chéquier n° {0}', [c.numero]),
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
                tr('{0} · ouvert le {1}', [c.plage, Fmt.date(c.dateOuverture)]),
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
                tr('{0} utilisé(s) · {1} disponible(s) / {2}', [
                  c.utilises,
                  c.disponibles,
                  c.total,
                ]),
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
    if (!await exigerLicence(context)) return;
    if (!mounted) return;
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
        tr('Ce compte existe déjà (même banque et même référence).'),
        erreur: true,
      );
      return;
    }
    try {
      await app.ecrire(
        (r) => r.enregistrerBanque(b, nouveau: widget.banque == null),
      );
      if (!mounted) return;
      notifier(context, tr('Compte enregistré'));
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
              ? tr('Nouveau compte bancaire')
              : tr('Modifier le compte'),
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
              decoration: d(tr('Nom de la banque *'), Icons.account_balance),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? tr('Obligatoire') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _agence,
              textCapitalization: TextCapitalization.words,
              decoration: d(tr('Agence'), Icons.store),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ville,
              textCapitalization: TextCapitalization.words,
              decoration: d(tr('Ville'), Icons.location_city),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titulaire,
              textCapitalization: TextCapitalization.words,
              decoration: d(tr('Titulaire du compte'), Icons.person),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ref,
              decoration: d(
                tr('Référence / désignation du compte'),
                Icons.numbers,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _infos,
              maxLines: 3,
              decoration: d(tr('Informations complémentaires'), Icons.notes),
            ),
            if (widget.banque != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Compte archivé')),
                subtitle: Text(
                  tr('Masqué lors de la saisie de nouveaux chèques'),
                ),
                value: _archive,
                onChanged: (v) => setState(() => _archive = v),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _enregistrer,
              child: Text(tr('Enregistrer')),
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
    if (!await exigerLicence(context)) return;
    if (!mounted) return;
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
          title: Text(tr('Chéquier invalide')),
          content: Text(ctrl.erreurs.map((e) => '• $e').join('\n')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('Corriger')),
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
    notifier(context, tr('Chéquier enregistré'));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final nb = _nbCheques;
    String? chiffres(String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return tr('Obligatoire');
      if (!RegExp(r'^\d+$').hasMatch(t)) return tr('Chiffres uniquement');
      return null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.chequier == null
              ? tr('Nouveau chéquier')
              : tr('Modifier le chéquier'),
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
              decoration: InputDecoration(
                labelText: tr('Numéro du chéquier *'),
                prefixIcon: const Icon(Icons.book),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? tr('Obligatoire') : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _premier,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr('Premier chèque *'),
                    ),
                    validator: chiffres,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _dernier,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr('Dernier chèque *'),
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
                    ? tr('Saisissez la plage de numéros')
                    : tr('Nombre total de chèques : {0}', [nb]),
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
                decoration: InputDecoration(
                  labelText: tr('Date d\'ouverture / enregistrement'),
                  prefixIcon: const Icon(Icons.event),
                ),
                child: Text(Fmt.date(_date)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<StatutChequier>(
              initialValue: _statut,
              decoration: InputDecoration(
                labelText: tr('Statut'),
                prefixIcon: const Icon(Icons.flag),
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
              child: Text(tr('Enregistrer')),
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
        body: Vide(icone: Icons.book, texte: tr('Chéquier introuvable')),
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
        title: Text(tr('Chéquier n° {0}', [c.numero])),
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
                  Text(tr('Plage {0} · {1}', [c.plage, c.statut.libelle])),
                  Text(
                    tr('{0} chèques · {1} utilisé(s) · {2} disponible(s)', [
                      c.total,
                      c.utilises,
                      c.disponibles,
                    ]),
                  ),
                  Text(
                    tr('Montant émis : {0}', [
                      Fmt.mad(liste.fold(0, (s, x) => s + x.montant)),
                    ]),
                  ),
                ],
              ),
            ),
          ),
          if (libres.isNotEmpty) ...[
            Section(tr('Numéros disponibles')),
            Text(
              libres.length > 40
                  ? '${libres.take(40).map(c.formatNumero).join(', ')}... (+${libres.length - 40})'
                  : libres.map(c.formatNumero).join(', '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          Section(tr('Chèques émis ({0})', [liste.length])),
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
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(tr('Aucun chèque émis.')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
