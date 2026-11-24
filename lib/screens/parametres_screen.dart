import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../services/rappels.dart';
import '../services/sauvegarde.dart';
import '../services/securite.dart';
import '../state/app_state.dart';
import '../widgets/communs.dart';

class ParametresScreen extends StatefulWidget {
  const ParametresScreen({super.key});
  @override
  State<ParametresScreen> createState() => _ParametresScreenState();
}

class _ParametresScreenState extends State<ParametresScreen> {
  final _sec = ServiceSecurite.instance;
  bool _bioDispo = false;

  @override
  void initState() {
    super.initState();
    _sec.biometrieDisponible().then((v) {
      if (mounted) setState(() => _bioDispo = v);
    });
  }

  Future<void> _changerPin() async {
    final ancien = await _saisirPin('Code actuel');
    if (ancien == null || !mounted) return;
    if (!await _sec.verifierPin(ancien)) {
      if (mounted) notifier(context, 'Code actuel incorrect', erreur: true);
      return;
    }
    if (!mounted) return;
    final nouveau = await _saisirPin('Nouveau code (4 à 6 chiffres)');
    if (nouveau == null || !mounted) return;
    final confirmation = await _saisirPin('Confirmez le nouveau code');
    if (confirmation == null || !mounted) return;
    if (nouveau != confirmation) {
      notifier(context, 'Les codes ne correspondent pas', erreur: true);
      return;
    }
    await _sec.definirPin(nouveau);
    if (mounted) notifier(context, 'Code modifié');
  }

  Future<String?> _saisirPin(String titre) async {
    final ctrl = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          maxLength: 6,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (RegExp(r'^\d{4,6}$').hasMatch(v)) Navigator.pop(ctx, v);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return r;
  }

  Future<void> _entreprise(AppState app) async {
    final ctrl = TextEditingController(text: app.entreprise);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nom affiché sur les rapports'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Ex. Société ABC SARL'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (r != null) await app.definirEntreprise(r);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    const delais = {
      0: 'Immédiat',
      1: '1 minute',
      5: '5 minutes',
      15: '15 minutes',
      30: '30 minutes',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres et sauvegardes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 40),
        children: [
          const Section('Sécurité'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.pin),
                  title: const Text('Modifier le code PIN'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changerPin,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Déverrouillage biométrique'),
                  subtitle: Text(
                    _bioDispo
                        ? 'Empreinte digitale / Face ID'
                        : 'Non disponible sur cet appareil',
                  ),
                  value: _sec.biometrieActive && _bioDispo,
                  onChanged: _bioDispo
                      ? (v) async {
                          if (v && !await _sec.authentifierBiometrie()) return;
                          await _sec.definirBiometrie(v);
                          setState(() {});
                        }
                      : null,
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Verrouillage automatique'),
                  subtitle: Text(
                    'Après ${delais[_sec.delaiVerrouMinutes] ?? '${_sec.delaiVerrouMinutes} min'} d\'inactivité',
                  ),
                  trailing: DropdownButton<int>(
                    value: delais.containsKey(_sec.delaiVerrouMinutes)
                        ? _sec.delaiVerrouMinutes
                        : 5,
                    underline: const SizedBox(),
                    items: delais.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) async {
                      if (v == null) return;
                      await _sec.definirDelai(v);
                      setState(() {});
                    },
                  ),
                ),
                const ListTile(
                  leading: Icon(Icons.enhanced_encryption_outlined),
                  title: Text('Chiffrement des données'),
                  subtitle: Text(
                    'Base de données chiffrée (AES-256, SQLCipher). Clé protégée par le système.',
                  ),
                ),
              ],
            ),
          ),
          const Section('Rappels'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Réglages des rappels'),
              subtitle: Text(
                app.reglages.actifs
                    ? 'Veille à ${_heure(app.reglages.heureVeille)} · jour J à ${_heure(app.reglages.heureJour)}'
                    : 'Désactivés',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReglagesRappelsScreen(),
                ),
              ),
            ),
          ),
          const Section('Sauvegardes'),
          const _Sauvegardes(),
          const Section('Affichage'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: const Text('Thème'),
                  trailing: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode, size: 18),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.phone_android, size: 18),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode, size: 18),
                      ),
                    ],
                    selected: {app.themeMode},
                    onSelectionChanged: (s) => app.definirTheme(s.first),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.business),
                  title: const Text('Nom sur les rapports'),
                  subtitle: Text(
                    app.entreprise.isEmpty ? 'Non renseigné' : app.entreprise,
                  ),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: () => _entreprise(app),
                ),
              ],
            ),
          ),
          const Section('À propos'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Cheque Manager Pro'),
              subtitle: Text(
                'Version 1.0.0 · Phase 1 (fonctionnement local)\nDevise : dirham marocain (MAD)',
              ),
              isThreeLine: true,
            ),
          ),
        ],
      ),
    );
  }
}

String _heure(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

class _Sauvegardes extends StatefulWidget {
  const _Sauvegardes();
  @override
  State<_Sauvegardes> createState() => _SauvegardesState();
}

class _SauvegardesState extends State<_Sauvegardes> {
  List<InfoSauvegarde> _liste = [];
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final l = await context.read<AppState>().sauvegardes.lister();
    if (mounted) setState(() => _liste = l);
  }

  Future<void> _creer() async {
    setState(() => _enCours = true);
    try {
      final f = await context.read<AppState>().sauvegardes.creer();
      await _charger();
      if (!mounted) return;
      notifier(context, 'Sauvegarde créée');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(f.path)],
          subject: 'Sauvegarde Cheque Manager Pro',
          text: 'Conservez ce fichier en lieu sûr (Drive, e-mail, clé USB).',
        ),
      );
    } catch (e) {
      if (mounted) notifier(context, 'Échec : $e', erreur: true);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _restaurer(File f) async {
    final app = context.read<AppState>();
    try {
      final m = await app.sauvegardes.lireManifeste(f);
      if (!mounted) return;
      final date = DateTime.tryParse(m['date'] as String? ?? '');
      final ok = await confirmer(
        context,
        titre: 'Restaurer cette sauvegarde ?',
        message:
            'Sauvegarde du ${Fmt.dateHeure(date)} · ${m['nb_cheques']} chèque(s).\n\n'
            'Toutes les données actuelles seront remplacées. Une sauvegarde de sécurité '
            'des données actuelles sera créée automatiquement avant la restauration.',
        ok: 'Restaurer',
        danger: true,
      );
      if (!ok) return;
      setState(() => _enCours = true);
      await app.sauvegardes.restaurer(f);
      await app.rafraichir();
      await _charger();
      if (mounted) notifier(context, 'Restauration terminée');
    } catch (e) {
      if (mounted) {
        notifier(context, 'Restauration impossible : $e', erreur: true);
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _importer() async {
    final r = await FilePicker.pickFiles();
    final chemin = r.isEmpty ? null : r.first.path;
    if (chemin == null) return;
    if (!chemin.endsWith(ServiceSauvegarde.extension)) {
      if (mounted) {
        notifier(
          context,
          'Choisissez un fichier ${ServiceSauvegarde.extension}',
          erreur: true,
        );
      }
      return;
    }
    await _restaurer(File(chemin));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          if (_enCours) const LinearProgressIndicator(),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Créer et exporter une sauvegarde'),
            subtitle: const Text('Données + photos + documents'),
            onTap: _enCours ? null : _creer,
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: const Text('Restaurer depuis un fichier'),
            subtitle: const Text('Fichier .cmpbak reçu ou enregistré'),
            onTap: _enCours ? null : _importer,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'Sauvegarde automatique quotidienne · ${_liste.length} sauvegarde(s) sur l\'appareil',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (final s in _liste.take(8))
            ListTile(
              dense: true,
              leading: Icon(
                p.basename(s.fichier.path).startsWith('auto')
                    ? Icons.schedule
                    : Icons.save_outlined,
                size: 20,
              ),
              title: Text(Fmt.dateHeure(s.date)),
              subtitle: Text(
                '${p.basename(s.fichier.path)} · ${(s.taille / 1024).toStringAsFixed(0)} Ko',
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (a) async {
                  if (a == 'r') await _restaurer(s.fichier);
                  if (a == 'p') {
                    await SharePlus.instance.share(
                      ShareParams(files: [XFile(s.fichier.path)]),
                    );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'p', child: Text('Partager')),
                  PopupMenuItem(value: 'r', child: Text('Restaurer')),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Important : les sauvegardes restent sur le téléphone. Exportez-en une régulièrement '
              'vers un autre support. La synchronisation cloud arrive en phase 2.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

class ReglagesRappelsScreen extends StatefulWidget {
  const ReglagesRappelsScreen({super.key});
  @override
  State<ReglagesRappelsScreen> createState() => _ReglagesRappelsScreenState();
}

class _ReglagesRappelsScreenState extends State<ReglagesRappelsScreen> {
  late ReglagesRappels r;

  @override
  void initState() {
    super.initState();
    final x = context.read<AppState>().reglages;
    r = ReglagesRappels(
      actifs: x.actifs,
      heureVeille: x.heureVeille,
      heureJour: x.heureJour,
      alerteRetard: x.alerteRetard,
      alerteImpayes: x.alerteImpayes,
    );
  }

  Future<void> _sauver() async {
    final app = context.read<AppState>();
    if (r.actifs) await ServiceRappels.instance.demanderPermission();
    await app.enregistrerReglages(r);
  }

  Future<void> _choisirHeure(bool veille) async {
    final m = veille ? r.heureVeille : r.heureJour;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (t == null) return;
    setState(() {
      if (veille) {
        r.heureVeille = t.hour * 60 + t.minute;
      } else {
        r.heureJour = t.hour * 60 + t.minute;
      }
    });
    await _sauver();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rappels')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Activer les rappels'),
                  subtitle: const Text('Fonctionnent même application fermée'),
                  value: r.actifs,
                  onChanged: (v) async {
                    setState(() => r.actifs = v);
                    await _sauver();
                  },
                ),
                ListTile(
                  enabled: r.actifs,
                  leading: const Icon(Icons.event),
                  title: const Text('Rappel la veille'),
                  trailing: Text(
                    _heure(r.heureVeille),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => _choisirHeure(true),
                ),
                ListTile(
                  enabled: r.actifs,
                  leading: const Icon(Icons.today),
                  title: const Text('Rappel le jour même'),
                  subtitle: const Text(
                    'Heure également utilisée pour les alertes de suivi',
                  ),
                  trailing: Text(
                    _heure(r.heureJour),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => _choisirHeure(false),
                ),
                SwitchListTile(
                  title: const Text('Alerte chèques en retard'),
                  subtitle: const Text(
                    'Toujours en attente après la date de présentation',
                  ),
                  value: r.alerteRetard,
                  onChanged: r.actifs
                      ? (v) async {
                          setState(() => r.alerteRetard = v);
                          await _sauver();
                        }
                      : null,
                ),
                SwitchListTile(
                  title: const Text('Alerte impayés à régulariser'),
                  value: r.alerteImpayes,
                  onChanged: r.actifs
                      ? (v) async {
                          setState(() => r.alerteImpayes = v);
                          await _sauver();
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await ServiceRappels.instance.demanderPermission();
              await ServiceRappels.instance.testerMaintenant();
            },
            icon: const Icon(Icons.notifications),
            label: const Text('Envoyer une notification de test'),
          ),
          const SizedBox(height: 12),
          Text(
            'Les rappels peuvent être désactivés individuellement depuis la fiche de chaque chèque '
            '(Modifier > Rappels de présentation).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
