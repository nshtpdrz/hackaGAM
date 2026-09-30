import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/shared.dart';
import 'almacen_local.dart';
import 'reminders.dart';
import 'state.dart';

// Alarma de tomas dentro de la app (también en web, donde no hay notificaciones locales):
// revisa cada 20 s los horarios del paciente y, cuando llega la hora de una toma pendiente o pospuesta,
// abre /recordatorio en modo alarma (sonido en bucle, vibración y voz). Además mantiene programadas
// las alarmas del sistema (reminders.dart) y abre la toma cuando se toca una notificación.

/// Textos de cada estado (en español; se traducen con tr() al mostrarlos).
const etiquetasEstado = {'pendiente': 'Pendiente', 'tomada': 'Tomada', 'omitida': 'Omitida', 'pospuesta': 'Pospuesta'};

/// Respuesta dada en este teléfono hoy (la API solo guarda tomada|omitida; "Más tarde" es local).
class EstadoLocal {
  final String estado; final DateTime? hasta; final String dia;
  EstadoLocal(this.estado, {this.hasta, String? dia}) : dia = dia ?? _hoy(DateTime.now());
  Map<String, dynamic> toJson() => {'estado': estado, 'dia': dia, if (hasta != null) 'hasta': hasta!.toIso8601String()};
  static EstadoLocal? fromJson(Object? j) => j is Map && j['estado'] is String && j['dia'] is String
      ? EstadoLocal('${j['estado']}', dia: '${j['dia']}', hasta: DateTime.tryParse('${j['hasta'] ?? ''}')) : null;
}
String _hoy(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Se guarda en el teléfono por cuenta (almacen_local.dart): al reabrir la app, una toma pospuesta
/// sigue pospuesta y la alarma interna no vuelve a sonar. Solo se conservan las respuestas de hoy.
class TomasLocales extends StateNotifier<Map<String, EstadoLocal>> {
  TomasLocales([this.usuario]) : super({}) { _cargar(); }
  final String? usuario;
  String? get _clave => usuario == null ? null : claveDeUsuario(usuario!, 'tomas');

  Future<void> _cargar() async {
    final k = _clave; if (k == null) return;
    final j = await almacen.leer(k); if (j is! Map || !mounted) return;
    final hoy = _hoy(DateTime.now());
    final guardadas = {for (final e in j.entries) if (EstadoLocal.fromJson(e.value) case final l? when l.dia == hoy) '${e.key}': l};
    state = {...guardadas, ...state}; // lo respondido mientras cargaba gana
  }
  void _poner(Object? id, EstadoLocal l) {
    state = {...state, '$id': l};
    final k = _clave; if (k != null) almacen.guardar(k, {for (final e in state.entries) e.key: e.value.toJson()});
  }
  void tomada(Object? id) => _poner(id, EstadoLocal('tomada'));
  void omitida(Object? id) => _poner(id, EstadoLocal('omitida'));
  void pospuesta(Object? id, Duration en) => _poner(id, EstadoLocal('pospuesta', hasta: DateTime.now().add(en)));
}
final tomasLocalesProvider = StateNotifierProvider<TomasLocales, Map<String, EstadoLocal>>((ref) =>
    TomasLocales(ref.watch(sessionProvider.select((s) => s?.userId)))); // se reinicia al cambiar de cuenta

/// Horarios con el estado respondido hoy en este teléfono encima del de la API.
List<Map> conEstadoLocal(List horarios, Map<String, EstadoLocal> locales, [DateTime? ahora]) {
  final hoy = _hoy(ahora ?? DateTime.now());
  return [for (final h in horarios.whereType<Map>())
    switch (locales['${h['id']}']) { final l? when l.dia == hoy => {...h, 'estado': l.estado}, _ => h }];
}

/// La toma cuya alarma debe sonar ahora (o null). Suena desde su hora (o la hora pospuesta) y hasta
/// 30 min después; [alertadas] evita repetir la misma alarma.
({Map toma, String clave})? tomaQueToca(List horarios, Map<String, EstadoLocal> locales, Set<String> alertadas, DateTime ahora) {
  final hoy = _hoy(ahora);
  for (final h in horarios.whereType<Map>()) {
    final l = locales['${h['id']}']; final local = l != null && l.dia == hoy ? l : null;
    final estado = local?.estado ?? '${h['estado'] ?? 'pendiente'}';
    if (estado != 'pendiente' && estado != 'pospuesta') continue;
    DateTime? cuando = local?.hasta;
    if (cuando == null) {
      try { final t = parseHora('${h['hora']}'); cuando = DateTime(ahora.year, ahora.month, ahora.day, t.hour, t.minute); }
      catch (_) { continue; }
    }
    final pasado = ahora.difference(cuando);
    final clave = '${h['id']}@${cuando.toIso8601String()}';
    if (!pasado.isNegative && pasado < const Duration(minutes: 30) && !alertadas.contains(clave)) {
      return (toma: {...h, 'estado': estado}, clave: clave);
    }
  }
  return null;
}

/// true mientras la pantalla de alarma está abierta (no se abre otra encima).
final alarmaEnCurso = ValueNotifier<bool>(false);

/// Envuelve la app (MaterialApp.router builder). [abrir] navega a /recordatorio con la toma;
/// [listo] dice si ya se puede navegar (p. ej. no estamos en splash ni login).
class VigilanteTomas extends ConsumerStatefulWidget {
  final Widget child; final void Function(Map toma) abrir; final bool Function() listo;
  final Duration cada;
  const VigilanteTomas({super.key, required this.child, required this.abrir, required this.listo,
      this.cada = const Duration(seconds: 20)});
  @override ConsumerState<VigilanteTomas> createState() => _VigilanteState();
}

class _VigilanteState extends ConsumerState<VigilanteTomas> with WidgetsBindingObserver {
  Timer? _timer; final _alertadas = <String>{};
  Map? _pendiente; // toma de una notificación tocada, se abre al tener sesión de paciente
  AppLifecycleState _ciclo = AppLifecycleState.resumed;

  bool get _esPaciente => ref.read(sessionProvider)?.role == Role.paciente;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    alResponderAlarma = (toma, accion) {
      if (accion == accionMasTarde) {
        // Se pospuso desde la notificación con la app abierta: se registra sin abrir la pantalla.
        ref.read(tomasLocalesProvider.notifier).pospuesta(toma['id'], const Duration(minutes: 10));
        // "Más tarde" es local: la API solo acepta tomada|omitida.
        return;
      }
      _pendiente = toma; _abrirPendiente();
    };
    if (tomaDeArranque != null) { _pendiente = tomaDeArranque; tomaDeArranque = null; }
    WidgetsBinding.instance.addPostFrameCallback((_) => _alCambiarSesion());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    alResponderAlarma = null; _timer?.cancel(); super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) { _ciclo = s; if (s == AppLifecycleState.resumed) _revisar(); }

  void _alCambiarSesion() {
    _timer?.cancel(); _timer = null;
    if (!mounted || !_esPaciente) return;
    _timer = Timer.periodic(widget.cada, (_) => _revisar());
    // Espera a que el router salga de splash/login antes de navegar.
    Future.delayed(const Duration(seconds: 1), () { if (mounted) _revisar(); });
  }

  void _abrirPendiente() {
    final t = _pendiente;
    if (t == null || !mounted || !_esPaciente || !widget.listo()) return;
    _pendiente = null;
    widget.abrir({...t}); // tocada desde la notificación: ya sonó, se abre sin repetir el sonido
  }

  Future<void> _revisar() async {
    if (!mounted || !_esPaciente) return;
    _abrirPendiente();
    List horarios;
    try { horarios = (await ref.read(futureFor('horarios').future)) as List; } catch (_) { return; }
    if (!mounted) return;
    programarAlarmasTomas(horarios); // alarmas del sistema (no hace nada si no cambiaron)
    // Con la app en segundo plano en el teléfono suena la alarma del sistema; en web siempre se usa esta.
    if (!kIsWeb && _ciclo != AppLifecycleState.resumed) return;
    if (alarmaEnCurso.value || !widget.listo()) return;
    final r = tomaQueToca(horarios, ref.read(tomasLocalesProvider), _alertadas, DateTime.now());
    if (r == null) return;
    _alertadas.add(r.clave);
    widget.abrir({...r.toma, 'alarma': true});
  }

  @override
  Widget build(BuildContext c) {
    ref.listen(sessionProvider, (a, b) { if (a?.role != b?.role || a?.userId != b?.userId) _alCambiarSesion(); });
    return widget.child;
  }
}
