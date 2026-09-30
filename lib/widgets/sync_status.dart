import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/sync.dart';
import '../core/theme.dart';
import '../core/tr.dart';
import '../core/api.dart';
import '../core/mock_api.dart';

/// Sin conexión / sincronizando / pendientes / sincronizado. `compact` se oculta cuando todo está al día.
class SyncStatus extends ConsumerWidget {
  final bool compact; const SyncStatus({super.key, this.compact = false});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final online = ref.watch(onlineProvider); final s = ref.watch(syncProvider); final n = s.cola.length;
    final (icon, text, col) = !online
        ? (Icons.cloud_off, n == 0 ? tr('Sin conexión') : tr('Sin conexión · {n} pendientes', {'n': n}), C.warning)
        : s.sincronizando
            ? (Icons.sync, tr('Sincronizando…'), C.info)
            : n > 0
                ? (Icons.cloud_upload_outlined, tr('{n} pendientes de enviar', {'n': n}), C.warning)
                : (Icons.cloud_done_outlined, tr('Sincronizado'), C.success);
    if (compact && online && n == 0 && !s.sincronizando) return const SizedBox.shrink();
    return Semantics(liveRegion: true, label: text, child: InkWell(onTap: () => c.push('/pendientes'),
      child: Container(width: double.infinity, constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: col.withValues(alpha: .14),
        child: Row(children: [Icon(icon, color: col), const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(c).textTheme.labelLarge))]))));
  }
}

/// GET /salud (público): "conectado" en el inicio de sesión (lista de verificación de la guía de integración).
final saludProvider = FutureProvider.autoDispose<bool>((ref) async {
  final r = await ref.read(apiProvider).salud();
  return r is Map && r['estado'] == 'ok';
});

class EstadoServidor extends ConsumerWidget { const EstadoServidor({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final (ic, col, txt) = useMock ? (Icons.science_outlined, C.info, tr('Modo demo (sin servidor)'))
        : ref.watch(saludProvider).when(
            data: (ok) => ok ? (Icons.cloud_done_outlined, C.success, tr('Conectado al servidor')) : (Icons.cloud_off, C.error, tr('El servidor no responde bien')),
            loading: () => (Icons.cloud_sync_outlined, C.text2, tr('Conectando…')),
            error: (_, __) => (Icons.cloud_off, C.error, tr('Sin conexión con el servidor')));
    return Semantics(liveRegion: true, child: InkWell(borderRadius: BorderRadius.circular(8),
      onTap: useMock ? null : () => ref.invalidate(saludProvider),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
        Icon(ic, color: col, size: 20), const SizedBox(width: 8),
        Flexible(child: Text(txt, style: Theme.of(c).textTheme.bodySmall?.copyWith(color: col, fontWeight: FontWeight.w600))),
        if (!useMock && col == C.error) ...[const SizedBox(width: 8), Text(tr('Reintentar'), style: Theme.of(c).textTheme.bodySmall?.copyWith(decoration: TextDecoration.underline))]]))));
  }
}
