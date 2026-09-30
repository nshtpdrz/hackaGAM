import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/api_modelos.dart';
import '../../core/sync.dart';
import '../../core/theme.dart';
import '../../widgets/components.dart';
import '../../widgets/dialogs.dart';
import '../shared.dart';
import '../../core/tr.dart';
import '../../core/escala_texto.dart';
import '../../core/validacion.dart';

/// Escala de síntomas de la API: 0 = no … 4 = muy fuerte.
const _escala = ['No', 'Leve', 'Moderado', 'Fuerte', 'Muy fuerte'];

// 3. Registrar: una pregunta por pantalla, generada desde GET /plan (preguntas del día).
// Todo lo contestado se envía en UN lote (un episodio) con id_local por registro: si se cae la red,
// la cola reenvía el mismo lote y la API no lo duplica.
class RegistrarScreen extends ConsumerStatefulWidget { const RegistrarScreen({super.key});
  @override ConsumerState<RegistrarScreen> createState() => _RegState(); }
class _RegState extends ConsumerState<RegistrarScreen> {
  int i = 0; bool busy = false; String? err;
  final Map<String, Object> resp = {}; // variable -> número | [sistólica, diastólica] | escala
  final _a = TextEditingController(), _b = TextEditingController();
  int? _sintoma;
  @override
  void dispose() { _a.dispose(); _b.dispose(); super.dispose(); }

  void _cargar(Map q) { // al cambiar de pregunta se muestran las respuestas ya dadas
    final v = resp[q['variable']];
    _a.text = v is List ? '${v[0]}' : (v is num && q['tipo'] != 'sintoma' ? '$v' : '');
    _b.text = v is List ? '${v[1]}' : ''; _sintoma = q['tipo'] == 'sintoma' && v is int ? v : null;
  }

  String? _guardarRespuesta(Map q) {
    final variable = '${q['variable']}';
    if (q['tipo'] == 'sintoma') {
      if (_sintoma == null) return tr('Elige una opción.');
      resp[variable] = _sintoma!; return null;
    }
    final a = num.tryParse(_a.text.trim().replaceAll(',', '.'));
    if (variable == 'presion') {
      final b = num.tryParse(_b.text.trim().replaceAll(',', '.'));
      if (a == null || b == null) return tr('Escribe los dos números de la presión.');
      final e = validarPresion(a, b); if (e != null) return e;
      resp[variable] = [a, b]; return null;
    }
    if (a == null) return tr('Escribe el número.');
    // Fuera de lo físicamente posible es un error de dedo (p. ej. 1200 en vez de 120): no se envía.
    final e = validarMedicion(variable, a); if (e != null) return e;
    resp[variable] = a; return null;
  }

  /// Valor posible pero raro: se pide confirmar el número (un error de dedo generaría una alerta falsa;
  /// un valor real y peligroso se envía igual después de confirmar).
  bool _inusual(Map q) {
    final v = resp['${q['variable']}'];
    if (q['tipo'] == 'sintoma') return false;
    return v is List ? presionInusual(v[0] as num, v[1] as num) : v is num && medicionInusual('${q['variable']}', v);
  }

  Future<bool> _confirmarInusual(Map q) async {
    final v = resp['${q['variable']}'];
    final texto = v is List ? '${v[0]}/${v[1]}' : '$v';
    return ConfirmationDialog.show(context, titulo: tr('¿Es correcto {v} {u}?', {'v': texto, 'u': '${q['unidad'] ?? ''}'}),
        mensaje: tr('Es un valor poco común. Revisa que lo escribiste igual que en el aparato.'),
        ok: tr('Sí, es correcto'), cancel: tr('Corregir'));
  }

  Future<void> _enviar(List qs) async {
    final tomado = ahoraUtc();
    final lote = {'registros': [for (final q in qs) if (resp[q['variable']] != null)
      registroParaApi('${q['variable']}', '${q['tipo']}', resp[q['variable']]!, tomado)]};
    setState(() { busy = true; err = null; });
    try {
      final r = await ref.read(apiProvider).crearRegistro(pid(ref), lote);
      ref.invalidate(historialProvider); ref.invalidate(futureFor('plan'));
      if (mounted) context.push('/resultado', extra: r);
    } catch (e) {
      if (!mounted) return;
      if (!isNetworkError(e)) { setState(() { busy = false; err = mensajeError(e) ?? tr('No se pudo guardar. Intenta de nuevo.'); }); return; }
      ref.read(syncProvider.notifier).encolar('registro', pid(ref), lote); // mismo lote, mismos id_local
      aviso(context, tr('Sin conexión: guardado en el teléfono. Se enviará solo.')); context.go('/hoy');
    }
    if (mounted) setState(() => busy = false);
  }

  Widget _entrada(BuildContext c, Map q) {
    final big = escalaDe(c) >= 1.4 ? Theme.of(c).textTheme.headlineMedium : Theme.of(c).textTheme.headlineLarge;
    InputDecoration dec(String? l) => InputDecoration(labelText: l == null ? null : tr(l), suffixText: '${q['unidad'] ?? ''}');
    if (q['tipo'] == 'sintoma') {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var n = 0; n < _escala.length; n++) Padding(padding: const EdgeInsets.only(bottom: 8),
        child: BigButton(tr(_escala[n]), secondary: _sintoma != n, icon: _sintoma == n ? Icons.check : null,
          onTap: () => setState(() => _sintoma = n)))]);
    }
    const kt = TextInputType.numberWithOptions(decimal: true);
    final solo = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')), LengthLimitingTextInputFormatter(6)];
    if (q['variable'] == 'presion') {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: _a, autofocus: true, keyboardType: kt, style: big, textAlign: TextAlign.center, inputFormatters: solo, decoration: dec('Arriba (sistólica)')),
        const SizedBox(height: 16),
        TextField(controller: _b, keyboardType: kt, style: big, textAlign: TextAlign.center, inputFormatters: solo, decoration: dec('Abajo (diastólica)'))]);
    }
    return TextField(controller: _a, autofocus: true, keyboardType: kt, style: big, textAlign: TextAlign.center, inputFormatters: solo, decoration: dec(null));
  }

  @override
  Widget build(BuildContext c) => page(c, tr('Registrar'), AsyncView(ref.watch(futureFor('plan')), (d) {
    // Se preguntan primero las que aún no se contestan hoy; si ya se contestó todo, se puede registrar de nuevo.
    final todas = (d['preguntas'] as List? ?? []);
    final pend = todas.where((q) => q['contestada_hoy'] != true).toList();
    final qs = pend.isEmpty ? todas : pend;
    if (qs.isEmpty) return Center(child: Text(tr('Hoy no hay preguntas en tu plan.')));
    if (i >= qs.length) i = qs.length - 1;
    final q = qs[i] as Map; final ultima = i == qs.length - 1;
    return Column(children: [
      Expanded(child: QuestionStep(index: i, total: qs.length, questionKey: '${q['message_key']}', respaldo: q['respaldo'], last: ultima,
        input: _entrada(c, q),
        onPrev: i > 0 && !busy ? () { setState(() { i--; _cargar(qs[i]); err = null; }); } : null,
        onNext: busy ? null : () async {
          final e = _guardarRespuesta(q);
          if (e != null) { setState(() => err = e); return; }
          if (_inusual(q) && !await _confirmarInusual(q)) { resp.remove('${q['variable']}'); return; }
          if (!mounted) return;
          if (!ultima) { setState(() { i++; _cargar(qs[i]); err = null; }); return; }
          _enviar(qs);
        })),
      if (err != null) Semantics(liveRegion: true, child: Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Text(err!, style: const TextStyle(color: C.error, fontWeight: FontWeight.w600))))]);
  }, onRetry: () => ref.invalidate(futureFor('plan'))));
}
