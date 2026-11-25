import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

import 'plan_rappels.dart';
import '../l10n/i18n.dart';

export 'plan_rappels.dart';

/// Planification des rappels (cahier des charges §5). Les notifications sont
/// programmées dans le système : elles se déclenchent application fermée.
class ServiceRappels {
  ServiceRappels._();
  static final ServiceRappels instance = ServiceRappels._();

  final _plugin = FlutterLocalNotificationsPlugin();
  void Function(String chequeId)? surOuverture;
  bool _pret = false;

  Future<void> initialiser() async {
    if (_pret) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Casablanca'));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (r) {
        final id = r.payload;
        if (id != null && id.isNotEmpty) surOuverture?.call(id);
      },
    );
    final lancement = await _plugin.getNotificationAppLaunchDetails();
    final payload = lancement?.notificationResponse?.payload;
    if ((lancement?.didNotificationLaunchApp ?? false) &&
        payload != null &&
        payload.isNotEmpty) {
      Future.delayed(
        const Duration(seconds: 1),
        () => surOuverture?.call(payload),
      );
    }
    _pret = true;
  }

  Future<bool> demanderPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    bool? ok;
    if (android != null) ok = await android.requestNotificationsPermission();
    if (ios != null) {
      ok = await ios.requestPermissions(alert: true, badge: true, sound: true);
    }
    return ok ?? false;
  }

  /// Annule et reprogramme toutes les notifications (appelé au démarrage et
  /// après chaque modification de chèque).
  Future<void> reprogrammer(
    Iterable<Cheque> cheques,
    ReglagesRappels r, {
    String Function(Cheque)? libelleNumero,
  }) async {
    if (!_pret) return;
    try {
      await _plugin.cancelAll();
      final plan = PlanificateurRappels.planifier(
        cheques,
        r,
        maintenant: DateTime.now(),
        libelleNumero: libelleNumero,
      );
      for (final p in plan) {
        await _plugin.zonedSchedule(
          id: p.id,
          title: p.titre,
          body: p.corps,
          scheduledDate: tz.TZDateTime.from(p.date, tz.local),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'rappels_cheques',
              tr('Rappels des chèques'),
              channelDescription: tr(
                'Rappels de présentation, retards et impayés',
              ),
              importance: Importance.high,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(p.corps),
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: p.chequeId,
        );
      }
    } catch (e) {
      debugPrint('Erreur de programmation des rappels : $e');
    }
  }

  Future<void> testerMaintenant() async {
    await _plugin.show(
      id: 3,
      title: tr('Cheque Manager Pro'),
      body: tr('Les notifications fonctionnent correctement.'),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'rappels_cheques',
          tr('Rappels des chèques'),
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
