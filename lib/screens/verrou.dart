import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/securite.dart';

/// Protège toute l'application : code PIN / biométrie au démarrage, au retour
/// en premier plan et après une période d'inactivité.
class VerrouGate extends StatefulWidget {
  const VerrouGate({super.key, required this.child});
  final Widget child;

  @override
  State<VerrouGate> createState() => _VerrouGateState();
}

enum _Etat { chargement, creationPin, verrouille, ouvert }

class _VerrouGateState extends State<VerrouGate> with WidgetsBindingObserver {
  final _sec = ServiceSecurite.instance;
  _Etat _etat = _Etat.chargement;
  DateTime _derniereActivite = DateTime.now();
  DateTime? _miseEnArrierePlan;
  Timer? _minuteur;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _minuteur = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _verifierInactivite(),
    );
  }

  Future<void> _init() async {
    final defini = await _sec.pinDefini();
    if (!mounted) return;
    setState(() => _etat = defini ? _Etat.verrouille : _Etat.creationPin);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minuteur?.cancel();
    super.dispose();
  }

  bool get _delaiDepasse {
    final d = _sec.delaiVerrouMinutes;
    return d > 0 && DateTime.now().difference(_derniereActivite).inMinutes >= d;
  }

  void _verifierInactivite() {
    if (_etat == _Etat.ouvert && _delaiDepasse) {
      setState(() => _etat = _Etat.verrouille);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _miseEnArrierePlan ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final depuis = _miseEnArrierePlan;
      _miseEnArrierePlan = null;
      if (depuis != null && _etat == _Etat.ouvert) {
        final d = _sec.delaiVerrouMinutes;
        // Délai 0 = verrouillage immédiat à chaque sortie de l'application.
        final minutes = DateTime.now().difference(depuis).inMinutes;
        if (d == 0 || minutes >= d) setState(() => _etat = _Etat.verrouille);
      }
    }
  }

  void _ouvrir() => setState(() {
    _etat = _Etat.ouvert;
    _derniereActivite = DateTime.now();
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _derniereActivite = DateTime.now(),
      child: Stack(
        children: [
          // L'application reste montée (pas de perte de saisie) mais invisible.
          Offstage(
            offstage: _etat != _Etat.ouvert,
            child: TickerMode(
              enabled: _etat == _Etat.ouvert,
              child: widget.child,
            ),
          ),
          if (_etat == _Etat.chargement)
            const Material(
              color: AppColors.bleuNuit,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          if (_etat == _Etat.creationPin) _CreationPin(onTermine: _ouvrir),
          if (_etat == _Etat.verrouille) _EcranVerrou(onOuvert: _ouvrir),
        ],
      ),
    );
  }
}

class _EcranVerrou extends StatefulWidget {
  const _EcranVerrou({required this.onOuvert});
  final VoidCallback onOuvert;
  @override
  State<_EcranVerrou> createState() => _EcranVerrouState();
}

class _EcranVerrouState extends State<_EcranVerrou> {
  final _sec = ServiceSecurite.instance;
  String _pin = '';
  String? _erreur;
  bool _bioDispo = false;
  bool _verif = false;

  @override
  void initState() {
    super.initState();
    _initBio();
  }

  Future<void> _initBio() async {
    if (!_sec.biometrieActive) return;
    _bioDispo = await _sec.biometrieDisponible();
    if (!mounted) return;
    setState(() {});
    if (_bioDispo) _bio();
  }

  Future<void> _bio() async {
    if (await _sec.authentifierBiometrie()) widget.onOuvert();
  }

  Future<void> _valider() async {
    if (_pin.length < 4 || _verif) return;
    setState(() => _verif = true);
    final bloque = await _sec.blocageRestant();
    if (bloque > 0) {
      setState(() {
        _verif = false;
        _pin = '';
        _erreur = 'Trop de tentatives. Réessayez dans $bloque s.';
      });
      return;
    }
    final ok = await _sec.verifierPin(_pin);
    if (!mounted) return;
    if (ok) {
      widget.onOuvert();
    } else {
      setState(() {
        _verif = false;
        _pin = '';
        _erreur = 'Code incorrect';
      });
    }
  }

  @override
  Widget build(BuildContext context) => _FondSecurite(
    titre: 'Saisissez votre code',
    pin: _pin,
    erreur: _erreur,
    chargement: _verif,
    onTouche: (d) => setState(() {
      _erreur = null;
      if (_pin.length < 6) _pin += d;
    }),
    onEffacer: () => setState(
      () => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1),
    ),
    onValider: _valider,
    bio: _bioDispo ? _bio : null,
  );
}

class _CreationPin extends StatefulWidget {
  const _CreationPin({required this.onTermine});
  final VoidCallback onTermine;
  @override
  State<_CreationPin> createState() => _CreationPinState();
}

class _CreationPinState extends State<_CreationPin> {
  String _pin = '';
  String? _premier;
  String? _erreur;

  Future<void> _valider() async {
    if (_pin.length < 4) {
      setState(() => _erreur = 'Le code doit contenir 4 à 6 chiffres');
      return;
    }
    if (_premier == null) {
      setState(() {
        _premier = _pin;
        _pin = '';
        _erreur = null;
      });
      return;
    }
    if (_premier != _pin) {
      setState(() {
        _premier = null;
        _pin = '';
        _erreur = 'Les codes ne correspondent pas, recommencez';
      });
      return;
    }
    final sec = ServiceSecurite.instance;
    await sec.definirPin(_pin);
    if (await sec.biometrieDisponible()) await sec.definirBiometrie(true);
    widget.onTermine();
  }

  @override
  Widget build(BuildContext context) => _FondSecurite(
    titre: _premier == null
        ? 'Créez votre code de sécurité'
        : 'Confirmez votre code',
    sousTitre: 'De 4 à 6 chiffres. Il protège l\'accès à vos chèques.',
    pin: _pin,
    erreur: _erreur,
    onTouche: (d) => setState(() {
      _erreur = null;
      if (_pin.length < 6) _pin += d;
    }),
    onEffacer: () => setState(
      () => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1),
    ),
    onValider: _valider,
  );
}

class _FondSecurite extends StatelessWidget {
  const _FondSecurite({
    required this.titre,
    this.sousTitre,
    required this.pin,
    this.erreur,
    required this.onTouche,
    required this.onEffacer,
    required this.onValider,
    this.bio,
    this.chargement = false,
  });
  final String titre;
  final String? sousTitre;
  final String pin;
  final String? erreur;
  final void Function(String) onTouche;
  final VoidCallback onEffacer;
  final VoidCallback onValider;
  final VoidCallback? bio;
  final bool chargement;

  @override
  Widget build(BuildContext context) {
    Widget touche(String label, {VoidCallback? onTap, IconData? icone}) =>
        SizedBox(
          width: 78,
          height: 66,
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
            ),
            onPressed: onTap ?? () => onTouche(label),
            child: icone != null
                ? Icon(icone, size: 26)
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
          ),
        );

    return Material(
      color: AppColors.bleuNuit,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.vert,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Cheque Manager Pro',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  titre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sousTitre != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 32, right: 32),
                    child: Text(
                      sousTitre!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(6, (i) {
                    final rempli = i < pin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: rempli ? AppColors.vert : Colors.transparent,
                        border: Border.all(
                          color: i < 4 || rempli
                              ? Colors.white70
                              : Colors.white24,
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(
                  height: 34,
                  child: Center(
                    child: chargement
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            erreur ?? '',
                            style: const TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
                for (final ligne in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ligne.map((d) => touche(d)).toList(),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    bio != null
                        ? touche('', onTap: bio, icone: Icons.fingerprint)
                        : touche(
                            '',
                            onTap: onEffacer,
                            icone: Icons.backspace_outlined,
                          ),
                    touche('0'),
                    touche('', onTap: onValider, icone: Icons.check_circle),
                  ],
                ),
                if (bio != null)
                  TextButton.icon(
                    onPressed: onEffacer,
                    icon: const Icon(
                      Icons.backspace_outlined,
                      color: Colors.white60,
                      size: 18,
                    ),
                    label: const Text(
                      'Effacer',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
