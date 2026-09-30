import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api.dart';
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

class PendingOp {
  final int id; final String tipo, pacienteId; final Map<String, dynamic> payload; final DateTime creado; int intentos = 0;
  PendingOp(this.id, this.tipo, this.pacienteId, this.payload, this.creado);
}

class SyncState {
  final List<PendingOp> cola; final bool sincronizando; final DateTime? ultima; final String? error;
  const SyncState({this.cola = const [], this.sincronizando = false, this.ultima, this.error});
  SyncState copy({List<PendingOp>? cola, bool? sincronizando, DateTime? ultima, String? error, bool clearError = false}) =>
      SyncState(cola: cola ?? this.cola, sincronizando: sincronizando ?? this.sincronizando,
          ultima: ultima ?? this.ultima, error: clearError ? null : (error ?? this.error));
}

/// Cola local de operaciones pendientes ('registro' | 'toma').
/// NOTA: hoy vive en memoria; la persistencia con Drift se conecta detrás de esta misma interfaz.
class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier(this.ref) : super(const SyncState());
  final Ref ref; int _seq = 0; bool _busy = false;

  void encolar(String tipo, String pacienteId, Map<String, dynamic> payload) =>
      state = state.copy(cola: [...state.cola, PendingOp(++_seq, tipo, pacienteId, payload, DateTime.now())]);

  Future<void> flush() async {
    if (_busy || state.cola.isEmpty) return;
    _busy = true; state = state.copy(sincronizando: true, clearError: true);
    final api = ref.read(apiProvider);
    for (final op in [...state.cola]) {
      try {
        if (op.tipo == 'registro') { await api.crearRegistro(op.pacienteId, op.payload); }
        else { await api.registrarToma(op.pacienteId, op.payload); }
        state = state.copy(cola: state.cola.where((o) => o.id != op.id).toList());
      } catch (e) {
        op.intentos++;
        state = state.copy(sincronizando: false, error: isNetworkError(e) ? tr('Sin conexión') : tr('Error al enviar'));
        _busy = false; return;
      }
    }
    state = state.copy(sincronizando: false, ultima: DateTime.now()); _busy = false;
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final n = SyncNotifier(ref);
  ref.listen<bool>(onlineProvider, (_, online) { if (online) n.flush(); });
  return n;
});
