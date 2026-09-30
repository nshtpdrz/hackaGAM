import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medmap/screens/auth/register_screen.dart';
import 'package:medmap/widgets/avatar_perfil.dart';
import 'package:medmap/widgets/lector_qr.dart';

Future<void> _abrirRegistro(WidgetTester t) async {
  t.view.physicalSize = const Size(600, 3000); t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(const ProviderScope(child: MaterialApp(home: RegisterScreen())));
  await t.pumpAndSettle();
}

/// Abre el lector desde el registro y escribe el código a mano (en pruebas no hay cámara).
Future<void> _escanearCodigo(WidgetTester t, String codigo) async {
  await t.tap(find.text(find.text('Escanear otro QR').evaluate().isEmpty ? 'Escanear QR del paciente' : 'Escanear otro QR'));
  await t.pumpAndSettle();
  await t.tap(find.text('Escribir código')); await t.pumpAndSettle();
  await t.enterText(find.byType(TextField).last, codigo);
  await t.tap(find.text('Continuar'));
  await t.pump(); await t.pump(const Duration(milliseconds: 400)); // mock de la API (250 ms)
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Registro de cuidador: ya no hay campo de token; se vincula por QR solo con cuidador asignado', (t) async {
    await _abrirRegistro(t);
    await t.tap(find.text('Cuidador')); await t.pumpAndSettle();
    expect(find.textContaining('Token'), findsNothing);
    expect(find.text('Escanear QR del paciente'), findsOneWidget);

    await _escanearCodigo(t, 'paciente-sin-cuidador');
    expect(find.textContaining('aún no tiene un cuidador asignado'), findsOneWidget);

    await _escanearCodigo(t, 'mock-qr-token-maria-lopez');
    expect(find.textContaining('Cuidador asignado: Luis López'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Luis López'), findsOneWidget); // nombre propuesto
  });

  testWidgets('Registro de médico: pide cédula profesional (7 u 8 dígitos)', (t) async {
    await _abrirRegistro(t);
    await t.tap(find.text('Médico')); await t.pumpAndSettle();
    expect(find.text('Cédula profesional'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Nombre completo'), 'Ana Torres');
    await t.enterText(find.widgetWithText(TextField, 'Correo electrónico'), 'ana@demo.com');
    await t.enterText(find.byWidgetPredicate((w) => w is TextField && w.obscureText), 'secreto123');
    await t.enterText(find.widgetWithText(TextField, 'Cédula profesional'), '12');
    await t.tap(find.text('Completar Registro')); await t.pumpAndSettle();
    expect(find.text('La cédula profesional debe tener 7 u 8 dígitos.'), findsOneWidget);
  });

  testWidgets('Lector QR: un código que falla muestra el error y permite reintentar', (t) async {
    var llamadas = 0;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: LectorQr(onCodigo: (c) async { llamadas++; throw Exception('no'); }))));
    await t.pumpAndSettle();
    await t.tap(find.text('Escribir código')); await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'abc'); await t.tap(find.text('Continuar')); await t.pumpAndSettle();
    expect(llamadas, 1);
    expect(find.text('Código no válido o paciente no encontrado.'), findsOneWidget);
    expect(t.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNotNull);
  });

  testWidgets('Insignia del médico', (t) async {
    await t.pumpWidget(const MaterialApp(home: Column(children: [InsigniaMedico(verificado: true), InsigniaMedico(verificado: false)])));
    expect(find.text('Médico verificado'), findsOneWidget);
    expect(find.text('Cédula en revisión'), findsOneWidget);
  });
}
