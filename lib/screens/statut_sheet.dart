import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../data/repository.dart';
import '../models/models.dart';
import '../services/validation.dart';
import '../state/app_state.dart';
import '../widgets/communs.dart';
import '../widgets/pieces.dart';

const motifsRejet = [
  'Provision insuffisante',
  'Signature non conforme',
  'Chèque mal rempli',
  'Compte clôturé',
  'Opposition',
  'Date de validité dépassée',
  'Autre',
];

/// Changement de statut avec commentaire, justificatif et confirmation (§4).
Future<bool> changerStatut(
  BuildContext context,
  Cheque c,
  Statut nouveau,
) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _StatutSheet(cheque: c, nouveau: nouveau),
  );
  return r ?? false;
}

class _StatutSheet extends StatefulWidget {
  const _StatutSheet({required this.cheque, required this.nouveau});
  final Cheque cheque;
  final Statut nouveau;
  @override
  State<_StatutSheet> createState() => _StatutSheetState();
}

class _StatutSheetState extends State<_StatutSheet> {
  final _commentaire = TextEditingController();
  final _motifAutre = TextEditingController();
  final _frais = TextEditingController();
  String? _motif;
  DateTime? _nouvelleDate;
  FichierChoisi? _justif;
  bool _enCours = false;

  bool get _impaye => widget.nouveau == Statut.impaye;
  bool get _represente =>
      widget.cheque.statut == Statut.impaye &&
      widget.nouveau == Statut.presente;

  @override
  void initState() {
    super.initState();
    if (_represente) {
      final today = Fmt.jour(DateTime.now());
      _nouvelleDate = widget.cheque.datePresentation.isBefore(today)
          ? today
          : widget.cheque.datePresentation;
    }
  }

  @override
  void dispose() {
    _commentaire.dispose();
    _motifAutre.dispose();
    _frais.dispose();
    super.dispose();
  }

  String get _motifFinal =>
      _motif == 'Autre' ? _motifAutre.text.trim() : (_motif ?? '');

  String get _messageConfirmation => switch (widget.nouveau) {
    Statut.paye =>
      'Confirmez-vous que le débit de ce chèque a bien été constaté sur le compte bancaire ?\n\n'
          'Un chèque présenté n\'est considéré comme payé qu\'après cette confirmation explicite.',
    Statut.detruit =>
      'La destruction est définitive. Le chèque restera conservé dans l\'historique '
          'mais ne pourra plus changer de statut.\n\nConfirmez-vous la destruction ?',
    Statut.recupere =>
      'Confirmez-vous avoir récupéré physiquement ce chèque auprès du bénéficiaire ?',
    _ => 'Passer le chèque au statut « ${widget.nouveau.libelle} » ?',
  };

  Future<void> _valider() async {
    final c = widget.cheque;
    final frais = _frais.text.trim().isEmpty
        ? 0
        : Fmt.parseMontant(_frais.text);
    if (frais == null || frais < 0) {
      notifier(context, 'Frais invalides', erreur: true);
      return;
    }
    final ctrl = Regles.changementStatut(
      c,
      widget.nouveau,
      nouvelleDatePresentation: _nouvelleDate,
      motifRejet: _impaye ? _motifFinal : '',
    );
    if (!ctrl.ok) {
      notifier(context, ctrl.erreurs.first, erreur: true);
      return;
    }
    final ok = await confirmer(
      context,
      titre: '${c.statut.libelle} → ${widget.nouveau.libelle}',
      message: _messageConfirmation,
      ok: widget.nouveau == Statut.detruit ? 'Détruire' : 'Confirmer',
      danger: widget.nouveau == Statut.detruit,
    );
    if (!ok || !mounted) return;
    setState(() => _enCours = true);
    final app = context.read<AppState>();
    try {
      await app.ecrire(
        (r) => r.changerStatut(
          c,
          widget.nouveau,
          commentaire: _commentaire.text,
          justificatifSource: _justif?.chemin,
          justificatifNom: _justif?.nom,
          motifRejet: _impaye ? _motifFinal : '',
          fraisRejet: _impaye ? frais : 0,
          nouvelleDatePresentation: _nouvelleDate,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on RegleException catch (e) {
      if (mounted) notifier(context, e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.nouveau;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(n.icone, color: n.couleur),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Passer en « ${n.libelle} »',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Chèque n° ${context.read<AppState>().numero(widget.cheque)} · ${Fmt.mad(widget.cheque.montant)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_impaye) ...[
              DropdownButtonFormField<String>(
                initialValue: _motif,
                decoration: const InputDecoration(
                  labelText: 'Motif du rejet *',
                ),
                items: motifsRejet
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _motif = v),
              ),
              if (_motif == 'Autre') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _motifAutre,
                  decoration: const InputDecoration(
                    labelText: 'Préciser le motif *',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _frais,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Frais de rejet',
                  suffixText: 'MAD',
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_impaye || _represente) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.event_repeat),
                label: Text(
                  _nouvelleDate == null
                      ? 'Nouvelle date de présentation${_represente ? ' *' : ' (facultatif)'}'
                      : 'Nouvelle présentation : ${Fmt.date(_nouvelleDate)}',
                ),
                onPressed: () async {
                  final d = await choisirDate(
                    context,
                    _nouvelleDate ?? DateTime.now(),
                  );
                  if (d != null) setState(() => _nouvelleDate = d);
                },
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _commentaire,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Commentaire',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: Icon(
                _justif == null ? Icons.attach_file : Icons.check_circle,
                color: _justif == null ? null : Colors.green,
              ),
              label: Text(
                _justif == null
                    ? 'Joindre un justificatif (facultatif)'
                    : _justif!.nom,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () async {
                final f = await choisirPiece(context, titre: 'Justificatif');
                if (f != null) setState(() => _justif = f);
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: n == Statut.detruit || n == Statut.impaye
                  ? FilledButton.styleFrom(backgroundColor: n.couleur)
                  : null,
              onPressed: _enCours ? null : _valider,
              child: Text('Valider : ${n.libelle}'),
            ),
          ],
        ),
      ),
    );
  }
}
