import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/alarma_tomas.dart';
import '../../core/reminders.dart';
import '../../widgets/components.dart';
import '../shared.dart';
import '../../core/tr.dart';

// 2. Hoy
class HoyScreen extends ConsumerWidget { const HoyScreen({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    // Cada vez que se cargan los horarios se (re)programan las alarmas diarias de las tomas.
    ref.listen(futureFor('horarios'), (_, n) => n.whenData((d) { if (d is List) programarAlarmasTomas(d); }));
    final locales = ref.watch(tomasLocalesProvider);
    return page(c, tr('Hoy'), AsyncView(ref.watch(futureFor('horarios')),
      (d) => ListView(padding: const EdgeInsets.all(16), children: [
        Text(tr('Próximas tomas'), style: Theme.of(c).textTheme.headlineSmall), const SizedBox(height: 8),
        for (final h in conEstadoLocal(d as List, locales)) Padding(padding: const EdgeInsets.only(bottom: 12), child: InfoCard(
          child: ListTile(contentPadding: EdgeInsets.zero, minVerticalPadding: 12,
            title: Text(tr('{hora} · {med}', {'hora': h['hora'], 'med': h['medicamento']})),
            subtitle: Text(tr('{dosis} · {estado}', {'dosis': h['dosis'], 'estado': tr(etiquetasEstado['${h['estado']}'] ?? '${h['estado']}')})),
            onTap: () => c.push('/recordatorio', extra: h)))),
        BigButton(tr('Mostrar mi código QR'), icon: Icons.qr_code, secondary: true, onTap: () => c.push('/qr')),
        const SizedBox(height: 12),
        BigButton(tr('Seguimiento de heridas'), icon: Icons.healing_outlined, secondary: true, onTap: () => c.push('/heridas'))]),
      onRetry: () => ref.invalidate(futureFor('horarios'))));
  }
}
