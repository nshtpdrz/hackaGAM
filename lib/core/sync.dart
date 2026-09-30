import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'almacen_local.dart';
import 'api.dart';
import 'api_modelos.dart';
import 'state.dart';
import 'tr.dart';

bool isNetworkError(Object e) => e is DioException && (e.type == DioExceptionType.connectionError ||
    e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout ||
    e.type == DioExceptionType.receiveTimeout);

/// Solo demo: fuerza "sin conexión" (ver switch en la pantalla de sincronización).
final simOfflineProvider = StateProvider<bool>((_) => false);

final _netProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool ok(List<ConnectivityResult> r) => r.any((e) => e != ConnectivityResult.none);
  yield ok(await c.checkConnectivity());
  yield* c.onConnectivityChanged.map(ok);
});
final onlineProvider = Provider<bool>((ref) => !ref.watch(simOfflineProvider) && (ref.watch(_netProvider).valueOrNull ?? true));

/// Registro o toma guardado en el teléfono para enviarse después. [usuario]: cuenta que lo creó
/// (solo se envía con esa sesión). [motivo]: por qué la API lo rechazó (solo en rechazadas).
class PendingOp {
  final int id; final String tipo, pacienteId, usuario; final Map<String, dynamic> payload; final DateTime creado;
  int intentos; String? motivo;
  PendingOp(this.id, this.tipo, this.pacienteId, this.payload, this.creado, {this.usuario = '', this.intentos = 0, this.motivo});
  Map<String, dynamic> toJson() => {'id': id, 'tipo': tipo, 'paciente': pacienteId, 'usuario': usuario, 'payload': payload,
      'creado': creado.toIso8601String(), 'intentos': intentos, if (motivo != null) 'motivo': motivo};
  static PendingOp? fromJson(Object? j) {
    if (j is! Map || j['payload'] is! Map) return null;
    return PendingOp(j['id'] is int ? j['id'] : 0, '${j['tipo']}', '${j['paciente']}',
        Map<String, dynamic>.from(j['payload'] as Map), DateTime.tryParse('${j['creado']}') ?? DateTime.now(),
        usuario: '${j['usuario'] ?? ''}', intentos: j['intentos'] is int ? j['intentos'] : 0, motivo: j['motivo']?.toString());
  }
}

class SyncState {
  /// [cola] y [rechazadas] son solo las de la cuenta con sesión.
  final List<PendingOp> cola, rechazadas; final bool sincronizando; final DateTime? ultima; final String? error;
  const SyncState({this.cola = const [], this.rechazadas = const [], this.sincronizando = false, this.ultima, this.error});
  SyncState copy({List<PendingOp>? cola, List<PendingOp>? rechazadas, bool? sincronizando, DateTime? ultima, String? error, bool clearError = false}) =>
      SyncState(cola: cola ?? this.cola, rechazadas: rechazadas ?? this.rechazadas, sincronizando: sincronizando ?? this.sincronizando,
          ultima: ultima ?? this.ultima, error: clearError ? null : (error ?? this.error));
}

/// Qué hacer con una operación que falló al enviarse.
enum FallaEnvio {
  /// Ya estaba en el servidor (409): se quita de la cola como enviada.
  yaEnviada,
  /// Red, servidor caído, 408, 429, 5xx o sesión expirada: se queda y se reintenta más tarde.
  reintentar,
  /// La API la rechazó (400, 403, 404, 422…): reenviarla daría lo mismo. Se aparta y se avisa.
  rechazada }

FallaEnvio clasificarFalla(Object e) {
  if (isNetworkError(e)) return FallaEnvio.reintentar;
  if (e is DioException && e.response == null) return FallaEnvio.reintentar;
  final x = errorApi(e);
  if (x == null) return FallaEnvio.rechazada; // error de la app al armar o leer el envío: reintentar no lo arregla
  final s = x.estado ?? 0;
  if (s == 409) return FallaEnvio.yaEnviada;
  if (s == 401 || s == 408 || s == 429 || s >= 500) return FallaEnvio.reintentar;
  return FallaEnvio.rechazada;
}

/// Cola local de operaciones pendientes ('registro' | 'toma'). Se guarda en el teléfono (almacen_local.dart):
/// sobrevive a cerrar la app y a que Android la termine. Cada lote lleva id_local, así que reenviarlo no lo duplica.
class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier(this.ref, {AlmacenLocal? almacenLocal}) : _al = almacenLocal ?? almacen, super(const SyncState()) {
    _listo = _cargar();
  }
  final Ref ref; final AlmacenLocal _al;
  late final Future<void> _listo;
  List<PendingOp> _todas = [], _rechazadasTodas = [];
  String? _usuario; bool _busy = false; Timer? _reintento;
  static const cadaReintento = Duration(minutes: 2);

  /// Espera a que termine de leer la cola guardada.
  Future<void> get listo => _listo;

  Future<void> _cargar() async {
    List<PendingOp> leer(Object? v) => [for (final j in v is List ? v : const []) if (PendingOp.fromJson(j) case final o?) o];
    _todas = [...leer(await _al.leer('senda.cola')), ..._todas];
    _rechazadasTodas = [...leer(await _al.leer('senda.rechazadas')), ..._rechazadasTodas];
    _publicar();
  }

  Future<void> _guardar() async {
    await _al.guardar('senda.cola', [for (final o in _todas) o.toJson()]);
    await _al.guardar('senda.rechazadas', [for (final o in _rechazadasTodas) o.toJson()]);
  }

  void _publicar() {
    if (!mounted) return;
    bool mia(PendingOp o) => o.usuario == (_usuario ?? '');
    state = state.copy(cola: _todas.where(mia).toList(), rechazadas: _rechazadasTodas.where(mia).toList());
    // Mientras haya pendientes se reintenta cada pocos minutos (p. ej. hay Wi-Fi pero el servidor estaba caído).
    if (state.cola.isEmpty) { _reintento?.cancel(); _reintento = null; }
    else { _reintento ??= Timer.periodic(cadaReintento, (_) { if (ref.read(onlineProvider)) flush(); }); }
  }

  /// La sesión cambió: se muestran y envían solo las operaciones de esa cuenta.
  Future<void> cambiarUsuario(String? usuario) async {
    _usuario = usuario; await _listo; _publicar();
    if (usuario != null && ref.read(onlineProvider)) await flush();
  }

  Future<void> encolar(String tipo, String pacienteId, Map<String, dynamic> payload) async {
    await _listo;
    final id = [..._todas, ..._rechazadasTodas].fold(0, (m, o) => o.id > m ? o.id : m) + 1;
    _todas = [..._todas, PendingOp(id, tipo, pacienteId, payload, DateTime.now(), usuario: _usuario ?? '')];
    _publicar(); await _guardar();
  }

  /// Una rechazada se descarta (la persona ya lo sabe) o se regresa a la cola para intentar otra vez.
  Future<void> descartar(PendingOp op) async {
    _rechazadasTodas = _rechazadasTodas.where((o) => o.id != op.id).toList(); _publicar(); await _guardar();
  }
  Future<void> reintentarRechazada(PendingOp op) async {
    _rechazadasTodas = _rechazadasTodas.where((o) => o.id != op.id).toList();
    _todas = [..._todas, op..motivo = null]; _publicar(); await _guardar(); await flush();
  }

  Future<void> flush() async {
    await _listo;
    if (!mounted || _busy || _usuario == null || state.cola.isEmpty) return;
    _busy = true; state = state.copy(sincronizando: true, clearError: true);
    final api = ref.read(apiProvider); String? error;
    for (final op in [...state.cola]) {
      try {
        if (op.tipo == 'registro') { await api.crearRegistro(op.pacienteId, op.payload); }
        else { await api.registrarToma(op.pacienteId, op.payload); }
        _todas = _todas.where((o) => o.id != op.id).toList();
      } catch (e) {
        op.intentos++;
        final f = clasificarFalla(e);
        if (f == FallaEnvio.yaEnviada) { _todas = _todas.where((o) => o.id != op.id).toList(); }
        else if (f == FallaEnvio.rechazada) {
          // Se aparta para no detener lo que sigue en la cola.
          _todas = _todas.where((o) => o.id != op.id).toList();
          _rechazadasTodas = [..._rechazadasTodas, op..motivo = mensajeError(e) ?? tr('Error al enviar')];
          error = tr('Algunos datos no se pudieron enviar');
        } else {
          // Sin red o servidor caído: lo demás también fallaría. Se reintenta después.
          error = isNetworkError(e) ? tr('Sin conexión') : tr('Error al enviar');
          break;
        }
      }
      _publicar(); await _guardar();
    }
    _busy = false;
    await _guardar();
    if (!mounted) return;
    _publicar();
    state = state.copy(sincronizando: false, error: error, ultima: error == null ? DateTime.now() : null);
  }

  @override
  void dispose() { _reintento?.cancel(); super.dispose(); }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final n = SyncNotifier(ref);
  ref.listen<bool>(onlineProvider, (_, online) { if (online) n.flush(); });
  ref.listen<String?>(sessionProvider.select((s) => s?.userId), (_, u) => n.cambiarUsuario(u), fireImmediately: true);
  // Al volver la app a primer plano también se intenta enviar.
  AppLifecycleListener? ciclo;
  try { ciclo = AppLifecycleListener(onResume: () { if (ref.read(onlineProvider)) n.flush(); }); } catch (_) {}
  ref.onDispose(() => ciclo?.dispose());
  return n;
});
