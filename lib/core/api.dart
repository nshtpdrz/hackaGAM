import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_modelos.dart';
import 'mock_api.dart';

/// Único punto de salida de red. Base: /api/v1 (Node.js + Express). Ver "Guía de conexión del frontend".
/// La app NUNCA habla con PostgreSQL, IA ni servicios externos. Todas las respuestas pasan por
/// api_modelos.dart para convertirlas al formato de las pantallas.
///
///   Teléfono por USB:  flutter run --dart-define=API_URL=http://localhost:3000/api/v1   (y adb reverse tcp:3000 tcp:3000)
///   Emulador Android:  --dart-define=API_URL=http://10.0.2.2:3000/api/v1
///   Sin API_URL la app arranca en modo demo (mock_api.dart), con las mismas formas de respuesta que la API.
const apiUrl = String.fromEnvironment('API_URL', defaultValue: String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3000/api/v1'));
const _store = FlutterSecureStorage();

Future<String?> readToken() => _store.read(key: 'jwt');
Future<void> saveToken(String? t) => t == null ? _store.delete(key: 'jwt') : _store.write(key: 'jwt', value: t);

class Api {
  final Dio _d = Dio(BaseOptions(baseUrl: apiUrl, connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 40))); // la lectura de recetas con Azure tarda ~10 s
  void Function()? onUnauthorized;
  Api() {
    if (useMock) _d.interceptors.add(MockInterceptor());
    _d.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) async {
        final t = await readToken();
        if (t != null) o.headers['Authorization'] = 'Bearer $t';
        h.next(o);
      },
      onError: (e, h) {
        // 401 (sin_sesion, sesion_invalida, usuario_inactivo): borrar token y volver al inicio de sesión.
        // El 401 del propio login son credenciales incorrectas: no cierra nada.
        if (e.response?.statusCode == 401 && e.requestOptions.path != '/auth/login') onUnauthorized?.call();
        h.next(e);
      }));
  }
  Future<dynamic> _get(String p, [Map<String, dynamic>? q]) async =>
      (await _d.get(p, queryParameters: q?..removeWhere((_, v) => v == null))).data;
  Future<dynamic> _post(String p, [dynamic b]) async => (await _d.post(p, data: b)).data;
  Future<dynamic> _put(String p, dynamic b) async => (await _d.put(p, data: b)).data;
  Future<dynamic> _patch(String p, dynamic b) async => (await _d.patch(p, data: b)).data;

  /// Recorre una lista paginada (?limite=&cursor= -> siguiente_cursor) hasta [maxPaginas].
  Future<List> _todas(String p, Map<String, dynamic> q, {List<String> claves = const [], int maxPaginas = 10}) async {
    final out = []; String? cursor;
    for (var i = 0; i < maxPaginas; i++) {
      final r = await _get(p, {...q, if (cursor != null) 'cursor': cursor});
      out.addAll(lista(r, claves)); cursor = siguienteCursor(r);
      if (cursor == null) break;
    }
    return out;
  }

  // Sesión
  Future<dynamic> salud() => _get('/salud');
  /// -> {token, expira_en_horas, usuario{id, nombre, rol}}
  Future<dynamic> login(String correo, String contrasena) => _post('/auth/login', {'correo': correo, 'contrasena': contrasena});
  /// -> {id, rol (navegación), rol_api, pacientes_a_cargo, paciente_id, preferencias, ...}
  Future<Map<String, dynamic>> yo() async => normalizarYo(await _get('/auth/yo'));
  /// Push: después del login. {token_fcm, plataforma: android|ios}
  Future<dynamic> registrarDispositivo(String tokenFcm, String plataforma) =>
      _post('/dispositivos', {'token_fcm': tokenFcm, 'plataforma': plataforma});
  /// Catálogo de textos para el paciente (sin token): lengua ISO 639-3 y variante.
  Future<List<Map<String, dynamic>>> mensajes(String lang, {String? variante}) async =>
      normalizarMensajes(await _get('/mensajes', {'lengua': lenguaApi[lang] ?? lang, if (lang == 'ote') 'variante': variante}));
  Future<dynamic> avisoPrivacidad() => _get('/aviso-privacidad');

  // Pacientes y expediente
  /// Tablero del equipo (rojos primero, con alertas_abiertas).
  Future<List<Map<String, dynamic>>> pacientes({String? q, String? semaforo, String? programa}) async =>
      normalizarPacientes(await _todas('/pacientes', {'q': q, 'semaforo': semaforo, 'programa': programa, 'limite': 50},
          claves: ['pacientes'], maxPaginas: 4));
  /// Alta (enfermera, médico): devuelve paciente + codigo_qr + credenciales temporales (una sola vez).
  Future<Map<String, dynamic>> crearPaciente(Map<String, dynamic> datos, {String? versionAviso}) async {
    final r = await _post('/pacientes', altaPacienteParaApi(datos, versionAviso: versionAviso));
    return {...(r is Map ? r.cast<String, dynamic>() : {}), ...normalizarPaciente(r), 'codigo_qr': normalizarQr(r)['token']};
  }
  Future<Map<String, dynamic>> paciente(String id) async => normalizarPaciente(await _get('/pacientes/$id'));
  /// PUT preferencias: {lengua, variante, prefiere_audio, letra, contraste}
  Future<dynamic> guardarPreferencias(String id, Map<String, dynamic> p) => _put('/pacientes/$id/preferencias', p);
  Future<Map<String, dynamic>> plan(String id) async => normalizarPlan(await _get('/pacientes/$id/plan'));
  /// Médico: [{programa_paciente_id, variable, min?, max?, frecuencia?, meta?}]
  Future<dynamic> guardarPlan(String id, dynamic b) => _put('/pacientes/$id/plan', b);
  Future<dynamic> consentimiento(String id, String version) =>
      _post('/pacientes/$id/consentimientos', {'version': version, 'aceptado': true});
  /// Médico: {resumen: {texto} | null, datos}
  Future<dynamic> resumen(String id, {int dias = 14}) => _get('/pacientes/$id/resumen', {'dias': dias});

  // Registros (mediciones y síntomas)
  /// Serie para historial y gráficas: presión y glucosa de los últimos [dias].
  Future<List<Map<String, dynamic>>> registros(String id, {int dias = 180, List<String> variables = const ['presion', 'glucosa']}) async {
    final desde = DateTime.now().subtract(Duration(days: dias)).toUtc().toIso8601String();
    final out = <Map<String, dynamic>>[];
    for (final v in variables) {
      out.addAll(normalizarRegistros(await _todas('/pacientes/$id/registros', {'variable': v, 'desde': desde, 'limite': 200},
          claves: ['registros'])));
    }
    return out;
  }
  /// Lote {registros:[{id_local, tipo, variable, valor_num?, valor_num2?, escala?, tomado_en}]} (un lote = un episodio).
  /// Reenviar el mismo lote con el mismo id_local no duplica (repetido: true).
  Future<Map<String, dynamic>> crearRegistro(String id, Map<String, dynamic> lote) async =>
      normalizarResultado(await _post('/pacientes/$id/registros', lote));

  // Horarios y tomas
  /// Tomas de hoy en formato de pantalla (ver normalizarHorarios).
  Future<List<Map<String, dynamic>>> horarios(String id) async => normalizarHorarios(await _get('/pacientes/$id/horarios'));
  /// Lote de loteToma(). "pospuesta" no existe en la API: se queda en el teléfono.
  Future<dynamic> registrarToma(String id, Map<String, dynamic> lote) async {
    if (lote['tomas'] == null) lote = loteToma({'id': lote['toma_id'], ...lote}, '${lote['estado']}');
    final tomas = [for (final t in lote['tomas'] as List) if (t is Map && t['estado'] != 'pospuesta') t];
    if (tomas.isEmpty) return {'local': true};
    return _post('/pacientes/$id/tomas', {'tomas': tomas});
  }
  Future<Map<String, dynamic>> adherencia(String id, {int dias = 14}) async =>
      normalizarAdherencia(await _get('/pacientes/$id/tomas', {'dias': dias}));

  // Medicamentos y MEDMAP
  Future<List<Map<String, dynamic>>> medicamentos(String id) async =>
      normalizarMedicamentos(await _get('/pacientes/$id/medicamentos', {'activos': true}));
  /// Para el equipo: lista + cruces (alertas_medicacion con fuente y cita, rojo primero).
  Future<Map<String, dynamic>> medicamentosConAlertas(String id) async {
    final r = await _get('/pacientes/$id/medicamentos', {'activos': true});
    return {'medicamentos': normalizarMedicamentos(r), 'alertas_medicacion': alertasMedicacion(r)};
  }
  /// Foto (campo "archivo") y/o transcripción ("texto"), y tipo receta|caja|estudio. Devuelve la propuesta; no guarda nada.
  Future<Map<String, dynamic>> subirDocumento(String id, {Uint8List? bytes, String? nombre, String? texto, String tipo = 'receta'}) async =>
      normalizarDocumento(await _post('/pacientes/$id/documentos', FormData.fromMap({'tipo': tipo,
        if (bytes != null) 'archivo': MultipartFile.fromBytes(bytes, filename: nombre ?? 'receta.jpg',
            contentType: DioMediaType('image', (nombre ?? '').toLowerCase().endsWith('.png') ? 'png' : 'jpeg')),
        if (texto != null && texto.trim().isNotEmpty) 'texto': texto.trim()})));
  /// Lo que la persona revisó -> medicamentos y horarios guardados. Luego hay que volver a pedir /horarios.
  Future<dynamic> confirmarDocumento(String docId, List medicamentos) =>
      _post('/documentos/$docId/confirmar', confirmacionDocumento(medicamentos));

  // QR y alertas
  Future<Map<String, dynamic>> qr(String id) async => normalizarQr(await _get('/pacientes/$id/qr'));
  /// Equipo: paciente identificado por su QR (queda en bitácora).
  Future<Map<String, dynamic>> qrCodigo(String codigo) async {
    final r = await _get('/qr/$codigo');
    return {'paciente_id': pacienteDeQr(r), 'paciente': normalizarPaciente(r)};
  }
  Future<List<Map<String, dynamic>>> alertas({String estado = 'abierta'}) async =>
      normalizarAlertas(await _todas('/alertas', {'estado': estado, 'limite': 50}, claves: ['alertas'], maxPaginas: 4));
  /// {accion} obligatoria. 409 si ya estaba atendida. El cuidador solo atiende las ámbar.
  Future<dynamic> atenderAlerta(String id, String accion) => _patch('/alertas/$id', {'accion': accion});

  // ---- Funciones de la app que la guía del backend todavía NO incluye (pendiente de acordar). ----
  // En modo demo responden desde mock_api.dart; con la API real devuelven 404 y la app lo avisa.
  Future<dynamic> registro(Map<String, dynamic> b) => _post('/auth/registro', b);
  Future<dynamic> actualizarYo(Map<String, dynamic> b) => _patch('/auth/yo', b);
  Future<dynamic> subirFotoPerfil(Uint8List bytes, String nombre) =>
      _post('/auth/yo/foto', FormData.fromMap({'foto': MultipartFile.fromBytes(bytes, filename: nombre)}));
  Future<dynamic> qrRegistro(String codigo) => _get('/registro/qr/$codigo');
  Future<dynamic> clinicas() => _get('/clinicas');
  Future<dynamic> actualizarPaciente(String id, Map<String, dynamic> b) => _patch('/pacientes/$id', b);
}

final apiProvider = Provider<Api>((_) => Api());
