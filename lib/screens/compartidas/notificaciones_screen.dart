import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/notifs.dart';
import '../../core/theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/components.dart';
import '../../widgets/state_views.dart';
import '../../core/tr.dart';
import '../../core/escala_texto.dart';

// Centro de notificaciones: recordatorios, alertas y tomas omitidas; leídas / no leídas.
class NotificacionesScreen extends ConsumerStatefulWidget { const NotificacionesScreen({super.key});
  @override ConsumerState<NotificacionesScreen> createState() => _NotifState(); }
class _NotifState extends ConsumerState<NotificacionesScreen> {
  String filtro = 'todas';
  static const _filtros = {'todas': 'Todas', 'nuevas': 'No leídas', 'alerta': 'Alertas', 'recordatorio': 'Recordatorios', 'omitida': 'Omitidas'};

  void _abrir(Map<String, dynamic> n) {
    ref.read(leidasProvider.notifier).state = {...ref.read(leidasProvider), '${n['id']}'};
    if (n['tipo'] == 'alerta') { context.push('/alerta/${(n['alerta'] as Map)['id']}', extra: n['alerta']); }
    else { context.push('/recordatorio', extra: n['toma']); }
  }
  @override
  Widget build(BuildContext c) {
    final leidas = ref.watch(leidasProvider); final todas = ref.watch(notificacionesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Notificaciones')), backgroundColor: C.bg, actions: [
        // Con letra grande el texto le quita espacio al título: se muestra solo el ícono (con su nombre en el tooltip).
        if (escalaDe(c) >= 1.4)
          IconButton(tooltip: tr('Marcar todas'), icon: const Icon(Icons.done_all),
            onPressed: () => ref.read(leidasProvider.notifier).state = {...leidas, ...?todas.valueOrNull?.map((n) => '${n['id']}')})
        else
          TextButton(onPressed: () => ref.read(leidasProvider.notifier).state = {...leidas, ...?todas.valueOrNull?.map((n) => '${n['id']}')},
            child: Text(tr('Marcar todas')))]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: ChoiceWrap(options: _filtros, isSel: (k) => filtro == k, onTap: (k) => setState(() => filtro = k))),
        Expanded(child: AsyncView(todas, (d) {
          final l = [for (final n in d as List<Map<String, dynamic>>) if (filtro == 'todas' || (filtro == 'nuevas' ? !leidas.contains(n['id']) : n['tipo'] == filtro)) n]
            ..sort((a, b) => (leidas.contains(a['id']) ? 1 : 0).compareTo(leidas.contains(b['id']) ? 1 : 0));
          if (l.isEmpty) return EmptyView(icon: Icons.notifications_none, title: tr('Nada por aquí'), message: tr('No hay notificaciones en este filtro.'));
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
            for (final n in l) Padding(padding: const EdgeInsets.only(bottom: 8),
              child: NotificationCard(n: n, leida: leidas.contains(n['id']), onTap: () => _abrir(n)))]);
        }, onRetry: () => ref.invalidate(notificacionesProvider), emptyTitle: tr('Sin notificaciones'), emptyMessage: tr('Aquí verás recordatorios, alertas y tomas omitidas.')))]));
  }
}
