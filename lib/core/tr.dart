import 'package:flutter/widgets.dart';
import 'traducciones.dart';
import 'traducciones_extra.dart';

// Traducción de la interfaz. La clave es el propio texto en español, así el código sigue legible:
//   Text(tr('Guardar cambios'))            -> 'Save changes' en inglés
//   tr('Bajó {n} {u}', {'n': 5, 'u': 'mmHg'})  -> reemplaza {n} y {u}
// Si falta una traducción se muestra el español. Hñähñu ('ote') usa el catálogo de /mensajes
// para los mensajes clínicos; los textos de pantalla caen a español hasta tener traducción nativa.

String _idioma = 'es';
String get idiomaActual => _idioma;

String tr(String es, [Map<String, Object?> args = const {}]) {
  var s = traducciones[_idioma]?[es] ?? traduccionesExtra[_idioma]?[es] ?? es;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
  return s;
}

/// Cambia el idioma y redibuja toda la app conservando su estado (formularios, navegación, diálogos abiertos).
void fijarIdioma(String lang) {
  if (lang == _idioma) return;
  _idioma = lang;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    void marcar(Element e) { e.markNeedsBuild(); e.visitChildren(marcar); }
    WidgetsBinding.instance.rootElement?.visitChildren(marcar);
  });
}
