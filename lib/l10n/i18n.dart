import 'package:flutter/widgets.dart';

import 'traductions.dart';

enum Langue {
  fr('fr', 'Français'),
  ar('ar', 'العربية'),
  en('en', 'English');

  const Langue(this.code, this.nom);
  final String code;
  final String nom;

  Locale get locale => Locale(code);
  bool get rtl => this == ar;

  static Langue fromCode(String? c) =>
      Langue.values.firstWhere((l) => l.code == c, orElse: () => Langue.fr);
}

class I18n {
  I18n._();
  static Langue langue = Langue.fr;
}

/// Traduit un texte écrit en français dans la langue de l'application.
/// Les valeurs variables sont notées {0}, {1}... et fournies dans [args].
String tr(String fr, [List<Object?> args = const []]) {
  var s = fr;
  final l = I18n.langue;
  if (l != Langue.fr) {
    final t = traductions[fr];
    if (t != null) s = l == Langue.en ? t[0] : t[1];
  }
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}
