// Adaptadores entre la API real (Guía de conexión del frontend, /api/v1) y los mapas que usan las pantallas.
// Las pantallas no conocen los nombres del backend: todo pasa por aquí. Si el backend cambia un campo,
// se corrige en este archivo. Donde la guía no fija un nombre exacto se aceptan variantes razonables
// (p. ej. 'nombre_comercial' o 'nombre'); esas suposiciones están marcadas con "SUPUESTO".
import 'dart:math';
import 'package:dio/dio.dart';
import 'tr.dart';

// ---------- utilidades ----------

final _rnd = Random.secure();
/// UUID v4 para id_local (reintentos sin duplicar).
String uuidV4() {
  final b = List<int>.generate(16, (_) => _rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// Instante actual en ISO 8601 UTC (formato de la API).
String ahoraUtc() => DateTime.now().toUtc().toIso8601String();

Object? _p(Map m, List<String> ks) { for (final k in ks) { if (m[k] != null) return m[k]; } return null; }
String? _s(Map m, List<String> ks) => _p(m, ks)?.toString();
Map _m(Object? v) => v is Map ? v : const {};

/// Lista de una respuesta que puede venir como lista o paginada ({<clave>: [...], siguiente_cursor}).
List lista(dynamic r, [List<String> claves = const []]) {
  if (r is List) return r;
  if (r is Map) {
    for (final k in [...claves, 'datos', 'items', 'resultados', 'lista']) { if (r[k] is List) return r[k] as List; }
    final ls = r.values.whereType<List>(); if (ls.isNotEmpty) return ls.first;
  }
  return const [];
}
String? siguienteCursor(dynamic r) => r is Map ? r['siguiente_cursor']?.toString() : null;

String _hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String _fechaCorta(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${_hhmm(d)}';
DateTime? _instante(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

// ---------- errores {"error": {codigo, mensaje, campos?}} ----------

class ErrorApi { final int? estado; final String? codigo, mensaje; final Map campos;
  const ErrorApi(this.estado, this.codigo, this.mensaje, this.campos); }

ErrorApi? errorApi(Object e) {
  if (e is! DioException || e.response == null) return null;
  final d = e.response!.data; final err = d is Map ? _m(d['error']) : const {};
  return ErrorApi(e.response!.statusCode, err['codigo']?.toString(), err['mensaje']?.toString(), _m(err['campos']));
}

/// Texto para la persona según el código de error (la API nunca manda texto para el paciente).
String? mensajeError(Object e) {
  final x = errorApi(e); if (x == null) return null;
  return switch (x.codigo) {
    'credenciales_invalidas' || 'credenciales_incorrectas' || 'credenciales' => tr('Correo o contraseña incorrectos'),
    'sin_sesion' || 'sesion_invalida' => tr('Tu sesión expiró. Inicia sesión de nuevo.'),
    'usuario_inactivo' => tr('Tu cuenta está desactivada. Pide ayuda a tu clínica.'),
    'sin_permiso' => tr('Tu cuenta no puede ver esta información.'),
    'documento_ilegible' => tr('No se pudo leer la receta. Prueba con otra foto.'),
    'sin_medicamentos' => tr('No detectamos medicamentos'),
    'ocr_no_disponible' => tr('La lectura automática no está disponible. Escribe la receta.'),
    'demasiados_intentos' => tr('Demasiados intentos. Espera un momento.'),
    _ => switch (x.estado) {
      400 => tr('Revisa los datos marcados.'),
      401 => x.codigo == null ? tr('Correo o contraseña incorrectos') : tr('Tu sesión expiró. Inicia sesión de nuevo.'),
      403 => tr('Tu cuenta no puede ver esta información.'),
      404 => tr('No se encontró la información.'),
      409 => tr('Esto ya estaba registrado.'),
      422 => tr('No se pudo leer la receta. Prueba con otra foto.'),
      429 => tr('Demasiados intentos. Espera un momento.'),
      503 => tr('El servicio no está disponible por ahora.'),
      _ => null } };
}

// ---------- sesión ----------

/// Rol de la API -> rol de navegación. enfermera y medico comparten pantallas (equipo); admin no tiene app clínica.
String rolNavegacion(String? rolApi) => switch (rolApi) {
  'paciente' || 'usuario' => 'paciente', 'cuidador' => 'cuidador', _ => 'equipo' };

/// GET /auth/yo -> {usuario, pacientes_a_cargo}. Devuelve un mapa plano para la sesión y el perfil.
Map<String, dynamic> normalizarYo(dynamic r) {
  final m = _m(r); final u = m['usuario'] is Map ? m['usuario'] as Map : m;
  final aCargo = [for (final p in lista(m['pacientes_a_cargo'])) if (p is Map) {'id': '${_p(p, ['id', 'paciente_id'])}',
    'nombre': _s(p, ['nombre', 'nombre_completo']) ?? '', 'parentesco': p['parentesco']}];
  return {...u.cast<String, dynamic>(), 'id': '${u['id']}', 'rol_api': u['rol'], 'rol': rolNavegacion(u['rol']?.toString()),
    'correo': _s(u, ['correo', 'email']), 'cedula_profesional': _s(u, ['cedula_profesional', 'cedula']),
    // SUPUESTO: la guía no define un campo de verificación; las cuentas de médico las da de alta el admin
    // de la clínica con su cédula, así que se consideran verificadas si traen cédula.
    'cedula_verificada': u['cedula_verificada'] ?? (u['rol'] == 'medico' && _s(u, ['cedula_profesional', 'cedula']) != null),
    'pacientes_a_cargo': aCargo, 'paciente_id': aCargo.isEmpty ? null : aCargo.first['id'],
    'preferencias': m['preferencias'] ?? u['preferencias']};
}

// ---------- preferencias ----------

/// Lengua ISO 639-3 de la API <-> código de la app.
const lenguaApi = {'es': 'spa', 'en': 'eng', 'ote': 'ote'};
String lenguaApp(String? l) => switch (l) { 'spa' || 'es' => 'es', 'eng' || 'en' => 'en', 'ote' => 'ote', _ => 'es' };
String letraApi(double escala) => escala >= 1.6 ? 'muy_grande' : escala > 1.05 ? 'grande' : 'normal';
double escalaLetra(Object? letra, [double actual = 1.0]) => switch (letra) {
  'muy_grande' => 1.8, 'grande' => 1.4, 'normal' => 1.0, num n => n.toDouble(), _ => actual };

// ---------- plan y registros ----------

/// Unidades y textos de respaldo (cuando el catálogo aún no trae el mensaje_clave).
const unidades = {'presion': 'mmHg', 'glucosa': 'mg/dL', 'peso': 'kg', 'temperatura': '°C', 'frecuencia_cardiaca': 'lpm'};
const nombresSintoma = {'cefalea': 'dolor de cabeza', 'acufenos': 'zumbido de oídos', 'alteracion_visual': 'visión borrosa o luces',
  'edema': 'hinchazón', 'sangrado': 'sangrado', 'fiebre': 'fiebre', 'salida_liquido': 'salida de líquido', 'contracciones': 'contracciones',
  'convulsiones': 'convulsiones', 'disuria': 'ardor al orinar', 'movimientos_fetales_disminuidos': 'menos movimientos del bebé', 'movimientos_fetales': 'menos movimientos del bebé',
  'nausea': 'náusea', 'vomito': 'vómito', 'diarrea': 'diarrea', 'mucositis': 'llagas en la boca', 'dolor': 'dolor', 'fatiga': 'cansancio',
  'neuropatia': 'hormigueo o adormecimiento', 'falta_de_aire': 'falta de aire', 'dolor_de_pecho': 'dolor de pecho', 'mareo': 'mareo',
  'hipoglucemia_sintomas': 'temblor, sudor o debilidad (azúcar baja)'};

String preguntaRespaldo(String variable, String tipo) => tipo == 'sintoma'
    ? tr('¿Tienes {s}?', {'s': tr(nombresSintoma[variable] ?? variable.replaceAll('_', ' '))})
    : switch (variable) {
        'presion' => tr('¿Cuánto marca tu presión?'), 'glucosa' => tr('¿Cuánto marca tu glucosa?'),
        'peso' => tr('¿Cuánto pesas hoy?'), 'temperatura' => tr('¿Cuánto marca tu temperatura?'),
        'frecuencia_cardiaca' => tr('¿Cuántos latidos por minuto marca?'), _ => variable };

/// GET /pacientes/:id/plan -> {preguntas:[{variable, tipo, message_key, unidad, contestada_hoy}], proxima_cita, rangos}
Map<String, dynamic> normalizarPlan(dynamic r) {
  final m = _m(r);
  return {'hoy': m['hoy'], 'proxima_cita': m['proxima_cita'], 'rangos': lista(m['rangos']),
    'preguntas': [for (final q in lista(m['preguntas'])) if (q is Map) () {
      final v = '${q['variable'] ?? ''}'; final tipo = '${q['tipo'] ?? (nombresSintoma.containsKey(v) ? 'sintoma' : 'medicion')}';
      return {'variable': v, 'tipo': tipo, 'message_key': _s(q, ['mensaje_clave', 'message_key']) ?? 'preg.$v',
        'unidad': q['unidad'] ?? unidades[v], 'contestada_hoy': q['contestada_hoy'] == true, 'respaldo': preguntaRespaldo(v, tipo)};
    }()]};
}

/// Una respuesta de la pantalla Registrar -> un elemento del lote.
/// presion: [sistólica, diastólica]; otra medición: número; síntoma: escala 0..4.
Map<String, dynamic> registroParaApi(String variable, String tipo, Object valor, String tomadoEn) => {
  'id_local': uuidV4(), 'tipo': tipo, 'variable': variable, 'tomado_en': tomadoEn,
  if (tipo == 'sintoma') 'escala': valor
  else if (valor is List) ...{'valor_num': valor[0], 'valor_num2': valor[1]}
  else 'valor_num': valor};

/// Respuesta de POST registros -> {semaforo, message_key, estado, faltantes, alertas}
Map<String, dynamic> normalizarResultado(dynamic r) {
  final m = _m(r); final estado = '${m['estado'] ?? 'completa'}';
  return {...m.cast<String, dynamic>(), 'semaforo': _s(m, ['nivel', 'semaforo']) ?? 'verde', 'estado': estado,
    'message_key': _s(m, ['mensaje_clave', 'message_key']) ?? (estado == 'incompleta' ? 'resultado.faltan_datos' : 'resultado.registrado'),
    'faltantes': lista(m['faltantes']), 'alertas': lista(m['alertas']), 'repetido': m['repetido'] == true};
}

/// Serie de GET /pacientes/:id/registros -> [{fecha, valores:{sistole, diastole, glucosa, ...}, semaforo}]
List<Map<String, dynamic>> normalizarRegistros(dynamic r) => [
  for (final x in lista(r, ['registros'])) if (x is Map) () {
    final v = '${x['variable'] ?? ''}'; final n1 = x['valor_num'], n2 = x['valor_num2'];
    return <String, dynamic>{'id': x['id'], 'fecha': _s(x, ['tomado_en', 'fecha']), 'semaforo': _s(x, ['nivel', 'semaforo']),
      'variable': v, 'valores': x['valores'] ?? {
        if (v == 'presion') ...{'sistole': n1, 'diastole': n2} else if (x['tipo'] == 'sintoma') v: x['escala'] else v: n1}};
  }()];

// ---------- horarios y tomas ----------

/// GET /pacientes/:id/horarios -> {horarios[], tomas[] de hoy y mañana}
/// Devuelve las tomas de HOY como {id (=horario_id), horario_id, programada_en, hora, medicamento, dosis, estado, via}.
/// SUPUESTO: cada horario trae hora_local y el medicamento (anidado o plano); cada toma trae horario_id y programada_en.
List<Map<String, dynamic>> normalizarHorarios(dynamic r) {
  final m = _m(r); final hs = <String, Map>{for (final h in lista(m['horarios'])) if (h is Map) '${h['id']}': h};
  Map<String, dynamic> desde(Map h, [Map t = const {}]) {
    final med = _m(h['medicamento']);
    final nombre = _s(med, ['nombre_comercial', 'nombre']) ?? _s(h, ['nombre_comercial', 'medicamento', 'nombre']) ?? '';
    final conc = _s(med, ['concentracion']) ?? _s(h, ['concentracion']);
    final prog = _instante(t['programada_en']);
    return {'id': '${t['horario_id'] ?? h['id']}', 'horario_id': t['horario_id'] ?? h['id'], 'programada_en': t['programada_en'],
      'hora': _s(h, ['hora_local', 'hora']) ?? (prog == null ? null : _hhmm(prog)),
      'medicamento': conc == null || nombre.contains(conc) ? nombre : '$nombre $conc',
      'dosis': _s(med, ['dosis']) ?? _s(h, ['dosis']) ?? '', 'via': _s(med, ['via']) ?? _s(h, ['via']) ?? 'oral',
      'estado': _s(t, ['estado']) ?? 'pendiente'};
  }
  final tomas = lista(m['tomas']);
  if (tomas.isEmpty) {
    // Sin tomas del día: se arman desde los horarios (o desde una lista plana).
    final List fuente = m.isEmpty && r is List ? r : hs.values.toList();
    return [for (final h in fuente) if (h is Map) desde(h, h)];
  }
  final hoy = DateTime.now();
  return [for (final t in tomas) if (t is Map) () {
    final prog = _instante(t['programada_en']);
    if (prog != null && (prog.year != hoy.year || prog.month != hoy.month || prog.day != hoy.day)) return null;
    return desde(hs['${t['horario_id']}'] ?? t, t);
  }()].whereType<Map<String, dynamic>>().toList()..sort((a, b) => '${a['hora']}'.compareTo('${b['hora']}'));
}

/// Lote para POST /pacientes/:id/tomas. La API solo acepta tomada|omitida ("Más tarde" es local).
/// El id_local se genera una vez: la cola sin conexión reenvía el mismo lote sin duplicar.
Map<String, dynamic> loteToma(Map toma, String estado, {String? motivo}) {
  var prog = toma['programada_en']?.toString();
  if (prog == null && toma['hora'] != null) {
    final p = '${toma['hora']}'.split(':'); final h = DateTime.now();
    prog = DateTime(h.year, h.month, h.day, int.parse(p[0]), int.parse(p[1])).toUtc().toIso8601String();
  }
  return {'tomas': [{'id_local': uuidV4(), 'horario_id': toma['horario_id'] ?? toma['id'], 'programada_en': prog,
    'estado': estado, 'confirmada_en': ahoraUtc(), if (motivo != null) 'motivo': motivo}]};
}

/// GET /pacientes/:id/tomas?dias= -> adherencia {vencidas, tomadas, omitidas, sin_medicina, porcentaje}
Map<String, dynamic> normalizarAdherencia(dynamic r) {
  final m = _m(r); final a = _m(m['adherencia']).isNotEmpty ? _m(m['adherencia']) : m;
  return {'porcentaje': a['porcentaje'], 'tomadas': a['tomadas'], 'omitidas': a['omitidas'], 'vencidas': a['vencidas'],
    'sin_medicina': a['sin_medicina']};
}

// ---------- medicamentos y MEDMAP ----------

String _frecuencia(Map m) => _s(m, ['frecuencia']) ??
    (m['frecuencia_horas'] != null ? tr('cada {h} h', {'h': m['frecuencia_horas']}) : '');

/// GET /pacientes/:id/medicamentos -> [{id, nombre, concentracion, dosis, frecuencia, horarios, message_key}]
List<Map<String, dynamic>> normalizarMedicamentos(dynamic r) => [
  for (final x in lista(r, ['medicamentos'])) if (x is Map) {
    'id': x['id'], 'nombre': _s(x, ['nombre_comercial', 'nombre']) ?? '', 'concentracion': _s(x, ['concentracion']) ?? '',
    'dosis': _s(x, ['dosis']) ?? '', 'frecuencia': _frecuencia(x), 'via': x['via'],
    'horarios': [for (final h in lista(x['horarios'])) h is Map ? _s(h, ['hora_local', 'hora']) : '$h'],
    'message_key': _s(x, ['mensaje_clave', 'message_key']), 'activo': x['activo'] ?? true}];

/// alertas_medicacion de /medicamentos o de un documento -> [{nivel, message_key, fuente, cita}] (rojo primero)
List<Map<String, dynamic>> alertasMedicacion(dynamic r) {
  final l = [for (final a in lista(_m(r)['alertas_medicacion'])) if (a is Map) <String, dynamic>{...a.cast<String, dynamic>(),
    'nivel': _s(a, ['nivel']) ?? 'ambar', 'message_key': _s(a, ['mensaje_clave', 'message_key']), 'fuente': a['fuente'], 'cita': a['cita'],
    'regla': a['regla'], 'verificada': a['verificada'] != false}];
  return l..sort((a, b) => (a['nivel'] == 'rojo' ? 0 : 1).compareTo(b['nivel'] == 'rojo' ? 0 : 1));
}

/// Motivos de revisión de MEDMAP -> texto para la persona.
const motivosRevision = {
  'sustancia_no_encontrada_en_catalogo': 'No encontramos este medicamento en el catálogo.',
  'producto_combinado_no_soportado': 'Es un producto combinado que el sistema aún no reconoce.',
  'clasificada_por_ia_fuera_de_catalogo': 'La sustancia la clasificó la IA; no está en el catálogo.',
  'sustancia_inferida_por_ia': 'La sustancia la dedujo la IA: confírmala.',
  'lectura_dudosa': 'La lectura es dudosa: compárala con la foto.'};

/// Campo de discrepancia de la API -> campo del formulario de revisión.
const _campoRevision = {'nombre_comercial': 'nombre', 'frecuencia_horas': 'frecuencia'};

/// POST documentos (propuesta, nada guardado) -> {id, archivo_url, medicamentos, advertencias, alergias_en_documento,
/// lectura {manuscrito, renglones_dudosos, doble_lectura, ilegibles}, message_key, texto_ocr}
Map<String, dynamic> normalizarDocumento(dynamic r) {
  final m = _m(r); final doc = _m(m['documento']);
  return {'id': m['id'] ?? m['documento_id'] ?? doc['id'], 'archivo_url': doc['archivo_url'] ?? m['archivo_url'],
    'texto_ocr': _s(m, ['texto_ocr', 'texto']) ?? _s(doc, ['texto_ocr']),
    'alergias_en_documento': lista(m['alergias_en_documento']), 'advertencias': alertasMedicacion(m),
    'lectura': _m(m['lectura']), 'message_key': _s(m, ['mensaje_clave', 'message_key']),
    'medicamentos': [for (final x in lista(m['medicamentos'])) if (x is Map) () {
      final sus = _m(x['sustancia']); final comb = _m(x['producto_combinado']);
      final hp = x['horarios_propuestos'] ?? x['horarios'];
      // null en la API = no está escrito o no se leyó con certeza: queda vacío para que la persona lo complete.
      final disc = <String, List<String>>{};
      _m(x['discrepancias']).forEach((k, v) {
        final opciones = [for (final o in _m(v).values) if (o != null && '$o'.trim().isNotEmpty) '$o'].toSet().toList();
        if (opciones.isNotEmpty) disc[_campoRevision['$k'] ?? '$k'] = opciones;
      });
      final comps = lista(x['componentes']).isNotEmpty ? lista(x['componentes']) : lista(comb['componentes']);
      return <String, dynamic>{'nombre': _s(x, ['nombre_comercial', 'nombre']) ?? '',
        'sustancia': _s(sus, ['nombre_generico', 'nombre']) ?? _s(x, ['sustancia']) ?? '',
        'sustancia_id': sus['id'], 'sustancia_ia': sus['origen'] == 'ia', 'clase': sus['clase'],
        'producto_combinado_id': comb['id'], 'componentes': comps.isEmpty ? null : comps, 'candidatos': lista(x['candidatos']),
        'concentracion': _s(x, ['concentracion']) ?? '', 'dosis': _s(x, ['dosis']) ?? '', 'frecuencia': _frecuencia(x),
        'frecuencia_horas': x['frecuencia_horas'], 'duracion_dias': x['duracion_dias'], 'via': _s(x, ['via']) ?? '',
        'momento': _s(x, ['momento']) ?? '',
        'horarios': [for (final h in lista(hp)) h is Map ? _s(h, ['hora_local', 'hora']) : '$h'],
        'por_revisar': x['por_revisar'] == true, 'motivo_revision': x['motivo_revision'],
        'lectura_dudosa': x['lectura_dudosa'] == true || x['motivo_revision'] == 'lectura_dudosa', 'discrepancias': disc};
    }()]};
}

/// "cada 8 h", "8", "cada 8 horas" -> 8
int? horasDeFrecuencia(Object? texto) => int.tryParse(RegExp(r'\d+').firstMatch('${texto ?? ''}')?.group(0) ?? '');

/// Nombre legible de un componente de un producto combinado.
String textoComponente(Object? c) {
  final m = _m(c); final sus = _m(m['sustancia']);
  return [_s(sus, ['nombre_generico', 'nombre']) ?? _s(m, ['nombre', 'sustancia']) ?? '', _s(m, ['concentracion']) ?? '']
      .where((x) => x.isNotEmpty).join(' ');
}

/// Lo revisado por la persona -> cuerpo de POST /documentos/:id/confirmar.
/// sustancia_id va solo si el catálogo lo reconoció (con origen IA viene null y queda "por revisar" para el equipo).
Map<String, dynamic> confirmacionDocumento(List meds, {List reemplaza = const []}) => {
  'medicamentos': [for (final x in meds) if (x is Map) {
    'nombre_comercial': x['nombre'],
    if ('${x['concentracion'] ?? ''}'.isNotEmpty) 'concentracion': x['concentracion'],
    if ('${x['dosis'] ?? ''}'.isNotEmpty) 'dosis': x['dosis'],
    if ('${x['via'] ?? ''}'.isNotEmpty) 'via': x['via'],
    if ('${x['momento'] ?? ''}'.isNotEmpty) 'momento': x['momento'],
    if (x['producto_combinado_id'] != null) ...{'producto_combinado_id': x['producto_combinado_id'],
      'componentes': [for (final c in (x['componentes'] as List? ?? const [])) if (c is Map)
        {'sustancia_id': _m(c['sustancia'])['id'] ?? c['sustancia_id'], 'concentracion': c['concentracion']}]}
    else if (x['sustancia_id'] != null) 'sustancia_id': x['sustancia_id'],
    // Si la persona corrigió "cada 8 h", se toma el número que escribió.
    if ((horasDeFrecuencia(x['frecuencia']) ?? x['frecuencia_horas']) != null) 'frecuencia_horas': horasDeFrecuencia(x['frecuencia']) ?? x['frecuencia_horas'],
    'duracion_dias': x['duracion_dias'],
    'horarios': x['horarios'] ?? const [], 'dias': x['dias'] ?? const [1, 2, 3, 4, 5, 6, 7]}],
  'reemplaza': reemplaza};

// ---------- seguimiento fotográfico de lesiones ----------

const tiposLesion = {'herida_quirurgica': 'Herida quirúrgica', 'ulcera_presion': 'Úlcera por presión', 'pie_diabetico': 'Pie diabético',
  'lesion_piel': 'Lesión de piel', 'sitio_cateter': 'Sitio de catéter', 'otra': 'Otra'};
const zonasCorporales = {'cabeza_cara': 'Cabeza o cara', 'cuello': 'Cuello', 'torax': 'Tórax', 'abdomen': 'Abdomen', 'espalda': 'Espalda',
  'sacro_gluteo': 'Sacro o glúteo', 'brazo': 'Brazo', 'antebrazo': 'Antebrazo', 'mano': 'Mano', 'muslo': 'Muslo', 'rodilla': 'Rodilla',
  'pierna': 'Pierna', 'tobillo': 'Tobillo', 'talon': 'Talón', 'pie_dorso': 'Dorso del pie', 'pie_planta': 'Planta del pie',
  'dedos_pie': 'Dedos del pie', 'otra': 'Otra'};
const ladosCuerpo = {'izquierdo': 'Izquierdo', 'derecho': 'Derecho', 'centro': 'Centro'};
const referenciasFoto = {'moneda_10_pesos': 'Moneda de 10 pesos', 'tarjeta': 'Tarjeta', 'ninguna': 'Ninguna'};

/// Lesión en seguimiento -> {id, tipo, zona_corporal, lado, descripcion, ultima_foto, fotos, ...}
Map<String, dynamic> normalizarLesion(dynamic r) {
  final m = _m(r); final l = _m(m['lesion']).isNotEmpty ? _m(m['lesion']) : m;
  final fotos = [for (final f in lista(m['fotos'] ?? l['fotos'])) if (f is Map) normalizarFotoLesion(f)]
    ..sort((a, b) => '${b['tomada_en']}'.compareTo('${a['tomada_en']}'));
  return {...m.cast<String, dynamic>(), ...l.cast<String, dynamic>(), 'id': '${l['id']}', 'tipo': l['tipo'], 'zona_corporal': l['zona_corporal'],
    'lado': l['lado'], 'descripcion': l['descripcion'], 'fotos': fotos,
    'ultima_foto': fotos.isNotEmpty ? fotos.first : (l['ultima_foto'] is Map ? normalizarFotoLesion(l['ultima_foto']) : null),
    'evolucion': m['evolucion'] ?? l['evolucion']};
}
List<Map<String, dynamic>> normalizarLesiones(dynamic r) => [for (final x in lista(r, ['lesiones'])) if (x is Map) normalizarLesion(x)];

/// Foto de lesión (respuesta de POST /lesiones/:id/fotos o elemento de GET /lesiones/:id).
Map<String, dynamic> normalizarFotoLesion(dynamic r) {
  final m = _m(r); final f = _m(m['foto']).isNotEmpty ? _m(m['foto']) : m;
  final t = _instante(f['tomada_en']);
  return {...f.cast<String, dynamic>(), 'id': f['id'], 'tomada_en': f['tomada_en'], 'fecha': t == null ? null : _fechaCorta(t),
    'largo_cm': f['largo_cm'], 'ancho_cm': f['ancho_cm'], 'estado': _s(f, ['estado']) ?? _s(m, ['estado']),
    'message_key': _s(m, ['mensaje_clave']) ?? _s(f, ['mensaje_clave']), 'comparacion': m['comparacion'] ?? f['comparacion'],
    'descripcion_ia': _s(f, ['descripcion_ia', 'descripcion']), 'escala': f['escala']};
}
/// Tamaño legible: "3.2 × 1.8 cm" (o null si no se pudo medir).
String? tamanoLesion(Map? f) {
  if (f == null || f['largo_cm'] == null) return null;
  String n(Object? v) => v is num ? v.toStringAsFixed(1) : '$v';
  return f['ancho_cm'] == null ? '${n(f['largo_cm'])} cm' : '${n(f['largo_cm'])} × ${n(f['ancho_cm'])} cm';
}

// ---------- alertas, pacientes, expediente, QR ----------

/// GET /alertas -> [{id, nivel, paciente, paciente_id, message_key, hora, registro, estado}]
List<Map<String, dynamic>> normalizarAlertas(dynamic r) => [
  for (final a in lista(r, ['alertas'])) if (a is Map) () {
    final pac = a['paciente']; final reg = _m(a['registro']); final creada = _instante(a['creada_en']);
    final fr = _instante(reg['tomado_en']);
    return <String, dynamic>{...a.cast<String, dynamic>(), 'id': a['id'], 'nivel': _s(a, ['nivel']) ?? 'ambar',
      'paciente': pac is Map ? _s(pac, ['nombre']) : (pac ?? a['paciente_nombre'] ?? ''), 'paciente_id': a['paciente_id'] ?? _m(pac)['id'],
      'message_key': _s(a, ['mensaje_clave', 'message_key']), 'hora': creada == null ? (a['hora'] ?? '') : _fechaCorta(creada),
      'estado': a['estado'] ?? 'abierta',
      'registro': reg.isEmpty ? a['registro'] : {'variable': reg['variable'], 'fecha': fr == null ? reg['fecha'] : _fechaCorta(fr),
        'valor': reg['valor_num2'] != null ? '${reg['valor_num']}/${reg['valor_num2']}' : (reg['valor_num'] ?? reg['escala'] ?? reg['valor'])}};
  }()];

int? _edad(Object? nac) { final d = DateTime.tryParse('${nac ?? ''}'); if (d == null) return null;
  final h = DateTime.now(); return h.year - d.year - ((h.month < d.month || (h.month == d.month && h.day < d.day)) ? 1 : 0); }

/// Clave de programa de la API -> clave de la app. SUPUESTO: la API usa 'cronicas' y 'oncologia'.
String programaApp(Object? p) => switch ('${p is Map ? (p['programa'] ?? p['clave'] ?? p['nombre']) : p}') {
  'cronicas' || 'cronico' || 'cronicas_degenerativas' => 'cronico', 'adulto_mayor' => 'adulto_mayor',
  'embarazo' || 'embarazo_puerperio' => 'embarazo', final otro => otro };
/// Confirmado con GET /salud: los programas del servidor son cronicas, embarazo_puerperio y adulto_mayor.
String programaApi(String p) => switch (p) { 'cronico' => 'cronicas', 'embarazo' => 'embarazo_puerperio', _ => p };

/// Paciente del tablero, del expediente o del QR -> mapa plano {id, nombre, edad, semaforo, programas, cuidador, ...}
Map<String, dynamic> normalizarPaciente(dynamic r) {
  final m = _m(r); final p = m['paciente'] is Map ? m['paciente'] as Map : m;
  final perfil = _m(p['perfil']).isNotEmpty ? _m(p['perfil']) : p;
  final cuidadores = lista(m['cuidadores'] ?? p['cuidadores']);
  final cu = cuidadores.isNotEmpty && cuidadores.first is Map ? cuidadores.first as Map : _m(p['cuidador']);
  return {...m.cast<String, dynamic>(), ...perfil.cast<String, dynamic>(), 'id': '${p['id'] ?? m['id']}',
    'nombre': _s(perfil, ['nombre', 'nombre_completo']) ?? '', 'edad': perfil['edad'] ?? _edad(perfil['fecha_nacimiento']),
    'semaforo': _s(p, ['semaforo', 'nivel']) ?? _s(m, ['semaforo']) ?? 'verde', 'alertas_abiertas': p['alertas_abiertas'] ?? m['alertas_abiertas'],
    'programas': [for (final x in lista(m['programas'] ?? p['programas'])) programaApp(x)],
    'cuidador': cu.isEmpty ? null : {'nombre': _s(cu, ['nombre']) ?? '', 'contacto': _s(cu, ['telefono', 'contacto', 'correo']) ?? ''},
    'alergias': perfil['alergias'], 'tipo_sangre': perfil['tipo_sangre']};
}
List<Map<String, dynamic>> normalizarPacientes(dynamic r) =>
    [for (final x in lista(r, ['pacientes'])) if (x is Map) normalizarPaciente(x)];

/// GET /pacientes/:id/qr -> {token}: se dibuja codigo_qr.
Map<String, dynamic> normalizarQr(dynamic r) => {'token': _s(_m(r), ['codigo_qr', 'token', 'codigo']) ?? ''};

/// GET /qr/:codigo -> {paciente_id}
String? pacienteDeQr(dynamic r) { final m = _m(r);
  return (_p(m, ['paciente_id']) ?? _m(m['paciente'])['id'] ?? m['id'])?.toString(); }

/// Alta de paciente (POST /pacientes): perfil + programas[] + cuidador? + consentimiento{version, aceptado:true}.
Map<String, dynamic> altaPacienteParaApi(Map d, {String? versionAviso}) => {
  'nombre': d['nombre'], 'fecha_nacimiento': d['fecha_nacimiento'], 'sexo': d['sexo'],
  if (d['tipo_sangre'] != null) 'tipo_sangre': d['tipo_sangre'],
  if (d['alergias'] != null && '${d['alergias']}'.isNotEmpty) 'alergias': d['alergias'],
  if (d['diagnosticos'] != null && '${d['diagnosticos']}'.isNotEmpty) 'diagnosticos': d['diagnosticos'],
  'programas': [for (final p in (d['programas'] as List? ?? const [])) {'programa': programaApi('$p')}],
  if (d['cuidador'] is Map && '${(d['cuidador'] as Map)['nombre'] ?? ''}'.isNotEmpty)
    'cuidador': {'nombre': (d['cuidador'] as Map)['nombre'], 'telefono': (d['cuidador'] as Map)['contacto']},
  'consentimiento': {'version': versionAviso ?? '1', 'aceptado': true}};

// ---------- catálogo de mensajes ----------

/// GET /mensajes -> [{key, text, audio_url, pictogram, interprete}]
List<Map<String, dynamic>> normalizarMensajes(dynamic r) {
  Map<String, dynamic> uno(String? k, Map e) => {'key': k ?? _s(e, ['clave', 'mensaje_clave', 'key']),
    'text': _s(e, ['texto', 'text']) ?? '', 'audio_url': e['audio_url'], 'pictogram': _s(e, ['pictograma', 'pictogram']),
    'interprete': e['requiere_interprete'] == true && e['respaldo'] == 'espanol'};
  if (r is Map && r['mensajes'] is Map) r = r['mensajes'];
  if (r is Map && r.values.every((v) => v is Map)) return [for (final e in r.entries) uno('${e.key}', e.value as Map)];
  return [for (final e in lista(r, ['mensajes'])) if (e is Map) uno(null, e)].where((x) => x['key'] != null).toList();
}
