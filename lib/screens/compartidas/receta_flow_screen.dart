import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api.dart';
import '../../core/api_modelos.dart';
import '../../core/reminders.dart';
import '../../core/sync.dart';
import '../../core/theme.dart';
import '../../widgets/components.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/medication.dart';
import '../../widgets/state_views.dart';
import '../shared.dart';
import '../../core/tr.dart';

// MEDMAP: foto -> procesamiento -> resultados -> revisión/edición -> horarios -> confirmación.
// Nada de lo detectado se guarda hasta el último paso, cuando la persona confirma.
class RecetaFlowScreen extends ConsumerStatefulWidget { const RecetaFlowScreen({super.key});
  @override ConsumerState<RecetaFlowScreen> createState() => _RecetaState(); }
class _RecetaState extends ConsumerState<RecetaFlowScreen> {
  static const titulos = ['Foto de la receta', 'Leyendo la receta', 'Lo que se detectó', 'Revisa y corrige', 'Horarios de toma', 'Confirmar', 'Listo'];
  int paso = 0, _n = 0; bool busy = false, recordatorios = false, escribir = false; String? err, fotoNombre; Uint8List? foto;
  Map? doc; List<Map<String, dynamic>> meds = [];
  final _texto = TextEditingController();
  @override
  void dispose() { _texto.dispose(); super.dispose(); }

  Future<void> _foto(ImageSource s) async {
    final f = await ImagePicker().pickImage(source: s, maxWidth: 2400, imageQuality: 85);
    if (f == null) return;
    final b = await f.readAsBytes(); // bytes: funciona igual en teléfono y en web
    setState(() { foto = b; fotoNombre = f.name; err = null; });
  }
  bool get _listo => foto != null || (escribir && _texto.text.trim().isNotEmpty);
  Future<void> _procesar() async {
    setState(() { paso = 1; err = null; });
    try {
      final d = await ref.read(apiProvider).subirDocumento(pid(ref), bytes: foto, nombre: fotoNombre,
          texto: escribir ? _texto.text : null);
      doc = d;
      meds = [for (final m in (d['medicamentos'] as List? ?? [])) {...Map<String, dynamic>.from(m as Map), '_k': _n++}];
      if (mounted) setState(() => paso = 2);
    } catch (e) {
      final x = errorApi(e);
      if (mounted) {
        setState(() {
          paso = 0;
          // 503 ocr_no_disponible: se ofrece escribir la receta. 422: pedir otra foto o que la transcriban.
          if (x?.estado == 503 || x?.codigo == 'ocr_no_disponible' || x?.estado == 422) escribir = true;
          err = isNetworkError(e) ? tr('Sin conexión. Para leer la receta necesitas internet.')
              : mensajeError(e) ?? tr('No se pudo leer la receta. Prueba con otra foto.');
        });
      }
    }
  }
  // Los "por revisar" pueden ir sin dosis: el equipo los completa.
  bool get _revisionOk => meds.isNotEmpty && meds.every((m) => '${m['nombre'] ?? ''}'.trim().isNotEmpty &&
      (m['por_revisar'] == true || '${m['dosis'] ?? ''}'.trim().isNotEmpty));
  List<String> _h(int i) => List<String>.from(meds[i]['horarios'] ?? const []);
  String _nombre(int i) => '${meds[i]['nombre']} ${meds[i]['concentracion'] ?? ''}'.trim();

  Future<void> _confirmar() async {
    final ok = await ConfirmationDialog.show(context, titulo: tr('¿Guardar estos medicamentos?'),
        mensaje: tr('Solo se guardará lo que revisaste. Se programarán recordatorios en tu teléfono.'));
    if (!ok || !mounted) return;
    setState(() { busy = true; err = null; });
    try {
      await ref.read(apiProvider).confirmarDocumento('${doc!['id']}', [for (final m in meds) {...m}..remove('_k')]);
      // Guía: después de confirmar se vuelven a pedir los horarios y con ellos se reprograman las alarmas.
      ref.invalidate(futureFor('meds')); ref.invalidate(futureFor('horarios'));
      var rec = true;
      try { await programarAlarmasTomas(await ref.read(futureFor('horarios').future) as List); } catch (_) { rec = false; }
      if (mounted) setState(() { recordatorios = rec; paso = 6; busy = false; });
    } catch (e) {
      if (mounted) setState(() { busy = false; err = isNetworkError(e) ? tr('Sin conexión. No se guardó nada; intenta de nuevo.') : tr('No se pudo guardar. Intenta de nuevo.'); });
    }
  }

  Widget _aviso() => InfoCard(child: Row(children: [const Icon(Icons.info_outline, color: C.info), const SizedBox(width: 12),
    Expanded(child: Text(tr('Un sistema automático leyó la receta y puede equivocarse. No se guarda nada hasta que tú confirmes.'), style: Theme.of(context).textTheme.bodyMedium))]));

  Widget _cuerpo() {
    final t = Theme.of(context).textTheme;
    switch (paso) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('Toma una foto clara de la receta o de la caja del medicamento.'), style: t.bodyLarge), const SizedBox(height: 16),
          BigButton(tr('Tomar foto'), icon: Icons.photo_camera, onTap: () => _foto(ImageSource.camera)), const SizedBox(height: 12),
          BigButton(tr('Elegir de la galería'), icon: Icons.photo_library_outlined, secondary: true, onTap: () => _foto(ImageSource.gallery)),
          if (foto != null) Padding(padding: const EdgeInsets.only(top: 16), child: Row(children: [const Icon(Icons.check_circle, color: C.success),
            const SizedBox(width: 8), Text(tr('Foto lista'))])),
          const SizedBox(height: 12),
          // Sin foto o sin lectura automática: la persona (o su cuidador) transcribe la receta.
          if (!escribir) TextButton.icon(icon: const Icon(Icons.edit_note), label: Text(tr('Prefiero escribir la receta')),
            onPressed: () => setState(() => escribir = true))
          else TextField(controller: _texto, minLines: 4, maxLines: 10, onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: tr('Escribe lo que dice la receta'),
              hintText: tr('Ej.: Naproxeno 250 mg, 1 tableta cada 8 horas por 5 días'), alignLabelWithHint: true))]);
      case 1:
        return SizedBox(height: 240, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(), SizedBox(height: 16), Text(tr('Leyendo tu receta… puede tardar unos segundos.'))])));
      case 2:
        if (meds.isEmpty) {
          return EmptyView(icon: Icons.search_off, title: tr('No detectamos medicamentos'), message: tr('Prueba con una foto más clara y con buena luz.'),
            action: FilledButton(onPressed: () => setState(() { paso = 0; foto = null; }), child: Text(tr('Tomar otra foto'))));
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InfoCard(child: Text(tr('Se detectaron {n} medicamento(s).', {'n': meds.length}), style: t.headlineSmall)), const SizedBox(height: 12),
          if ('${doc?['texto_ocr'] ?? ''}'.isNotEmpty) InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Texto leído'), style: t.labelLarge), Text('${doc!['texto_ocr']}')])),
          // Cruces de medicación (rojo primero) con su fuente.
          for (final a in (doc?['advertencias'] as List? ?? [])) Padding(padding: const EdgeInsets.only(top: 12), child: InfoCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              SemaforoBadge('${a['nivel'] ?? 'ambar'}'), const SizedBox(height: 8),
              if (a['message_key'] != null) MsgText('${a['message_key']}'),
              if (a['fuente'] != null || a['cita'] != null) Padding(padding: const EdgeInsets.only(top: 6),
                child: Text([a['fuente'], a['cita']].whereType<Object>().join(' · '), style: t.bodySmall))]))),
          if ((doc?['alergias_en_documento'] as List? ?? []).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: InfoCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Alergias que aparecen en el documento'), style: t.labelLarge),
              Text(listaAlergias(doc!['alergias_en_documento']).join(', ')),
              Text(tr('Se pasarán a tu expediente para que el equipo de salud las revise.'), style: t.bodySmall)]))),
          const SizedBox(height: 12), _aviso()]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_aviso(),
          for (var i = 0; i < meds.length; i++) Padding(padding: const EdgeInsets.only(top: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // por_revisar: no se identificó la sustancia; se guarda marcado para que el equipo lo revise.
            if (meds[i]['por_revisar'] == true) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: C.warning.withValues(alpha: .12), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.warning)),
              child: Row(children: [const Icon(Icons.warning_amber_rounded, color: C.warning), const SizedBox(width: 8),
                Expanded(child: Text(tr('Por revisar: no lo encontramos en el catálogo. Tu equipo de salud lo revisará.')))])),
            OCRReviewCard(key: ValueKey(meds[i]['_k']), med: meds[i], onChanged: (m) => meds[i] = m, onDiscard: () => setState(() => meds.removeAt(i)))])),
          if (!_revisionOk) Padding(padding: const EdgeInsets.only(top: 12), child: Text(meds.isEmpty ? tr('No queda ningún medicamento.') : tr('Completa nombre y dosis de cada medicamento.'), style: const TextStyle(color: C.error)))]);
      case 4:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('Estos son los horarios propuestos. Cámbialos si hace falta; a esas horas sonará un recordatorio en tu teléfono.'), style: t.bodyLarge),
          for (var i = 0; i < meds.length; i++) Padding(padding: const EdgeInsets.only(top: 12), child: MedicationSchedule(
            medicamento: _nombre(i), horarios: _h(i), onChanged: (l) => setState(() => meds[i] = {...meds[i], 'horarios': l})))]);
      case 5:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('Revisa que todo sea correcto:'), style: t.bodyLarge),
          for (var i = 0; i < meds.length; i++) Padding(padding: const EdgeInsets.only(top: 12), child: InfoCard(child: Text(
            '${_nombre(i)}\n${meds[i]['dosis']} · ${meds[i]['frecuencia'] ?? ''} · ${meds[i]['via'] ?? ''}\n${tr('Horarios')}: ${_h(i).join(', ')}', style: t.bodyMedium)))]);
      default:
        return EmptyView(icon: Icons.check_circle, title: tr('Medicamentos guardados'),
          message: recordatorios ? tr('Los recordatorios quedaron programados en tu teléfono.') : tr('No se pudieron programar los recordatorios. Revisa el permiso de notificaciones.'));
    }
  }

  Widget _pie() {
    Widget atras() => Expanded(child: BigButton(tr('Anterior'), icon: Icons.arrow_back, secondary: true, onTap: () => setState(() => paso--)));
    Widget sig(String l, VoidCallback? f) => Expanded(child: BigButton(l, onTap: f));
    return switch (paso) {
      0 => Row(children: [sig(tr('Analizar receta'), _listo ? _procesar : null)]),
      2 => Row(children: [sig(tr('Revisar medicamentos'), meds.isEmpty ? null : () => setState(() => paso = 3))]),
      3 => Row(children: [atras(), const SizedBox(width: 12), sig(tr('Siguiente'), _revisionOk ? () => setState(() => paso = 4) : null)]),
      4 => Row(children: [atras(), const SizedBox(width: 12), sig(tr('Siguiente'), () => setState(() => paso = 5))]),
      5 => Row(children: [atras(), const SizedBox(width: 12), sig(tr('Confirmar y guardar'), busy ? null : _confirmar)]),
      6 => Row(children: [sig(tr('Listo'), () => context.pop())]),
      _ => const SizedBox.shrink() };
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(tr(titulos[paso])), backgroundColor: C.bg),
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(label: tr('Paso {n} de {t}', {'n': paso + 1, 't': 7}), child: LinearProgressIndicator(value: (paso + 1) / 7, minHeight: 10)),
      const SizedBox(height: 16), Expanded(child: SingleChildScrollView(child: _cuerpo())),
      if (err != null) Semantics(liveRegion: true, child: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(err!, style: const TextStyle(color: C.error)))),
      _pie()]))));
}
