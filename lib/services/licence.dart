import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'licence_cle.dart';
import '../l10n/i18n.dart';

export 'licence_cle.dart';

enum EtatLicence { essai, active, expiree }

class InfoLicence {
  final EtatLicence etat;
  final int joursRestants;
  final DateTime? expiration;
  final Formule? formule;
  final String codeAppareil;
  InfoLicence(
    this.etat,
    this.joursRestants,
    this.expiration,
    this.formule,
    this.codeAppareil,
  );

  /// Saisie et modification autorisées.
  bool get utilisable => etat != EtatLicence.expiree;
  bool get bientotExpiree =>
      etat != EtatLicence.expiree && expiration != null && joursRestants <= 7;
}

/// Licence de l'application : période d'essai, puis clé d'activation signée
/// (Ed25519) liée à l'appareil. Seule la clé publique est dans l'application :
/// impossible de fabriquer une clé sans la clé privée du vendeur.
class ServiceLicence {
  ServiceLicence._();
  static final ServiceLicence instance = ServiceLicence._();

  /// Durée de l'essai gratuit.
  static const joursEssai = 30;

  /// Clé publique du vendeur (la clé privée reste hors de l'application).
  static const _clePublique = 'kq5CDuR6fVseS6VlacU8fx0lPjYgfxXZcNB4CjRL/AY=';

  static const _storage = FlutterSecureStorage();
  static const _kInstall = 'lic_appareil';
  static const _kDebut = 'lic_essai_debut';
  static const _kCle = 'lic_cle';
  static const _kVu = 'lic_dernier_jour';

  late String _codeAppareil;
  DateTime _debutEssai = DateTime.now();
  CleLicence? _cle;
  DateTime _dernierJourVu = DateTime.now();

  InfoLicence info = InfoLicence(EtatLicence.essai, joursEssai, null, null, '');

  String get codeAppareil => _codeAppareil;

  Future<void> charger() async {
    var install = await _storage.read(key: _kInstall);
    if (install == null) {
      final r = Random.secure();
      install = base32Encoder(List<int>.generate(5, (_) => r.nextInt(256)));
      await _storage.write(key: _kInstall, value: install);
    }
    _codeAppareil = install;

    final debut = DateTime.tryParse(await _storage.read(key: _kDebut) ?? '');
    if (debut == null) {
      _debutEssai = DateTime.now();
      await _storage.write(key: _kDebut, value: _debutEssai.toIso8601String());
    } else {
      _debutEssai = debut;
    }

    // Protection contre le recul de l'horloge du téléphone.
    final vu = DateTime.tryParse(await _storage.read(key: _kVu) ?? '');
    final maintenant = DateTime.now();
    _dernierJourVu = (vu != null && vu.isAfter(maintenant)) ? vu : maintenant;
    await _storage.write(key: _kVu, value: _dernierJourVu.toIso8601String());

    final cle = await _storage.read(key: _kCle);
    _cle = cle == null ? null : await verifier(cle);
    _calculer();
  }

  /// Pour les tests et captures d'écran : état sans accès au stockage sécurisé.
  void initialiserPourTests({
    String code = 'K7Q2M9XD',
    int joursEssaiRestants = 23,
  }) {
    _codeAppareil = code;
    _debutEssai = DateTime.now().subtract(
      Duration(days: joursEssai - joursEssaiRestants),
    );
    _dernierJourVu = DateTime.now();
    _cle = null;
    _calculer();
  }

  String get codeAffiche =>
      '${_codeAppareil.substring(0, 4)}-${_codeAppareil.substring(4)}';

  /// Vérifie une clé saisie. Renvoie null si invalide ou destinée à un autre appareil.
  Future<CleLicence?> verifier(String saisie) async {
    final cle = await decoderCle(saisie, _clePublique);
    if (cle == null || cle.codeAppareil != _codeAppareil) return null;
    return cle;
  }

  /// Active une clé. Renvoie un message d'erreur, ou null si tout va bien.
  Future<String?> activer(String saisie) async {
    final cle = await verifier(saisie);
    if (cle == null) {
      return tr(
        'Clé invalide ou destinée à un autre appareil. Vérifiez qu\'elle a été copiée entièrement.',
      );
    }
    if (cle.expiration != null && cle.expiration!.isBefore(_dernierJourVu)) {
      return tr('Cette clé est expirée.');
    }
    await _storage.write(key: _kCle, value: saisie.trim());
    _cle = cle;
    _calculer();
    return null;
  }

  void _calculer() {
    final ref = _dernierJourVu;
    final cle = _cle;
    if (cle != null) {
      if (cle.expiration == null) {
        info = InfoLicence(
          EtatLicence.active,
          99999,
          null,
          cle.formule,
          _codeAppareil,
        );
        return;
      }
      final reste = cle.expiration!.difference(ref).inDays;
      if (reste >= 0) {
        info = InfoLicence(
          EtatLicence.active,
          reste,
          cle.expiration,
          cle.formule,
          _codeAppareil,
        );
        return;
      }
    }
    final fin = _debutEssai.add(const Duration(days: joursEssai));
    final reste = fin.difference(ref).inDays;
    info = reste >= 0
        ? InfoLicence(EtatLicence.essai, reste, fin, null, _codeAppareil)
        : InfoLicence(
            EtatLicence.expiree,
            0,
            cle?.expiration ?? fin,
            cle?.formule,
            _codeAppareil,
          );
  }
}
