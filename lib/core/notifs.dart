import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api.dart';
import 'state.dart';
import 'tr.dart';

/// Leídas/no leídas (local). Las notificaciones se derivan de /alertas y /pacientes/:id/horarios.
final leidasProvider = StateProvider<Set<String>>((_) => {});

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
