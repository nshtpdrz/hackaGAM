import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/alarma_tomas.dart';
import 'core/reminders.dart';
import 'core/router.dart';
import 'core/state.dart';
import 'core/theme.dart';
import 'core/tr.dart';
import 'core/escala_texto.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initReminders();
  runApp(const ProviderScope(child: MedmapApp()));
}

class MedmapApp extends ConsumerWidget {
  const MedmapApp({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final p = ref.watch(prefsProvider); final s = ref.watch(sessionProvider);
    fijarIdioma(p.lang); // textos de pantalla (tr) en el idioma elegido
    ref.watch(catalogLoadProvider);
    return MaterialApp.router(
      title: 'SENDA', routerConfig: ref.watch(routerProvider),
      theme: buildTheme(highContrast: p.highContrast, patient: s?.role == Role.paciente || p.bigButtons),
      locale: Locale(p.lang == 'ote' ? 'es' : p.lang), // ote usa catálogo propio
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(textScaler: EscalaTexto(p.textScale)), // no lineal: títulos crecen menos
        // Alarma de tomas: abre /recordatorio cuando toca una toma o se toca una notificación.
        child: VigilanteTomas(
          abrir: (toma) => ref.read(routerProvider).push('/recordatorio', extra: toma),
          listo: () {
            final ruta = ref.read(routerProvider).routerDelegate.currentConfiguration.uri.path;
            return ruta.isNotEmpty && !const {'/splash', '/login', '/registro', '/consentimiento'}.contains(ruta);
          },
          child: child!)));
  }
}
