import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/shared.dart';
import 'api.dart';
import 'notifs.dart';
import 'reminders.dart';
import 'state.dart';

// Notificaciones push con Firebase Cloud Messaging (FCM). Guía: docs/NOTIFICACIONES.md.
// - Sin google-services.json (Android) / GoogleService-Info.plist (iOS) la app funciona igual y el push no se activa.
// - Con sesión, el token va a POST /dispositivos {token_fcm, plataforma}; también cuando Firebase lo renueva.
// - Al cerrar sesión se borra el token del teléfono: no llegan avisos de la cuenta anterior (teléfono compartido).
// - Con la app abierta Android no muestra el push: se muestra con flutter_local_notifications (canal "alertas").
// - Al tocar un push se abre la pantalla según data.tipo (rutaDePush).
// Las alarmas de tomas NO dependen del push: son locales (reminders.dart) y suenan sin internet.

bool _activo = false;
/// true si Firebase quedó configurado en este teléfono.
bool get pushActivo => _activo;

Map<String, dynamic>? _deArranque; // push que abrió la app estando cerrada (se consume una vez)
final _llegadas = StreamController<Map<String, dynamic>>.broadcast(); // en primer plano
final _toques = StreamController<Map<String, dynamic>>.broadcast(); // push tocado (FCM o local)
final _renovados = StreamController<String>.broadcast(); // Firebase cambió el token

/// Se llama en main() antes de runApp.
Future<void> iniciarPush() async {
  alTocarPush = _toques.add;
  _deArranque = pushLocalDeArranque; pushLocalDeArranque = null;
  if (kIsWeb) return;
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Push sin configurar (falta google-services.json o GoogleService-Info.plist): $e');
    return;
  }
  _activo = true;
  try {
    FirebaseMessaging.onBackgroundMessage(_pushEnSegundoPlano);
    final fm = FirebaseMessaging.instance;
    // iOS: con la app abierta el sistema muestra el aviso (en Android lo mostramos nosotros).
    await fm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    FirebaseMessaging.onMessage.listen(_enPrimerPlano);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _toques.add(_datos(m)));
    fm.onTokenRefresh.listen(_renovados.add);
    final inicial = await fm.getInitialMessage();
    if (inicial != null) _deArranque = _datos(inicial);
  } catch (e) {
    debugPrint('Push: $e');
  }
}

/// data del mensaje + título y texto de la parte "notification" (si no vienen ya en data).
Map<String, dynamic> _datos(RemoteMessage m) => {
  ...m.data,
  if (m.notification?.title != null && m.data['titulo'] == null) 'titulo': m.notification!.title,
  if (m.notification?.body != null && m.data['cuerpo'] == null) 'cuerpo': m.notification!.body};

// Ids 900000-989999: no chocan con las alarmas de tomas (700000-809999, ver MainActivity.kt).
int _idPush(RemoteMessage m) => 900000 + (m.messageId ?? '${m.sentTime ?? DateTime.now()}').hashCode.abs() % 90000;

void _enPrimerPlano(RemoteMessage m) {
  final d = _datos(m);
  _llegadas.add(d);
  final titulo = d['titulo']?.toString();
  // iOS ya lo muestra solo si trae "notification"; Android nunca en primer plano.
  if (titulo == null || (defaultTargetPlatform == TargetPlatform.iOS && m.notification != null)) return;
  mostrarPush(_idPush(m), titulo, d['cuerpo']?.toString() ?? '', d);
}

/// App en segundo plano o cerrada (corre en otro isolate). Los mensajes con "notification" ya los muestra
/// el sistema; aquí solo se muestran los de solo datos que traen data.titulo.
@pragma('vm:entry-point')
Future<void> _pushEnSegundoPlano(RemoteMessage m) async {
  if (m.notification != null) return;
  final titulo = m.data['titulo']?.toString(); if (titulo == null) return;
  await mostrarPush(_idPush(m), titulo, m.data['cuerpo']?.toString() ?? '', _datos(m));
}

String? _registrado; Future<void>? _enCurso;

/// POST /dispositivos {token_fcm, plataforma} con la sesión actual. Se puede llamar varias veces
/// (inicio de sesión, restaurar sesión, token renovado): solo envía si el token cambió.
Future<void> registrarDispositivoPush(Api api) => _enCurso ??= _registrar(api).whenComplete(() => _enCurso = null);

Future<void> _registrar(Api api) async {
  final plataforma = switch (defaultTargetPlatform) { TargetPlatform.iOS => 'ios', TargetPlatform.android => 'android', _ => null };
  if (!_activo || plataforma == null) return;
  try {
    final fm = FirebaseMessaging.instance;
    await fm.requestPermission(); // si lo niega se registra igual: puede activarlo después en Ajustes
    if (plataforma == 'ios') { // iOS entrega el token de FCM después del de Apple (APNs)
      for (var i = 0; i < 10 && await fm.getAPNSToken() == null; i++) { await Future.delayed(const Duration(milliseconds: 500)); }
    }
    final token = await fm.getToken();
    if (token == null || token == _registrado) return;
    if (kDebugMode) debugPrint('Token FCM (para enviar una prueba desde la consola de Firebase): $token');
    await api.registrarDispositivo(token, plataforma);
    _registrado = token;
  } catch (e) {
    debugPrint('Push no disponible: $e');
  }
}

/// Al cerrar sesión (o si la sesión expira): este teléfono deja de recibir los avisos de esa cuenta.
/// En el siguiente inicio de sesión Firebase crea otro token y se registra de nuevo.
Future<void> olvidarDispositivoPush() async {
  _registrado = null;
  if (!_activo) return;
  try { await FirebaseMessaging.instance.deleteToken(); } catch (_) {}
}

/// Pantalla que abre un push según data.tipo (propuesta para backend en docs/NOTIFICACIONES.md).
/// [pestana]: es una pestaña de la barra inferior (se navega con go, no se apila).
({String ruta, bool pestana}) rutaDePush(Map<String, dynamic> d, Role rol) => switch ('${d['tipo'] ?? ''}') {
  'alerta' when rol == Role.equipo => (ruta: '/cola', pestana: true),
  'alerta' when rol == Role.cuidador => (ruta: '/alertas', pestana: true),
  'toma' || 'recordatorio' || 'horarios' when rol == Role.paciente => (ruta: '/hoy', pestana: true),
  'toma' || 'recordatorio' || 'horarios' || 'receta' || 'medicamentos' when rol != Role.equipo => (ruta: '/medicamentos', pestana: true),
  'herida' when rol != Role.equipo => (ruta: '/heridas', pestana: false),
  _ => (ruta: '/notificaciones', pestana: false) };

/// Envuelve la app (junto a VigilanteTomas): registra el teléfono al tener sesión, lo olvida al cerrarla,
/// recarga alertas cuando llega un push y abre la pantalla del push que se tocó.
class ReceptorPush extends ConsumerStatefulWidget {
  final Widget child;
  /// Navega a [ruta]; [extra] para pantallas de detalle, [pestana] para las de la barra inferior.
  final void Function(String ruta, {Object? extra, bool pestana}) abrir;
  /// Ya se puede navegar (no estamos en splash ni login).
  final bool Function() listo;
  const ReceptorPush({super.key, required this.child, required this.abrir, required this.listo});
  @override ConsumerState<ReceptorPush> createState() => _ReceptorState();
}

class _ReceptorState extends ConsumerState<ReceptorPush> {
  final _subs = <StreamSubscription>[];
  Map<String, dynamic>? _pendiente;

  @override
  void initState() {
    super.initState();
    _pendiente = _deArranque; _deArranque = null;
    _subs
      ..add(_llegadas.stream.listen((_) => _recargar()))
      ..add(_toques.stream.listen((d) { _pendiente = d; _recargar(); _abrirPendiente(); }))
      ..add(_renovados.stream.listen((_) { if (ref.read(sessionProvider) != null) registrarDispositivoPush(ref.read(apiProvider)); }));
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _alCambiarSesion(null, ref.read(sessionProvider)); });
  }

  @override
  void dispose() { for (final s in _subs) { s.cancel(); } super.dispose(); }

  void _alCambiarSesion(Session? antes, Session? ahora) {
    if (ahora != null && antes?.userId != ahora.userId) { _conSesion(); }
    else if (ahora == null && antes != null) { olvidarDispositivoPush(); }
  }

  Future<void> _conSesion() async {
    await pedirPermisoNotificaciones(); // Android 13+ e iOS: una sola vez, ya con sesión
    if (!mounted) return;
    await registrarDispositivoPush(ref.read(apiProvider));
    // Espera a que el router salga de splash/login antes de abrir el push que abrió la app.
    Future.delayed(const Duration(seconds: 1), () { if (mounted) _abrirPendiente(); });
  }

  void _recargar() {
    if (ref.read(sessionProvider) == null) return;
    ref.invalidate(notificacionesProvider);
    for (final k in ['alertas', 'pacientes', 'horarios', 'meds']) { ref.invalidate(futureFor(k)); }
  }

  Future<void> _abrirPendiente() async {
    final d = _pendiente; final s = ref.read(sessionProvider);
    if (d == null || s == null || !widget.listo()) return;
    _pendiente = null;
    // Cuidador con varios familiares: pasa al paciente del aviso.
    final pid = d['paciente_id']?.toString();
    if (pid != null && s.role == Role.cuidador && s.pacientesACargo.any((p) => '${p['id']}' == pid)) {
      ref.read(sessionProvider.notifier).elegirPaciente(pid);
    }
    // Alerta concreta: abre su detalle si todavía está en la lista.
    if ('${d['tipo']}' == 'alerta' && d['alerta_id'] != null && s.role != Role.paciente) {
      try {
        final a = ((await ref.read(apiProvider).alertas()) as List).whereType<Map>()
            .where((a) => '${a['id']}' == '${d['alerta_id']}').firstOrNull;
        if (a != null && mounted) { widget.abrir('/alerta/${a['id']}', extra: a); return; }
      } catch (_) {}
    }
    if (!mounted) return;
    final r = rutaDePush(d, s.role);
    widget.abrir(r.ruta, pestana: r.pestana);
  }

  @override
  Widget build(BuildContext c) {
    ref.listen<Session?>(sessionProvider, _alCambiarSesion);
    return widget.child;
  }
}
