import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../services/licence.dart';
import '../state/app_state.dart';
import '../widgets/communs.dart';
import '../l10n/i18n.dart';

/// Vérifie que la licence permet la saisie. Sinon, propose l'activation.
Future<bool> exigerLicence(BuildContext context) async {
  final info = ServiceLicence.instance.info;
  if (info.utilisable) return true;
  final activer = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.lock_clock_rounded, size: 36),
      title: Text(tr('Licence requise')),
      content: Text(
        tr(
          'La période d\'essai est terminée. Vos données restent consultables et vous pouvez toujours les sauvegarder.\n\nActivez votre licence pour continuer à saisir et modifier vos chèques.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(tr('Plus tard')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(tr('Activer')),
        ),
      ],
    ),
  );
  if (activer == true && context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LicenceScreen()),
    );
  }
  return ServiceLicence.instance.info.utilisable;
}

/// Bandeau d'information sur l'essai ou l'expiration (accueil).
class BandeauLicence extends StatelessWidget {
  const BandeauLicence({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final info = ServiceLicence.instance.info;
    final String texte;
    final Color couleur;
    switch (info.etat) {
      case EtatLicence.essai:
        texte = tr('Essai gratuit : {0} jour(s) restant(s)', [
          info.joursRestants,
        ]);
        couleur = info.joursRestants <= 7
            ? Colors.orange.shade800
            : Theme.of(context).colorScheme.primary;
      case EtatLicence.expiree:
        texte = tr('Essai terminé : application en lecture seule');
        couleur = Colors.red.shade700;
      case EtatLicence.active:
        if (!info.bientotExpiree) return const SizedBox.shrink();
        texte = tr('Votre licence expire dans {0} jour(s)', [
          info.joursRestants,
        ]);
        couleur = Colors.orange.shade800;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: couleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LicenceScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: couleur, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    texte,
                    style: TextStyle(
                      color: couleur,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  tr('Activer'),
                  style: TextStyle(color: couleur, fontWeight: FontWeight.w800),
                ),
                Icon(Icons.chevron_right, color: couleur),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LicenceScreen extends StatefulWidget {
  const LicenceScreen({super.key});
  @override
  State<LicenceScreen> createState() => _LicenceScreenState();
}

class _LicenceScreenState extends State<LicenceScreen> {
  final _cle = TextEditingController();
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _cle.dispose();
    super.dispose();
  }

  Future<void> _activer() async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    final erreur = await ServiceLicence.instance.activer(_cle.text);
    if (!mounted) return;
    setState(() {
      _enCours = false;
      _erreur = erreur;
    });
    if (erreur == null) {
      context.read<AppState>().licenceChangee();
      await context.read<AppState>().repo.logSysteme(
        'licence',
        tr('Licence activée'),
      );
      if (mounted) notifier(context, tr('Licence activée. Merci !'));
    }
  }

  Future<void> _coller() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) setState(() => _cle.text = d!.text!.trim());
  }

  @override
  Widget build(BuildContext context) {
    final lic = ServiceLicence.instance;
    final info = lic.info;
    final t = Theme.of(context).textTheme;
    final (titre, detail, couleur, icone) = switch (info.etat) {
      EtatLicence.active => (
        info.formule?.libelle ?? tr('Licence active'),
        info.expiration == null
            ? tr('Valable sans limite de durée')
            : tr('Valable jusqu\'au {0}', [Fmt.date(info.expiration)]),
        AppColors.vert,
        Icons.verified_rounded,
      ),
      EtatLicence.essai => (
        tr('Essai gratuit'),
        tr('{0} jour(s) restant(s), jusqu\'au {1}', [
          info.joursRestants,
          Fmt.date(info.expiration),
        ]),
        AppColors.bleuNuitClair,
        Icons.hourglass_bottom_rounded,
      ),
      EtatLicence.expiree => (
        tr('Licence expirée'),
        tr(
          'Lecture seule : consultation, recherche et sauvegarde restent possibles',
        ),
        Colors.red.shade700,
        Icons.lock_clock_rounded,
      ),
    };

    return Scaffold(
      appBar: AppBar(title: Text(tr('Licence'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(icone, color: couleur, size: 40),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titre,
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: couleur,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(detail, style: t.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Section(tr('Code de cet appareil')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(
                    lic.codeAffiche,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'Communiquez ce code au vendeur pour recevoir votre clé d\'activation.',
                    ),
                    textAlign: TextAlign.center,
                    style: t.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: lic.codeAffiche),
                            );
                            if (context.mounted) {
                              notifier(context, tr('Code copié'));
                            }
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: Text(tr('Copier')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => SharePlus.instance.share(
                            ShareParams(
                              text: tr(
                                'Bonjour, je souhaite activer Cheque Manager Pro. Code de mon appareil : {0}',
                                [lic.codeAffiche],
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: Text(tr('Envoyer')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Section(tr('Activer une clé')),
          TextField(
            controller: _cle,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: tr('Collez ici la clé reçue'),
              errorText: _erreur,
              errorMaxLines: 3,
              suffixIcon: IconButton(
                tooltip: tr('Coller'),
                onPressed: _coller,
                icon: const Icon(Icons.content_paste_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _enCours ? null : _activer,
            icon: _enCours
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.vpn_key_rounded),
            label: Text(tr('Activer la licence')),
          ),
          const SizedBox(height: 18),
          Text(
            tr(
              'Vos données ne sont jamais bloquées : même sans licence, vous pouvez les consulter, les rechercher et les sauvegarder.',
            ),
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
