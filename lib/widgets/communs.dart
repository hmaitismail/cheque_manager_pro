import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../l10n/i18n.dart';

class StatutChip extends StatelessWidget {
  const StatutChip(this.statut, {super.key, this.petit = false});
  final Statut statut;
  final bool petit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: petit ? 8 : 10,
        vertical: petit ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: statut.couleur.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statut.icone, size: petit ? 12 : 14, color: statut.couleur),
          const SizedBox(width: 4),
          Text(
            statut.libelle,
            style: TextStyle(
              color: statut.couleur,
              fontWeight: FontWeight.w600,
              fontSize: petit ? 11 : 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.titre,
    required this.valeur,
    this.sousTitre,
    required this.icone,
    required this.couleur,
    this.onTap,
  });
  final String titre;
  final String valeur;
  final String? sousTitre;
  final IconData icone;
  final Color couleur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: couleur.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icone, size: 18, color: couleur),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      titre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  valeur,
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (sousTitre != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    sousTitre!,
                    style: t.bodySmall?.copyWith(
                      color: couleur,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChequeTile extends StatelessWidget {
  const ChequeTile(
    this.cheque, {
    super.key,
    this.onTap,
    this.trailingDate = true,
  });
  final Cheque cheque;
  final VoidCallback? onTap;
  final bool trailingDate;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final t = Theme.of(context).textTheme;
    final retard = cheque.estEnRetard(DateTime.now());
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: cheque.statut.couleur.withValues(alpha: 0.13),
        child: Icon(
          cheque.statut.icone,
          color: cheque.statut.couleur,
          size: 20,
        ),
      ),
      title: Text(
        cheque.beneficiaire,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        tr('N° {0} · {1}\n{2}Présentation {3}', [
          app.numero(cheque),
          app.nomBanque(cheque.banqueId),
          retard ? 'EN RETARD · ' : '',
          Fmt.date(cheque.datePresentation),
        ]),
        maxLines: 2,
        style: t.bodySmall?.copyWith(color: retard ? Colors.red : null),
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Fmt.mad(cheque.montant, devise: false),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          StatutChip(cheque.statut, petit: true),
        ],
      ),
    );
  }
}

class Vide extends StatelessWidget {
  const Vide({
    super.key,
    required this.icone,
    required this.texte,
    this.action,
  });
  final IconData icone;
  final String texte;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 56, color: Theme.of(context).disabledColor),
          const SizedBox(height: 12),
          Text(
            texte,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}

class Section extends StatelessWidget {
  const Section(this.titre, {super.key, this.action});
  final String titre;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            titre.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
        ?action,
      ],
    ),
  );
}

Future<bool> confirmer(
  BuildContext context, {
  required String titre,
  required String message,
  String? ok,
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titre),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(tr('Annuler')),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok ?? tr('Confirmer')),
        ),
      ],
    ),
  );
  return r ?? false;
}

void notifier(BuildContext context, String message, {bool erreur = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: erreur ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

Future<DateTime?> choisirDate(BuildContext context, DateTime initiale) =>
    showDatePicker(
      context: context,
      initialDate: initiale,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: I18n.langue.locale,
    );
