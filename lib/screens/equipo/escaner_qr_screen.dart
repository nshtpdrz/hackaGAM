import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../widgets/lector_qr.dart';
import '../shared.dart';
import '../../core/tr.dart';

// 12. Escanear QR (equipo de salud): abre los datos e historial del paciente.
class EscanerScreen extends ConsumerWidget { const EscanerScreen({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) => page(c, tr('Escanear QR'), LectorQr(onCodigo: (code) async {
    final r = await ref.read(apiProvider).qrCodigo(code);
    // Se espera a que el médico regrese para no abrir el mismo paciente varias veces.
    if (c.mounted) await c.push('/paciente/${r['paciente_id']}');
  }));
}
