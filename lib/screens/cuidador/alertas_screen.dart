import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/cards.dart';
import '../../widgets/components.dart';
import '../shared.dart';
import '../../core/tr.dart';

// 10/11. Alertas (cuidador y equipo). Atenderlas se hace en el detalle (/alerta/:id).
class AlertasScreen extends ConsumerWidget { const AlertasScreen({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) => page(c, tr('Alertas'), AsyncView(ref.watch(futureFor('alertas')),
    (d) => ListView(padding: const EdgeInsets.all(16), children: [
      for (final a in (d as List)) Padding(padding: const EdgeInsets.only(bottom: 12),
        child: AlertCard(a: a as Map, onTap: () => c.push('/alerta/${a['id']}', extra: a)))]),
    onRetry: () => ref.invalidate(futureFor('alertas')), emptyTitle: tr('Sin alertas activas'), emptyMessage: tr('Cuando haya una alerta la verás aquí.')));
}
