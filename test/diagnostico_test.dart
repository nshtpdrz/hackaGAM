// Diagnóstico de conexión contra el mock (sin --dart-define): consulta solo GET, describe la forma de las
// respuestas y copia un reporte sin token ni dirección del servidor.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medmap/core/escala_texto.dart';
import 'package:medmap/core/mock_api.dart';
import 'package:medmap/core/state.dart';
import 'package:medmap/screens/compartidas/diagnostico_screen.dart';

class _Ses extends SessionNotifier { _Ses(super.ref, Session? s) { state = s; } }

void main() {
  test('formaJson: tipos y claves, sin valores; listas con ×N; profundidad limitada', () {
    expect(formaJson({'usuario': {'id': 'u1', 'nombre': 'María', 'rol': 'paciente'}, 'pacientes_a_cargo': [{'id': '1', 'nombre': 'María'}, {'id': '3'}],
      'n': 3, 'activo': true, 'nada': null, 'vacia': []}),
        '{usuario:{id:str, nombre:str, rol:str}, pacientes_a_cargo:[{id:str, nombre:str}]×2, n:num, activo:bool, nada:null, vacia:[]}');
    expect(formaJson({'a': {'b': {'c': {'d': {'e': {'f': 1}}}}}}), '{a:{b:{c:{d:{e:{…}}}}}}');
    expect(formaJson({for (var i = 0; i < 12; i++) 'k$i': {'texto': 'x'}}), '{‹clave›:{texto:str}}×12');
    expect(formaJson('María'), 'str');
  });

  testWidgets('paciente (demo): prueba los GET, marca ✓ y copia un reporte sin token', (t) async {
    expect(useMock, isTrue); // sin API_URL: nunca sale a la red
    FlutterSecureStorage.setMockInitialValues({'jwt': 't'});
    t.view.physicalSize = const Size(360, 740); t.view.devicePixelRatio = 1; addTearDown(t.view.reset);
    String? copiado;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copiado = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    const ses = Session('t', 'u-paciente', Role.paciente, '1', rolApi: 'paciente',
        pacientesACargo: [{'id': '1', 'nombre': 'María Demo López'}]);
    // Letra al 200 %: las filas deben ajustarse sin desbordes (un desborde hace fallar la prueba).
    await t.pumpWidget(ProviderScope(overrides: [sessionProvider.overrideWith((ref) => _Ses(ref, ses))],
      child: MaterialApp(home: const DiagnosticoScreen(),
        builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const EscalaTexto(2)), child: child!))));
    await t.pump();
    final lista = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.text('Probar conexión'), 150, scrollable: lista);
    await t.tap(find.text('Probar conexión'));

    // "Copiar reporte" se habilita al terminar (el mock tarda 250 ms por consulta).
    bool listo() {
      final b = find.ancestor(of: find.text('Copiar reporte'), matching: find.byType(OutlinedButton));
      return b.evaluate().isNotEmpty && t.widget<OutlinedButton>(b).onPressed != null;
    }
    for (var i = 0; i < 100 && !listo(); i++) {
      await t.pump(const Duration(milliseconds: 100));
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 5)));
    }
    expect(listo(), isTrue);
    await t.scrollUntilVisible(find.textContaining('correctas'), 150, scrollable: lista);
    expect(find.text('10 correctas · 0 con error · 2 omitidas'), findsOneWidget);

    // Recorre todas las filas (se construyen al hacerse visibles) para comprobar que ninguna se desborda.
    var marcas = 0;
    for (var i = 0; i < 60; i++) {
      marcas += find.text('✓').evaluate().length;
      if (find.text('GET /mensajes?lengua=spa').evaluate().isNotEmpty) break;
      await t.drag(lista, const Offset(0, -300)); await t.pump();
    }
    expect(marcas, greaterThan(3)); // hay varias filas con ✓
    expect(find.text('✗', skipOffstage: false), findsNothing);

    await t.scrollUntilVisible(find.text('Copiar reporte'), -300, scrollable: lista);
    await t.tap(find.text('Copiar reporte'));
    await t.pump(); await t.pump(const Duration(milliseconds: 300));
    expect(copiado, isNotNull);
    final r = copiado!;
    expect(RegExp(r'^\d+\. ✓ ', multiLine: true).allMatches(r).length, 10);
    expect(RegExp(r'^\d+\. — ', multiLine: true).allMatches(r).length, 2);
    expect(r, contains('Modo: demo'));
    expect(r, contains('Rol: paciente · rol_api: paciente'));
    expect(r, contains('✓ GET /pacientes/:id/horarios · HTTP 200'));
    expect(r, contains('horarios:[{id:str, hora_local:str, medicamento:{'));
    expect(r, contains('normalizarHorarios → tomas de hoy=4'));
    expect(r, contains('normalizarYo → rol=paciente, rol_api=paciente'));
    expect(r, contains('omitida: no aplica al paciente'));
    for (final prohibido in ['Bearer', 'Authorization', 'jwt', 'http://', 'https://', 'María', 'PQR-DEMO']) {
      expect(r, isNot(contains(prohibido)), reason: prohibido);
    }
    await t.pumpWidget(const SizedBox()); // desmonta (cancela temporizadores del aviso)
    await t.pump(const Duration(seconds: 1));
  });
}
