import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../l10n/i18n.dart';

/// Authentification locale : code PIN (haché + salé, stocké dans le
/// Keystore / Keychain) et biométrie (empreinte, Face ID).
class ServiceSecurite {
  ServiceSecurite._();
  static final ServiceSecurite instance = ServiceSecurite._();

  static const _storage = FlutterSecureStorage();
  static const _kHash = 'pin_hash';
  static const _kSel = 'pin_sel';
  static const _kBio = 'bio_actif';
  static const _kDelai = 'verrou_minutes';
  static const _kEchecs = 'pin_echecs';
  static const _kBlocage = 'pin_blocage_jusqua';

  final _auth = LocalAuthentication();

  bool biometrieActive = false;
  int delaiVerrouMinutes = 5;

  Future<void> charger() async {
    biometrieActive = (await _storage.read(key: _kBio)) == '1';
    delaiVerrouMinutes =
        int.tryParse(await _storage.read(key: _kDelai) ?? '') ?? 5;
  }

  Future<bool> pinDefini() async => (await _storage.read(key: _kHash)) != null;

  static String _hacher(String pin, String sel) {
    List<int> bytes = utf8.encode('$sel:$pin');
    for (var i = 0; i < 20000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Encode(bytes);
  }

  Future<void> definirPin(String pin) async {
    final r = Random.secure();
    final sel = base64Encode(List<int>.generate(16, (_) => r.nextInt(256)));
    await _storage.write(key: _kSel, value: sel);
    await _storage.write(key: _kHash, value: _hacher(pin, sel));
    await _storage.delete(key: _kEchecs);
    await _storage.delete(key: _kBlocage);
  }

  /// Secondes restantes de blocage après trop d'échecs (0 si libre).
  Future<int> blocageRestant() async {
    final jusqua = DateTime.tryParse(await _storage.read(key: _kBlocage) ?? '');
    if (jusqua == null) return 0;
    final s = jusqua.difference(DateTime.now()).inSeconds;
    return s > 0 ? s : 0;
  }

  Future<bool> verifierPin(String pin) async {
    if (await blocageRestant() > 0) return false;
    final sel = await _storage.read(key: _kSel);
    final hash = await _storage.read(key: _kHash);
    if (sel == null || hash == null) return false;
    final ok = _hacher(pin, sel) == hash;
    if (ok) {
      await _storage.delete(key: _kEchecs);
      return true;
    }
    final echecs =
        (int.tryParse(await _storage.read(key: _kEchecs) ?? '') ?? 0) + 1;
    await _storage.write(key: _kEchecs, value: '$echecs');
    if (echecs >= 5) {
      final secondes =
          30 * (1 << (echecs - 5).clamp(0, 5)); // 30 s, 60 s, 120 s...
      await _storage.write(
        key: _kBlocage,
        value: DateTime.now()
            .add(Duration(seconds: secondes))
            .toIso8601String(),
      );
    }
    return false;
  }

  Future<bool> biometrieDisponible() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authentifierBiometrie() async {
    try {
      return await _auth.authenticate(
        localizedReason: tr('Déverrouiller Cheque Manager Pro'),
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> definirBiometrie(bool actif) async {
    biometrieActive = actif;
    await _storage.write(key: _kBio, value: actif ? '1' : '0');
  }

  Future<void> definirDelai(int minutes) async {
    delaiVerrouMinutes = minutes;
    await _storage.write(key: _kDelai, value: '$minutes');
  }
}
