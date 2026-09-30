import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medmap/core/alarma_tomas.dart';
import 'package:medmap/core/state.dart';
import 'package:medmap/screens/auth/register_screen.dart';
import 'package:medmap/screens/compartidas/perfil_form.dart';
import 'package:medmap/screens/paciente/recordatorio_screen.dart';
import 'package:medmap/widgets/avatar_perfil.dart';
import 'package:medmap/widgets/dialogs.dart';
import 'package:medmap/widgets/lector_qr.dart';

/// Teléfono de 412x915 con la letra al 200 %.
void _telefonoLetraGrande(WidgetTester t) {
  t.view.physicalSize = const Size(412, 915); t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Widget _conLetra(Widget home, {double escala = 2.0}) => MaterialApp(
  builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(escala)), child: child!),
  home: home);

const _toma = {'id': 2, 'hora': '14:00', 'medicamento': 'Metformina 500 mg', 'dosis': '1 tableta', 'estado': 'pendiente', 'via': 'oral'};

void main() {
  testWidgets('Registro: el interruptor de accesibilidad enciende y apaga las preferencias', (t) async {
    t.view.physicalSize = const Size(600, 3000); t.view.devicePixelRatio = 1; addTearDown(t.view.reset);
    final cont = ProviderContainer(); addTearDown(cont.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: cont, child: const MaterialApp(home: RegisterScreen())));
    await t.pumpAndSettle();
    final sw = find.byType(SwitchListTile);
    expect(t.widget<SwitchListTile>(sw).value, isFalse);

    await t.tap(sw); await t.pumpAndSettle();
    var p = cont.read(prefsProvider);
    expect([p.highContrast, p.audio, p.pictograms, p.bigButtons, p.textScale], [true, true, true, true, 1.25]);
    expect(t.widget<SwitchListTile>(sw).value, isTrue);

    await t.tap(sw); await t.pumpAndSettle();
    p = cont.read(prefsProvider);
    expect([p.highContrast, p.audio, p.pictograms, p.bigButtons, p.textScale], [false, false, false, false, 1.0]);
    expect(t.widget<SwitchListTile>(sw).value, isFalse);
  });

  testWidgets('ConfirmationDialog con letra al 200 %: sin desbordes y botones apilados', (t) async {
    _telefonoLetraGrande(t);
    bool? r;
    await t.pumpWidget(_conLetra(Builder(builder: (c) => Scaffold(body: Center(child: TextButton(
      onPressed: () async => r = await ConfirmationDialog.show(c, titulo: '¿Cerrar sesión?',
          mensaje: 'Tendrás que volver a escribir tu correo y contraseña para entrar. ' * 4, ok: 'Cerrar sesión'),
      child: const Text('abrir')))))));
    await t.tap(find.text('abrir')); await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final ok = t.getRect(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    final no = t.getRect(find.widgetWithText(TextButton, 'Cancelar'));
    expect(ok.bottom <= no.top, isTrue, reason: 'el principal va arriba y apilado');
    expect(ok.height, greaterThanOrEqualTo(48));
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await t.tap(find.widgetWithText(FilledButton, 'Cerrar sesión')); await t.pumpAndSettle();
    expect(r, isTrue);
  });

  testWidgets('Diálogo "Escribir código" del lector QR con letra al 200 %', (t) async {
    _telefonoLetraGrande(t);
    await t.pumpWidget(_conLetra(Scaffold(body: LectorQr(onCodigo: (_) async {}))));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Escribir código'));
    await t.tap(find.text('Escribir código')); await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('"Más tarde": hoja con 10 / 30 / 60 min, registra pospuesta y vuelve a Hoy', (t) async {
    _telefonoLetraGrande(t);
    final cont = ProviderContainer(); addTearDown(cont.dispose);
    cont.read(sessionProvider.notifier).enterDemo(Role.paciente);
    final router = GoRouter(initialLocation: '/recordatorio', routes: [
      GoRoute(path: '/recordatorio', builder: (_, __) => const RecordatorioScreen(toma: _toma)),
      GoRoute(path: '/hoy', builder: (_, __) => const Scaffold(body: Text('HOY')))]);
    await t.pumpWidget(UncontrolledProviderScope(container: cont, child: MaterialApp.router(routerConfig: router,
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(2)), child: child!))));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Más tarde'));
    await t.tap(find.text('Más tarde')); await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    for (final m in [10, 30, 60]) { expect(find.text('En $m minutos'), findsOneWidget); }

    await t.ensureVisible(find.text('En 30 minutos'));
    await t.tap(find.text('En 30 minutos'));
    await t.pump(); await t.pump(const Duration(milliseconds: 400)); await t.pumpAndSettle();
    final l = cont.read(tomasLocalesProvider)['2']!;
    expect(l.estado, 'pospuesta');
    expect(l.hasta!.difference(DateTime.now()).inMinutes, inInclusiveRange(28, 30));
    expect(find.text('HOY'), findsOneWidget);
  });

  test('tomaQueToca: suena a su hora, no se repite y respeta lo pospuesto', () {
    final horarios = [
      {'id': 1, 'hora': '08:00', 'medicamento': 'A', 'estado': 'pendiente'},
      {'id': 2, 'hora': '14:00', 'medicamento': 'B', 'estado': 'pendiente'},
      {'id': 3, 'hora': '14:00', 'medicamento': 'C', 'estado': 'tomada'}];
    final ahora = DateTime(2026, 9, 29, 14, 5); final alertadas = <String>{};
    final r = tomaQueToca(horarios, {}, alertadas, ahora)!;
    expect(r.toma['id'], 2); // la de las 08:00 ya pasó hace más de 30 min; la 3 ya se tomó
    alertadas.add(r.clave);
    expect(tomaQueToca(horarios, {}, alertadas, ahora), isNull);
    expect(tomaQueToca(horarios, {}, {}, DateTime(2026, 9, 29, 13, 59)), isNull);
    // Pospuesta en este teléfono: vuelve a sonar al cumplirse el tiempo.
    final locales = {'2': EstadoLocal('pospuesta', hasta: DateTime.now().add(const Duration(minutes: 10)))};
    final hoy = DateTime.now();
    expect(tomaQueToca(horarios, locales, alertadas, hoy), isNull);
    expect(tomaQueToca(horarios, locales, alertadas, hoy.add(const Duration(minutes: 11)))?.toma['id'], 2);
  });

  testWidgets('Pantalla en modo alarma: aviso visible y se detiene con "Más tarde"', (t) async {
    _telefonoLetraGrande(t);
    final cont = ProviderContainer(); addTearDown(cont.dispose);
    cont.read(sessionProvider.notifier).enterDemo(Role.paciente);
    await t.pumpWidget(UncontrolledProviderScope(container: cont,
      child: const MaterialApp(home: RecordatorioScreen(toma: {..._toma, 'alarma': true}))));
    await t.pump(); await t.pump(const Duration(milliseconds: 100));
    expect(find.text('¡Es hora de tu medicamento!'), findsOneWidget);
    expect(alarmaEnCurso.value, isTrue);
    await t.ensureVisible(find.text('Más tarde'));
    await t.tap(find.text('Más tarde')); await t.pumpAndSettle();
    expect(alarmaEnCurso.value, isFalse);
    expect(find.text('¡Es hora de tu medicamento!'), findsNothing);
    await t.ensureVisible(find.text('Cancelar'));
    await t.tap(find.text('Cancelar')); await t.pumpAndSettle();
  });

  testWidgets('Hoja de foto de perfil con letra al 200 %: sin desbordes', (t) async {
    _telefonoLetraGrande(t);
    await t.pumpWidget(ProviderScope(child: _conLetra(Consumer(builder: (c, ref, _) => Scaffold(body: Center(child: TextButton(
      onPressed: () => cambiarFotoPerfil(c, ref, tieneFoto: true), child: const Text('foto'))))))));
    await t.tap(find.text('foto')); await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Quitar foto'), findsOneWidget);
  });

  testWidgets('Diálogo "Otro medicamento" con letra al 200 %', (t) async {
    _telefonoLetraGrande(t);
    await t.pumpWidget(_conLetra(Scaffold(body: SingleChildScrollView(child: AlergiasSelector(alergias: List<String>.empty(growable: true), onChanged: () {})))));
    await t.tap(find.text('Agregar alergia')); await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Otro medicamento…'), 200, scrollable: find.byType(Scrollable).last);
    await t.tap(find.text('Otro medicamento…')); await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Agregar'), findsOneWidget);
  });
}
