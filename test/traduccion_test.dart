import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medmap/core/tr.dart';
import 'package:medmap/core/traducciones.dart';
import 'package:medmap/core/traducciones_extra.dart';
import 'package:medmap/core/traducciones_plataforma.dart';
import 'package:medmap/screens/compartidas/historial_screen.dart';
import 'package:medmap/screens/shared.dart';

class _Titulo extends StatelessWidget { const _Titulo();
  @override Widget build(BuildContext c) => Text(tr('Guardar cambios')); }

void main() {
  tearDown(() => fijarIdioma('es'));
  _todoTraducido();

  test('tr: traduce, reemplaza variables y cae a español si falta', () {
    fijarIdioma('en');
    expect(tr('Guardar cambios'), 'Save changes');
    expect(tr('Paso {n} de {t}', {'n': 2, 't': 5}), 'Step 2 of 5');
    expect(tr('Texto que no existe'), 'Texto que no existe');
    fijarIdioma('ote'); // sin traducción de pantalla: español
    expect(tr('Guardar cambios'), 'Guardar cambios');
  });

  testWidgets('al cambiar de idioma se redibujan hasta los widgets const y se conserva lo escrito', (t) async {
    final ctl = TextEditingController();
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [const _Titulo(), TextField(controller: ctl)]))));
    await t.enterText(find.byType(TextField), 'hola');
    expect(find.text('Guardar cambios'), findsOneWidget);
    fijarIdioma('en');
    await t.pump(); await t.pump();
    expect(find.text('Save changes'), findsOneWidget);
    expect(ctl.text, 'hola');
  });

  testWidgets('historial en inglés', (t) async {
    fijarIdioma('en');
    final hoy = DateTime.now();
    await t.pumpWidget(ProviderScope(overrides: [historialProvider('1').overrideWith((_) async => [
      {'fecha': hoy.toIso8601String(), 'valores': {'sistole': 150, 'diastole': 85}},
      {'fecha': hoy.subtract(const Duration(days: 9)).toIso8601String(), 'valores': {'sistole': 120, 'diastole': 80}}])],
      child: const MaterialApp(home: Scaffold(body: HistorialContenido(pacienteId: '1')))));
    await t.pumpAndSettle();
    for (final s in ['Blood pressure', 'Glucose', 'Day', 'Week', 'Month', 'Last 14 days', 'Average', 'Trend']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    expect(find.textContaining('compared with the previous week'), findsOneWidget);
  });
}

/// T4: todo texto literal en tr('…') dentro de lib/ tiene traducción al inglés en traducciones*.dart.
/// (Los textos con variables {x} cuentan; los que se arman con $ no se pueden revisar así.)
void _todoTraducido() {
  test('todo tr(\'…\') de lib/ tiene inglés', () {
    final en = {...traducciones['en']!, ...traduccionesExtra['en']!, ...traduccionesPlataforma['en']!};
    // Texto partido en varias líneas ('a ' 'b'): se juntan los literales seguidos.
    final re = RegExp(r"""\btr\(\s*((?:'(?:[^'\\]|\\.)*'\s*)+)""");
    final lit = RegExp(r"""'((?:[^'\\]|\\.)*)'""");
    final faltan = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.contains('traducciones')) continue;
      for (final m in re.allMatches(f.readAsStringSync())) {
        final k = lit.allMatches(m.group(1)!).map((l) => l.group(1)!).join().replaceAll(r"\'", "'");
        if (!k.contains(r'$') && !en.containsKey(k)) faltan.add('${f.path}: $k');
      }
    }
    expect(faltan, isEmpty, reason: 'Agrega estos textos a lib/core/traducciones_plataforma.dart');
  });
}
