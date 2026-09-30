// Pruebas en el teléfono o emulador (modo demo, sin servidor):
//   flutter test integration_test -d <id-del-celular>
// Recorren la app completa (arranque, inicio de sesión, registro) con los plugins reales.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medmap/core/api.dart';
import 'package:medmap/core/reminders.dart';
import 'package:medmap/main.dart';

Future<void> _abrirApp(WidgetTester t) async {
  await saveToken(null); // cada prueba empieza sin sesión
  await initReminders();
  await t.pumpWidget(const ProviderScope(child: MedmapApp()));
  // Splash (~1 s) y luego el inicio de sesión.
  for (var i = 0; i < 20 && find.text('Iniciar sesión').evaluate().isEmpty; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
  await t.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Inicio de sesión: correo inválido no llega al servidor; la cuenta demo entra a Hoy', (t) async {
    await _abrirApp(t);
    expect(find.text('Iniciar sesión'), findsWidgets);

    await t.enterText(find.byType(TextField).first, 'no-es-correo');
    await t.tap(find.text('Iniciar sesión').last);
    await t.pumpAndSettle();
    expect(find.textContaining('correo'), findsWidgets); // aviso de correo inválido

    await t.scrollUntilVisible(find.text('Entrar como Paciente'), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Entrar como Paciente'));
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Próximas tomas'), findsOneWidget);
  });

  testWidgets('Crear cuenta: valida antes de enviar y regresa con Atrás', (t) async {
    await _abrirApp(t);
    await t.scrollUntilVisible(find.text('Crear cuenta'), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Crear cuenta'));
    await t.pumpAndSettle();
    expect(find.text('Registro en SENDA'), findsOneWidget);

    await t.scrollUntilVisible(find.text('Completar Registro'), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Completar Registro'));
    await t.pumpAndSettle();
    expect(find.text('Escribe tu nombre.'), findsOneWidget); // no se envía nada con el formulario vacío

    await t.binding.handlePopRoute(); // botón Atrás del sistema
    await t.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsWidgets);
  });
}
