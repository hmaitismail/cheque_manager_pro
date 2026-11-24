import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../data/repository.dart';
import '../models/models.dart';
import '../services/validation.dart';
import '../state/app_state.dart';
import '../widgets/champ_suggestions.dart';
import '../widgets/communs.dart';
import '../widgets/pieces.dart';

/// Création / modification d'un chèque, avec tous les contrôles (§3 et §12).
class ChequeFormScreen extends StatefulWidget {
  const ChequeFormScreen({super.key, this.cheque});
  final Cheque? cheque;
  @override
  State<ChequeFormScreen> createState() => _ChequeFormScreenState();
}

class _ChequeFormScreenState extends State<ChequeFormScreen> {
  final _form = GlobalKey<FormState>();
  final _numero = TextEditingController();
  final _montant = TextEditingController();
  final _beneficiaire = TextEditingController();
  final _ville = TextEditingController();
  final _objet = TextEditingController();
  final _observations = TextEditingController();
  String? _banqueId;
  String? _chequierId;
  DateTime _edition = Fmt.jour(DateTime.now());
  DateTime _presentation = Fmt.jour(DateTime.now());
  bool _rappels = true;
  final List<FichierChoisi> _pieces = [];
  bool _enCours = false;

  bool get _nouveau => widget.cheque == null;
  bool get _verrouille => widget.cheque?.statut.estCloture ?? false;

  @override
  void initState() {
    super.initState();
    final c = widget.cheque;
    final app = context.read<AppState>();
    if (c != null) {
      _banqueId = c.banqueId;
      _chequierId = c.chequierId;
      _numero.text = app.numero(c);
      _montant.text = Fmt.montantSaisie(c.montant);
      _beneficiaire.text = c.beneficiaire;
      _ville.text = c.ville;
      _objet.text = c.objet;
      _observations.text = c.observations;
      _edition = c.dateEdition;
      _presentation = c.datePresentation;
      _rappels = c.rappelsActifs;
    } else {
      final actifs = app.chequiers
          .where((x) => x.statut == StatutChequier.actif)
          .toList();
      if (actifs.isNotEmpty) {
        _banqueId = actifs.first.banqueId;
        _choisirChequier(actifs.first.id);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _numero,
      _montant,
      _beneficiaire,
      _ville,
      _objet,
      _observations,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<Chequier> _chequiersDisponibles(AppState app) => app.chequiers
      .where(
        (c) =>
            c.banqueId == _banqueId &&
            (c.statut == StatutChequier.actif ||
                c.id == widget.cheque?.chequierId),
      )
      .toList();

  Future<void> _choisirChequier(String? id) async {
    setState(() => _chequierId = id);
    if (!_nouveau || id == null) return;
    final app = context.read<AppState>();
    final ch = app.chequier(id);
    if (ch == null) return;
    final n = await app.repo.prochainNumero(ch);
    if (!mounted) return;
    setState(() => _numero.text = n == null ? '' : ch.formatNumero(n));
  }

  Future<void> _enregistrer() async {
    if (!_form.currentState!.validate()) return;
    final app = context.read<AppState>();
    final ch = _chequierId == null ? null : app.chequier(_chequierId!);
    final numero = int.parse(_numero.text.trim());
    final montant = Fmt.parseMontant(_montant.text)!;
    final now = DateTime.now();
    final base = widget.cheque;
    final c =
        base?.copy() ??
        Cheque(
          id: app.repo.nouvelId(),
          banqueId: _banqueId!,
          chequierId: _chequierId!,
          numero: numero,
          montant: montant,
          dateEdition: _edition,
          datePresentation: _presentation,
          beneficiaire: '',
          createdAt: now,
          updatedAt: now,
        );
    c
      ..banqueId = _banqueId!
      ..chequierId = _chequierId!
      ..numero = numero
      ..montant = montant
      ..dateEdition = _edition
      ..datePresentation = _presentation
      ..beneficiaire = _beneficiaire.text.trim()
      ..ville = _ville.text.trim()
      ..objet = _objet.text.trim()
      ..observations = _observations.text.trim()
      ..rappelsActifs = _rappels;

    setState(() => _enCours = true);
    try {
      final memeCompte = await app.repo.chequesDuCompte(c.banqueId);
      final ctrl = Regles.cheque(
        c,
        chequier: ch,
        chequesMemeBanque: memeCompte,
      );
      if (!mounted) return;
      if (!ctrl.ok) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.block, color: Colors.red),
            title: const Text('Enregistrement impossible'),
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
      if (ctrl.avertissements.isNotEmpty) {
        final ok = await confirmer(
          context,
          titre: 'Vérification',
          message:
              '${ctrl.avertissements.map((e) => '• $e').join('\n')}\n\nEnregistrer quand même ?',
          ok: 'Enregistrer',
        );
        if (!ok) return;
      }
      await app.repo.enregistrerCheque(c, nouveau: _nouveau);
      for (final p in _pieces) {
        await app.repo.ajouterPiece(c.id, p.chemin, nom: p.nom);
      }
      await app.rafraichir();
      if (!mounted) return;
      notifier(
        context,
        _nouveau
            ? 'Chèque n° ${_numero.text} enregistré'
            : 'Modifications enregistrées',
      );
      Navigator.pop(context, true);
    } on RegleException catch (e) {
      if (mounted) notifier(context, e.message, erreur: true);
    } catch (e) {
      if (mounted) notifier(context, 'Erreur : $e', erreur: true);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final banques = app.banques
        .where((b) => !b.archive || b.id == widget.cheque?.banqueId)
        .toList();
    final chequiers = _chequiersDisponibles(app);
    final ch = _chequierId == null ? null : app.chequier(_chequierId!);

    Widget champDate(
      String label,
      DateTime d,
      ValueChanged<DateTime> onChange,
    ) => InkWell(
      onTap: () async {
        final r = await choisirDate(context, d);
        if (r != null) setState(() => onChange(r));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event),
        ),
        child: Text(Fmt.date(d)),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_nouveau ? 'Nouveau chèque' : 'Modifier le chèque'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            if (_verrouille)
              Card(
                color: Colors.amber.withValues(alpha: 0.15),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Chèque clôturé : le compte, le numéro et le montant ne sont plus modifiables.',
                  ),
                ),
              ),
            const Section('Compte et chéquier'),
            DropdownButtonFormField<String>(
              key: ValueKey('bq-$_banqueId'),
              initialValue: banques.any((b) => b.id == _banqueId)
                  ? _banqueId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Banque *',
                prefixIcon: Icon(Icons.account_balance),
              ),
              items: banques
                  .map(
                    (b) =>
                        DropdownMenuItem(value: b.id, child: Text(b.libelle)),
                  )
                  .toList(),
              onChanged: _verrouille
                  ? null
                  : (v) {
                      setState(() => _banqueId = v);
                      final premiers = _chequiersDisponibles(app);
                      _choisirChequier(
                        premiers.isEmpty ? null : premiers.first.id,
                      );
                    },
              validator: (v) => v == null ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('ch-$_banqueId-$_chequierId'),
              initialValue: chequiers.any((c) => c.id == _chequierId)
                  ? _chequierId
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Chéquier *',
                prefixIcon: const Icon(Icons.book),
                helperText: ch == null
                    ? null
                    : 'Plage ${ch.plage} · ${ch.disponibles} disponible(s)',
              ),
              items: chequiers
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text('N° ${c.numero}  (${c.plage})'),
                    ),
                  )
                  .toList(),
              onChanged: _verrouille ? null : _choisirChequier,
              validator: (v) =>
                  v == null ? 'Aucun chéquier actif pour cette banque' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _numero,
              enabled: !_verrouille,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Numéro du chèque *',
                prefixIcon: Icon(Icons.tag),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Obligatoire';
                if (!RegExp(r'^\d+$').hasMatch(t)) return 'Chiffres uniquement';
                final n = int.parse(t);
                if (ch != null && !ch.contient(n)) {
                  return 'Hors de la plage du chéquier (${ch.plage})';
                }
                return null;
              },
            ),
            const Section('Paiement'),
            TextFormField(
              controller: _montant,
              enabled: !_verrouille,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                labelText: 'Montant *',
                suffixText: 'MAD',
                prefixIcon: Icon(Icons.payments),
              ),
              validator: (v) {
                final m = Fmt.parseMontant(v ?? '');
                if (m == null) return 'Montant invalide (ex. 15000,50)';
                if (m <= 0) return 'Le montant doit être supérieur à zéro';
                return null;
              },
            ),
            const SizedBox(height: 12),
            ChampSuggestions(
              controller: _beneficiaire,
              suggestions: app.beneficiairesConnus,
              label: 'Bénéficiaire (à l\'ordre de) *',
              icone: Icons.person,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 12),
            ChampSuggestions(
              controller: _ville,
              suggestions: app.villesConnues,
              label: 'Ville de présentation / remise',
              icone: Icons.location_city,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _objet,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Objet / motif du paiement',
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const Section('Dates'),
            Row(
              children: [
                Expanded(
                  child: champDate(
                    'Date d\'édition *',
                    _edition,
                    (d) => _edition = d,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: champDate(
                    'Présentation prévue *',
                    _presentation,
                    (d) => _presentation = d,
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Rappels de présentation'),
              subtitle: const Text('La veille et le jour même'),
              value: _rappels,
              onChanged: (v) => setState(() => _rappels = v),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _observations,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observations',
                alignLabelWithHint: true,
              ),
            ),
            if (_nouveau) ...[
              Section(
                'Pièces jointes',
                action: TextButton.icon(
                  onPressed: () async {
                    final f = await choisirPiece(context);
                    if (f != null) setState(() => _pieces.add(f));
                  },
                  icon: const Icon(Icons.add_a_photo, size: 18),
                  label: const Text('Ajouter'),
                ),
              ),
              if (_pieces.isEmpty)
                Text(
                  'Photographiez le chèque ou joignez un PDF (facultatif).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in _pieces)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: p.estPdf
                              ? Container(
                                  width: 90,
                                  height: 90,
                                  color: Colors.red.withValues(alpha: 0.1),
                                  child: const Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                )
                              : Image.file(
                                  File(p.chemin),
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton.filled(
                            iconSize: 16,
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                            ),
                            onPressed: () => setState(() => _pieces.remove(p)),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _enCours ? null : _enregistrer,
            icon: _enCours
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(
              _nouveau
                  ? 'Enregistrer le chèque'
                  : 'Enregistrer les modifications',
            ),
          ),
        ),
      ),
    );
  }
}
