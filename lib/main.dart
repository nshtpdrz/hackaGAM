import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/alarma_tomas.dart';
import 'core/push.dart';
import 'core/reminders.dart';
import 'core/router.dart';
import 'core/state.dart';
import 'core/sync.dart';
import 'core/theme.dart';
import 'core/tr.dart';
import 'core/escala_texto.dart';
import 'widgets/bloqueo_al_volver.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Letra, contraste e idioma guardados: se aplican desde la primera pantalla (y el idioma a las alarmas).
  final prefs = await leerPrefsGuardadas();
  fijarIdioma(prefs.lang);
  await initReminders();
  await iniciarPush(); // sin configuración de Firebase no hace nada (docs/NOTIFICACIONES.md)
  runApp(ProviderScope(overrides: [prefsProvider.overrideWith((_) => prefs)], child: const MedmapApp()));
}

class MedmapApp extends ConsumerWidget {
  const MedmapApp({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final p = ref.watch(prefsProvider); final s = ref.watch(sessionProvider);
    fijarIdioma(p.lang); // textos de pantalla (tr) en el idioma elegido
    ref.watch(catalogLoadProvider);
    ref.listen<Prefs>(prefsProvider, (antes, p) {
      guardarPrefs(p);
      if (antes?.lang != p.lang) actualizarIdiomaAvisos(); // nombres de los canales de Android en el idioma nuevo
    });
    ref.listen(syncProvider, (_, __) {}); // la cola sin conexión se carga y se envía desde que abre la app
    final router = ref.watch(routerProvider);
    // Ya se puede navegar desde una alarma o un push (no estamos en splash ni login).
    bool listo() {
      final ruta = router.routerDelegate.currentConfiguration.uri.path;
      return ruta.isNotEmpty && !const {'/splash', '/login', '/registro', '/consentimiento'}.contains(ruta);
    }
    return MaterialApp.router(
      title: 'SENDA', routerConfig: router,
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
          abrir: (toma) => router.push('/recordatorio', extra: toma),
          listo: listo,
          // Push: registra el teléfono con sesión, lo olvida al cerrarla y abre la pantalla del aviso tocado.
          child: ReceptorPush(
            abrir: (ruta, {extra, pestana = false}) => pestana ? router.go(ruta) : router.push(ruta, extra: extra),
            listo: listo,
            // Con huella activa, al volver después de 5 min en segundo plano se pide otra vez.
            child: BloqueoAlVolver(child: child!)))));
  }
}
