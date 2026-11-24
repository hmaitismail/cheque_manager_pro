import 'dart:convert';

import 'package:archive/archive.dart';

/// Styles disponibles dans le classeur généré.
enum XStyle { normal, gras, entete, montant, montantGras, titre }

/// Cellule Excel : texte, montant (centimes, affiché en #,##0.00) ou entier.
class XCell {
  final String? texte;
  final int? centimes;
  final int? entier;
  final XStyle style;
  const XCell.texte(String this.texte, [this.style = XStyle.normal])
    : centimes = null,
      entier = null;
  const XCell.montant(int this.centimes, [this.style = XStyle.montant])
    : texte = null,
      entier = null;
  const XCell.entier(int this.entier, [this.style = XStyle.normal])
    : texte = null,
      centimes = null;
}

/// Générateur XLSX minimal (Office Open XML), sans dépendance externe :
/// produit un vrai fichier .xlsx lisible par Excel, LibreOffice et Google Sheets,
/// avec montants numériques (pas du texte) et formats MAD.
class Xlsx {
  Xlsx._();

  static String _esc(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      // Caractères de contrôle interdits en XML 1.0
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

  static String colonne(int index) {
    var n = index + 1;
    var s = '';
    while (n > 0) {
      final r = (n - 1) % 26;
      s = String.fromCharCode(65 + r) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }

  static String _decimal(int centimes) {
    final neg = centimes < 0;
    final a = centimes.abs();
    return '${neg ? '-' : ''}${a ~/ 100}.${(a % 100).toString().padLeft(2, '0')}';
  }

  static List<int> construire({
    required String feuille,
    required List<List<XCell>> lignes,
    List<double> largeurs = const [],
  }) {
    final sheet = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
      );
    if (largeurs.isNotEmpty) {
      sheet.write('<cols>');
      for (var i = 0; i < largeurs.length; i++) {
        sheet.write(
          '<col min="${i + 1}" max="${i + 1}" width="${largeurs[i]}" customWidth="1"/>',
        );
      }
      sheet.write('</cols>');
    }
    sheet.write('<sheetData>');
    for (var r = 0; r < lignes.length; r++) {
      sheet.write('<row r="${r + 1}">');
      for (var c = 0; c < lignes[r].length; c++) {
        final cell = lignes[r][c];
        final ref = '${colonne(c)}${r + 1}';
        final s = cell.style.index;
        if (cell.centimes != null) {
          sheet.write(
            '<c r="$ref" s="$s"><v>${_decimal(cell.centimes!)}</v></c>',
          );
        } else if (cell.entier != null) {
          sheet.write('<c r="$ref" s="$s"><v>${cell.entier}</v></c>');
        } else if ((cell.texte ?? '').isNotEmpty) {
          sheet.write(
            '<c r="$ref" s="$s" t="inlineStr"><is><t xml:space="preserve">${_esc(cell.texte!)}</t></is></c>',
          );
        } else if (cell.style != XStyle.normal) {
          sheet.write('<c r="$ref" s="$s"/>');
        }
      }
      sheet.write('</row>');
    }
    sheet.write('</sheetData></worksheet>');

    const contentTypes =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '</Types>';
    const rels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>';
    final workbook =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="${_esc(feuille)}" sheetId="1" r:id="rId1"/></sheets></workbook>';
    const workbookRels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '</Relationships>';
    // Ordre des cellXfs = ordre de l'enum XStyle.
    const styles =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<numFmts count="1"><numFmt numFmtId="164" formatCode="#,##0.00"/></numFmts>'
        '<fonts count="4">'
        '<font><sz val="11"/><name val="Calibri"/></font>'
        '<font><b/><sz val="11"/><name val="Calibri"/></font>'
        '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
        '<font><b/><sz val="14"/><color rgb="FF0B1F3A"/><name val="Calibri"/></font>'
        '</fonts>'
        '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
        '<fill><patternFill patternType="solid"><fgColor rgb="FF0B1F3A"/><bgColor indexed="64"/></patternFill></fill></fills>'
        '<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border>'
        '<border><left/><right/><top style="thin"><color rgb="FF0B1F3A"/></top><bottom/><diagonal/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="6">'
        '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
        '<xf numFmtId="0" fontId="2" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
        '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
        '<xf numFmtId="164" fontId="1" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyFont="1" applyBorder="1"/>'
        '<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
        '</cellXfs>'
        '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
        '</styleSheet>';

    final archive = Archive();
    void ajouter(String nom, String contenu) {
      final octets = utf8.encode(contenu);
      archive.addFile(ArchiveFile(nom, octets.length, octets));
    }

    ajouter('[Content_Types].xml', contentTypes);
    ajouter('_rels/.rels', rels);
    ajouter('xl/workbook.xml', workbook);
    ajouter('xl/_rels/workbook.xml.rels', workbookRels);
    ajouter('xl/styles.xml', styles);
    ajouter('xl/worksheets/sheet1.xml', sheet.toString());
    return ZipEncoder().encode(archive);
  }
}
