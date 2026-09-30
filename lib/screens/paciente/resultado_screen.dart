import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_modelos.dart';
import '../../core/state.dart';
import '../../core/theme.dart';
import '../../widgets/components.dart';
import '../../widgets/pedir_ayuda.dart';
import '../shared.dart';
import '../../core/tr.dart';

// 4. Resultado del registro: nivel (color) + mensaje_clave (texto y audio) + alertas creadas.
// estado "incompleta": faltan datos; nunca se afirma que todo está bien.
class ResultadoScreen extends ConsumerWidget { final Map data; const ResultadoScreen({super.key, required this.data});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final nivel = '${data['semaforo'] ?? 'verde'}'; final incompleta = data['estado'] == 'incompleta';
    final faltan = [for (final f in (data['faltantes'] as List? ?? const [])) '$f'];
    final alertas = (data['alertas'] as List? ?? const []).length;
    return page(c, tr('Resultado'), ListView(padding: const EdgeInsets.all(24), children: [
      if (!incompleta) Center(child: SemaforoBadge(nivel)),
      if (incompleta) InfoCard(child: Row(children: [const Icon(Icons.help_outline, color: C.info, size: 32), const SizedBox(width: 12),
        Expanded(child: Text(tr('Faltan datos para evaluar tu registro'), style: Theme.of(c).textTheme.titleMedium))])),
      const SizedBox(height: 24),
      InfoCard(child: MsgText('${data['message_key']}')),
      if (incompleta && faltan.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: InfoCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Falta:'), style: Theme.of(c).textTheme.labelLarge),
          for (final f in faltan) Text('• ${_faltante(f)}')]))),
      if (alertas > 0) Padding(padding: const EdgeInsets.only(top: 12), child: InfoCard(child: Row(children: [
        const Icon(Icons.notifications_active_outlined, color: C.error), const SizedBox(width: 12),
        Expanded(child: Text(tr('Avisamos a tu equipo de salud y a tu cuidador.')))]))),
      const SizedBox(height: 24),
      if (!incompleta && nivel != 'verde') BigButton(ref.watch(trProvider)('help.caregiver').text, icon: Icons.phone, color: C.error,
        onTap: () => pedirAyuda(c, urgente: nivel == 'rojo')),
      if (incompleta) BigButton(tr('Contestar lo que falta'), icon: Icons.edit_note, onTap: () => c.go('/registrar')),
      const SizedBox(height: 12), BigButton(tr('Listo'), secondary: true, onTap: () => c.go('/hoy'))]));
  }

  /// "rango:presion" = el médico aún no fija la meta; si no, es un síntoma sin contestar.
  String _faltante(String f) => f.startsWith('rango:')
      ? tr('Tu médico aún no fija la meta de {v}', {'v': tr(nombreVariable(f.substring(6))).toLowerCase()})
      : tr(nombresSintoma[f] ?? f.replaceAll('_', ' '));
}
