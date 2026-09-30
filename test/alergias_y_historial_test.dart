import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medmap/screens/compartidas/historial_screen.dart';
import 'package:medmap/screens/compartidas/perfil_form.dart';
import 'package:medmap/screens/shared.dart';

void main() {
  group('Alergias a medicamentos (lista desplegable)', () {
    Future<DatosPerfil> abrir(WidgetTester t) async {
      final datos = DatosPerfil({'alergias': ['Penicilina']});
      await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
          child: DatosPerfilForm(datos: datos, paciente: true)))));
      await t.ensureVisible(find.text('Agregar alergia'));
      return datos;
    }

    testWidgets('carga las guardadas, agrega del catálogo y quita', (t) async {
      final datos = await abrir(t);
      expect(find.widgetWithText(InputChip, 'Penicilina'), findsOneWidget);

      await t.tap(find.text('Agregar alergia'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Ibuprofeno'), 100, scrollable: find.byType(Scrollable).last);
      await t.tap(find.text('Ibuprofeno'));
      await t.pumpAndSettle();
      expect(datos.alergias, ['Penicilina', 'Ibuprofeno']);
      expect(find.widgetWithText(InputChip, 'Ibuprofeno'), findsOneWidget);

      await t.tap(find.byTooltip('Quitar Penicilina'));
      await t.pumpAndSettle();
      expect(datos.alergias, ['Ibuprofeno']);
    });

    testWidgets('"Otro medicamento…" agrega uno escrito y no duplica', (t) async {
      final datos = await abrir(t);
      Future<void> otro(String nombre) async {
        await t.tap(find.text('Agregar alergia'));
        await t.pumpAndSettle();
        await t.scrollUntilVisible(find.text('Otro medicamento…'), 200, scrollable: find.byType(Scrollable).last);
        await t.tap(find.text('Otro medicamento…'));
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField).last, nombre);
        await t.tap(find.text('Agregar'));
        await t.pumpAndSettle();
      }
      await otro('Clindamicina');
      expect(datos.alergias, ['Penicilina', 'Clindamicina']);
      await otro('penicilina'); // ya está (sin importar mayúsculas)
      await otro('ibuprofeno'); // se guarda con el nombre del catálogo
      expect(datos.alergias, ['Penicilina', 'Clindamicina', 'Ibuprofeno']);
    });
  });

  group('Historial con letra grande (sin desbordes)', () {
    final hoy = DateTime.now();
    final datos = [
      for (var d = 0; d < 180; d++) ...[
        {'fecha': hoy.subtract(Duration(days: d, hours: 2)).toIso8601String(),
          'valores': {'sistole': 120 + d % 25, 'diastole': 78 + d % 12, 'glucosa': 100 + d % 60}, 'semaforo': 'verde'},
        if (d.isEven) {'fecha': hoy.subtract(Duration(days: d, hours: 12)).toIso8601String(),
          'valores': {'glucosa': 150 + d % 40}, 'semaforo': 'ambar'}]];

    for (final escala in [1.0, 1.5, 2.0]) {
      testWidgets('escala ${(escala * 100).round()}%: presión/glucosa × día/semana/mes', (t) async {
        t.view.physicalSize = const Size(412, 915); t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(ProviderScope(
          overrides: [historialProvider('1').overrideWith((_) async => datos)],
          child: MaterialApp(builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(escala)), child: child!),
            home: const Scaffold(body: HistorialContenido(pacienteId: '1')))));
        await t.pumpAndSettle();
        for (final v in ['Presión', 'Glucosa']) {
          await t.tap(find.text(v)); await t.pumpAndSettle();
          for (final p in ['Día', 'Semana', 'Mes']) {
            await t.tap(find.text(p)); await t.pumpAndSettle();
            // Recorre toda la pantalla para que se dibujen gráficas y lista.
            await t.fling(find.byType(ListView), const Offset(0, -3000), 3000); await t.pumpAndSettle();
            await t.fling(find.byType(ListView), const Offset(0, 3000), 3000); await t.pumpAndSettle();
          }
        }
        expect(t.takeException(), isNull);
      });
    }
  });
}
