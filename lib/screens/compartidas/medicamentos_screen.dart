import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/state.dart';
import '../../core/theme.dart';
import '../../widgets/components.dart';
import '../shared.dart';
import '../../core/tr.dart';
import '../../core/escala_texto.dart';

/// Adherencia de los últimos 14 días: GET /pacientes/:id/tomas?dias=14.
final adherenciaProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) => ref.read(apiProvider).adherencia(id));

/// Tarjeta "Tomaste X de Y" (se oculta si la API no trae el dato).
class TarjetaAdherencia extends ConsumerWidget { final String pacienteId;
  const TarjetaAdherencia({super.key, required this.pacienteId});
  @override
  Widget build(BuildContext c, WidgetRef ref) => ref.watch(adherenciaProvider(pacienteId)).maybeWhen(orElse: () => const SizedBox.shrink(),
    data: (a) {
      final pct = a['porcentaje']; if (pct is! num) return const SizedBox.shrink();
      final col = pct >= 80 ? C.success : pct >= 60 ? C.warning : C.error;
      return InfoCard(child: Row(children: [
        SizedBox(width: 56, height: 56, child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(value: pct / 100, strokeWidth: 6, color: col, backgroundColor: C.border),
          Text('${pct.round()}%', style: const TextStyle(fontWeight: FontWeight.w700))])),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Adherencia (últimos 14 días)'), style: Theme.of(c).textTheme.labelLarge),
          Text(tr('Tomadas: {t} · Omitidas: {o}', {'t': a['tomadas'] ?? '—', 'o': a['omitidas'] ?? '—'})),
          if ((a['sin_medicina'] ?? 0) is num && (a['sin_medicina'] ?? 0) > 0)
            Text(tr('Sin medicamento: {n}', {'n': a['sin_medicina']}), style: const TextStyle(color: C.warning))]))]));
    });
}

// 6. Medicamentos activos. El escaneo (foto -> OCR -> revisión -> horarios -> confirmación) vive en /receta.
class MedicamentosScreen extends ConsumerWidget { const MedicamentosScreen({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    ref.watch(sessionProvider.select((s) => s?.patientId));
    return page(c, tr('Mis medicamentos'), AsyncView(ref.watch(futureFor('meds')),
      (d) => ListView(padding: EdgeInsets.fromLTRB(16, 16, 16, 40 + 72 * escalaDe(c)), children: [
        TarjetaAdherencia(pacienteId: pid(ref)), const SizedBox(height: 12),
        for (final m in (d as List)) Padding(padding: const EdgeInsets.only(bottom: 12), child: InfoCard(child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['nombre']} ${m['concentracion']}'.trim(), style: Theme.of(c).textTheme.headlineSmall),
            Text([m['dosis'], m['frecuencia']].where((x) => '${x ?? ''}'.isNotEmpty).join(' · ')),
            if ((m['horarios'] as List? ?? []).isNotEmpty) Text('${tr('Horarios')}: ${(m['horarios'] as List).join(', ')}',
              style: Theme.of(c).textTheme.bodySmall)])),
          if (m['message_key'] != null) ListenButton('${m['message_key']}')])))]),
      onRetry: () => ref.invalidate(futureFor('meds')), emptyTitle: tr('Aún no tienes medicamentos'),
      emptyMessage: tr('Toma una foto de tu receta o caja para agregarlos.')),
      fab: FloatingActionButton.extended(icon: const Icon(Icons.photo_camera), label: Text(tr('Escanear receta o caja')), onPressed: () => c.push('/receta')));
  }
}
