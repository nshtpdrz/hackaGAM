import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/notifs.dart';
import '../core/state.dart';
import '../core/theme.dart';
import 'components.dart';
import '../core/tr.dart';
import '../core/escala_texto.dart';

class AlertCard extends StatelessWidget {
  final Map a; final VoidCallback onTap; const AlertCard({super.key, required this.a, required this.onTap});
  @override
  Widget build(BuildContext c) => Semantics(button: true, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap,
    child: InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SemaforoBadge('${a['nivel']}'), Text('${a['paciente']}', style: Theme.of(c).textTheme.labelLarge)]),
      const SizedBox(height: 8), MsgText('${a['message_key']}'),
      if (a['hora'] != null) Padding(padding: const EdgeInsets.only(top: 4),
          child: Text('${a['hora']}', style: Theme.of(c).textTheme.bodySmall?.copyWith(color: C.text2)))]))));
}

class NotificationCard extends ConsumerWidget {
  final Map n; final bool leida; final VoidCallback onTap;
  const NotificationCard({super.key, required this.n, required this.leida, required this.onTap});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final cat = ref.watch(trProvider);
    final icon = switch (n['tipo']) { 'alerta' => Icons.notification_important_outlined, 'omitida' => Icons.event_busy, _ => Icons.alarm };
    final tipo = switch (n['tipo']) { 'alerta' => tr('Alerta'), 'omitida' => tr('Toma omitida'), _ => tr('Recordatorio') };
    final detalle = n['key'] != null ? cat('${n['key']}').text : '${n['detalle'] ?? ''}';
    final w = leida ? FontWeight.w400 : FontWeight.w700;
    return Semantics(button: true, excludeSemantics: true, label: '${leida ? '' : tr('Sin leer. ')}$tipo. ${n['titulo']}. $detalle',
      child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: InfoCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: C.primary), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text(tipo, style: Theme.of(c).textTheme.bodySmall?.copyWith(color: C.text2)), const SizedBox(width: 8),
            if (!leida) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: C.p100, borderRadius: BorderRadius.circular(8)),
              child: Text(tr('Nueva'), style: Theme.of(c).textTheme.bodySmall?.copyWith(color: C.primary, fontWeight: FontWeight.w700)))]),
          Text('${n['titulo']}', style: Theme.of(c).textTheme.bodyLarge?.copyWith(fontWeight: w)),
          Text(detalle, style: Theme.of(c).textTheme.bodyMedium)]))]))));
  }
}

class PatientCard extends StatelessWidget {
  final Map p; final VoidCallback? onTap; const PatientCard({super.key, required this.p, this.onTap});
  @override
  Widget build(BuildContext c) {
    final datos = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${p['nombre']}', style: Theme.of(c).textTheme.bodyLarge),
      if (p['edad'] != null) Text(tr('{n} años', {'n': p['edad']}), style: Theme.of(c).textTheme.bodyMedium),
      if ((p['alertas_abiertas'] ?? 0) is num && (p['alertas_abiertas'] ?? 0) > 0) Padding(padding: const EdgeInsets.only(top: 4),
        child: Row(children: [const Icon(Icons.notification_important_outlined, size: 18, color: C.error), const SizedBox(width: 4),
          Flexible(child: Text(tr('{n} alerta(s) abierta(s)', {'n': p['alertas_abiertas']}),
            style: Theme.of(c).textTheme.bodySmall?.copyWith(color: C.error, fontWeight: FontWeight.w700)))]))]);
    final badge = SemaforoBadge('${p['semaforo'] ?? 'verde'}');
    // El semáforo va a la derecha solo si hay espacio (tableta o letra normal en pantalla ancha);
    // en celular, o con letra grande, baja debajo del nombre para no partir palabras.
    return Semantics(button: onTap != null, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap,
      child: InfoCard(child: LayoutBuilder(builder: (_, box) => box.maxWidth / escalaDe(c) < 400
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [datos, const SizedBox(height: 8), badge])
        : Row(children: [Expanded(child: datos), const SizedBox(width: 12), badge])))));
  }
}

/// Campana con contador de no leídas, para el AppBar.
class NotifBell extends ConsumerWidget {
  const NotifBell({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final n = ref.watch(noLeidasProvider);
    return IconButton(tooltip: n > 0 ? tr('Notificaciones, {n} sin leer', {'n': n}) : tr('Notificaciones'), onPressed: () => c.push('/notificaciones'),
      icon: Badge(isLabelVisible: n > 0, label: Text('$n'), child: const Icon(Icons.notifications_outlined)));
  }
}
