import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../widgets/components.dart';
import '../shared.dart';
import '../../core/tr.dart';

// 8. QR
class QrScreen extends ConsumerWidget { const QrScreen({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) => page(c, tr('Mi código QR'), AsyncView(ref.watch(futureFor('qr')),
    (d) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Semantics(label: tr('Código QR de identificación'), child: QrImageView(data: d['token'], size: 260, backgroundColor: Colors.white)),
      // Respaldo si el lector no lee el QR: el equipo lo escribe en "Escribir código". Solo si es corto
      // (un token largo no se puede dictar; backend: codigo_corto, ver docs/PENDIENTES_FRONTEND.md PA3).
      if ('${d['token']}'.isNotEmpty && '${d['token']}'.length <= 24) Padding(padding: const EdgeInsets.only(top: 16),
        child: Column(children: [
          Text(tr('Código'), style: Theme.of(c).textTheme.bodySmall),
          SelectableText('${d['token']}', textAlign: TextAlign.center,
            style: Theme.of(c).textTheme.headlineSmall?.copyWith(letterSpacing: 2, fontWeight: FontWeight.w700))])),
      Padding(padding: EdgeInsets.all(24), child: Text(tr('Muestra este código en la clínica para identificarte en consulta'),
        textAlign: TextAlign.center))]))));
}

