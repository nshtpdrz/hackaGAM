// Pantalla de desarrollo "Diagnóstico de conexión": con la sesión que la persona YA inició, consulta los endpoints
// de la API y arma un reporte con la FORMA de cada respuesta (tipos y campos, nunca los valores) y con lo que
// produce cada adaptador de api_modelos.dart. Sirve para ajustar los adaptadores a las respuestas reales.
// Solo hace GET. El reporte nunca incluye el token, la dirección del servidor ni encabezados.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/api_modelos.dart';
import '../../core/mock_api.dart';
import '../../core/state.dart';
import '../../core/theme.dart';
import '../../core/tr.dart';
import '../../widgets/components.dart';
import '../shared.dart';

const _maxProf = 5, _maxClaves = 40;

/// Forma de un JSON sin copiar datos: `{usuario:{id:str, rol:str}, pacientes_a_cargo:[{id:str}]×2}`.
/// De las listas se describe solo el primer elemento (×N). Profundidad máxima 5.
String formaJson(Object? v, [int prof = 0]) {
  if (v == null) return 'null';
  if (v is bool) return 'bool';
  if (v is num) return 'num';
  if (v is String) return 'str';
  if (v is List) {
    if (v.isEmpty) return '[]';
    return '[${prof >= _maxProf ? '…' : formaJson(v.first, prof + 1)}]×${v.length}';
  }
  if (v is Map) {
    if (v.isEmpty) return '{}';
    if (prof >= _maxProf) return '{…}';
    final formas = [for (final e in v.entries) ('${e.key}', formaJson(e.value, prof + 1))];
    // Mapa usado como diccionario (p. ej. mensajes por clave): se describe una sola entrada.
    if (v.length > 10 && formas.every((f) => f.$2 == formas.first.$2)) return '{‹clave›:${formas.first.$2}}×${v.length}';
    final vis = formas.take(_maxClaves).map((f) => '${f.$1}:${f.$2}').join(', ');
    return '{$vis${v.length > _maxClaves ? ', …+${v.length - _maxClaves}' : ''}}';
  }
  return v.runtimeType.toString();
}

/// Resultado de una consulta. [ok] null = omitida (no aplica al rol o no hay paciente).
class ResultadoChequeo {
  final String nombre; final bool? ok; final int? http; final int ms;
  final String? forma, normalizador, codigo, sinRespuesta, omitida; final bool? lleno;
  const ResultadoChequeo(this.nombre, {this.ok, this.http, this.ms = 0, this.forma, this.normalizador, this.lleno,
      this.codigo, this.sinRespuesta, this.omitida});
  String get marca => ok == null ? '—' : ok! ? '✓' : '✗';
}

/// Reporte en texto plano para copiar. Sin token, sin URL, sin encabezados, sin ids ni valores.
String reporteDiagnostico(List<ResultadoChequeo> res, {required bool demo, Session? sesion, DateTime? fecha}) {
  final ok = res.where((r) => r.ok == true).length, mal = res.where((r) => r.ok == false).length;
  final b = StringBuffer()
    ..writeln('SENDA · Diagnóstico de conexión')
    ..writeln('Modo: ${demo ? 'demo (datos de demostración, sin servidor)' : 'servidor'}')
    ..writeln('Rol: ${sesion?.role.name ?? '—'} · rol_api: ${sesion?.rolApi ?? '—'} · pacientes a cargo: ${sesion?.pacientesACargo.length ?? 0}')
    ..writeln('Fecha (UTC): ${(fecha ?? DateTime.now()).toUtc().toIso8601String()}')
    ..writeln('Resultado: $ok correctas, $mal con error, ${res.length - ok - mal} omitidas')
    ..writeln();
  for (var i = 0; i < res.length; i++) {
    final r = res[i];
    b.write('${i + 1}. ${r.marca} ${r.nombre}');
    if (r.omitida != null) { b.writeln(' · omitida: ${r.omitida}'); continue; }
    b.writeln(' · HTTP ${r.http ?? '—'} · ${r.ms} ms${r.codigo == null ? '' : ' · codigo: ${r.codigo}'}'
        '${r.sinRespuesta == null ? '' : ' · sin respuesta (${r.sinRespuesta})'}');
    if (r.forma != null) b.writeln('   forma: ${r.forma}');
    if (r.normalizador != null) b.writeln('   normalizador: ${r.normalizador}${r.lleno == false ? '  [VACÍO]' : ''}');
  }
  return b.toString();
}

// ---------- adaptadores: qué produce cada uno (conteos y campos presentes, nunca valores personales) ----------

typedef _Norm = (String, bool) Function(dynamic d);

bool _hay(Object? v) => v != null && '$v'.isNotEmpty && '$v' != 'null';
int _con(List<Map<String, dynamic>> l, String k) => l.where((x) => _hay(x[k])).length;
String _campos(List<Map<String, dynamic>> l, List<String> ks) => ks.map((k) => '$k=${_con(l, k)}').join(', ');

(String, bool) _nYo(dynamic d) {
  final y = normalizarYo(d);
  return ('normalizarYo → rol=${y['rol']}, rol_api=${y['rol_api']}, id=${_hay(y['id'])}, paciente_id=${_hay(y['paciente_id'])}, '
      'pacientes_a_cargo=${(y['pacientes_a_cargo'] as List).length}, preferencias=${y['preferencias'] is Map}', _hay(y['rol_api']));
}
(String, bool) _nPacientes(dynamic d) {
  final l = normalizarPacientes(d);
  return ('normalizarPacientes → ${l.length} (${_campos(l, ['id', 'nombre', 'edad', 'semaforo', 'alertas_abiertas'])})', l.isNotEmpty);
}
(String, bool) _nPlan(dynamic d) {
  final p = normalizarPlan(d); final q = (p['preguntas'] as List).cast<Map<String, dynamic>>();
  return ('normalizarPlan → preguntas=${q.length} (${_campos(q, ['variable', 'tipo', 'message_key'])}), '
      'rangos=${(p['rangos'] as List).length}, proxima_cita=${_hay(p['proxima_cita'])}', q.isNotEmpty);
}
(String, bool) _nHorarios(dynamic d) {
  final l = normalizarHorarios(d); final m = d is Map ? d : const {};
  return ('normalizarHorarios → tomas de hoy=${l.length} (${_campos(l, ['hora', 'medicamento', 'dosis', 'programada_en'])}); '
      'crudo: horarios=${lista(m['horarios']).length}, tomas=${lista(m['tomas']).length}', l.isNotEmpty);
}
(String, bool) _nRegistros(dynamic d) {
  final l = normalizarRegistros(d);
  return ('normalizarRegistros → ${l.length} (${_campos(l, ['fecha', 'variable', 'semaforo', 'valores'])})', l.isNotEmpty);
}
(String, bool) _nTomas(dynamic d) {
  final a = normalizarAdherencia(d);
  return ('normalizarAdherencia → ${a.keys.map((k) => '$k=${_hay(a[k])}').join(', ')}', a.values.any(_hay));
}
(String, bool) _nMedicamentos(dynamic d) {
  final l = normalizarMedicamentos(d);
  return ('normalizarMedicamentos → ${l.length} (${_campos(l, ['nombre', 'concentracion', 'dosis', 'frecuencia'])}, '
      'con horarios=${l.where((x) => (x['horarios'] as List).isNotEmpty).length}); alertasMedicacion → ${alertasMedicacion(d).length}', l.isNotEmpty);
}
(String, bool) _nQr(dynamic d) { final t = normalizarQr(d)['token']; return ('normalizarQr → token=${_hay(t)}', _hay(t)); }
(String, bool) _nAlertas(dynamic d) {
  final l = normalizarAlertas(d);
  return ('normalizarAlertas → ${l.length} (${_campos(l, ['nivel', 'paciente', 'paciente_id', 'message_key', 'hora'])})', l.isNotEmpty);
}
(String, bool) _nLesiones(dynamic d) {
  final l = normalizarLesiones(d);
  return ('normalizarLesiones → ${l.length} (${_campos(l, ['tipo', 'zona_corporal', 'lado', 'ultima_foto'])}, '
      'fotos=${l.fold<int>(0, (s, x) => s + (x['fotos'] as List).length)})', l.isNotEmpty);
}
(String, bool) _nMensajes(dynamic d) { final l = normalizarMensajes(d); return ('normalizarMensajes → ${l.length}', l.isNotEmpty); }

class _Chequeo {
  final String plantilla; final Map<String, dynamic>? q; final _Norm? norm;
  const _Chequeo(this.plantilla, {this.q, this.norm});
  String get nombre => 'GET $plantilla${q == null ? '' : '?${q!.entries.map((e) => '${e.key}=${e.value}').join('&')}'}';
}

const _salud = _Chequeo('/salud');
const _yo = _Chequeo('/auth/yo', norm: _nYo);
const _pacientes = _Chequeo('/pacientes', q: {'limite': 5}, norm: _nPacientes);
const _porPaciente = [
  _Chequeo('/pacientes/:id/plan', norm: _nPlan),
  _Chequeo('/pacientes/:id/horarios', norm: _nHorarios),
  _Chequeo('/pacientes/:id/registros', q: {'variable': 'presion', 'limite': 5}, norm: _nRegistros),
  _Chequeo('/pacientes/:id/tomas', q: {'dias': 7}, norm: _nTomas),
  _Chequeo('/pacientes/:id/medicamentos', norm: _nMedicamentos)];
const _qr = _Chequeo('/pacientes/:id/qr', norm: _nQr);
const _alertas = _Chequeo('/alertas', q: {'estado': 'abierta'}, norm: _nAlertas);
const _lesiones = _Chequeo('/pacientes/:id/lesiones', norm: _nLesiones);
const _mensajes = _Chequeo('/mensajes', q: {'lengua': 'spa'}, norm: _nMensajes);
const _total = 12;

/// Una consulta: estado HTTP, tiempo, forma y resultado del adaptador. Devuelve también los datos (si fue 2xx).
Future<(ResultadoChequeo, dynamic)> _ejecutar(Api api, _Chequeo ch, String? id) async {
  final ruta = ch.plantilla.replaceAll(':id', Uri.encodeComponent(id ?? ''));
  final sw = Stopwatch()..start();
  Response<dynamic>? r; String? sinRespuesta;
  try {
    r = await api.crudo(ruta, ch.q == null ? null : Map.of(ch.q!));
  } on DioException catch (e) {
    r = e.response; if (r == null) sinRespuesta = e.type.name; // nunca e.message: puede traer la dirección
  } catch (e) {
    sinRespuesta = '${e.runtimeType}';
  }
  sw.stop();
  final http = r?.statusCode; final ok = http != null && http >= 200 && http < 300; final data = r?.data;
  final err = data is Map ? data['error'] : null;
  String? norma; bool? lleno;
  if (ok && ch.norm != null) {
    try { final (t, l) = ch.norm!(data); norma = t; lleno = l; }
    catch (e) { norma = 'el adaptador falló: ${e is TypeError ? '$e'.split('\n').first : e.runtimeType}'; lleno = false; }
  }
  return (ResultadoChequeo(ch.nombre, ok: ok, http: http, ms: sw.elapsedMilliseconds, forma: r == null ? null : formaJson(data),
      normalizador: norma, lleno: lleno, codigo: err is Map && err['codigo'] != null ? '${err['codigo']}' : null,
      sinRespuesta: sinRespuesta), ok ? data : null);
}

String? _primerPaciente(dynamic pacs) {
  try { final l = normalizarPacientes(pacs); return l.isEmpty || !_hay(l.first['id']) ? null : '${l.first['id']}'; } catch (_) { return null; }
}
String? _pacienteDeYo(dynamic yo) {
  try { final id = normalizarYo(yo)['paciente_id']; return _hay(id) ? '$id' : null; } catch (_) { return null; }
}

class DiagnosticoScreen extends ConsumerStatefulWidget { const DiagnosticoScreen({super.key});
  @override ConsumerState<DiagnosticoScreen> createState() => _DiagnosticoState(); }

class _DiagnosticoState extends ConsumerState<DiagnosticoScreen> {
  final _res = <ResultadoChequeo>[];
  bool _corriendo = false;

  Future<dynamic> _paso(Api api, _Chequeo ch, {String? id, String? omitir}) async {
    if (!mounted) return null;
    if (omitir != null) { setState(() => _res.add(ResultadoChequeo(ch.nombre, omitida: omitir))); return null; }
    final (r, data) = await _ejecutar(api, ch, id);
    if (mounted) setState(() => _res.add(r));
    return data;
  }

  Future<void> _probar() async {
    final s = ref.read(sessionProvider); if (s == null || _corriendo) return;
    final api = ref.read(apiProvider);
    final equipo = s.role == Role.equipo, paciente = s.role == Role.paciente;
    setState(() { _res.clear(); _corriendo = true; });
    try {
      await _paso(api, _salud);
      final yo = await _paso(api, _yo);
      final pacs = await _paso(api, _pacientes, omitir: equipo ? null : 'solo para el equipo de salud');
      // Equipo: el primer paciente del tablero. Paciente y cuidador: el paciente activo de la sesión.
      final id = equipo ? (_primerPaciente(pacs) ?? s.patientId) : (s.patientId ?? _pacienteDeYo(yo));
      final sinPaciente = id == null ? 'sin paciente activo' : null;
      for (final ch in _porPaciente) { await _paso(api, ch, id: id, omitir: sinPaciente); }
      await _paso(api, _qr, id: id, omitir: equipo ? 'no aplica al equipo de salud' : sinPaciente);
      await _paso(api, _alertas, omitir: paciente ? 'no aplica al paciente' : null);
      await _paso(api, _lesiones, id: id, omitir: sinPaciente);
      await _paso(api, _mensajes);
    } finally {
      if (mounted) setState(() => _corriendo = false);
    }
  }

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: reporteDiagnostico(_res, demo: useMock, sesion: ref.read(sessionProvider))));
    if (mounted) aviso(context, 'Reporte copiado');
  }

  @override
  Widget build(BuildContext c) {
    final s = ref.watch(sessionProvider); final t = Theme.of(c).textTheme;
    final ok = _res.where((r) => r.ok == true).length, mal = _res.where((r) => r.ok == false).length;
    return page(c, 'Diagnóstico de conexión', bell: false, ListView(padding: const EdgeInsets.all(16), children: [
      InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(useMock ? Icons.science_outlined : Icons.cloud_outlined, color: C.primary), const SizedBox(width: 12),
          Expanded(child: Text(useMock ? tr('Modo demo: se prueba contra los datos de demostración, no contra el servidor.')
              : tr('Modo servidor: se prueba con tu sesión actual.'), style: t.bodyMedium))])])),
      const SizedBox(height: 16),
      if (s == null) ...[Text(tr('Inicia sesión para probar la conexión.'), style: t.bodyMedium), const SizedBox(height: 12)],
      BigButton('Probar conexión', icon: Icons.network_check, onTap: s == null || _corriendo ? null : _probar),
      const SizedBox(height: 8),
      BigButton('Copiar reporte', icon: Icons.copy_outlined, secondary: true, onTap: _res.isEmpty || _corriendo ? null : _copiar),
      const SizedBox(height: 8),
      Text(tr('Solo hace consultas de lectura. El reporte describe la forma de cada respuesta (tipos y campos), '
          'sin datos personales, sin el token y sin la dirección del servidor.'), style: t.bodySmall?.copyWith(color: C.text2)),
      const SizedBox(height: 16),
      if (_corriendo) ...[
        LinearProgressIndicator(value: _res.length / _total, semanticsLabel: tr('Progreso de la prueba')),
        const SizedBox(height: 8),
        Semantics(liveRegion: true, child: Text(tr('Probando… {n} de {t}', {'n': _res.length, 't': _total}), style: t.bodyMedium)),
      ] else if (_res.isNotEmpty)
        Semantics(liveRegion: true, child: Text(tr('{ok} correctas · {err} con error · {om} omitidas',
            {'ok': ok, 'err': mal, 'om': _res.length - ok - mal}), style: t.labelLarge)),
      const SizedBox(height: 8),
      for (final r in _res) _Fila(r),
    ]));
  }
}

class _Fila extends StatelessWidget { final ResultadoChequeo r; const _Fila(this.r);
  @override
  Widget build(BuildContext c) {
    final t = Theme.of(c).textTheme; final gris = t.bodySmall?.copyWith(color: C.text2);
    final color = r.ok == null ? C.text2 : r.ok! ? C.success : C.error;
    final estado = r.ok == null ? tr('Prueba omitida') : r.ok! ? tr('Prueba correcta') : tr('Prueba con error');
    final detalle = r.omitida != null ? tr('Se omitió: {m}', {'m': tr(r.omitida!)})
        : [if (r.http != null) 'HTTP ${r.http}', '${r.ms} ms'].join(' · ');
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: Padding(padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(label: estado, child: ExcludeSemantics(child: Text(r.marca,
              style: t.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w700)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.nombre, style: t.labelLarge),
            Text(detalle, style: gris),
            if (r.codigo != null) Text(tr('Código de error: {c}', {'c': r.codigo}), style: t.bodySmall?.copyWith(color: C.error)),
            if (r.sinRespuesta != null) Text(tr('Sin respuesta ({t})', {'t': r.sinRespuesta}), style: t.bodySmall?.copyWith(color: C.error)),
          ]))]),
        if (r.forma != null) ...[
          const SizedBox(height: 8),
          Text(tr('Forma de la respuesta'), style: gris),
          const SizedBox(height: 4),
          Container(width: double.infinity, padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.border)),
            child: SelectableText(r.forma!, style: const TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Courier New', 'Courier'],
                fontSize: 12.5, height: 1.4, color: C.text))),
        ],
        if (r.normalizador != null) ...[
          const SizedBox(height: 8),
          Text(r.normalizador!, style: t.bodySmall),
          if (r.lleno == false) Padding(padding: const EdgeInsets.only(top: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.warning_amber_rounded, color: C.warning, size: 20), const SizedBox(width: 6),
            Expanded(child: Text(tr('El adaptador no produjo datos.'), style: t.bodySmall))])),
        ],
      ]))));
  }
}
