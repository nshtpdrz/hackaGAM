import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../core/l10n.dart';
import '../core/state.dart';
import '../core/theme.dart';
import 'state_views.dart';
import '../core/tr.dart';
import '../core/escala_texto.dart';

final _tts = FlutterTts();
final _player = AudioPlayer();

/// Audio: URL del catálogo (Hñähñu) o TTS (es/en). Devuelve un aviso (traducido) si no se pudo reproducir.
Future<String?> speak(Msg m, String lang) async {
  if (m.audioUrl != null) {
    try { await _player.play(UrlSource(m.audioUrl!)); return null; }
    catch (_) { return tr('No se pudo reproducir el audio. Revisa tu internet.'); } // sin red cae a la voz del teléfono
  }
  final idioma = lang == 'en' ? 'en-US' : 'es-MX';
  try {
    // Sin la voz del idioma instalada el teléfono no dice nada: se avisa cómo instalarla.
    final hay = await _tts.isLanguageAvailable(idioma);
    if (hay == false) {
      return lang == 'en' ? tr('Instala la voz en inglés en los Ajustes del teléfono para escuchar.')
          : tr('Instala la voz en español en los Ajustes del teléfono para escuchar.');
    }
    await _tts.setLanguage(idioma);
    await _tts.speak(m.text);
    return null;
  } catch (_) { return tr('No se pudo leer en voz alta.'); }
}

/// [speak] y, si falla, lo dice en pantalla.
Future<void> hablar(BuildContext c, Msg m, String lang) async {
  final aviso = await speak(m, lang);
  if (aviso != null && c.mounted) ScaffoldMessenger.maybeOf(c)?.showSnackBar(SnackBar(content: Text(aviso)));
}

class BigButton extends StatelessWidget {
  final String label; final IconData? icon; final VoidCallback? onTap; final bool secondary; final Color? color;
  const BigButton(this.label, {super.key, this.icon, this.onTap, this.secondary = false, this.color});
  @override
  Widget build(BuildContext c) {
    final child = Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon), SizedBox(width: 8)], Flexible(child: Text(tr(label)))]);
    // El lector de pantalla lee un solo botón con su texto traducido, dice si está desactivado y lo activa con doble toque.
    return Semantics(button: true, label: tr(label), enabled: onTap != null, onTap: onTap, excludeSemantics: true,
      child: SizedBox(width: double.infinity,
      child: secondary ? OutlinedButton(onPressed: onTap, child: child)
          : FilledButton(style: color == null ? null : FilledButton.styleFrom(backgroundColor: color),
              onPressed: onTap, child: child)));
  }
}

/// message_key: texto siempre visible + audio + pictograma opcional.
class MsgText extends ConsumerWidget {
  /// [respaldo]: texto a mostrar si el catálogo aún no trae [k] (p. ej. una pregunta nueva del plan).
  final String k; final TextStyle? style; final String? respaldo;
  const MsgText(this.k, {super.key, this.style, this.respaldo});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    ref.watch(trProvider); final p = ref.watch(prefsProvider);
    final m = ref.read(catalogProvider).get(p.lang, k, respaldo: respaldo);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (p.pictograms && m.pictogram != null) Padding(padding: const EdgeInsets.only(right: 12),
          child: Image.network(m.pictogram!, width: 48, height: 48, semanticLabel: m.text,
            errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 48, child: Icon(Icons.image_not_supported_outlined, color: C.text2)))),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.text, style: style ?? Theme.of(c).textTheme.bodyLarge),
        // La frase aún no está validada en esta lengua: se muestra en español y se avisa.
        if (m.interprete) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
          const Icon(Icons.record_voice_over_outlined, size: 18, color: C.warning), const SizedBox(width: 6),
          Flexible(child: Text(tr('En español: pide apoyo de un intérprete'), style: Theme.of(c).textTheme.bodySmall?.copyWith(color: C.warning)))]))])),
      ListenButton(k, respaldo: respaldo)]);
  }
}

class ListenButton extends ConsumerWidget {
  final String k; final String? respaldo; const ListenButton(this.k, {super.key, this.respaldo});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    ref.watch(trProvider); final lang = ref.watch(prefsProvider).lang;
    final m = ref.read(catalogProvider).get(lang, k, respaldo: respaldo);
    // Sin audio grabado, la voz del teléfono solo se usa en español o inglés (no sabe leer otomí).
    if (m.audioUrl == null && lang == 'ote' && !m.interprete) return const SizedBox.shrink();
    return Semantics(button: true, label: ref.watch(trProvider)('listen').text, enabled: true, onTap: () => hablar(c, m, lang), excludeSemantics: true,
      child: IconButton(constraints: BoxConstraints(minWidth: 48, minHeight: 48),
        style: IconButton.styleFrom(backgroundColor: C.p100), color: C.primary,
        icon: Icon(Icons.volume_up_rounded), onPressed: () => hablar(c, m, lang)));
  }
}

/// Semáforo: color + icono + texto (nunca solo color).
class SemaforoBadge extends ConsumerWidget {
  final String nivel; // verde | ambar | rojo
  const SemaforoBadge(this.nivel, {super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final (col, ic) = switch (nivel) { 'verde' => (C.success, Icons.check_circle),
      'ambar' => (C.warning, Icons.warning_amber_rounded), _ => (C.error, Icons.error) };
    final t = ref.watch(trProvider)('semaforo.$nivel').text;
    return Semantics(label: t, child: Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: col.withValues(alpha: .12), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: col, width: 2)),
      // El ícono siempre junto al texto; si el ancho es limitado, el texto baja de renglón.
      child: LayoutBuilder(builder: (_, box) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(ic, color: col, size: 28), const SizedBox(width: 8),
        if (box.maxWidth.isFinite) Flexible(child: Text(t, style: Theme.of(c).textTheme.labelLarge))
        else Text(t, style: Theme.of(c).textTheme.labelLarge)]))));
  }
}

class InfoCard extends StatelessWidget {
  final Widget child; const InfoCard({super.key, required this.child});
  @override
  Widget build(BuildContext c) => Card(child: Padding(padding: EdgeInsets.all(16), child: child));
}

/// Carga / vacío / error para datos de la API (aplica a todas las pantallas que lo usan).
class AsyncView extends StatelessWidget {
  final AsyncValue<dynamic> v; final Widget Function(dynamic) builder; final VoidCallback? onRetry; final String emptyTitle; final String? emptyMessage;
  const AsyncView(this.v, this.builder, {super.key, this.onRetry, this.emptyTitle = 'No hay información todavía', this.emptyMessage});
  @override
  Widget build(BuildContext c) => v.when(
    data: (d) => d is List && d.isEmpty ? EmptyView(icon: Icons.inbox_outlined, title: emptyTitle, message: emptyMessage) : builder(d),
    loading: () => Semantics(label: tr('Cargando'), child: const Center(child: CircularProgressIndicator())),
    error: (e, _) => ErrorView(error: e, onRetry: onRetry));
}

/// "Una pregunta por pantalla": barra de progreso + navegación gigante.
class QuestionStep extends ConsumerWidget {
  final int index, total; final String questionKey; final String? respaldo; final Widget input; final VoidCallback? onPrev, onNext; final bool last;
  const QuestionStep({super.key, required this.index, required this.total, required this.questionKey, this.respaldo,
      required this.input, this.onPrev, this.onNext, this.last = false});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(label: tr('Paso {n} de {t}', {'n': index + 1, 't': total}), child: LinearProgressIndicator(value: (index + 1) / total, minHeight: 10)),
      const SizedBox(height: 16),
      Expanded(child: ListView(children: [
        MsgText(questionKey, respaldo: respaldo, style: escalaDe(c) >= 1.4 ? Theme.of(c).textTheme.headlineSmall : Theme.of(c).textTheme.headlineMedium),
        const SizedBox(height: 24), input, const SizedBox(height: 16)])),
      const SizedBox(height: 8),
      Row(children: [
        if (onPrev != null) Expanded(child: BigButton(t('prev').text, icon: Icons.arrow_back, secondary: true, onTap: onPrev)),
        if (onPrev != null) const SizedBox(width: 12),
        Expanded(child: BigButton(t(last ? 'save' : 'next').text, onTap: onNext))])]));
  }
}

/// Opciones tipo chip (selección única o múltiple según el callback). Muestra check al seleccionar.
class ChoiceWrap extends StatelessWidget {
  final Map<String, String> options; final bool Function(String) isSel; final void Function(String) onTap;
  const ChoiceWrap({super.key, required this.options, required this.isSel, required this.onTap});
  @override
  // Opción propia (en vez de ChoiceChip): si el texto no cabe, baja de renglón en lugar de cortarse con letra grande.
  Widget build(BuildContext c) => Wrap(spacing: 8, runSpacing: 8, children: [
    for (final e in options.entries) _Opcion(texto: tr(e.value), sel: isSel(e.key), onTap: () => onTap(e.key))]);
}

class _Opcion extends StatelessWidget {
  final String texto; final bool sel; final VoidCallback onTap;
  const _Opcion({required this.texto, required this.sel, required this.onTap});
  @override
  Widget build(BuildContext c) {
    final cs = Theme.of(c).colorScheme;
    return Semantics(button: true, selected: sel, inMutuallyExclusiveGroup: true, child: Material(
      color: sel ? cs.secondaryContainer : C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: sel ? cs.secondaryContainer : C.border)),
      child: InkWell(borderRadius: BorderRadius.circular(8), onTap: onTap, child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (sel) ...[Icon(Icons.check, size: 18, color: cs.onSecondaryContainer), const SizedBox(width: 6)],
            Flexible(child: Text(texto, style: Theme.of(c).textTheme.labelLarge?.copyWith(color: sel ? cs.onSecondaryContainer : C.text)))]))))));
  }
}

class AppField extends StatelessWidget {
  final TextEditingController ctl; final String label; final bool obscure, readOnly; final TextInputType? kt;
  final List<TextInputFormatter>? formatos; final int? maxLength; final Iterable<String>? autofill; final String? ayuda;
  const AppField(this.ctl, this.label, {super.key, this.obscure = false, this.readOnly = false, this.kt,
    this.formatos, this.maxLength, this.autofill, this.ayuda});
  @override
  Widget build(BuildContext c) => Padding(padding: const EdgeInsets.only(bottom: 16), child: TextField(
      controller: ctl, obscureText: obscure, readOnly: readOnly, keyboardType: kt, inputFormatters: formatos,
      maxLength: maxLength, autofillHints: autofill, autocorrect: !obscure, enableSuggestions: !obscure,
      decoration: InputDecoration(labelText: tr(label), helperText: ayuda, helperMaxLines: 3, counterText: '')));
}

/// Campo de contraseña con botón para mostrarla u ocultarla (ayuda a quien escribe con dificultad).
class CampoContrasena extends StatefulWidget {
  final TextEditingController ctl; final String label; final bool nueva; final String? ayuda; final ValueChanged<String>? alEnviar;
  const CampoContrasena(this.ctl, this.label, {super.key, this.nueva = false, this.ayuda, this.alEnviar});
  @override State<CampoContrasena> createState() => _CampoContrasenaState();
}
class _CampoContrasenaState extends State<CampoContrasena> {
  bool _ver = false;
  @override
  Widget build(BuildContext c) => Padding(padding: const EdgeInsets.only(bottom: 16), child: TextField(
    controller: widget.ctl, obscureText: !_ver, autocorrect: false, enableSuggestions: false, maxLength: 72,
    autofillHints: [widget.nueva ? AutofillHints.newPassword : AutofillHints.password],
    textInputAction: widget.alEnviar == null ? TextInputAction.next : TextInputAction.done, onSubmitted: widget.alEnviar,
    decoration: InputDecoration(labelText: tr(widget.label), helperText: widget.ayuda, helperMaxLines: 3, counterText: '',
      suffixIcon: IconButton(tooltip: _ver ? tr('Ocultar contraseña') : tr('Mostrar contraseña'),
        icon: Icon(_ver ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _ver = !_ver)))));
}

class SectionLabel extends StatelessWidget {
  final String text; const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext c) => Padding(padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(tr(text), style: Theme.of(c).textTheme.labelLarge));
}
