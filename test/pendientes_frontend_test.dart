import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medmap/core/permisos.dart';
import 'package:medmap/core/state.dart';
import 'package:medmap/screens/equipo/plan_control_screen.dart';
import 'package:medmap/screens/paciente/resultado_screen.dart';
import 'package:medmap/screens/shared.dart';
import 'package:medmap/widgets/pedir_ayuda.dart';

class _Ses extends SessionNotifier { _Ses(super.ref) { state = const Session('t', 'u', Role.paciente, '1', rolApi: 'paciente'); } }

void main() {
  test('telefonoMarcable: acepta teléfonos y descarta correos', () {
    expect(telefonoMarcable('771 000 0011'), '7710000011');
    expect(telefonoMarcable('+52 (771) 000-0011'), '+527710000011');
    expect(telefonoMarcable('rosa@demo.invalid'), isNull);
    expect(telefonoMarcable(null), isNull);
  });

  test('esPermisoNegado: solo los códigos de permiso de image_picker', () {
    expect(esPermisoNegado(PlatformException(code: 'camera_access_denied')), isTrue);
    expect(esPermisoNegado(PlatformException(code: 'photo_access_denied')), isTrue);
    expect(esPermisoNegado(PlatformException(code: 'otro')), isFalse);
  });

  test('RangoPlan: valida mínimos, máximos y límites; arma el cuerpo del PUT', () {
    final p = RangoPlan.deApi('presion', {'minimo': 90, 'maximo': 140, 'min2': 60, 'max2': 90, 'frecuencia': 'dos_al_dia'});
    expect(p.activo, isTrue);
    expect(p.validar(), isNull);
    expect(p.toJson(), {'variable': 'presion', 'activo': true, 'frecuencia': 'dos_al_dia', 'min': 90, 'max': 140, 'min2': 60, 'max2': 90});
    p.max2.text = '50';
    expect(p.validar(), contains('mínimo'));
    final g = RangoPlan('glucosa', activo: true)..min.text = '70'..max.text = '9000';
    expect(g.validar(), contains('entre'));
    expect(RangoPlan('peso').validar(), isNull); // apagada: no se valida
  });

  testWidgets('Resultado rojo: "Pedir ayuda" ofrece llamar al cuidador y al 911', (t) async {
    await t.pumpWidget(ProviderScope(overrides: [
      sessionProvider.overrideWith(_Ses.new),
      futureFor('perfil').overrideWith((_) async => {'cuidador': {'nombre': 'Rosa Demo', 'contacto': '771 000 0011'}}),
    ], child: const MaterialApp(home: ResultadoScreen(data: {'semaforo': 'rojo', 'message_key': 'x'}))));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.phone).first);
    await t.pumpAndSettle();
    expect(find.text('Llamar al 911'), findsOneWidget);
    expect(find.text('Llamar a Rosa'), findsOneWidget);
  });

  testWidgets('Resultado ámbar sin teléfono del cuidador: explica a quién pedirlo y no ofrece 911', (t) async {
    await t.pumpWidget(ProviderScope(overrides: [
      sessionProvider.overrideWith(_Ses.new),
      futureFor('perfil').overrideWith((_) async => {'cuidador': null}),
    ], child: const MaterialApp(home: ResultadoScreen(data: {'semaforo': 'ambar', 'message_key': 'x'}))));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.phone).first);
    await t.pumpAndSettle();
    expect(find.textContaining('No tenemos el teléfono'), findsOneWidget);
    expect(find.text('Llamar al 911'), findsNothing);
  });
}
