import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../widgets/cards.dart';
import '../core/tr.dart';
import '../widgets/marca.dart';

/// Scaffold base: título, campana de notificaciones y botón flotante opcional.
Widget page(BuildContext c, String title, Widget body, {bool bell = true, Widget? fab}) => Scaffold(
    appBar: AppBar(title: Text(tr(title), style: Theme.of(c).textTheme.headlineSmall), backgroundColor: C.bg,
        // Pantallas raíz (pestañas): icono SENDA; pantallas abiertas encima: flecha de regreso.
        leading: (ModalRoute.of(c)?.canPop ?? false) ? null
            : const Padding(padding: EdgeInsets.all(10), child: IconoSenda(tam: 36, decorativo: true)),
        actions: [const SelectorPaciente(), if (bell) const NotifBell()]),
    body: body, floatingActionButton: fab == null ? null : MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: MediaQuery.textScalerOf(c).clamp(maxScaleFactor: 1.3)), child: fab));

/// Cuidador con más de un familiar a su cargo: elige a quién ve (GET /auth/yo -> pacientes_a_cargo).
class SelectorPaciente extends ConsumerWidget { const SelectorPaciente({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    if (s == null || s.role != Role.cuidador || s.pacientesACargo.length < 2) return const SizedBox.shrink();
    final actual = s.pacientesACargo.firstWhere((p) => p['id'] == s.patientId, orElse: () => s.pacientesACargo.first);
    return PopupMenuButton<String>(tooltip: tr('Cambiar de paciente'), initialValue: s.patientId,
      onSelected: (id) => ref.read(sessionProvider.notifier).elegirPaciente(id),
      itemBuilder: (_) => [for (final p in s.pacientesACargo) PopupMenuItem(value: '${p['id']}', child: Text('${p['nombre']}'))],
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.person_outline), const SizedBox(width: 4),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 120), child: Text('${actual['nombre']}'.split(' ').first, overflow: TextOverflow.ellipsis)),
        const Icon(Icons.arrow_drop_down)])));
  }
}

/// Nombre legible de una variable de registro de la API.
String nombreVariable(String v) => switch (v) { 'presion' => 'Presión', 'glucosa' => 'Glucosa', 'peso' => 'Peso',
  'temperatura' => 'Temperatura', 'frecuencia_cardiaca' => 'Frecuencia cardiaca', _ => v.replaceAll('_', ' ') };

/// Mensaje breve de éxito o error (con icono y texto, no solo color).
void aviso(BuildContext c, String msg, {bool ok = true}) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(
    content: Row(children: [Icon(ok ? Icons.check_circle : Icons.error_outline, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(tr(msg)))]),
    backgroundColor: ok ? C.success : C.error));

/// Par etiqueta / valor.
Widget dato(BuildContext c, String l, Object? v) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr(l), style: Theme.of(c).textTheme.bodySmall?.copyWith(color: C.text2)),
      Text(v == null || '$v'.isEmpty ? '—' : '$v', style: Theme.of(c).textTheme.bodyMedium)]));

/// Id del paciente activo (el cuidador usará el paciente seleccionado; pendiente).
String _pidFrom(Session s) => s.patientId ?? s.userId;

/// Para usar dentro de widgets (WidgetRef).
String pid(WidgetRef r) => _pidFrom(r.read(sessionProvider)!);

/// Consultas GET compartidas por clave. Conectar aquí cada endpoint nuevo.
final futureFor = FutureProvider.family<dynamic, String>((ref, key) {
  final a = ref.read(apiProvider); final s = ref.read(sessionProvider)!;
  ref.watch(sessionProvider.select((s) => s?.patientId)); // se recarga al cambiar de paciente
  final id = _pidFrom(s);
  return switch (key) { 'plan' => a.plan(id), 'horarios' => a.horarios(id), 'meds' => a.medicamentos(id),
    'qr' => a.qr(id), 'perfil' => s.role == Role.paciente ? a.paciente(id) : a.yo(),
    'alertas' => a.alertas(), 'pacientes' => a.pacientes(), _ => a.yo() };
});

/// Historial de mediciones (180 días) de un paciente. Lo usan el propio paciente, su cuidador y el médico.
final historialProvider = FutureProvider.family<dynamic, String>((ref, id) => ref.read(apiProvider).registros(id, dias: 180));

/// Programas de cuidado: clave (dato) -> nombre en el idioma actual.
Map<String, String> get programasCuidado =>
    {'embarazo': tr('Embarazo y puerperio'), 'cronico': tr('Crónico-degenerativas'), 'adulto_mayor': tr('Adulto mayor')};
const tiposSangre = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'No sé'];

/// Lista acotada: fármacos que causan alergia con más frecuencia. Si no está, el usuario elige "Otro medicamento…".
const alergiasFarmacos = ['Penicilina', 'Amoxicilina', 'Cefalosporinas', 'Sulfas (sulfonamidas)',
  'Aspirina (ácido acetilsalicílico)', 'Ibuprofeno', 'Naproxeno', 'Diclofenaco', 'Metamizol', 'Paracetamol'];

/// Alergias a fármacos como lista. Acepta lista o texto separado por comas (datos anteriores).
List<String> listaAlergias(Object? v) => v is List ? [for (final a in v) if ('$a'.trim().isNotEmpty) '$a'.trim()]
    : '${v ?? ''}'.split(',').map((a) => a.trim()).where((a) => a.isNotEmpty).toList();
String? textoAlergias(Object? v) { final l = listaAlergias(v); return l.isEmpty ? tr('Ninguna registrada') : l.join(', '); }
String fmtFecha(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
