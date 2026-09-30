import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../widgets/cards.dart';
import '../../widgets/components.dart';
import '../shared.dart';
import '../../core/tr.dart';
import '../../core/escala_texto.dart';

/// Tablero: GET /pacientes?q=&semaforo= (la API ordena con los rojos primero).
final _tableroProvider = FutureProvider.family<dynamic, (String, String)>((ref, f) =>
    ref.read(apiProvider).pacientes(q: f.$1.isEmpty ? null : f.$1, semaforo: f.$2.isEmpty ? null : f.$2));

// 13. Mis pacientes (tablero del equipo)
class PacientesScreen extends ConsumerStatefulWidget { const PacientesScreen({super.key});
  @override ConsumerState<PacientesScreen> createState() => _PacientesState(); }
class _PacientesState extends ConsumerState<PacientesScreen> {
  String q = '', semaforo = '';
  final _buscar = TextEditingController();
  @override
  void dispose() { _buscar.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext c) {
    final f = (q, semaforo);
    return page(c, tr('Mis pacientes'), Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: TextField(controller: _buscar, textInputAction: TextInputAction.search,
        decoration: InputDecoration(labelText: tr('Buscar paciente'), prefixIcon: const Icon(Icons.search)),
        onSubmitted: (v) => setState(() => q = v.trim()))),
      Padding(padding: const EdgeInsets.all(16), child: ChoiceWrap(
        options: const {'': 'Todos', 'rojo': 'Rojo', 'ambar': 'Ámbar', 'verde': 'Verde'},
        isSel: (k) => semaforo == k, onTap: (k) => setState(() => semaforo = k))),
      Expanded(child: AsyncView(ref.watch(_tableroProvider(f)),
        (d) => RefreshIndicator(onRefresh: () => ref.refresh(_tableroProvider(f).future), child: ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, 40 + 72 * escalaDe(c)), children: [
          for (final p in (d as List)) Padding(padding: const EdgeInsets.only(bottom: 8),
            child: PatientCard(p: p as Map, onTap: () => c.push('/paciente/${p['id']}')))])),
        onRetry: () => ref.invalidate(_tableroProvider(f)), emptyTitle: tr('Aún no hay pacientes'),
        emptyMessage: tr('Da de alta al primero con el botón de abajo.')))]),
      fab: FloatingActionButton.extended(onPressed: () async { await c.push('/alta'); ref.invalidate(_tableroProvider); },
        icon: const Icon(Icons.person_add_alt), label: Text(tr('Alta de paciente'))));
  }
}
