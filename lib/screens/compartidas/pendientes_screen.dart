import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/mock_api.dart';
import '../../core/sync.dart';
import '../../core/theme.dart';
import '../../widgets/components.dart';
import '../../widgets/state_views.dart';
import '../../widgets/sync_status.dart';
import '../shared.dart';
import '../../core/tr.dart';

// Sincronización: cola local de registros y tomas pendientes de enviar.
class PendientesScreen extends ConsumerWidget { const PendientesScreen({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final s = ref.watch(syncProvider); final online = ref.watch(onlineProvider);
    String hora(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return page(c, tr('Sincronización'), Column(children: [
      const SyncStatus(),
      if (useMock) SwitchListTile(title: Text(tr('Simular sin conexión (demo)')), value: ref.watch(simOfflineProvider), onChanged: (v) {
        MockInterceptor.offline = v; ref.read(simOfflineProvider.notifier).state = v; }),
      if (s.error != null) Padding(padding: const EdgeInsets.all(16), child: Text(tr('Último error: {e}', {'e': tr(s.error!)}))),
      Expanded(child: s.cola.isEmpty && s.rechazadas.isEmpty
        ? EmptyView(icon: Icons.cloud_done_outlined, title: tr('Todo sincronizado'), message: tr('No hay registros pendientes de enviar.'))
        : ListView(padding: const EdgeInsets.all(16), children: [
            for (final o in s.cola) Padding(padding: const EdgeInsets.only(bottom: 8),
              child: InfoCard(child: ListTile(contentPadding: EdgeInsets.zero,
                leading: Icon(o.tipo == 'registro' ? Icons.edit_note : Icons.medication_outlined),
                title: Text(o.tipo == 'registro' ? tr('Registro de mediciones') : tr('Toma de medicamento')),
                subtitle: Text(tr('Guardado a las {h}', {'h': hora(o.creado)}) + (o.intentos > 0 ? ' · ${tr('{n} intento(s)', {'n': o.intentos})}' : ''))))),
            // Rechazadas por la API (datos inválidos, sin permiso…): no bloquean la cola; la persona decide.
            if (s.rechazadas.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
              child: Text(tr('No se pudieron enviar'), style: Theme.of(c).textTheme.titleMedium)),
            for (final o in s.rechazadas) Padding(padding: const EdgeInsets.only(bottom: 8), child: InfoCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.error_outline, color: C.error),
                  title: Text(o.tipo == 'registro' ? tr('Registro de mediciones') : tr('Toma de medicamento')),
                  subtitle: Text('${tr('Guardado a las {h}', {'h': hora(o.creado)})}\n${o.motivo ?? tr('Error al enviar')}')),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(icon: const Icon(Icons.refresh), label: Text(tr('Reintentar')),
                    onPressed: online ? () => ref.read(syncProvider.notifier).reintentarRechazada(o) : null),
                  TextButton.icon(icon: const Icon(Icons.delete_outline), label: Text(tr('Descartar')),
                    onPressed: () => ref.read(syncProvider.notifier).descartar(o))])])))])),
      if (s.cola.isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: BigButton(s.sincronizando ? tr('Sincronizando…') : tr('Sincronizar ahora'),
        icon: Icons.sync, onTap: (!online || s.sincronizando) ? null : () => ref.read(syncProvider.notifier).flush()))]), bell: false);
  }
}
