// Responsividad: recorre todas las pantallas de los tres roles en un celular de 360 px con letra grande
// (por omisión 200 %, el máximo de Preferencias) y falla si algo se desborda.
// Otras escalas o capturas para revisar a ojo:
//   flutter test test/responsivo_test.dart --dart-define=ESCALA=150 --dart-define=ALTO=1800
//   flutter test test/responsivo_test.dart --dart-define=CAPTURAS=true --update-goldens   (quedan en test/resp/)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medmap/core/escala_texto.dart';
import 'package:medmap/core/router.dart';
import 'package:medmap/core/state.dart';
import 'package:medmap/core/theme.dart';

Future<void> _f(String fam, List<String> r) async { final l = FontLoader(fam);
  for (final x in r) { l.addFont(File(x).readAsBytes().then((b) => ByteData.view(b.buffer))); } await l.load(); }

// Réplica de buildTheme sin google_fonts (en pruebas no puede descargar Inter).
ThemeData tema(bool patient) {
  TextStyle s(double sz, double h, FontWeight w) => TextStyle(fontFamily: 'Roboto', fontSize: sz, height: h / sz, fontWeight: w, color: C.text);
  return ThemeData(useMaterial3: true, fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(seedColor: C.primary, primary: C.primary, error: C.error, surface: C.surface), scaffoldBackgroundColor: C.bg,
    textTheme: TextTheme(headlineLarge: s(32, 40, FontWeight.w700), headlineMedium: s(26, 34, FontWeight.w700), headlineSmall: s(20, 28, FontWeight.w600),
      bodyLarge: s(18, 27, FontWeight.w400), bodyMedium: s(16, 24, FontWeight.w400), labelLarge: s(16, 24, FontWeight.w600), bodySmall: s(14, 20, FontWeight.w500)),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: Size(48, minTap(patient)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: Size(48, minTap(patient)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: C.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
    cardTheme: CardThemeData(color: C.surface, elevation: 0, margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.border))));
}

class _Ses extends SessionNotifier { _Ses(super.ref, Session? s) { state = s; } }

final perfilPaciente = {'nombre': 'María Demo López', 'correo': 'maria@demo.invalid', 'telefono': '771 000 0001', 'fecha_nacimiento': '1996-03-12',
  'sexo': 'F', 'tipo_sangre': 'O+', 'alergias': ['Penicilina'], 'programas': ['embarazo']};
final toma = {'id': 'h1', 'horario_id': 'h1', 'hora': '08:00', 'medicamento': 'Losartán 50 mg', 'dosis': '1 tableta', 'estado': 'pendiente', 'via': 'oral'};
final alerta = {'id': 'a2', 'nivel': 'ambar', 'paciente': 'María Demo López', 'message_key': 'alerta.omision', 'hora': '30/09 08:10',
  'registro': {'variable': 'presion', 'valor': '150/95', 'fecha': '30/09 08:00'}};
final resultado = {'semaforo': 'ambar', 'estado': 'incompleta', 'message_key': 'resultado.faltan_datos', 'faltantes': ['cefalea', 'rango:presion'], 'alertas': [1]};

final casos = <(Role?, String, Object?)>[
  (null, '/login', null), (null, '/registro', null), (null, '/consentimiento', null),
  (Role.paciente, '/hoy', null), (Role.paciente, '/registrar', null), (Role.paciente, '/medicamentos', null),
  (Role.paciente, '/historial', null), (Role.paciente, '/perfil', null), (Role.paciente, '/perfil/editar', perfilPaciente),
  (Role.paciente, '/preferencias', null), (Role.paciente, '/notificaciones', null), (Role.paciente, '/recordatorio', toma),
  (Role.paciente, '/resultado', resultado), (Role.paciente, '/qr', null), (Role.paciente, '/receta', null), (Role.paciente, '/pendientes', null),
  (Role.cuidador, '/alertas', null), (Role.cuidador, '/alerta/a2', alerta), (Role.cuidador, '/medicamentos', null), (Role.cuidador, '/perfil', null),
  (Role.equipo, '/cola', null), (Role.equipo, '/pacientes', null), (Role.equipo, '/paciente/1', null), (Role.equipo, '/alta', null),
  (Role.equipo, '/expediente/1', null), (Role.equipo, '/plan/1', null), (Role.equipo, '/perfil', null),
];

Session? sesion(Role? r) => r == null ? null : Session('t', 'u', r, '1', rolApi: r == Role.equipo ? 'medico' : r.name,
    pacientesACargo: const [{'id': '1', 'nombre': 'María Demo López'}, {'id': '3', 'nombre': 'Carmen Demo Sánchez'}]);

void main() {
  setUpAll(() async { const mf = 'C:/flutter/bin/cache/artifacts/material_fonts';
    await _f('Roboto', ['$mf/roboto-regular.ttf', '$mf/roboto-medium.ttf', '$mf/roboto-bold.ttf']);
    await _f('MaterialIcons', ['$mf/materialicons-regular.otf']); });

  const escalaPct = int.fromEnvironment('ESCALA', defaultValue: 200);
  final escala = escalaPct / 100;
  const altoPx = int.fromEnvironment('ALTO', defaultValue: 740);
  final alto = altoPx.toDouble();
  const capturas = bool.fromEnvironment('CAPTURAS');
  for (final (rol, ruta, extra) in casos) {
    testWidgets('${rol?.name ?? 'sin sesión'} $ruta @${escala}x', (t) async {
      FlutterSecureStorage.setMockInitialValues({'jwt': 't'});
      t.view.physicalSize = Size(360, alto); t.view.devicePixelRatio = 1; addTearDown(t.view.reset);
      final errores = <String>[];
      final previo = FlutterError.onError;
      FlutterError.onError = (d) {
        final txt = d.toString();
        if (txt.contains('overflow') || txt.contains('OVERFLOW')) {
          final m = RegExp(r'lib[\\/][\w\\/]+\.dart:\d+').firstMatch(txt);
          errores.add('${d.exceptionAsString().split('\n').first}  <-  ${m?.group(0) ?? '?'}');
        } else { errores.add('OTRO: ${d.exceptionAsString().split('\n').first}'); }
      };
      final cont = ProviderContainer(overrides: [sessionProvider.overrideWith((ref) => _Ses(ref, sesion(rol)))]);
      addTearDown(cont.dispose);
      final router = cont.read(routerProvider);
      await t.pumpWidget(UncontrolledProviderScope(container: cont, child: MaterialApp.router(debugShowCheckedModeBanner: false,
        routerConfig: router, theme: tema(rol == Role.paciente),
        builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: EscalaTexto(escala)), child: child!))));
      router.go(ruta, extra: extra);
      for (var i = 0; i < 8; i++) { await t.pump(const Duration(milliseconds: 250)); }
      if (ruta == '/registro') { // también los campos del cuidador y del médico
        for (final r in ['Cuidador', 'Médico']) { final f = find.text(r); if (f.evaluate().isNotEmpty) { await t.tap(f.first); await t.pump(const Duration(milliseconds: 300)); } }
      }
      if (capturas) {
        final nombre = '${rol?.name ?? 'anon'}${ruta.replaceAll('/', '_')}_${(escala * 100).round()}_${alto.round()}';
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('resp/$nombre.png'));
      }
      FlutterError.onError = previo;
      // ignore: avoid_print
      for (final e in errores.toSet()) { print('DESBORDE ${rol?.name ?? 'anon'} $ruta: $e'); }
      expect(errores.where((e) => !e.startsWith('OTRO')).toSet(), isEmpty, reason: 'Hay desbordes con letra al ${escalaPct} %');
      await t.pumpWidget(const SizedBox()); // desmonta (cancela temporizadores)
      await t.pump(const Duration(seconds: 1));
    });
  }
}
