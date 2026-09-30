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
      Padding(padding: EdgeInsets.all(24), child: Text(tr('Muestra este código en la clínica para identificarte en consulta'),
        textAlign: TextAlign.center))]))));
}

