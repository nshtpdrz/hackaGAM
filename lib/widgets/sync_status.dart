import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/sync.dart';
import '../core/theme.dart';
import '../core/tr.dart';

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
