import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/l10n.dart';
import '../core/state.dart';
import 'components.dart';
import '../core/tr.dart';

/// Idioma, variante, audio, pictogramas, contraste, letra y botones grandes.
/// Hñähñu se integra por catálogo (message_key): texto + audio + pictograma cuando existen.
class AccessibilitySettings extends ConsumerWidget {
  final void Function(Prefs) onChanged; const AccessibilitySettings({super.key, required this.onChanged});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final p = ref.watch(prefsProvider);
    Widget sw(String t, bool v, Prefs Function(bool) f) => SwitchListTile(title: Text(t), value: v, onChanged: (x) => onChanged(f(x)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionLabel(tr('Idioma')),
      ChoiceWrap(options: langs, isSel: (k) => p.lang == k, onTap: (k) => onChanged(p.copy(lang: k))),
      if (p.lang == 'ote') ...[
        SectionLabel(tr('Variante')),
        ChoiceWrap(options: {'ote': tr('Otomí del Mezquital (ote)')}, isSel: (k) => p.variant == k, onTap: (k) => onChanged(p.copy(variant: k))),
        Padding(padding: EdgeInsets.only(top: 8), child: Text(tr('Se muestran texto, audio y pictograma cuando existen en el catálogo.')))],
      const SizedBox(height: 8),
      sw(tr('Prefiero escuchar audios'), p.audio, (x) => p.copy(audio: x)),
      sw(tr('Prefiero pictogramas'), p.pictograms, (x) => p.copy(pictograms: x)),
      sw(tr('Alto contraste'), p.highContrast, (x) => p.copy(highContrast: x)),
      sw(tr('Botones grandes'), p.bigButtons, (x) => p.copy(bigButtons: x)),
      ListTile(title: Text(tr('Tamaño de letra: {n}%', {'n': (p.textScale * 100).round()})), subtitle: Slider(min: 1, max: 2, divisions: 4,
        value: p.textScale, label: '${(p.textScale * 100).round()}%', onChanged: (v) => onChanged(p.copy(textScale: v))))]);
  }
}
