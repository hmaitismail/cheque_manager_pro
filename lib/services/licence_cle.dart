import '../l10n/i18n.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Alphabet base 32 sans caractères ambigus (pas de I, O, 0, 1).
const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String base32Encoder(List<int> octets) {
  final b = StringBuffer();
  var buffer = 0, bits = 0;
  for (final o in octets) {
    buffer = (buffer << 8) | o;
    bits += 8;
    while (bits >= 5) {
      b.write(_alphabet[(buffer >> (bits - 5)) & 31]);
      bits -= 5;
    }
  }
  if (bits > 0) b.write(_alphabet[(buffer << (5 - bits)) & 31]);
  return b.toString();
}

Uint8List? base32Decoder(String texte) {
  final propre = texte.toUpperCase().replaceAll(RegExp('[^$_alphabet]'), '');
  final out = <int>[];
  var buffer = 0, bits = 0;
  for (final c in propre.split('')) {
    final v = _alphabet.indexOf(c);
    if (v < 0) return null;
    buffer = ((buffer << 5) | v) & 0xFFFFFF;
    bits += 5;
    if (bits >= 8) {
      out.add((buffer >> (bits - 8)) & 0xFF);
      bits -= 8;
    }
  }
  return Uint8List.fromList(out);
}

enum Formule {
  annuelle(1, 'Abonnement annuel'),
  aVie(2, 'Licence à vie'),
  mensuelle(3, 'Abonnement mensuel');

  const Formule(this.code, this._libelle);
  final int code;
  final String _libelle;
  String get libelle => tr(_libelle);
  static Formule? fromCode(int c) =>
      Formule.values.where((f) => f.code == c).firstOrNull;
}

class CleLicence {
  final String codeAppareil;
  final DateTime? expiration; // null = à vie
  final Formule formule;
  CleLicence(this.codeAppareil, this.expiration, this.formule);
}

final origineLicence = DateTime.utc(2026, 1, 1);

/// Décode et vérifie la signature d'une clé (sans contrôle de l'appareil).
Future<CleLicence?> decoderCle(String saisie, String clePubliqueB64) async {
  final octets = base32Decoder(saisie);
  if (octets == null || octets.length < 9 + 64) return null;
  final payload = octets.sublist(0, 9);
  final signature = octets.sublist(9, 9 + 64);
  if (payload[0] != 1) return null;
  final ok = await Ed25519().verify(
    payload,
    signature: Signature(
      signature,
      publicKey: SimplePublicKey(
        base64Decode(clePubliqueB64),
        type: KeyPairType.ed25519,
      ),
    ),
  );
  if (!ok) return null;
  final formule = Formule.fromCode(payload[8]);
  if (formule == null) return null;
  final jours = (payload[6] << 8) | payload[7];
  return CleLicence(
    base32Encoder(payload.sublist(1, 6)),
    jours == 0 ? null : origineLicence.add(Duration(days: jours)),
    formule,
  );
}
