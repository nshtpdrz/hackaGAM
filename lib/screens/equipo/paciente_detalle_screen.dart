import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/state.dart';
import '../../core/theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/components.dart';
import '../compartidas/historial_screen.dart';
import '../compartidas/medicamentos_screen.dart';
import '../shared.dart';
import '../../core/tr.dart';

final _pacienteProvider = FutureProvider.family<dynamic, String>((ref, id) => ref.read(apiProvider).paciente(id));
/// Medicación con cruces (alertas_medicacion con fuente y cita, rojo primero).
final _medsEquipoProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) => ref.read(apiProvider).medicamentosConAlertas(id));

// Detalle de paciente (al escanear su QR o desde el tablero): expediente, medicación, adherencia e historial.
class PacienteDetalleScreen extends ConsumerWidget { final String id;
  const PacienteDetalleScreen({super.key, required this.id});
  @override
  Widget build(BuildContext c, WidgetRef ref) => page(c, tr('Paciente'), AsyncView(ref.watch(_pacienteProvider(id)), (d) {
    final p = d as Map; final cu = p['cuidador'] as Map?; final t = Theme.of(c).textTheme;
    final progs = (p['programas'] as List?)?.map((k) => programasCuidado[k] ?? tr('$k')).join(', ');
    final nac = DateTime.tryParse('${p['fecha_nacimiento'] ?? ''}');
    final medico = ref.watch(sessionProvider)?.esMedico ?? false;
    return HistorialContenido(pacienteId: id, encabezado: [
      PatientCard(p: p),
      const SizedBox(height: 12),
      InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        dato(c, tr('Fecha de nacimiento'), nac == null ? null : fmtFecha(nac)),
        dato(c, tr('Sexo'), p['sexo'] == 'F' ? tr('Mujer') : p['sexo'] == 'M' ? tr('Hombre') : null),
        dato(c, tr('Tipo de sangre'), p['tipo_sangre']),
        dato(c, tr('Alergias a medicamentos'), textoAlergias(p['alergias'])),
        dato(c, tr('Programa de cuidado'), progs), dato(c, tr('Teléfono'), p['telefono']),
        dato(c, tr('Cuidador responsable'), cu == null ? null : '${cu['nombre']} · ${cu['contacto']}')])),
      const SizedBox(height: 12),
      TarjetaAdherencia(pacienteId: id),
      const SizedBox(height: 12),
      _Medicacion(id: id),
      const SizedBox(height: 16),
      if (medico) ...[BigButton(tr('Resumen para consulta'), icon: Icons.summarize_outlined,
        onTap: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => _ResumenScreen(id: id, nombre: '${p['nombre']}')))),
        const SizedBox(height: 12)],
      BigButton(tr('Ver expediente'), icon: Icons.folder_open, secondary: medico, onTap: () => c.push('/expediente/$id')),
      const SizedBox(height: 12),
      BigButton(tr('Heridas en seguimiento'), icon: Icons.healing_outlined, secondary: true, onTap: () => c.push('/paciente/$id/heridas')),
      if (medico) ...[const SizedBox(height: 12),
        BigButton(tr('Plan de control'), icon: Icons.tune, secondary: true, onTap: () => c.push('/plan/$id'))],
      const SizedBox(height: 24),
      Text(tr('Historial de mediciones'), style: t.headlineSmall),
      const SizedBox(height: 12)]);
  }, onRetry: () => ref.invalidate(_pacienteProvider(id))));
}

class _Medicacion extends ConsumerWidget { final String id; const _Medicacion({required this.id});
  @override
  Widget build(BuildContext c, WidgetRef ref) => ref.watch(_medsEquipoProvider(id)).maybeWhen(orElse: () => const SizedBox.shrink(),
    data: (m) {
      final meds = m['medicamentos'] as List; final cruces = m['alertas_medicacion'] as List; final t = Theme.of(c).textTheme;
      return InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Medicación'), style: t.titleMedium), const SizedBox(height: 8),
        if (meds.isEmpty) Text(tr('Sin medicamentos activos.')),
        for (final x in meds) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(
          '• ${'${x['nombre']} ${x['concentracion']}'.trim()} — ${[x['dosis'], x['frecuencia']].where((v) => '${v ?? ''}'.isNotEmpty).join(' · ')}')),
        for (final a in cruces) Padding(padding: const EdgeInsets.only(top: 8), child: Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
            border: Border.all(color: a['nivel'] == 'rojo' ? C.error : C.warning)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SemaforoBadge('${a['nivel']}'), const SizedBox(height: 6),
            if (a['message_key'] != null) MsgText('${a['message_key']}', style: t.bodyMedium),
            if (a['fuente'] != null || a['cita'] != null)
              Text([a['fuente'], a['cita']].whereType<Object>().join(' · '), style: t.bodySmall)])))]));
    });
}

/// Médico: GET /pacientes/:id/resumen?dias=14 -> {resumen: {texto} | null, datos}. Sin IA solo hay datos.
final _resumenProvider = FutureProvider.family<dynamic, String>((ref, id) => ref.read(apiProvider).resumen(id));

class _ResumenScreen extends ConsumerWidget { final String id, nombre; const _ResumenScreen({required this.id, required this.nombre});
  @override
  Widget build(BuildContext c, WidgetRef ref) => page(c, tr('Resumen para consulta'), AsyncView(ref.watch(_resumenProvider(id)), (d) {
    final r = d is Map ? d : const {}; final texto = r['resumen'] is Map ? (r['resumen'] as Map)['texto'] : null;
    final datos = r['datos'] is Map ? r['datos'] as Map : const {};
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(nombre, style: Theme.of(c).textTheme.headlineSmall), Text(tr('Últimos 14 días')), const SizedBox(height: 12),
      if (texto != null) InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.auto_awesome, color: C.info), const SizedBox(width: 8), Text(tr('Resumen automático'), style: Theme.of(c).textTheme.labelLarge)]),
        const SizedBox(height: 8), SelectableText('$texto'), const SizedBox(height: 8),
        Text(tr('Generado automáticamente: verifícalo con los datos.'), style: Theme.of(c).textTheme.bodySmall)]))
      else InfoCard(child: Text(tr('Sin resumen automático: se muestran solo los datos.'))),
      const SizedBox(height: 12),
      InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Datos'), style: Theme.of(c).textTheme.labelLarge),
        for (final e in datos.entries) dato(c, tr('${e.key}'.replaceAll('_', ' ')), e.value is Map
            ? (e.value as Map).entries.map((x) => '${x.key}: ${x.value}').join(' · ') : e.value)]))]);
  }, onRetry: () => ref.invalidate(_resumenProvider(id))), bell: false);
}
