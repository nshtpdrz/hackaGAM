import 'dart:math';
import 'package:dio/dio.dart';
import 'mediciones.dart';

/// Modo demo: responde sin backend, con las MISMAS formas de respuesta que la API real
/// (Guía de conexión del frontend), para que la app use el mismo código en demo y con servidor.
/// Se activa solo si no se pasa API_URL. Forzar: --dart-define=MOCK=true|false
const useMock = bool.fromEnvironment('MOCK',
    defaultValue: !(bool.hasEnvironment('API_URL') || bool.hasEnvironment('API_BASE')));

/// Usuarios de demo (mismos correos que la semilla del backend; contraseña Demo2026!).
const cuentasDemo = {'paciente': 'maria@demo.invalid', 'cuidador': 'pedro@demo.invalid', 'equipo': 'medica@demo.invalid'};
const contrasenaDemo = 'Demo2026!';

class _ErrorMock implements Exception { final int estado; final String codigo; final Map? campos;
  _ErrorMock(this.estado, this.codigo, [this.campos]); }

class MockInterceptor extends Interceptor {
  static bool offline = false; // demo: simula falta de conexión
  static String _rolApi = 'paciente';
  static String _nombreUsuario = 'María Demo López';

  static final _pacientes = <String, Map<String, dynamic>>{
    '1': {'id': '1', 'perfil': {'nombre': 'María Demo López', 'fecha_nacimiento': '1996-03-12', 'sexo': 'F', 'tipo_sangre': 'O+',
      'alergias': ['Penicilina'], 'telefono': '771 000 0001', 'correo': 'maria@demo.invalid'}, 'semaforo': 'ambar', 'alertas_abiertas': 1,
      'programas': [{'programa': 'embarazo'}], 'cuidadores': [{'nombre': 'Pedro Demo', 'telefono': '771 000 0010', 'parentesco': 'esposo'}],
      'codigo_qr': 'PQR-DEMO-maria-embarazo'},
    '2': {'id': '2', 'perfil': {'nombre': 'Juan Demo Ruiz', 'fecha_nacimiento': '1958-07-02', 'sexo': 'M', 'tipo_sangre': 'A+',
      'alergias': [], 'telefono': '771 000 0002'}, 'semaforo': 'rojo', 'alertas_abiertas': 1,
      'programas': [{'programa': 'cronicas'}, {'programa': 'oncologia'}], 'cuidadores': [{'nombre': 'Rosa Demo', 'telefono': '771 000 0011', 'parentesco': 'sobrina'}],
      'codigo_qr': 'PQR-DEMO-juan-oncologia'},
    '3': {'id': '3', 'perfil': {'nombre': 'Carmen Demo Sánchez', 'fecha_nacimiento': '1954-01-20', 'sexo': 'F', 'tipo_sangre': 'B+',
      'alergias': ['Sulfas (sulfonamidas)'], 'telefono': '771 000 0003'}, 'semaforo': 'verde', 'alertas_abiertas': 0,
      'programas': [{'programa': 'cronicas'}, {'programa': 'adulto_mayor'}], 'cuidadores': [{'nombre': 'Rosa Demo', 'telefono': '771 000 0011', 'parentesco': 'hija'}],
      'codigo_qr': 'PQR-DEMO-carmen-adultomayor'},
  };
  static final Map<String, dynamic> _medico = {'id': 'u-medica', 'nombre': 'Dra. Ana Demo Pérez', 'rol': 'medico', 'correo': 'medica@demo.invalid',
    'telefono': '771 123 4567', 'cedula': 'DEMO-0000001', 'clinica': 'Centro de Salud Ixmiquilpan'};
  static Map<String, dynamic> _prefs = {};

  /// Demo: 180 días de mediciones de María (presión y glucosa) con tendencia a mejorar. Formato de la API.
  static final List<Map<String, dynamic>> _registros = () {
    final rnd = Random(7); final hoy = DateTime.now(); final out = <Map<String, dynamic>>[]; var id = 1;
    Map<String, dynamic> reg(String variable, num v1, [num? v2, DateTime? t]) => {'id': 'r${id++}', 'tipo': 'medicion', 'variable': variable,
      'valor_num': v1, if (v2 != null) 'valor_num2': v2, 'tomado_en': t!.toUtc().toIso8601String(),
      'nivel': variable == 'presion' ? nivelPresion(v1, v2!) : nivelGlucosa(v1)};
    for (var d = 0; d < 180; d++) {
      final dia = DateTime(hoy.year, hoy.month, hoy.day).subtract(Duration(days: d)); final mejora = d / 180;
      if (rnd.nextDouble() < 0.85) {
        final t = dia.add(Duration(hours: 7, minutes: rnd.nextInt(90)));
        out.add(reg('presion', (124 + 24 * mejora + rnd.nextInt(22) - 8).round(), (78 + 12 * mejora + rnd.nextInt(12) - 5).round(), t));
        out.add(reg('glucosa', (108 + 45 * mejora + rnd.nextInt(40) - 15).round(), null, t));
      }
      if (d > 0 && rnd.nextDouble() < 0.45) {
        out.add(reg('glucosa', (132 + 50 * mejora + rnd.nextInt(45) - 18).round(), null, dia.add(Duration(hours: 20, minutes: rnd.nextInt(60)))));
      }
    }
    return out;
  }();
  static final _lotes = <String, Map<String, dynamic>>{}; // id_local -> resultado (reintentos sin duplicar)

  static final List<Map<String, dynamic>> _horarios = [
    {'id': 'h1', 'hora_local': '08:00', 'medicamento': {'id': 'm1', 'nombre_comercial': 'Losartán', 'concentracion': '50 mg', 'dosis': '1 tableta', 'via': 'oral'}},
    {'id': 'h2', 'hora_local': '14:00', 'medicamento': {'id': 'm2', 'nombre_comercial': 'Metformina', 'concentracion': '500 mg', 'dosis': '1 tableta', 'via': 'oral'}},
    {'id': 'h3', 'hora_local': '20:00', 'medicamento': {'id': 'm2', 'nombre_comercial': 'Metformina', 'concentracion': '500 mg', 'dosis': '1 tableta', 'via': 'oral'}},
    {'id': 'h4', 'hora_local': '06:00', 'medicamento': {'id': 'm1', 'nombre_comercial': 'Losartán', 'concentracion': '50 mg', 'dosis': '1 tableta', 'via': 'oral'}},
  ];
  static final _estadoTomas = <String, String>{'h4': 'omitida'}; // horario_id -> estado de hoy
  static final List<Map<String, dynamic>> _medicamentos = [
    {'id': 'm1', 'nombre_comercial': 'Losartán', 'concentracion': '50 mg', 'dosis': '1 tableta', 'frecuencia_horas': 24,
      'horarios': [{'hora_local': '08:00'}], 'mensaje_clave': 'med.losartan', 'activo': true},
    {'id': 'm2', 'nombre_comercial': 'Metformina', 'concentracion': '500 mg', 'dosis': '1 tableta', 'frecuencia_horas': 12,
      'horarios': [{'hora_local': '08:00'}, {'hora_local': '20:00'}], 'mensaje_clave': 'med.metformina', 'activo': true}];
  static final List<Map<String, dynamic>> _alertas = [
    {'id': 'a1', 'nivel': 'rojo', 'estado': 'abierta', 'paciente': {'id': '2', 'nombre': 'Juan Demo Ruiz'}, 'mensaje_clave': 'alerta.presion',
      'creada_en': DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String(),
      'registro': {'variable': 'presion', 'valor_num': 185, 'valor_num2': 110, 'tomado_en': DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String()}},
    {'id': 'a2', 'nivel': 'ambar', 'estado': 'abierta', 'paciente': {'id': '1', 'nombre': 'María Demo López'}, 'mensaje_clave': 'alerta.omision',
      'creada_en': DateTime.now().subtract(const Duration(hours: 5)).toUtc().toIso8601String()}];

  @override
  void onRequest(RequestOptions o, RequestInterceptorHandler h) async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (offline) { h.reject(DioException(requestOptions: o, type: DioExceptionType.connectionError)); return; }
    try {
      final data = _route(o.method, o.path, o.data, o.queryParameters);
      h.resolve(Response(requestOptions: o, statusCode: o.method == 'POST' ? 201 : 200, data: data));
    } on _ErrorMock catch (e) {
      h.reject(DioException(requestOptions: o, type: DioExceptionType.badResponse, response: Response(requestOptions: o,
        statusCode: e.estado, data: {'error': {'codigo': e.codigo, 'mensaje': e.codigo, if (e.campos != null) 'campos': e.campos}})));
    }
  }

  static String _hoyUtc(String hhmm, [int masDias = 0]) {
    final p = hhmm.split(':'); final d = DateTime.now();
    return DateTime(d.year, d.month, d.day + masDias, int.parse(p[0]), int.parse(p[1])).toUtc().toIso8601String();
  }
  static Map<String, dynamic> _resumenPaciente(Map<String, dynamic> p) {
    final nac = DateTime.parse(p['perfil']['fecha_nacimiento']); final h = DateTime.now();
    return {'id': p['id'], 'nombre': p['perfil']['nombre'], 'edad': h.year - nac.year - (h.month < nac.month ? 1 : 0),
      'semaforo': p['semaforo'], 'alertas_abiertas': p['alertas_abiertas'], 'programas': p['programas']};
  }

  dynamic _route(String m, String p, dynamic body, Map<String, dynamic> q) {
    bool r(String pat) => RegExp('^$pat\$').hasMatch(p);
    final idP = RegExp(r'^/pacientes/([^/]+)').firstMatch(p)?.group(1);

    if (r('/salud')) return {'estado': 'ok', 'base': 'ok', 'ocr': 'local', 'modo': 'demo'};
    if (r('/auth/login')) {
      final b = body as Map; final c = '${b['correo'] ?? ''}'.toLowerCase();
      if (c.isEmpty || '${b['contrasena'] ?? ''}'.isEmpty) throw _ErrorMock(401, 'credenciales_invalidas');
      _rolApi = c.contains('medic') ? 'medico' : c.contains('enfermera') ? 'enfermera'
          : (c.contains('pedro') || c.contains('rosa') || c.contains('cuidador')) ? 'cuidador' : 'paciente';
      _nombreUsuario = switch (_rolApi) { 'medico' => 'Dra. Ana Demo Pérez', 'enfermera' => 'Enfermera Demo', 'cuidador' => 'Pedro Demo',
        _ => c.contains('carmen') ? 'Carmen Demo Sánchez' : c.contains('juan') ? 'Juan Demo Ruiz' : 'María Demo López' };
      return {'token': 'mock-token', 'expira_en_horas': 8, 'usuario': {'id': 'u-$_rolApi', 'nombre': _nombreUsuario, 'rol': _rolApi}};
    }
    if (r('/auth/yo/foto')) return {'foto_url': null}; // (no está en la guía) la app muestra la foto elegida sin servidor
    if (r('/auth/yo')) {
      if (m == 'PATCH') { // (no está en la guía)
        if (_rolApi == 'medico') { _medico.addAll((body as Map).cast<String, dynamic>()); }
        return {'ok': true};
      }
      final aCargo = switch (_rolApi) {
        'paciente' => [{'id': '1', 'nombre': _nombreUsuario}],
        'cuidador' => [{'id': '1', 'nombre': 'María Demo López', 'parentesco': 'esposa'}, {'id': '3', 'nombre': 'Carmen Demo Sánchez', 'parentesco': 'suegra'}],
        _ => <Map<String, dynamic>>[] };
      final usuario = _rolApi == 'medico' ? _medico
          : {'id': 'u-$_rolApi', 'nombre': _nombreUsuario, 'rol': _rolApi, 'correo': '${_rolApi == 'cuidador' ? 'pedro' : 'maria'}@demo.invalid',
             if (_rolApi == 'paciente') ...{'telefono': _pacientes['1']!['perfil']['telefono']}};
      return {'usuario': usuario, 'pacientes_a_cargo': aCargo, if (_prefs.isNotEmpty) 'preferencias': _prefs};
    }
    if (r('/dispositivos')) return {'ok': true};
    if (r('/aviso-privacidad')) return {'version': '2026-09-demo', 'texto': null}; // la app usa su texto provisional
    if (r('/mensajes')) {
      // Demo: en otomí aún no hay frases validadas; la API responde con respaldo en español y aviso de intérprete.
      if (q['lengua'] != 'ote') return {'mensajes': []};
      return {'mensajes': [
        {'clave': 'res.ambar', 'texto': 'Tu presión está un poco alta. Descansa y mídete de nuevo en 30 minutos.', 'audio_url': null,
          'pictograma': null, 'respaldo': 'espanol', 'requiere_interprete': true}]};
    }
    // (no están en la guía) registro propio, clínicas y QR para registrar cuidador
    if (r('/registro/qr/[^/]+')) {
      return p.contains('sin') ? {'paciente': 'José H.', 'cuidador_asignado': null}
          : {'paciente': 'María L.', 'cuidador_asignado': {'nombre': 'Luis López'}};
    }
    if (r('/auth/registro')) return {'token': 'mock-token'};
    if (r('/clinicas')) return [{'id': 1, 'nombre': 'Centro de Salud Ixmiquilpan'}, {'id': 2, 'nombre': 'Hospital General Pachuca'}];

    if (r('/pacientes')) {
      if (m == 'POST') {
        final b = (body as Map).cast<String, dynamic>(); final id = '${_pacientes.length + 1}';
        _pacientes[id] = {'id': id, 'perfil': {'nombre': b['nombre'], 'fecha_nacimiento': b['fecha_nacimiento'], 'sexo': b['sexo'],
          'tipo_sangre': b['tipo_sangre'], 'alergias': b['alergias']}, 'semaforo': 'verde', 'alertas_abiertas': 0,
          'programas': b['programas'] ?? [], 'cuidadores': [if (b['cuidador'] != null) b['cuidador']], 'codigo_qr': 'PQR-DEMO-nuevo-$id'};
        return {'paciente': _pacientes[id], 'codigo_qr': 'PQR-DEMO-nuevo-$id',
          'credenciales': {'correo': 'paciente$id@demo.invalid', 'contrasena': 'Temporal-$id'}};
      }
      final l = [for (final x in _pacientes.values) _resumenPaciente(x)]
        ..sort((a, b) => const ['rojo', 'ambar', 'verde'].indexOf('${a['semaforo']}').compareTo(const ['rojo', 'ambar', 'verde'].indexOf('${b['semaforo']}')));
      final txt = '${q['q'] ?? ''}'.toLowerCase();
      return {'pacientes': l.where((x) => txt.isEmpty || '${x['nombre']}'.toLowerCase().contains(txt)).toList(), 'siguiente_cursor': null};
    }
    if (r('/pacientes/[^/]+/horarios')) {
      return {'horarios': _horarios, 'tomas': [
        for (final hh in _horarios) {'horario_id': hh['id'], 'programada_en': _hoyUtc('${hh['hora_local']}'), 'estado': _estadoTomas[hh['id']] ?? 'pendiente'},
        for (final hh in _horarios) {'horario_id': hh['id'], 'programada_en': _hoyUtc('${hh['hora_local']}', 1), 'estado': 'pendiente'}]};
    }
    if (r('/pacientes/[^/]+/tomas')) {
      if (m == 'POST') {
        final tomas = ((body as Map)['tomas'] as List).cast<Map>();
        for (final t in tomas) { _estadoTomas['${t['horario_id']}'] = '${t['estado']}'; }
        return {'tomas': tomas, 'alertas': []};
      }
      return {'tomas': [], 'adherencia': {'vencidas': 28, 'tomadas': 24, 'omitidas': 3, 'sin_medicina': 1, 'porcentaje': 86}};
    }
    if (r('/pacientes/[^/]+/plan')) {
      final embarazo = idP == '1';
      return {'hoy': DateTime.now().toIso8601String().substring(0, 10), 'proxima_cita': null, 'rangos': [],
        'preguntas': [
          {'mensaje_clave': 'preg.presion', 'tipo': 'medicion', 'variable': 'presion', 'contestada_hoy': false},
          {'mensaje_clave': 'preg.glucosa', 'tipo': 'medicion', 'variable': 'glucosa', 'contestada_hoy': false},
          if (embarazo) {'mensaje_clave': 'preg.cefalea', 'tipo': 'sintoma', 'variable': 'cefalea', 'contestada_hoy': false}]};
    }
    if (r('/pacientes/[^/]+/registros')) {
      if (m == 'POST') {
        final regs = ((body as Map)['registros'] as List).cast<Map>();
        final clave = regs.map((x) => x['id_local']).join(',');
        if (_lotes[clave] != null) return {..._lotes[clave]!, 'repetido': true};
        const orden = ['verde', 'ambar', 'rojo'];
        var nivel = 'verde'; var cefaleaFuerte = false; final creados = [];
        for (final x in regs) {
          final v = '${x['variable']}';
          final n = x['tipo'] == 'sintoma' ? (((x['escala'] ?? 0) as num) >= 3 ? 'ambar' : 'verde')
              : v == 'presion' ? nivelPresion(x['valor_num'] as num, x['valor_num2'] as num)
              : v == 'glucosa' ? nivelGlucosa(x['valor_num'] as num) : 'verde';
          if (v == 'cefalea' && ((x['escala'] ?? 0) as num) >= 3) cefaleaFuerte = true;
          if (orden.indexOf(n) > orden.indexOf(nivel)) nivel = n;
          final reg = {'id': 'r${_registros.length + 1}', ...x.cast<String, dynamic>(), 'nivel': n};
          if (x['tipo'] == 'medicion') _registros.add(reg);
          creados.add({'id': reg['id'], 'id_local': x['id_local'], 'nivel': n, 'alerta_id': null});
        }
        // Demo de la regla NOM-007: presión alta con cefalea fuerte en el embarazo es ROJO.
        if (cefaleaFuerte && nivel == 'ambar' && idP == '1') nivel = 'rojo';
        final res = {'nivel': nivel, 'mensaje_clave': 'res.$nivel', 'estado': 'completa', 'faltantes': [], 'coincidencias': [],
          'registros': creados, 'alertas': nivel == 'verde' ? [] : [{'id': 'a${_alertas.length + 1}', 'nivel': nivel}]};
        _lotes[clave] = res;
        return res;
      }
      final desde = DateTime.tryParse('${q['desde'] ?? ''}') ?? DateTime(2000);
      final serie = _registros.where((x) => (q['variable'] == null || x['variable'] == q['variable']) &&
          DateTime.parse('${x['tomado_en']}').isAfter(desde)).toList()
        ..sort((a, b) => '${a['tomado_en']}'.compareTo('${b['tomado_en']}'));
      final limite = int.tryParse('${q['limite'] ?? ''}') ?? 50; final ini = int.tryParse('${q['cursor'] ?? ''}') ?? 0;
      final fin = min(ini + limite, serie.length);
      return {'registros': serie.sublist(ini, fin), 'siguiente_cursor': fin < serie.length ? '$fin' : null};
    }
    if (r('/pacientes/[^/]+/medicamentos')) {
      return {'medicamentos': _medicamentos, 'alertas_medicacion': [
        {'nivel': 'ambar', 'mensaje_clave': 'adv.revisar', 'fuente': 'Catálogo demo', 'cita': 'Revisar interacción (dato ficticio)', 'origen': 'catalogo'}]};
    }
    if (r('/pacientes/[^/]+/documentos')) {
      final f = body is FormData ? body : null;
      final texto = f?.fields.firstWhere((e) => e.key == 'texto', orElse: () => const MapEntry('', '')).value ?? '';
      if ((f?.files.isEmpty ?? true) && texto.isEmpty) throw _ErrorMock(400, 'entrada_invalida', {'archivo': 'requerido'});
      if (texto.toLowerCase().contains('ilegible')) throw _ErrorMock(422, 'documento_ilegible');
      return {'id': 'd99', 'medicamentos': [
        {'nombre_comercial': 'Naproxeno', 'sustancia': {'id': 's-naproxeno', 'nombre': 'naproxeno'}, 'concentracion': '250 mg', 'dosis': '1 tableta',
          'frecuencia_horas': 8, 'duracion_dias': 5, 'via': 'oral', 'horarios_propuestos': ['06:00', '14:00', '22:00'], 'por_revisar': false},
        {'nombre_comercial': 'Xyzamol', 'sustancia': {'id': null, 'nombre': null}, 'concentracion': '', 'dosis': '',
          'horarios_propuestos': [], 'por_revisar': true, 'motivo_revision': 'no_en_catalogo'}],
        'alertas_medicacion': [{'nivel': 'ambar', 'mensaje_clave': 'adv.revisar', 'fuente': 'Catálogo demo', 'cita': 'Dato ficticio'}],
        'alergias_en_documento': [], 'texto_ocr': texto.isNotEmpty ? texto : 'NAPROXENO 250 MG 1 TAB C/8H X 5 DIAS'};
    }
    if (r('/documentos/[^/]+/confirmar')) {
      final meds = ((body as Map)['medicamentos'] as List).cast<Map>();
      for (final x in meds) {
        _medicamentos.add({'id': 'm${_medicamentos.length + 1}', 'nombre_comercial': x['nombre_comercial'], 'concentracion': x['concentracion'] ?? '',
          'dosis': x['dosis'] ?? '', 'frecuencia_horas': x['frecuencia_horas'], 'horarios': [for (final hh in (x['horarios'] as List? ?? [])) {'hora_local': hh}], 'activo': true});
      }
      return {'medicamentos': meds, 'alertas': []};
    }
    if (r('/pacientes/[^/]+/qr')) return {'codigo_qr': _pacientes[idP]?['codigo_qr'] ?? 'PQR-DEMO-$idP'};
    if (r('/pacientes/[^/]+/preferencias')) { _prefs = {..._prefs, ...(body as Map).cast<String, dynamic>()}; return _prefs; }
    if (r('/pacientes/[^/]+/consentimientos')) return {'ok': true};
    if (r('/pacientes/[^/]+/resumen')) {
      return {'resumen': null, 'datos': {'adherencia': {'porcentaje': 86}, 'alertas_abiertas': _pacientes[idP]?['alertas_abiertas'] ?? 0,
        'registros': _registros.length}};
    }
    if (r('/pacientes/[^/]+')) {
      final pac = _pacientes[idP] ?? (throw _ErrorMock(404, 'no_encontrado'));
      if (m == 'PATCH') { (pac['perfil'] as Map).addAll((body as Map).cast<String, dynamic>()); return {'ok': true}; } // (no está en la guía)
      return {'paciente': pac, 'programas': pac['programas'], 'cuidadores': pac['cuidadores'], 'rangos': [],
        'medicamentos': _medicamentos, 'alertas': [], 'registros_recientes': [], 'adherencia': {'porcentaje': 86}, 'notas': []};
    }
    if (r('/alertas')) {
      final est = '${q['estado'] ?? 'abierta'}';
      return {'alertas': _alertas.where((a) => est == 'todas' || a['estado'] == est).toList(), 'siguiente_cursor': null};
    }
    if (r('/alertas/[^/]+')) {
      final a = _alertas.firstWhere((x) => p.endsWith('/${x['id']}'), orElse: () => throw _ErrorMock(404, 'no_encontrado'));
      if (a['estado'] == 'atendida') throw _ErrorMock(409, 'ya_atendida');
      a['estado'] = 'atendida'; a['accion'] = (body as Map)['accion'];
      return a;
    }
    if (r('/qr/[^/]+')) {
      final cod = p.substring(4).toLowerCase();
      final pac = _pacientes.values.firstWhere((x) => '${x['codigo_qr']}'.toLowerCase() == cod ||
          (cod.contains('juan') && x['id'] == '2') || (cod.contains('carmen') && x['id'] == '3'), orElse: () => _pacientes['1']!);
      return {'paciente': pac};
    }
    return {'ok': true};
  }
}
