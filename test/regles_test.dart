// Tests des règles de gestion, des calculs et de la recherche.
// Lancer avec : flutter test
import 'package:cheque_manager_pro/core/format.dart';
import 'package:cheque_manager_pro/models/filtre.dart';
import 'package:cheque_manager_pro/models/models.dart';
import 'package:cheque_manager_pro/services/plan_rappels.dart';
import 'package:cheque_manager_pro/services/stats.dart';
import 'package:cheque_manager_pro/services/validation.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 1, 1);

Chequier chequier({
  String id = 'ch1',
  String banque = 'b1',
  String numero = 'A1',
  int premier = 125,
  int dernier = 149,
}) => Chequier(
  id: id,
  banqueId: banque,
  numero: numero,
  premier: premier,
  dernier: dernier,
  largeur: 7,
  dateOuverture: _t0,
  createdAt: _t0,
  updatedAt: _t0,
);

Cheque cheque({
  String id = 'c1',
  String banque = 'b1',
  String chequierId = 'ch1',
  int numero = 125,
  int montant = 1500000,
  DateTime? edition,
  DateTime? presentation,
  String beneficiaire = 'Société ABC',
  Statut statut = Statut.enAttente,
  String ville = 'Marrakech',
}) => Cheque(
  id: id,
  banqueId: banque,
  chequierId: chequierId,
  numero: numero,
  montant: montant,
  dateEdition: edition ?? DateTime(2026, 11, 10),
  datePresentation: presentation ?? DateTime(2026, 11, 20),
  beneficiaire: beneficiaire,
  statut: statut,
  ville: ville,
  createdAt: _t0,
  updatedAt: _t0,
);

void main() {
  final aujourdhui = DateTime(2026, 11, 18);

  group('Montants', () {
    test('saisie convertie en centimes sans erreur d\'arrondi', () {
      expect(Fmt.parseMontant('15 000,50'), 1500050);
      expect(Fmt.parseMontant('15000.5'), 1500050);
      expect(Fmt.parseMontant('0,1'), 10);
      expect(Fmt.parseMontant('1 234 567,89 MAD'), 123456789);
      expect(Fmt.parseMontant('12,345'), isNull);
      expect(Fmt.parseMontant('abc'), isNull);
      expect(Fmt.parseMontant(''), isNull);
    });
    test('affichage MAD', () {
      expect(Fmt.mad(1500000), '15 000,00 MAD');
      expect(Fmt.mad(5), '0,05 MAD');
      expect(Fmt.mad(123456789, devise: false), '1 234 567,89');
      expect(Fmt.montantSaisie(1500050), '15000,50');
    });
  });

  group('Chéquiers', () {
    test('plage et numéros', () {
      final c = chequier();
      expect(c.total, 25);
      expect(c.formatNumero(125), '0000125');
      expect(c.contient(149), isTrue);
      expect(c.contient(150), isFalse);
    });
    test('refuse doublon de numéro et chevauchement dans le même compte', () {
      final existant = chequier();
      final r = Regles.chequier(
        chequier(id: 'ch2', numero: 'A1', premier: 140, dernier: 160),
        existants: [existant],
      );
      expect(r.erreurs, hasLength(2));
    });
    test('accepte la même plage dans un autre compte', () {
      final r = Regles.chequier(
        chequier(id: 'ch2', banque: 'b2'),
        existants: [chequier()],
      );
      expect(r.ok, isTrue);
    });
    test('interdit de réduire la plage sous des chèques déjà émis', () {
      final r = Regles.chequier(
        chequier(dernier: 130),
        existants: [],
        numerosEmis: [131],
      );
      expect(r.ok, isFalse);
    });
    test('refuse une plage inversée', () {
      expect(
        Regles.chequier(chequier(premier: 200, dernier: 100), existants: []).ok,
        isFalse,
      );
    });
  });

  group('Chèques', () {
    test('chèque valide', () {
      final r = Regles.cheque(
        cheque(),
        chequier: chequier(),
        chequesMemeBanque: [],
        aujourdhui: aujourdhui,
      );
      expect(r.ok, isTrue);
      expect(r.avertissements, isEmpty);
    });
    test('montant nul ou négatif refusé', () {
      expect(
        Regles.cheque(
          cheque(montant: 0),
          chequier: chequier(),
          chequesMemeBanque: [],
          aujourdhui: aujourdhui,
        ).ok,
        isFalse,
      );
      expect(
        Regles.cheque(
          cheque(montant: -100),
          chequier: chequier(),
          chequesMemeBanque: [],
          aujourdhui: aujourdhui,
        ).ok,
        isFalse,
      );
    });
    test('numéro hors du chéquier refusé', () {
      final r = Regles.cheque(
        cheque(numero: 150),
        chequier: chequier(),
        chequesMemeBanque: [],
        aujourdhui: aujourdhui,
      );
      expect(r.ok, isFalse);
    });
    test('doublon dans le même compte refusé, y compris en corbeille', () {
      final autre = cheque(id: 'c2')..deletedAt = DateTime.now();
      final r = Regles.cheque(
        cheque(),
        chequier: chequier(),
        chequesMemeBanque: [autre],
        aujourdhui: aujourdhui,
      );
      expect(r.ok, isFalse);
      expect(r.erreurs.first, contains('corbeille'));
    });
    test('modification du même chèque : pas de faux doublon', () {
      final c = cheque();
      expect(
        Regles.cheque(
          c,
          chequier: chequier(),
          chequesMemeBanque: [c],
          aujourdhui: aujourdhui,
        ).ok,
        isTrue,
      );
    });
    test('chéquier d\'une autre banque refusé', () {
      final r = Regles.cheque(
        cheque(),
        chequier: chequier(banque: 'b2'),
        chequesMemeBanque: [],
        aujourdhui: aujourdhui,
      );
      expect(r.ok, isFalse);
    });
    test('présentation avant édition refusée', () {
      final r = Regles.cheque(
        cheque(
          edition: DateTime(2026, 11, 20),
          presentation: DateTime(2026, 11, 10),
        ),
        chequier: chequier(),
        chequesMemeBanque: [],
        aujourdhui: aujourdhui,
      );
      expect(r.ok, isFalse);
    });
    test('chèque similaire signalé (avertissement)', () {
      final autre = cheque(id: 'c2', numero: 126);
      final r = Regles.cheque(
        cheque(),
        chequier: chequier(),
        chequesMemeBanque: [autre],
        aujourdhui: aujourdhui,
      );
      expect(r.ok, isTrue);
      expect(r.avertissements, hasLength(1));
    });
  });

  group('Statuts', () {
    test('payé uniquement après présentation (présenté ≠ débité)', () {
      expect(Statut.enAttente.peutPasserA(Statut.paye), isFalse);
      expect(Statut.presente.peutPasserA(Statut.paye), isTrue);
    });
    test('payé et détruit sont définitifs', () {
      expect(Statut.paye.suivantsPossibles, isEmpty);
      expect(Statut.detruit.suivantsPossibles, isEmpty);
    });
    test('seul un chèque en attente peut être supprimé', () {
      for (final s in Statut.values) {
        expect(s.suppressionInterdite, s != Statut.enAttente);
      }
    });
    test('impayé : motif obligatoire', () {
      final c = cheque(statut: Statut.presente);
      expect(Regles.changementStatut(c, Statut.impaye).ok, isFalse);
      expect(
        Regles.changementStatut(
          c,
          Statut.impaye,
          motifRejet: 'Provision insuffisante',
        ).ok,
        isTrue,
      );
    });
    test('représentation : nouvelle date obligatoire', () {
      final c = cheque(statut: Statut.impaye);
      expect(Regles.changementStatut(c, Statut.presente).ok, isFalse);
      expect(
        Regles.changementStatut(
          c,
          Statut.presente,
          nouvelleDatePresentation: aujourdhui,
        ).ok,
        isTrue,
      );
    });
  });

  group('Tableau de bord', () {
    final liste = [
      cheque(id: '1', montant: 100000, presentation: aujourdhui),
      cheque(
        id: '2',
        montant: 200000,
        presentation: aujourdhui.add(const Duration(days: 1)),
      ),
      cheque(id: '3', montant: 300000, presentation: DateTime(2026, 11, 10)),
      cheque(id: '4', montant: 400000, statut: Statut.paye),
      cheque(id: '5', montant: 500000, statut: Statut.impaye),
      cheque(id: '6', montant: 600000)..deletedAt = DateTime.now(),
    ];
    final s = Stats.calculer([...liste, liste.first], maintenant: aujourdhui);

    test('aucun double comptage, corbeille exclue', () {
      expect(s.total.nombre, 5);
      expect(s.total.montant, 1500000);
    });
    test('agrégats par statut', () {
      expect(s.de(Statut.enAttente).nombre, 3);
      expect(s.de(Statut.enAttente).montant, 600000);
      expect(s.de(Statut.paye).montant, 400000);
      expect(s.de(Statut.impaye).montant, 500000);
    });
    test('priorités du jour', () {
      expect(s.aujourdhui, hasLength(1));
      expect(s.demain, hasLength(1));
      expect(s.enRetard, hasLength(1));
      expect(s.impayesASuivre, hasLength(1));
    });
    test('évolution mensuelle', () {
      final nov = s.mensuel.last;
      expect(nov.mois, DateTime(2026, 11, 1));
      expect(nov.nombre, 5);
      expect(nov.emis, 1500000);
    });
  });

  group('Recherche', () {
    final liste = [
      cheque(
        id: '1',
        numero: 125,
        montant: 1500000,
        beneficiaire: 'Société ABC',
        ville: 'Agadir',
      ),
      cheque(
        id: '2',
        numero: 126,
        montant: 250000,
        beneficiaire: 'Garage Atlas',
        statut: Statut.paye,
      ),
    ];
    List<Cheque> chercher(FiltreCheques f) => f.appliquer(
      liste,
      numero: (c) => c.numero.toString().padLeft(7, '0'),
      banque: (_) => 'BMCE',
      chequier: (_) => 'A1',
    );

    test('par bénéficiaire, numéro, montant et ville', () {
      expect(chercher(FiltreCheques()..texte = 'atlas'), hasLength(1));
      expect(chercher(FiltreCheques()..texte = '0000125'), hasLength(1));
      expect(chercher(FiltreCheques()..texte = '15000'), hasLength(1));
      expect(chercher(FiltreCheques()..ville = 'agadir'), hasLength(1));
    });
    test('filtre par statut et tri par montant', () {
      expect(chercher(FiltreCheques.statuts({Statut.paye})), hasLength(1));
      final tri = chercher(FiltreCheques()..tri = Tri.montantAsc);
      expect(tri.first.id, '2');
    });
  });

  group('Rappels (exemple du cahier des charges)', () {
    // Chèque n° 000125, 15 000 DH, Société ABC, présentation le 20/11/2026.
    final c = cheque(
      numero: 125,
      montant: 1500000,
      presentation: DateTime(2026, 11, 20),
    );
    final r = ReglagesRappels(heureVeille: 9 * 60, heureJour: 8 * 60);

    test('veille, jour J et alerte de retard programmés', () {
      final plan = PlanificateurRappels.planifier(
        [c],
        r,
        maintenant: DateTime(2026, 11, 18, 23, 10),
      );
      expect(plan, hasLength(3));
      expect(plan[0].date, DateTime(2026, 11, 19, 9));
      expect(plan[0].corps, contains('sera présenté demain'));
      expect(plan[1].date, DateTime(2026, 11, 20, 8));
      expect(plan[1].corps, contains('présenté aujourd\'hui'));
      expect(plan[2].date, DateTime(2026, 11, 21, 8));
      expect(plan[2].titre, 'Chèque en retard');
    });
    test('les rappels passés ne sont pas reprogrammés', () {
      final plan = PlanificateurRappels.planifier(
        [c],
        r,
        maintenant: DateTime(2026, 11, 20, 10),
      );
      expect(plan, hasLength(1));
      expect(plan.first.titre, 'Chèque en retard');
    });
    test('chèque en retard : alerte groupée', () {
      final plan = PlanificateurRappels.planifier(
        [c],
        r,
        maintenant: DateTime(2026, 11, 22, 10),
      );
      expect(plan, hasLength(1));
      expect(plan.first.titre, '1 chèque(s) en retard');
      expect(plan.first.date, DateTime(2026, 11, 23, 8));
    });
    test('rappels désactivés pour un chèque ou globalement', () {
      final sans = cheque(presentation: DateTime(2026, 11, 20))
        ..rappelsActifs = false;
      final plan = PlanificateurRappels.planifier(
        [sans],
        r,
        maintenant: DateTime(2026, 11, 18),
      );
      expect(plan, isEmpty);
      expect(
        PlanificateurRappels.planifier(
          [c],
          ReglagesRappels(actifs: false),
          maintenant: DateTime(2026, 11, 18),
        ),
        isEmpty,
      );
    });
    test('chèques payés ignorés, impayés suivis', () {
      final paye = cheque(
        id: 'p',
        statut: Statut.paye,
        presentation: DateTime(2026, 11, 20),
      );
      final impaye = cheque(
        id: 'i',
        statut: Statut.impaye,
        presentation: DateTime(2026, 11, 10),
      );
      final plan = PlanificateurRappels.planifier(
        [paye, impaye],
        r,
        maintenant: DateTime(2026, 11, 18, 12),
      );
      expect(plan, hasLength(1));
      expect(plan.first.titre, contains('impayé'));
    });
    test('identifiants stables et limite iOS de 60 notifications', () {
      expect(
        PlanificateurRappels.idPour('abc', 0),
        PlanificateurRappels.idPour('abc', 0),
      );
      final beaucoup = [
        for (var i = 0; i < 100; i++)
          cheque(id: 'c$i', numero: 125, presentation: DateTime(2026, 12, 1)),
      ];
      expect(
        PlanificateurRappels.planifier(
          beaucoup,
          r,
          maintenant: DateTime(2026, 11, 18),
        ),
        hasLength(60),
      );
    });
  });
}
