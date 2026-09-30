import 'package:flutter/material.dart';
import '../core/reminders.dart';
import '../core/theme.dart';
import 'components.dart';
import '../core/tr.dart';

/// Medicamento detectado por OCR/IA: editable. Nunca se guarda solo; quien lo usa decide cuándo confirmar.
class OCRReviewCard extends StatefulWidget {
  final Map<String, dynamic> med; final ValueChanged<Map<String, dynamic>> onChanged; final VoidCallback onDiscard;
  const OCRReviewCard({super.key, required this.med, required this.onChanged, required this.onDiscard});
  @override State<OCRReviewCard> createState() => _OCRState();
}
class _OCRState extends State<OCRReviewCard> {
  static const _campos = {'nombre': 'Nombre comercial', 'sustancia': 'Sustancia activa', 'concentracion': 'Concentración',
    'dosis': 'Dosis', 'frecuencia': 'Frecuencia', 'via': 'Vía', 'momento': 'Indicaciones (p. ej. con alimentos)'};
  late final Map<String, TextEditingController> _c = {for (final k in _campos.keys) k: TextEditingController(text: '${widget.med[k] ?? ''}')};
  void _emit() => widget.onChanged({...widget.med, for (final e in _c.entries) e.key: e.value.text.trim()});
  @override
  void dispose() { for (final x in _c.values) { x.dispose(); } super.dispose(); }
  @override
  Widget build(BuildContext c) => InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [const Icon(Icons.warning_amber_rounded, color: C.warning), const SizedBox(width: 8),
      Expanded(child: Text(tr('Detectado automáticamente · revísalo'), style: Theme.of(c).textTheme.labelLarge))]),
    const SizedBox(height: 12),
    for (final e in _campos.entries) Padding(padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: _c[e.key], onChanged: (_) => _emit(), decoration: InputDecoration(labelText: tr(e.value)))),
    TextButton.icon(onPressed: widget.onDiscard, icon: const Icon(Icons.delete_outline), label: Text(tr('Descartar este medicamento')))]));
}

/// Horarios de un medicamento: agregar, editar y quitar. Emite la lista ordenada en "HH:mm".
class MedicationSchedule extends StatelessWidget {
  final String medicamento; final List<String> horarios; final ValueChanged<List<String>> onChanged;
  const MedicationSchedule({super.key, required this.medicamento, required this.horarios, required this.onChanged});
  Future<void> _pick(BuildContext c, int? i) async {
    final t = await showTimePicker(context: c, initialTime: i == null ? const TimeOfDay(hour: 8, minute: 0) : parseHora(horarios[i]),
      // Los selectores de Material se desbordan con letra mayor a 130 %.
      builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(textScaler: MediaQuery.textScalerOf(ctx).clamp(maxScaleFactor: 1.3)), child: child!));
    if (t == null) return;
    final s = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final l = [...horarios];
    if (i == null) { l.add(s); } else { l[i] = s; }
    l.sort(); onChanged(l);
  }
  @override
  Widget build(BuildContext c) => InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(medicamento, style: Theme.of(c).textTheme.headlineSmall), const SizedBox(height: 8),
    if (horarios.isEmpty) Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text(tr('Sin horarios. Agrega al menos uno.'))),
    for (var i = 0; i < horarios.length; i++) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.alarm), title: Text(horarios[i]),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(tooltip: tr('Cambiar horario {h}', {'h': horarios[i]}), icon: const Icon(Icons.edit_outlined), onPressed: () => _pick(c, i)),
        IconButton(tooltip: tr('Quitar horario {h}', {'h': horarios[i]}), icon: const Icon(Icons.delete_outline),
          onPressed: () => onChanged([...horarios]..removeAt(i)))])),
    const SizedBox(height: 8), BigButton(tr('Agregar horario'), icon: Icons.add, secondary: true, onTap: () => _pick(c, null))]));
}
