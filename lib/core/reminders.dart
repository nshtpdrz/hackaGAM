import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'tr.dart';

final _plugin = FlutterLocalNotificationsPlugin();

TimeOfDay parseHora(String s) => TimeOfDay(hour: int.parse(s.split(':')[0]), minute: int.parse(s.split(':')[1]));

// Acciones de la notificación de alarma.
const accionTomada = 'tomada', accionMasTarde = 'mas_tarde';
const _categoriaIos = 'toma';

/// Qué hacer cuando la persona toca la alarma o uno de sus botones con la app abierta
/// ([accion] es null si tocó la notificación). Lo asigna el vigilante de tomas (alarma_tomas.dart).
void Function(Map<String, dynamic> toma, String? accion)? alResponderAlarma;

/// Toma que abrió la app desde una notificación (app cerrada). Se consume una sola vez.
Map<String, dynamic>? tomaDeArranque; String? accionDeArranque;

Map<String, dynamic>? _toma(String? payload) {
  try { return payload == null || payload.isEmpty ? null : Map<String, dynamic>.from(jsonDecode(payload) as Map); }
  catch (_) { return null; }
}

void _alResponder(NotificationResponse r) {
  final t = _toma(r.payload); if (t == null) return;
  if (r.actionId == accionMasTarde) programarPospuesta(t, const Duration(minutes: 10));
  alResponderAlarma?.call(t, r.actionId);
}

/// "Más tarde" desde la notificación con la app cerrada: corre en otro isolate, sin Riverpod ni API.
/// Solo programa la alarma de nuevo en 10 minutos (la pantalla registra "pospuesta" al abrirse después).
@pragma('vm:entry-point')
void alarmaEnSegundoPlano(NotificationResponse r) {
  if (r.actionId != accionMasTarde) return;
  final t = _toma(r.payload); if (t == null) return;
  try { tzdata.initializeTimeZones(); } catch (_) {}
  programarPospuesta(t, const Duration(minutes: 10));
}

Future<void> initReminders() async {
  if (kIsWeb) return;
  try {
    tzdata.initializeTimeZones();
    await _plugin.initialize(InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(notificationCategories: [
          DarwinNotificationCategory(_categoriaIos, actions: [
            DarwinNotificationAction.plain(accionTomada, tr('Ya la tomé'), options: {DarwinNotificationActionOption.foreground}),
            DarwinNotificationAction.plain(accionMasTarde, tr('Más tarde'))])])),
      onDidReceiveNotificationResponse: _alResponder,
      onDidReceiveBackgroundNotificationResponse: alarmaEnSegundoPlano);
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    // Alarmas exactas: ver docs/android_manifest_snippet.xml (sin permiso se programan inexactas).
    final arranque = await _plugin.getNotificationAppLaunchDetails();
    if (arranque?.didNotificationLaunchApp == true) {
      final r = arranque!.notificationResponse;
      tomaDeArranque = _toma(r?.payload); accionDeArranque = r?.actionId;
    }
  } catch (_) {}
}

int _id(String key, int i) => (key.hashCode.abs() % 100000) * 10 + i;

Future<void> _programar(int id, String titulo, String cuerpo, DateTime cuando, AndroidScheduleMode modo) =>
  _plugin.zonedSchedule(id, titulo, cuerpo, tz.TZDateTime.from(cuando, tz.UTC),
    NotificationDetails(
      android: AndroidNotificationDetails('tomas', tr('Recordatorios de toma'), importance: Importance.high, priority: Priority.high),
      iOS: const DarwinNotificationDetails()),
    androidScheduleMode: modo,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time); // se repite todos los días a esa hora

/// Programa recordatorios diarios locales (funcionan sin internet). Devuelve false si no se pudo.
Future<bool> scheduleMedReminders(String key, String titulo, String cuerpo, List<String> horarios) async {
  if (kIsWeb) return false;
  try {
    for (var i = 0; i < 10; i++) { await _plugin.cancel(_id(key, i)); }
    final now = DateTime.now();
    for (var i = 0; i < horarios.length && i < 10; i++) {
      final h = parseHora(horarios[i]);
      var t = DateTime(now.year, now.month, now.day, h.hour, h.minute);
      if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
      try { await _programar(_id(key, i), titulo, cuerpo, t, AndroidScheduleMode.exactAllowWhileIdle); }
      catch (_) { await _programar(_id(key, i), titulo, cuerpo, t, AndroidScheduleMode.inexactAllowWhileIdle); }
    }
    return true;
  } catch (_) { return false; }
}

// ---------------------------------------------------------------------------------------------
// Alarmas de toma: suenan y vibran como un despertador hasta que la persona responde.
// Ids: 700000+k alarma diaria de la toma k, 760000+k alarma pospuesta ("Más tarde") de la toma k.
const _baseDiaria = 700000, _basePospuesta = 760000, _rango = 50000;
int _k(Map toma) => (int.tryParse('${toma['id']}') ?? '${toma['id']}'.hashCode).abs() % _rango;

NotificationDetails _detallesAlarma() => NotificationDetails(
  android: AndroidNotificationDetails('alarma_tomas', tr('Alarma de medicamentos'),
    channelDescription: tr('Suena y vibra a la hora de cada toma hasta que respondas.'),
    importance: Importance.max, priority: Priority.max, playSound: true,
    enableVibration: true, vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]),
    category: AndroidNotificationCategory.alarm, fullScreenIntent: true, visibility: NotificationVisibility.public,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT: repite sonido y vibración hasta que se atiende
    timeoutAfter: 30 * 60 * 1000, // a los 30 min sin respuesta la toma se considera omitida
    actions: [
      AndroidNotificationAction(accionTomada, tr('Ya la tomé'), showsUserInterface: true),
      AndroidNotificationAction(accionMasTarde, tr('Más tarde'))]),
  iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBanner: true,
    interruptionLevel: InterruptionLevel.timeSensitive, categoryIdentifier: _categoriaIos));

String _titulo(Map t) => tr('Hora de tu medicamento');
String _cuerpo(Map t) => tr('{med} · {dosis} · {hora}', {'med': t['medicamento'], 'dosis': t['dosis'] ?? '', 'hora': t['hora']});

Future<void> _agendar(int id, Map toma, DateTime cuando, {required bool diaria}) async {
  final payload = jsonEncode(toma.map((k, v) => MapEntry('$k', v)));
  for (final modo in [AndroidScheduleMode.exactAllowWhileIdle, AndroidScheduleMode.inexactAllowWhileIdle]) {
    try {
      await _plugin.zonedSchedule(id, _titulo(toma), _cuerpo(toma), tz.TZDateTime.from(cuando, tz.UTC), _detallesAlarma(),
        androidScheduleMode: modo, payload: payload,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: diaria ? DateTimeComponents.time : null);
      return;
    } catch (_) {} // sin permiso de alarma exacta: se intenta inexacta
  }
}

DateTime _proxima(String hora) {
  final h = parseHora(hora); final now = DateTime.now();
  final t = DateTime(now.year, now.month, now.day, h.hour, h.minute);
  return t.isAfter(now) ? t : t.add(const Duration(days: 1));
}

String _firma = '';

/// Programa una alarma diaria por cada horario del paciente y quita las que ya no existen.
/// Se puede llamar seguido: si los horarios no cambiaron no hace nada.
Future<void> programarAlarmasTomas(List horarios) async {
  if (kIsWeb) return;
  final firma = [for (final h in horarios) '${h['id']}|${h['hora']}|${h['medicamento']}|${h['dosis']}'].join(';');
  if (firma == _firma) return;
  _firma = firma;
  try {
    final vigentes = <int>{};
    for (final h in horarios) {
      if (h is! Map || h['hora'] == null) continue;
      final id = _baseDiaria + _k(h); vigentes.add(id);
      await _agendar(id, h, _proxima('${h['hora']}'), diaria: true);
    }
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id >= _baseDiaria && p.id < _baseDiaria + _rango && !vigentes.contains(p.id)) await _plugin.cancel(p.id);
    }
  } catch (_) { _firma = ''; }
}

/// Alarma única dentro de [en] (botón "Más tarde"). Reemplaza la pospuesta anterior de esa toma.
Future<void> programarPospuesta(Map toma, Duration en) async {
  if (kIsWeb) return;
  try { await _agendar(_basePospuesta + _k(toma), toma, DateTime.now().add(en), diaria: false); } catch (_) {}
}

/// La toma ya se atendió: quita su alarma pospuesta y apaga la alarma que esté sonando
/// (la diaria se vuelve a programar para su siguiente horario).
Future<void> atenderAlarma(Map toma) async {
  if (kIsWeb) return;
  try {
    await _plugin.cancel(_basePospuesta + _k(toma));
    if (toma['hora'] != null) {
      await _plugin.cancel(_baseDiaria + _k(toma));
      await _agendar(_baseDiaria + _k(toma), toma, _proxima('${toma['hora']}'), diaria: true);
    }
  } catch (_) {}
}
