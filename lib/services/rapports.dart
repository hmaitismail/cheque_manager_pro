import '../l10n/i18n.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../models/models.dart';
import 'xlsx.dart';

enum TypeRapport {
  enAttente('Chèques en attente'),
  presentes('Chèques présentés'),
  payes('Chèques payés'),
  impayes('Chèques impayés'),
  recuperes('Chèques récupérés'),
  detruits('Chèques détruits'),
  parBanque('Situation par banque'),
  parPeriode('Situation par période (mensuelle)'),
  journal('Journal complet des chèques');

  const TypeRapport(this._titre);
  final String _titre;
  String get titre => tr(_titre);

  Statut? get statut => switch (this) {
    enAttente => Statut.enAttente,
    presentes => Statut.presente,
    payes => Statut.paye,
    impayes => Statut.impaye,
    recuperes => Statut.recupere,
    detruits => Statut.detruit,
    _ => null,
  };
}

enum FormatExport { pdf, xlsx, csv }

/// Cellule : texte ou montant (centimes) pour un typage correct dans Excel.
class Cellule {
  final String texte;
  final int? centimes;
  const Cellule.t(this.texte) : centimes = null;
  Cellule.m(int c) : centimes = c, texte = Fmt.mad(c, devise: false);
  Cellule.n(int n) : centimes = null, texte = '$n';
}

class Rapport {
  final String titre;
  final String periode;
  final List<String> colonnes;
  final List<List<Cellule>> lignes;
  final List<Cellule> totaux;
  final Set<int> colonnesNumeriques;
  final int totalGeneral;
  Rapport(
    this.titre,
    this.periode,
    this.colonnes,
    this.lignes,
    this.totaux,
    this.colonnesNumeriques,
    this.totalGeneral,
  );
}

class ServiceRapports {
  ServiceRapports({
    required this.banques,
    required this.chequiers,
    this.entreprise = '',
  });
  final Map<String, Banque> banques;
  final Map<String, Chequier> chequiers;
  final String entreprise;

  String numero(Cheque c) =>
      chequiers[c.chequierId]?.formatNumero(c.numero) ?? '${c.numero}';
  String banque(Cheque c) => banques[c.banqueId]?.libelle ?? '?';

  Rapport construire(
    TypeRapport type,
    List<Cheque> tous, {
    DateTime? du,
    DateTime? au,
  }) {
    final filtres = tous.where((c) {
      if (c.deletedAt != null) return false;
      final d = Fmt.jour(c.dateEdition);
      if (du != null && d.isBefore(Fmt.jour(du))) return false;
      if (au != null && d.isAfter(Fmt.jour(au))) return false;
      return true;
    }).toList();
    final periode = (du == null && au == null)
        ? tr('Toutes périodes')
        : tr('Du {0} au {1}', [
            du == null ? '...' : Fmt.date(du),
            au == null ? '...' : Fmt.date(au),
          ]);

    if (type == TypeRapport.parBanque) return _parBanque(filtres, periode);
    if (type == TypeRapport.parPeriode) {
      return _parPeriode(filtres, periode, du: du, au: au);
    }

    final st = type.statut;
    final liste = st == null
        ? filtres
        : filtres.where((c) => c.statut == st).toList();
    liste.sort((a, b) {
      final d = a.datePresentation.compareTo(b.datePresentation);
      return d != 0 ? d : a.numero.compareTo(b.numero);
    });
    final avecRejet = st == Statut.impaye;
    final colonnes = [
      tr('N° chèque'),
      tr('Banque'),
      tr('Bénéficiaire'),
      tr('Édition'),
      tr('Présentation'),
      tr('Ville'),
      tr('Objet'),
      if (st == null) tr('Statut'),
      if (avecRejet) tr('Motif rejet'),
      if (avecRejet) tr('Frais'),
      tr('Montant (MAD)'),
    ];
    final lignes = liste
        .map(
          (c) => [
            Cellule.t(numero(c)),
            Cellule.t(banque(c)),
            Cellule.t(c.beneficiaire),
            Cellule.t(Fmt.date(c.dateEdition)),
            Cellule.t(Fmt.date(c.datePresentation)),
            Cellule.t(c.ville),
            Cellule.t(c.objet),
            if (st == null) Cellule.t(c.statut.libelle),
            if (avecRejet) Cellule.t(c.motifRejet),
            if (avecRejet) Cellule.m(c.fraisRejet),
            Cellule.m(c.montant),
          ],
        )
        .toList();
    final total = liste.fold<int>(0, (s, c) => s + c.montant);
    final frais = liste.fold<int>(0, (s, c) => s + c.fraisRejet);
    final totaux = [
      Cellule.t(tr('TOTAL ({0} chèque(s))', [liste.length])),
      for (var i = 1; i < colonnes.length - (avecRejet ? 2 : 1); i++)
        const Cellule.t(''),
      if (avecRejet) Cellule.m(frais),
      Cellule.m(total),
    ];
    final numeriques = <int>{
      colonnes.length - 1,
      if (avecRejet) colonnes.length - 2,
    };
    return Rapport(
      type.titre,
      periode,
      colonnes,
      lignes,
      totaux,
      numeriques,
      total,
    );
  }

  Rapport _parBanque(List<Cheque> liste, String periode) {
    final colonnes = [
      tr('Banque / compte'),
      tr('Nb'),
      tr('Émis'),
      tr('En attente'),
      tr('Présentés'),
      tr('Payés'),
      tr('Impayés'),
      tr('Récup./détruits'),
    ];
    final groupes = <String, List<Cheque>>{};
    for (final c in liste) {
      groupes.putIfAbsent(c.banqueId, () => []).add(c);
    }
    int somme(List<Cheque> l, bool Function(Cheque) f) =>
        l.where(f).fold(0, (s, c) => s + c.montant);
    List<Cellule> ligne(String nom, List<Cheque> l) => [
      Cellule.t(nom),
      Cellule.n(l.length),
      Cellule.m(somme(l, (_) => true)),
      Cellule.m(somme(l, (c) => c.statut == Statut.enAttente)),
      Cellule.m(somme(l, (c) => c.statut == Statut.presente)),
      Cellule.m(somme(l, (c) => c.statut == Statut.paye)),
      Cellule.m(somme(l, (c) => c.statut == Statut.impaye)),
      Cellule.m(
        somme(
          l,
          (c) => c.statut == Statut.recupere || c.statut == Statut.detruit,
        ),
      ),
    ];
    final lignes =
        groupes.entries
            .map((e) => ligne(banques[e.key]?.libelle ?? '?', e.value))
            .toList()
          ..sort((a, b) => a.first.texte.compareTo(b.first.texte));
    return Rapport(
      TypeRapport.parBanque.titre,
      periode,
      colonnes,
      lignes,
      ligne(tr('TOTAL'), liste),
      {1, 2, 3, 4, 5, 6, 7},
      somme(liste, (_) => true),
    );
  }

  Rapport _parPeriode(
    List<Cheque> liste,
    String periode, {
    DateTime? du,
    DateTime? au,
  }) {
    final colonnes = [
      tr('Mois'),
      tr('Nb'),
      tr('Émis'),
      tr('Payés'),
      tr('Impayés'),
      tr('En attente / présentés'),
    ];
    final mois = <DateTime, List<Cheque>>{};
    for (final c in liste) {
      mois
          .putIfAbsent(
            DateTime(c.dateEdition.year, c.dateEdition.month),
            () => [],
          )
          .add(c);
    }
    final cles = mois.keys.toList()..sort();
    int somme(List<Cheque> l, bool Function(Cheque) f) =>
        l.where(f).fold(0, (s, c) => s + c.montant);
    List<Cellule> ligne(String nom, List<Cheque> l) => [
      Cellule.t(nom),
      Cellule.n(l.length),
      Cellule.m(somme(l, (_) => true)),
      Cellule.m(somme(l, (c) => c.statut == Statut.paye)),
      Cellule.m(somme(l, (c) => c.statut == Statut.impaye)),
      Cellule.m(
        somme(
          l,
          (c) => c.statut == Statut.enAttente || c.statut == Statut.presente,
        ),
      ),
    ];
    final lignes = cles
        .map((m) => ligne('${Fmt.moisLongs[m.month - 1]} ${m.year}', mois[m]!))
        .toList();
    return Rapport(
      TypeRapport.parPeriode.titre,
      periode,
      colonnes,
      lignes,
      ligne(tr('TOTAL'), liste),
      {1, 2, 3, 4, 5},
      somme(liste, (_) => true),
    );
  }

  // ------------------------------------------------------------------ PDF
  Future<Uint8List> pdf(Rapport r) async {
    final doc = pw.Document(title: r.titre, author: tr('Cheque Manager Pro'));
    const bleuNuit = PdfColor.fromInt(0xFF0B1F3A);
    const vert = PdfColor.fromInt(0xFF16A34A);
    final genere = Fmt.dateHeure(DateTime.now());
    // Police Amiri (latin + arabe) : noms arabes lisibles, rapports en arabe de droite à gauche.
    final amiri = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Amiri-Regular.ttf'),
    );
    final amiriGras = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Amiri-Bold.ttf'),
    );
    final arabe = I18n.langue == Langue.ar;
    final theme = arabe
        ? pw.ThemeData.withFont(base: amiri, bold: amiriGras)
        : pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
            fontFallback: [amiri],
          );
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        textDirection: arabe ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      entreprise.isEmpty
                          ? 'CHEQUE MANAGER PRO'
                          : entreprise.toUpperCase(),
                      style: const pw.TextStyle(
                        color: bleuNuit,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      r.titre,
                      style: const pw.TextStyle(
                        color: bleuNuit,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    pw.Text(
                      r.periode,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  tr('Édité le {0}', [genere]),
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.Container(
              height: 2,
              color: vert,
              margin: const pw.EdgeInsets.only(top: 6, bottom: 10),
            ),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            tr('Page {0} / {1}', [ctx.pageNumber, ctx.pagesCount]),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headers: r.colonnes,
            data: [
              ...r.lignes.map((l) => l.map((c) => c.texte).toList()),
              r.totaux.map((c) => c.texte).toList(),
            ],
            headerStyle: const pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            headerDecoration: const pw.BoxDecoration(color: bleuNuit),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignments: {
              for (final i in r.colonnesNumeriques) i: pw.Alignment.centerRight,
            },
            headerAlignments: {
              for (final i in r.colonnesNumeriques) i: pw.Alignment.centerRight,
            },
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF1F5F9),
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 3,
            ),
            border: null,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            tr('Montants exprimés en dirhams marocains (MAD).'),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
    return doc.save();
  }

  // ---------------------------------------------------------------- Excel
  List<int> xlsx(Rapport r) {
    final lignes = <List<XCell>>[
      [
        XCell.texte(
          entreprise.isEmpty ? tr('Cheque Manager Pro') : entreprise,
          XStyle.gras,
        ),
      ],
      [XCell.texte(r.titre, XStyle.titre)],
      [
        XCell.texte(
          tr('{0} - édité le {1}', [r.periode, Fmt.dateHeure(DateTime.now())]),
        ),
      ],
      const [],
      [for (final c in r.colonnes) XCell.texte(c, XStyle.entete)],
    ];
    XCell cellule(Cellule c, int i, {bool total = false}) {
      if (c.centimes != null) {
        return XCell.montant(
          c.centimes!,
          total ? XStyle.montantGras : XStyle.montant,
        );
      }
      if (r.colonnesNumeriques.contains(i)) {
        final n = int.tryParse(c.texte);
        if (n != null) {
          return XCell.entier(n, total ? XStyle.gras : XStyle.normal);
        }
      }
      return XCell.texte(c.texte, total ? XStyle.gras : XStyle.normal);
    }

    for (final l in r.lignes) {
      lignes.add([for (var i = 0; i < l.length; i++) cellule(l[i], i)]);
    }
    lignes.add([
      for (var i = 0; i < r.totaux.length; i++)
        cellule(r.totaux[i], i, total: true),
    ]);
    return Xlsx.construire(
      feuille: tr('Rapport'),
      lignes: lignes,
      largeurs: [
        for (var i = 0; i < r.colonnes.length; i++) i == 0 ? 24.0 : 16.0,
      ],
    );
  }

  // ------------------------------------------------------------------ CSV
  List<int> csv(Rapport r) {
    String esc(String v) =>
        (v.contains(';') || v.contains('"') || v.contains('\n'))
        ? '"${v.replaceAll('"', '""')}"'
        : v;
    String cell(Cellule c) => c.centimes != null
        ? Fmt.montantSaisie(c.centimes!).replaceAll('.', ',')
        : esc(c.texte);
    final b = StringBuffer()..writeln(r.colonnes.map(esc).join(';'));
    for (final l in r.lignes) {
      b.writeln(l.map(cell).join(';'));
    }
    b.writeln(r.totaux.map(cell).join(';'));
    return [0xEF, 0xBB, 0xBF, ...utf8.encode(b.toString())];
  }

  // ---------------------------------------------------- Fichier et partage
  Future<File> ecrire(Rapport r, FormatExport f) async {
    final dir = await getTemporaryDirectory();
    final base = r.titre
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâ]'), 'a')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final n = DateTime.now();
    final nom =
        '${base.isEmpty ? 'rapport' : base}_${Fmt.isoDate(n)}.${f.name}';
    final file = File(p.join(dir.path, nom));
    final List<int> octets = switch (f) {
      FormatExport.pdf => await pdf(r),
      FormatExport.xlsx => xlsx(r),
      FormatExport.csv => csv(r),
    };
    await file.writeAsBytes(octets, flush: true);
    return file;
  }

  Future<void> partager(Rapport r, FormatExport f) async {
    final file = await ecrire(r, f);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: r.titre),
    );
  }

  Future<void> imprimer(Rapport r) async {
    final bytes = await pdf(r);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: r.titre);
  }
}
