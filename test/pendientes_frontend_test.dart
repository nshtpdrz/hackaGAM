import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:dio/dio.dart';
import 'dart:ui' show Tristate;
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medmap/core/alarma_tomas.dart';
import 'package:medmap/core/api.dart';
import 'package:medmap/core/permisos.dart';
import 'package:medmap/core/state.dart';
import 'package:medmap/screens/equipo/plan_control_screen.dart';
import 'package:medmap/screens/paciente/registrar_screen.dart';
import 'package:medmap/screens/paciente/resultado_screen.dart';
import 'package:medmap/widgets/components.dart';
import 'package:medmap/screens/shared.dart';
import 'package:medmap/widgets/pedir_ayuda.dart';

class _Ses extends SessionNotifier { _Ses(super.ref) { state = const Session('t', 'u', Role.paciente, '1', rolApi: 'paciente'); } }

/// horarios: responde [datos] o, si es null, "sin red".
class _Api extends Api {
  List? datos; _Api(this.datos);
  @override
  Future<List<Map<String, dynamic>>> horarios(String id) async {
    if (datos == null) throw DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError);
    return datos!.cast<Map<String, dynamic>>();
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('A8: valores poco probables piden confirmación', () {
    expect(valorPocoProbable('presion', [1200, 80]), contains('1200'));
    expect(valorPocoProbable('presion', [120, 8]), contains('abajo'));
    expect(valorPocoProbable('presion', [120, 80]), isNull);
    expect(valorPocoProbable('glucosa', 5), contains('5'));
    expect(valorPocoProbable('glucosa', 110), isNull);
  });

  test('D4: lo respondido hoy sobrevive a cerrar la app (por cuenta)', () async {
    var c = ProviderContainer(overrides: [sessionProvider.overrideWith(_Ses.new)]);
    c.read(tomasLocalesProvider.notifier).pospuesta('7', const Duration(minutes: 10));
    await Future<void>.delayed(Duration.zero);
    c.dispose();
    c = ProviderContainer(overrides: [sessionProvider.overrideWith(_Ses.new)]);
    c.read(tomasLocalesProvider);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.read(tomasLocalesProvider)['7']?.estado, 'pospuesta');
    c.dispose();
  });

  test('D5: sin red se muestra la última copia guardada y se avisa', () async {
    final api = _Api([{'id': 1, 'hora': '08:00', 'medicamento': 'Losartán'}]);
    var c = ProviderContainer(overrides: [sessionProvider.overrideWith(_Ses.new), apiProvider.overrideWithValue(api)]);
    expect(await c.read(futureFor('horarios').future), hasLength(1));
    await Future<void>.delayed(Duration.zero);
    c.dispose();
    api.datos = null;
    c = ProviderContainer(overrides: [sessionProvider.overrideWith(_Ses.new), apiProvider.overrideWithValue(api)]);
    final d = await c.read(futureFor('horarios').future) as List;
    expect(d.single['medicamento'], 'Losartán');
    expect(c.read(copiasLocalesProvider).containsKey('horarios.1'), isTrue);
    c.dispose();
  });

  testWidgets('A3: BigButton se activa con lector de pantalla y dice si está desactivado', (t) async {
    final h = t.ensureSemantics(); var n = 0;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      BigButton('Guardar', onTap: () => n++), const BigButton('Enviar')]))));
    final activo = t.getSemantics(find.byType(BigButton).first);
    expect(activo.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    activo.owner!.performAction(activo.id, SemanticsAction.tap);
    expect(n, 1);
    final inactivo = t.getSemantics(find.byType(BigButton).last).getSemanticsData();
    expect(inactivo.flagsCollection.isEnabled, Tristate.isFalse); // tiene estado y está desactivado
    h.dispose();
  });
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
