import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medmap/core/biometria.dart';
import 'package:medmap/core/escala_texto.dart';
import 'package:medmap/core/push.dart';
import 'package:medmap/core/state.dart';
import 'package:medmap/core/tr.dart';
import 'package:medmap/widgets/avisos_settings.dart';

class _Ses extends SessionNotifier { _Ses(super.ref, Role r) { state = Session('t', 'u', r, '1', rolApi: r.name); } }

Future<void> _fuentes() async {
  final mf = '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter'}/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(File('$mf/$f').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await roboto.load();
  final iconos = FontLoader('MaterialIcons')..addFont(File('$mf/MaterialIcons-Regular.otf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  await iconos.load();
}

EstadoPermisos _todo(bool? v) =>
    (avisos: (notificaciones: v, exactas: v), nativo: (pantallaCompleta: v, sinRestriccionBateria: v, fabricante: 'xiaomi'));

/// Monta la sección en un celular de 360 px con letra al 200 % y devuelve los desbordes.
Future<List<String>> _montar(WidgetTester t, Role rol, EstadoPermisos e) async {
  t.view.physicalSize = const Size(360, 1600); t.view.devicePixelRatio = 1; addTearDown(t.view.reset);
  final errores = <String>[]; final previo = FlutterError.onError;
  FlutterError.onError = (d) => errores.add(d.exceptionAsString().split('\n').first);
  addTearDown(() => FlutterError.onError = previo);
  await t.pumpWidget(ProviderScope(overrides: [sessionProvider.overrideWith((ref) => _Ses(ref, rol))],
    child: MaterialApp(theme: ThemeData(fontFamily: 'Roboto'),
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const EscalaTexto(2)), child: child!),
      home: Scaffold(body: ListView(padding: const EdgeInsets.all(16), children: [AvisosSettings(leer: () async => e)])))));
  await t.pump(); await t.pump();
  return errores;
}

void main() {
  setUpAll(_fuentes);
  tearDown(() => fijarIdioma('es'));

  group('rutaDePush', () {
    test('alerta: tablero del equipo o alertas del cuidador', () {
      expect(rutaDePush({'tipo': 'alerta'}, Role.equipo), (ruta: '/cola', pestana: true));
      expect(rutaDePush({'tipo': 'alerta'}, Role.cuidador), (ruta: '/alertas', pestana: true));
      expect(rutaDePush({'tipo': 'alerta'}, Role.paciente), (ruta: '/notificaciones', pestana: false));
    });
    test('tomas y recetas', () {
      expect(rutaDePush({'tipo': 'toma'}, Role.paciente), (ruta: '/hoy', pestana: true));
      expect(rutaDePush({'tipo': 'recordatorio'}, Role.cuidador), (ruta: '/medicamentos', pestana: true));
      expect(rutaDePush({'tipo': 'receta'}, Role.paciente), (ruta: '/medicamentos', pestana: true));
      expect(rutaDePush({'tipo': 'herida'}, Role.cuidador), (ruta: '/heridas', pestana: false));
    });
    test('tipo desconocido o ausente: centro de notificaciones', () {
      expect(rutaDePush({}, Role.paciente), (ruta: '/notificaciones', pestana: false));
      expect(rutaDePush({'tipo': 'otro'}, Role.equipo), (ruta: '/notificaciones', pestana: false));
    });
  });

  test('biometría: cancelar no muestra error; los demás casos sí', () {
    expect(mensajeBio(ResultadoBio.ok), isNull);
    expect(mensajeBio(ResultadoBio.cancelado), isNull);
    for (final r in [ResultadoBio.noDisponible, ResultadoBio.sinRegistrar, ResultadoBio.bloqueado, ResultadoBio.error]) {
      expect(mensajeBio(r), contains('contraseña'), reason: '$r');
    }
    fijarIdioma('en');
    expect(mensajeBio(ResultadoBio.bloqueado), 'Too many attempts. Wait a few minutes or log in with your password.');
  });

  testWidgets('Avisos: paciente con todo pendiente, sin desbordes al 200 %', (t) async {
    final errores = await _montar(t, Role.paciente, _todo(false));
    expect(errores, isEmpty);
    expect(find.text('Avisos y alarmas'), findsOneWidget);
    for (final s in ['Notificaciones', 'Alarmas a la hora exacta', 'Alarma en pantalla completa', 'Ahorro de batería']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.byType(OutlinedButton), findsNWidgets(4));
    expect(find.textContaining('Inicio automático'), findsOneWidget); // Xiaomi
  });

  testWidgets('Avisos: el equipo no ve los ajustes de alarmas de tomas', (t) async {
    expect(await _montar(t, Role.equipo, _todo(false)), isEmpty);
    expect(find.text('Alarmas a la hora exacta'), findsNothing);
    expect(find.text('Alarma en pantalla completa'), findsNothing);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Ahorro de batería'), findsOneWidget);
  });

  testWidgets('Avisos: todo listo, sin botones', (t) async {
    expect(await _montar(t, Role.paciente, _todo(true)), isEmpty);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text('Permitidas.'), findsOneWidget);
  });

  testWidgets('Avisos: sin información del teléfono (web) no se muestra nada', (t) async {
    expect(await _montar(t, Role.paciente, _todo(null)), isEmpty);
    expect(find.text('Avisos y alarmas'), findsNothing);
  });

  testWidgets('Avisos en inglés', (t) async {
    fijarIdioma('en');
    expect(await _montar(t, Role.paciente, _todo(false)), isEmpty);
    expect(find.text('Notifications and alarms'), findsOneWidget);
    expect(find.text('Full-screen alarm'), findsOneWidget);
  });
}
