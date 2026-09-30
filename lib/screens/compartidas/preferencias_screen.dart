import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/state.dart';
import '../../widgets/accessibility_settings.dart';
import '../../widgets/avisos_settings.dart';
import '../shared.dart';
import '../../core/tr.dart';

// 9. Preferencias y accesibilidad
class PreferenciasScreen extends ConsumerWidget { const PreferenciasScreen({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) => page(c, tr('Preferencias'), ListView(padding: const EdgeInsets.all(16), children: [
    AccessibilitySettings(onChanged: (x) {
      ref.read(prefsProvider.notifier).state = x; // se aplica al instante; el guardado remoto no bloquea
      ref.read(apiProvider).guardarPreferencias(pid(ref), x.toJson()).catchError((_) {});
    }),
    const AvisosSettings()]), bell: false);
}
