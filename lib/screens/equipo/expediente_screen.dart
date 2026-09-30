import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/components.dart';
import '../shared.dart';
import '../../core/tr.dart';

// 14. Expediente (pestañas pendientes) y 15. Plan de control (solo médico; la API valida)
class ExpedienteScreen extends ConsumerWidget { final String id; const ExpedienteScreen({super.key, required this.id});
  @override
  Widget build(BuildContext c, WidgetRef ref) => page(c, tr('Expediente'), Padding(padding: const EdgeInsets.all(24),
    child: Column(children: [Text(tr('Paciente {id}', {'id': id})), const SizedBox(height: 16),
      BigButton(tr('Plan de control'), onTap: () => c.push('/plan/$id'))])));
}
