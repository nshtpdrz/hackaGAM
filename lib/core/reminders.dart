import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'tr.dart';

final _plugin = FlutterLocalNotificationsPlugin();
bool _iniciado = false; // por isolate: el de segundo plano (push de solo datos) lo inicia aparte

/// Ícono pequeño blanco (android/app/src/main/res/drawable-*/ic_stat_senda.png) y morado de la marca.
const _icono = '@drawable/ic_stat_senda', _morado = Color(0xFF593286);

/// Canal de Android para las notificaciones push (alertas del equipo y de familiares). Es también el canal
/// por omisión de Firebase (AndroidManifest.xml), así que debe existir antes de que llegue el primer push.
const canalAlertas = 'alertas';

TimeOfDay parseHora(String s) => TimeOfDay(hour: int.parse(s.split(':')[0]), minute: int.parse(s.split(':')[1]));

// Acciones de la notificación de alarma.
const accionTomada = 'tomada', accionMasTarde = 'mas_tarde';
const _categoriaIos = 'toma';

/// Qué hacer cuando la persona toca la alarma o uno de sus botones con la app abierta
/// ([accion] es null si tocó la notificación). Lo asigna el vigilante de tomas (alarma_tomas.dart).
void Function(Map<String, dynamic> toma, String? accion)? alResponderAlarma;

/// Toma que abrió la app desde una notificación (app cerrada). Se consume una sola vez.
Map<String, dynamic>? tomaDeArranque; String? accionDeArranque;

// Las notificaciones push que se muestran con la app abierta llevan sus datos bajo esta clave,
// para no confundirlas con una toma al tocarlas.
const _clavePush = '_push';

/// Qué hacer al tocar un push que se mostró con la app abierta. Lo asigna push.dart.
void Function(Map<String, dynamic> datos)? alTocarPush;

/// Datos del push local que abrió la app (app cerrada). Se consume una sola vez.
Map<String, dynamic>? pushLocalDeArranque;

Map<String, dynamic>? _toma(String? payload) {
  try { return payload == null || payload.isEmpty ? null : Map<String, dynamic>.from(jsonDecode(payload) as Map); }
  catch (_) { return null; }
}

Map<String, dynamic>? _datosPush(Map<String, dynamic>? m) =>
    m != null && m[_clavePush] is Map ? Map<String, dynamic>.from(m[_clavePush] as Map) : null;

void _alResponder(NotificationResponse r) {
  final t = _toma(r.payload); if (t == null) return;
  final push = _datosPush(t);
  if (push != null) { alTocarPush?.call(push); return; }
  if (r.actionId == accionMasTarde) programarPospuesta(t, const Duration(minutes: 10));
  alResponderAlarma?.call(t, r.actionId);
}

/// "Más tarde" desde la notificación con la app cerrada: corre en otro isolate, sin Riverpod ni API.
/// Solo programa la alarma de nuevo en 10 minutos (la pantalla registra "pospuesta" al abrirse después).
@pragma('vm:entry-point')
void alarmaEnSegundoPlano(NotificationResponse r) {
  if (r.actionId != accionMasTarde) return;
  final t = _toma(r.payload); if (t == null || _datosPush(t) != null) return;
  try { tzdata.initializeTimeZones(); } catch (_) {}
  programarPospuesta(t, const Duration(minutes: 10));
}

Future<void> initReminders() async {
  if (kIsWeb) return;
  try {
    tzdata.initializeTimeZones();
    await _usarZonaDelTelefono();
    await _plugin.initialize(InitializationSettings(
        android: const AndroidInitializationSettings(_icono),
        // El permiso se pide después de iniciar sesión (pedirPermisoNotificaciones), no al abrir la app.
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false,
          requestSoundPermission: false, notificationCategories: [
          DarwinNotificationCategory(_categoriaIos, actions: [
            DarwinNotificationAction.plain(accionTomada, tr('Ya la tomé'), options: {DarwinNotificationActionOption.foreground}),
            DarwinNotificationAction.plain(accionMasTarde, tr('Más tarde'))])])),
      onDidReceiveNotificationResponse: _alResponder,
      onDidReceiveBackgroundNotificationResponse: alarmaEnSegundoPlano);
    _iniciado = true;
    await _crearCanalAlertas();
    // Alarmas exactas y pantalla completa: Preferencias > Avisos (widgets/avisos_settings.dart).
    final arranque = await _plugin.getNotificationAppLaunchDetails();
    if (arranque?.didNotificationLaunchApp == true) {
      final r = arranque!.notificationResponse; final t = _toma(r?.payload);
      pushLocalDeArranque = _datosPush(t);
      if (pushLocalDeArranque == null) { tomaDeArranque = t; accionDeArranque = r?.actionId; }
    }
  } catch (_) {}
}

/// Las alarmas diarias se programan en la zona del teléfono: "8:00" sigue siendo 8:00 con horario de verano
/// o de viaje. Si no se puede saber la zona, se queda en UTC (la hora se corre una hora al cambiar el horario).
Future<void> _usarZonaDelTelefono() async {
  try { tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone())); } catch (_) {}
}

/// La zona del teléfono cambió (la app vuelve a primer plano): se reprograman las alarmas en la nueva.
Future<void> revisarZonaHoraria() async {
  if (kIsWeb || !_iniciado) return;
  final antes = tz.local.name; await _usarZonaDelTelefono();
  if (tz.local.name != antes) _firma = '';
}

Future<void> _crearCanalAlertas() async {
  await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
    AndroidNotificationChannel(canalAlertas, tr('Alertas de salud'),
      description: tr('Avisos del equipo de salud y de tus familiares.'), importance: Importance.high));
}

/// Cambió el idioma de la app: Android actualiza el nombre de los canales al volver a crearlos con el mismo id,
/// y las alarmas se reprograman con los botones ("Ya la tomé", "Más tarde") en el idioma nuevo.
Future<void> actualizarIdiomaAvisos() async {
  _firma = '';
  if (kIsWeb || !_iniciado) return;
  try {
    await _crearCanalAlertas();
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
      AndroidNotificationChannel('alarma_tomas', tr('Alarma de medicamentos'),
        description: tr('Suena y vibra a la hora de cada toma hasta que respondas.'), importance: Importance.max));
  } catch (_) {}
}

/// Pide permiso para mostrar notificaciones (Android 13+ e iOS). Se llama al iniciar sesión.
Future<bool> pedirPermisoNotificaciones() async {
  if (kIsWeb) return false;
  try {
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (a != null) return await a.requestNotificationsPermission() ?? false;
    final i = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (i != null) return await i.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  } catch (_) {}
  return false;
}

/// Permisos de los avisos en este teléfono (null: no aplica o no se pudo saber).
typedef EstadoAvisos = ({bool? notificaciones, bool? exactas});
Future<EstadoAvisos> estadoAvisos() async {
  if (kIsWeb) return (notificaciones: null, exactas: null);
  try {
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (a != null) return (notificaciones: await a.areNotificationsEnabled(), exactas: await a.canScheduleExactNotifications());
    final i = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (i != null) return (notificaciones: (await i.checkPermissions())?.isEnabled, exactas: null);
  } catch (_) {}
  return (notificaciones: null, exactas: null);
}

/// Android 12+: abre Ajustes > Alarmas y recordatorios. Al volver, las alarmas se reprograman exactas.
Future<bool> pedirAlarmasExactas() async {
  if (kIsWeb) return false;
  try {
    final ok = await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission() ?? false;
    _firma = ''; // la siguiente revisión del vigilante de tomas vuelve a programar todo
    return ok;
  } catch (_) { return false; }
}

/// Android 14+: abre el ajuste de "pantalla completa" si falta (en versiones anteriores ya está permitido).
Future<bool> pedirPantallaCompleta() async {
  if (kIsWeb) return false;
  try {
    return await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestFullScreenIntentPermission() ?? false;
  } catch (_) { return false; }
}

/// Muestra un push como notificación local: con la app abierta (Android no lo muestra solo) o cuando
/// llega un mensaje de solo datos. Al tocarlo se llama a [alTocarPush] con [datos].
Future<void> mostrarPush(int id, String titulo, String cuerpo, Map<String, dynamic> datos) async {
  if (kIsWeb) return;
  try {
    if (!_iniciado) { // isolate de segundo plano de Firebase: sin callbacks, solo mostrar
      await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings(_icono),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false)));
      _iniciado = true;
      await _crearCanalAlertas();
    }
    await _plugin.show(id, titulo, cuerpo, NotificationDetails(
        android: AndroidNotificationDetails(canalAlertas, tr('Alertas de salud'),
          importance: Importance.high, priority: Priority.high, icon: _icono, color: _morado,
          styleInformation: BigTextStyleInformation(cuerpo)),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentSound: true)),
      payload: jsonEncode({_clavePush: datos}));
  } catch (_) {}
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
    icon: _icono, color: _morado,
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
      await _plugin.zonedSchedule(id, _titulo(toma), _cuerpo(toma), tz.TZDateTime.from(cuando, tz.local), _detallesAlarma(),
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

/// Al cerrar sesión: quita todas las alarmas y avisos de SENDA de este teléfono (programados y visibles),
/// para que no suenen las tomas de una persona en la sesión de otra.
Future<void> cancelarAlarmasTomas() async {
  _firma = '';
  if (kIsWeb) return;
  try { await _plugin.cancelAll(); } catch (_) {}
}
