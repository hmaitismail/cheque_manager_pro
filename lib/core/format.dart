/// Formatage des montants (MAD) et des dates, sans dépendance aux données
/// de locale (évite les espaces insécables spéciaux, mal gérés en PDF).
class Fmt {
  Fmt._();

  static const moisCourts = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  static const moisLongs = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  static const joursCourts = [
    'lun.',
    'mar.',
    'mer.',
    'jeu.',
    'ven.',
    'sam.',
    'dim.',
  ];

  /// Montant en centimes -> "15 000,00 MAD"
  static String mad(int centimes, {bool devise = true}) {
    final negatif = centimes < 0;
    final abs = centimes.abs();
    final entier = abs ~/ 100;
    final dec = (abs % 100).toString().padLeft(2, '0');
    final s = entier.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '${negatif ? '-' : ''}$buf,$dec${devise ? ' MAD' : ''}';
  }

  /// Montant compact pour les graphiques : 15,2 k / 1,3 M
  static String madCompact(int centimes) {
    final v = centimes / 100.0;
    if (v.abs() >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
    }
    if (v.abs() >= 1000) {
      return '${(v / 1000).toStringAsFixed(1).replaceAll('.', ',')} k';
    }
    return v.toStringAsFixed(0);
  }

  /// Saisie utilisateur "15 000,50" / "15000.5" -> centimes. Null si invalide.
  static int? parseMontant(String input) {
    var s = input
        .trim()
        .replaceAll(RegExp(r'[\s  ]'), '')
        .replaceAll('MAD', '')
        .replaceAll('DH', '');
    if (s.isEmpty) return null;
    s = s.replaceAll(',', '.');
    if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(s)) return null;
    final parts = s.split('.');
    final negatif = parts[0].startsWith('-');
    final entier = int.parse(parts[0].replaceAll('-', ''));
    var cents = 0;
    if (parts.length == 2) cents = int.parse(parts[1].padRight(2, '0'));
    final total = entier * 100 + cents;
    return negatif ? -total : total;
  }

  /// Centimes -> "15000,50" pour pré-remplir un champ de saisie.
  static String montantSaisie(int centimes) {
    final e = centimes ~/ 100;
    final d = centimes % 100;
    return d == 0 ? '$e' : '$e,${d.toString().padLeft(2, '0')}';
  }

  static String date(DateTime? d) {
    if (d == null) return '-';
    return '${_d2(d.day)}/${_d2(d.month)}/${d.year}';
  }

  static String dateHeure(DateTime? d) {
    if (d == null) return '-';
    return '${date(d)} ${_d2(d.hour)}:${_d2(d.minute)}';
  }

  static String dateLongue(DateTime d) =>
      '${joursCourts[d.weekday - 1]} ${d.day} ${moisLongs[d.month - 1]} ${d.year}';

  static String moisAnnee(DateTime d) =>
      '${moisCourts[d.month - 1]} ${d.year.toString().substring(2)}';

  /// Date -> "yyyy-MM-dd" (stockage)
  static String isoDate(DateTime d) =>
      '${d.year}-${_d2(d.month)}-${_d2(d.day)}';

  static DateTime? parseIsoDate(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static DateTime jour(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _d2(int v) => v.toString().padLeft(2, '0');
}
