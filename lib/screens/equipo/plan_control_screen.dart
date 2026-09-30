import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/api_modelos.dart';
import '../../core/escala_texto.dart';
import '../../core/sync.dart';
import '../../core/theme.dart';
import '../../widgets/components.dart';
import '../shared.dart';
import '../../core/tr.dart';

/// Variables que el médico puede pedir y sus límites razonables (para detectar errores de captura).
/// presion usa dos pares: sistólica (min/max) y diastólica (min2/max2).
const variablesPlan = {
  'presion': (lo: 40.0, hi: 260.0),
  'glucosa': (lo: 20.0, hi: 600.0),
  'frecuencia_cardiaca': (lo: 20.0, hi: 250.0),
  'temperatura': (lo: 30.0, hi: 45.0),
  'peso': (lo: 1.0, hi: 400.0),
};
const frecuenciasPlan = {'diaria': 'Una vez al día', 'dos_al_dia': 'Dos veces al día', 'semanal': 'Una vez a la semana'};

/// Rango de una variable en el plan. Formato propuesto para GET/PUT /pacientes/:id/plan (por confirmar con backend):
/// {rangos: [{variable, activo, frecuencia, min, max, min2?, max2?, meta?}]}
class RangoPlan {
  final String variable; bool activo; String frecuencia;
  final min = TextEditingController(), max = TextEditingController(), min2 = TextEditingController(),
      max2 = TextEditingController(), meta = TextEditingController();
  RangoPlan(this.variable, {this.activo = false, this.frecuencia = 'diaria'});

  /// Lee un rango de la API aceptando nombres alternativos (min | minimo | valor_min…).
  factory RangoPlan.deApi(String variable, Map? r) {
    final x = RangoPlan(variable, activo: r != null && r['activo'] != false);
    if (r == null) return x;
    String n(List<String> ks) { for (final k in ks) { if (r[k] != null) return '${r[k]}'; } return ''; }
    if (frecuenciasPlan.containsKey(r['frecuencia'])) x.frecuencia = '${r['frecuencia']}';
    x.min.text = n(['min', 'minimo', 'valor_min']); x.max.text = n(['max', 'maximo', 'valor_max']);
    x.min2.text = n(['min2', 'minimo2', 'valor_min2']); x.max2.text = n(['max2', 'maximo2', 'valor_max2']);
    x.meta.text = n(['meta', 'objetivo']);
    return x;
  }

  bool get dosPares => variable == 'presion';
  static num? _num(TextEditingController c) => num.tryParse(c.text.trim().replaceAll(',', '.'));

  /// Mensaje de error (en el idioma de la app) o null si está bien.
  String? validar() {
    if (!activo) return null;
    final l = variablesPlan[variable]!; final nombre = tr(nombreVariable(variable));
    String? par(TextEditingController a, TextEditingController b, String etiqueta) {
      final lo = _num(a), hi = _num(b);
      if (lo == null || hi == null) return tr('{v}: escribe el mínimo y el máximo{e}.', {'v': nombre, 'e': etiqueta});
      if (lo < l.lo || hi > l.hi) return tr('{v}: los valores deben estar entre {a} y {b}.', {'v': nombre, 'a': l.lo.round(), 'b': l.hi.round()});
      if (lo >= hi) return tr('{v}: el mínimo debe ser menor que el máximo{e}.', {'v': nombre, 'e': etiqueta});
      return null;
    }
    return par(min, max, dosPares ? ' ${tr('(sistólica)')}' : '') ?? (dosPares ? par(min2, max2, ' ${tr('(diastólica)')}') : null);
  }

  Map<String, dynamic> toJson() => {'variable': variable, 'activo': activo, 'frecuencia': frecuencia,
    if (activo) ...{'min': _num(min), 'max': _num(max), if (dosPares) ...{'min2': _num(min2), 'max2': _num(max2)}},
    if (meta.text.trim().isNotEmpty) 'meta': meta.text.trim()};

  void dispose() { for (final c in [min, max, min2, max2, meta]) { c.dispose(); } }
}

/// Plan de control (solo médico): qué mediciones pide al paciente, cada cuándo y en qué rango está bien.
/// Fuera de rango el registro sale ámbar o rojo; sin rango, el resultado dice "Tu médico aún no fija la meta".
class PlanControlScreen extends ConsumerStatefulWidget { final String id; const PlanControlScreen({super.key, required this.id});
  @override ConsumerState<PlanControlScreen> createState() => _PlanState(); }

class _PlanState extends ConsumerState<PlanControlScreen> {
  List<RangoPlan>? _rangos; Object? _errorCarga; bool _busy = false; String? _err;

  @override
  void initState() { super.initState(); _cargar(); }
  @override
  void dispose() { for (final r in _rangos ?? const <RangoPlan>[]) { r.dispose(); } super.dispose(); }

  Future<void> _cargar() async {
    setState(() { _errorCarga = null; _rangos = null; });
    try {
      final plan = await ref.read(apiProvider).plan(widget.id);
      final porVar = {for (final r in plan['rangos'] as List) if (r is Map) '${r['variable']}': r};
      // Lo que ya pregunta el plan cuenta como activo aunque aún no tenga rango.
      final preguntadas = {for (final q in plan['preguntas'] as List) if (q is Map) '${q['variable']}'};
      if (!mounted) return;
      setState(() => _rangos = [for (final v in variablesPlan.keys)
        RangoPlan.deApi(v, porVar[v] ?? (preguntadas.contains(v) ? const {} : null))]);
    } catch (e) { if (mounted) setState(() => _errorCarga = e); }
  }

  Future<void> _guardar() async {
    final rs = _rangos!; final e = rs.map((r) => r.validar()).whereType<String>().firstOrNull;
    if (e != null) { setState(() => _err = e); return; }
    setState(() { _busy = true; _err = null; });
    try {
      await ref.read(apiProvider).guardarPlan(widget.id, {'rangos': [for (final r in rs) r.toJson()]});
      ref.invalidate(futureFor('plan'));
      if (mounted) { aviso(context, tr('Plan de control guardado.')); }
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = isNetworkError(e) ? tr('Sin conexión. Revisa tu internet e intenta de nuevo.')
          : mensajeError(e) ?? tr('No se pudo guardar. Intenta de nuevo.'));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Widget _par(BuildContext c, RangoPlan r, TextEditingController a, TextEditingController b, String? titulo) {
    const kt = TextInputType.numberWithOptions(decimal: true);
    final u = unidades[r.variable] ?? '';
    Widget campo(TextEditingController x, String l) => TextField(controller: x, keyboardType: kt,
        decoration: InputDecoration(labelText: tr(l), suffixText: u));
    final campos = [campo(a, 'Mínimo'), campo(b, 'Máximo')];
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (titulo != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(tr(titulo), style: Theme.of(c).textTheme.labelLarge)),
      // Con letra grande los dos campos no caben lado a lado.
      if (escalaDe(c) >= 1.4) ...[campos[0], const SizedBox(height: 8), campos[1]]
      else Row(children: [Expanded(child: campos[0]), const SizedBox(width: 12), Expanded(child: campos[1])])]));
  }

  Widget _tarjeta(BuildContext c, RangoPlan r) => Padding(padding: const EdgeInsets.only(bottom: 12), child: InfoCard(child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SwitchListTile(contentPadding: EdgeInsets.zero, value: r.activo, onChanged: (v) => setState(() => r.activo = v),
        title: Text(tr(nombreVariable(r.variable)), style: Theme.of(c).textTheme.titleMedium),
        subtitle: Text(r.activo ? tr('Se le pide al paciente') : tr('No se le pide'))),
      if (r.activo) ...[
        Text(tr('Frecuencia'), style: Theme.of(c).textTheme.labelLarge), const SizedBox(height: 8),
        ChoiceWrap(options: frecuenciasPlan, isSel: (k) => r.frecuencia == k, onTap: (k) => setState(() => r.frecuencia = k)),
        const SizedBox(height: 16),
        _par(c, r, r.min, r.max, r.dosPares ? 'Sistólica (arriba)' : 'Rango normal'),
        if (r.dosPares) _par(c, r, r.min2, r.max2, 'Diastólica (abajo)'),
        TextField(controller: r.meta, maxLines: null, decoration: InputDecoration(labelText: tr('Meta (opcional)'),
          hintText: tr('Ej. bajar a menos de 130/80 en 3 meses')))]])));

  @override
  Widget build(BuildContext c) {
    final rs = _rangos;
    final Widget cuerpo = _errorCarga != null
        ? AsyncView(AsyncValue.error(_errorCarga!, StackTrace.current), (_) => const SizedBox(), onRetry: _cargar)
        : rs == null ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: [
            Text(tr('Elige qué mediciones pedir, cada cuándo y en qué rango están bien. Fuera de rango, el registro avisa a tu equipo.')),
            const SizedBox(height: 16),
            for (final r in rs) _tarjeta(c, r),
            if (_err != null) Semantics(liveRegion: true, child: Padding(padding: const EdgeInsets.only(bottom: 12),
              child: Text(_err!, style: const TextStyle(color: C.error, fontWeight: FontWeight.w600)))),
            BigButton(_busy ? tr('Guardando…') : tr('Guardar plan'), icon: Icons.save_outlined, onTap: _busy ? null : _guardar)]);
    return page(c, tr('Plan de control'), cuerpo, bell: false);
  }
}
