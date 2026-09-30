import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'almacen_local.dart';
import 'api.dart';
import 'state.dart';
import 'tr.dart';

/// Leídas/no leídas (local). Las notificaciones se derivan de /alertas y /pacientes/:id/horarios.
/// Se guardan en el teléfono por cuenta (las últimas 300) para que al reabrir la app no vuelvan a "Nueva".
final leidasProvider = StateProvider<Set<String>>((ref) {
  final u = ref.watch(sessionProvider.select((s) => s?.userId));
  if (u == null) return {};
  final k = claveDeUsuario(u, 'leidas'); var cargado = false;
  almacen.leer(k).then((v) {
    cargado = true;
    try {
      if (v is List && v.isNotEmpty) ref.controller.state = {...v.map((e) => '$e'), ...ref.controller.state};
    } catch (_) {} // ya se cerró sesión
  });
  // ignore: deprecated_member_use
  ref.listenSelf((_, n) { // (Riverpod 3 lo cambia por Notifier.listenSelf)
    if (!cargado) return; // no se pisa lo guardado antes de leerlo
    final l = n.toList(); almacen.guardar(k, l.length > 300 ? l.sublist(l.length - 300) : l);
  });
  return {};
});

final notificacionesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final s = ref.watch(sessionProvider); if (s == null) return [];
  final api = ref.read(apiProvider); final out = <Map<String, dynamic>>[];
  try {
    for (final a in (await api.alertas()) as List) {
      out.add({'id': 'a${a['id']}', 'tipo': 'alerta', 'titulo': '${a['paciente']}', 'key': a['message_key'],
        'hora': a['hora'] ?? '', 'alerta': a});
    }
  } catch (_) {}
  if (s.role == Role.paciente) {
    try {
      for (final h in (await api.horarios(s.patientId ?? s.userId)) as List) {
        final om = h['estado'] == 'omitida';
        if (om || h['estado'] == 'pendiente') {
          out.add({'id': 't${h['id']}', 'tipo': om ? 'omitida' : 'recordatorio', 'titulo': '${h['medicamento']}',
            'detalle': om ? tr('Toma omitida de las {hora}', {'hora': h['hora']}) : tr('Te toca a las {hora}', {'hora': h['hora']}), 'hora': h['hora'], 'toma': h});
        }
      }
    } catch (_) {}
  }
  return out;
});

final noLeidasProvider = Provider<int>((ref) {
  final l = ref.watch(leidasProvider);
  return ref.watch(notificacionesProvider).maybeWhen(data: (d) => d.where((n) => !l.contains(n['id'])).length, orElse: () => 0);
});
