import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medmap/core/almacen_local.dart';
import 'package:medmap/core/api.dart';
import 'package:medmap/core/state.dart';
import 'package:medmap/core/sync.dart';

/// Responde según `payload['r']`: ok | 409 | 422 | red.
class _Api extends Api {
  final enviados = <String>[];
  @override
  Future<Map<String, dynamic>> crearRegistro(String id, Map<String, dynamic> lote) async {
    final r = '${lote['r']}';
    if (r == 'red') throw DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError);
    if (r != 'ok') {
      throw DioException(requestOptions: RequestOptions(), type: DioExceptionType.badResponse,
          response: Response(requestOptions: RequestOptions(), statusCode: int.parse(r), data: {'error': {'codigo': 'x'}}));
    }
    enviados.add('${lote['n']}');
    return {};
  }
}

class _Ses extends SessionNotifier { _Ses(super.ref, String u) { state = Session('t', u, Role.paciente, '1'); } }

ProviderContainer _contenedor(_Api api, {String usuario = 'u1'}) => ProviderContainer(overrides: [
  apiProvider.overrideWithValue(api),
  sessionProvider.overrideWith((ref) => _Ses(ref, usuario)),
  onlineProvider.overrideWithValue(true)]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('clasificarFalla: 409 ya enviada, red/5xx/401 reintentar, otro 4xx rechazada', () {
    DioException con(int s) => DioException(requestOptions: RequestOptions(), type: DioExceptionType.badResponse,
        response: Response(requestOptions: RequestOptions(), statusCode: s));
    expect(clasificarFalla(con(409)), FallaEnvio.yaEnviada);
    for (final s in [401, 408, 429, 500, 503]) { expect(clasificarFalla(con(s)), FallaEnvio.reintentar); }
    for (final s in [400, 403, 404, 422]) { expect(clasificarFalla(con(s)), FallaEnvio.rechazada); }
    expect(clasificarFalla(DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionTimeout)), FallaEnvio.reintentar);
  });

  test('un rechazo no bloquea la cola y todo sobrevive a cerrar la app', () async {
    final api = _Api(); var c = _contenedor(api);
    var n = c.read(syncProvider.notifier); await n.listo;
    await n.encolar('registro', '1', {'r': '422', 'n': 'a'});
    await n.encolar('registro', '1', {'r': 'ok', 'n': 'b'});
    await n.encolar('registro', '1', {'r': '409', 'n': 'c'});
    await n.encolar('registro', '1', {'r': 'red', 'n': 'd'});
    await n.flush();
    expect(api.enviados, ['b']);
    expect(c.read(syncProvider).cola.map((o) => o.payload['n']), ['d']); // sin red: se queda
    expect(c.read(syncProvider).rechazadas.map((o) => o.payload['n']), ['a']);
    c.dispose();

    // "Se cierra la app": otro contenedor lee lo guardado.
    c = _contenedor(api); n = c.read(syncProvider.notifier); await n.listo;
    expect(c.read(syncProvider).cola.single.payload['n'], 'd');
    final rech = c.read(syncProvider).rechazadas.single;
    expect(rech.motivo, isNotEmpty);
    await n.descartar(rech);
    expect(c.read(syncProvider).rechazadas, isEmpty);
    c.dispose();
  });

  test('otra cuenta no ve ni envía la cola de la anterior', () async {
    final api = _Api(); var c = _contenedor(api);
    var n = c.read(syncProvider.notifier); await n.listo;
    await n.encolar('registro', '1', {'r': 'red', 'n': 'x'});
    c.dispose();
    c = _contenedor(api, usuario: 'u2'); n = c.read(syncProvider.notifier); await n.listo;
    await n.flush();
    expect(c.read(syncProvider).cola, isEmpty);
    c.dispose();
    expect(await almacen.leer('senda.cola'), hasLength(1)); // sigue guardada para u1
  });

  test('cerrar sesión borra los datos de la cuenta; si expira, se conservan', () async {
    FlutterSecureStorage.setMockInitialValues({'jwt': 't'});
    await almacen.guardar(claveDeUsuario('u1', 'tomas'), {'a': 1});
    await almacen.guardar(claveDeUsuario('u2', 'tomas'), {'b': 1});
    final c = _contenedor(_Api());
    await c.read(sessionProvider.notifier).logout(expirada: true);
    expect(await almacen.leer(claveDeUsuario('u1', 'tomas')), isNotNull);
    c.dispose();

    final c2 = _contenedor(_Api());
    await c2.read(sessionProvider.notifier).logout();
    expect(c2.read(sessionProvider), isNull);
    expect(await readToken(), isNull);
    expect(await almacen.leer(claveDeUsuario('u1', 'tomas')), isNull);
    expect(await almacen.leer(claveDeUsuario('u2', 'tomas')), isNotNull);
    c2.dispose();
  });

  test('preferencias: se guardan completas en el teléfono', () async {
    const p = Prefs(lang: 'en', highContrast: true, bigButtons: true, pictograms: true, textScale: 1.6);
    await guardarPrefs(p);
    final l = await leerPrefsGuardadas();
    expect((l.lang, l.highContrast, l.bigButtons, l.pictograms, l.textScale), ('en', true, true, true, 1.6));
    expect(Prefs.fromLocal('basura').lang, 'es');
  });
}
