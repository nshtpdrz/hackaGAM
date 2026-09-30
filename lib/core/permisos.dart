import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/dialogs.dart';
import 'avisos_nativos.dart';
import 'tr.dart';

/// Permisos de cámara y fotos: si la persona los negó, se le dice qué pasa y se le lleva a Ajustes.

/// image_picker avisa así que el permiso está negado (Android e iOS).
bool esPermisoNegado(Object e) =>
    e is PlatformException && const {'camera_access_denied', 'photo_access_denied'}.contains(e.code);

/// Ficha de SENDA en los Ajustes del teléfono (Android: canal nativo; iOS: app-settings:).
Future<bool> abrirAjustesDeLaApp() async {
  if (kIsWeb) return false;
  if (defaultTargetPlatform == TargetPlatform.android) return abrirAjustesApp();
  try { return await launchUrl(Uri.parse('app-settings:')); } catch (_) { return false; }
}

/// Diálogo "Permite la cámara en Ajustes" con botón a Ajustes. [camara]: false = fotos/galería.
Future<void> avisarPermisoNegado(BuildContext c, {bool camara = true}) => showDialog<void>(context: c, builder: (ctx) =>
  DialogoAdaptable(
    titulo: Text(camara ? tr('SENDA no tiene permiso de usar la cámara') : tr('SENDA no tiene permiso de ver tus fotos')),
    contenido: Text(camara
        ? tr('Para tomar la foto, permite la cámara en los Ajustes del teléfono y vuelve a intentarlo.')
        : tr('Para elegir una foto, permite el acceso a fotos en los Ajustes del teléfono y vuelve a intentarlo.')),
    acciones: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Ahora no'))),
      if (!kIsWeb) FilledButton.icon(icon: const Icon(Icons.settings), label: Text(tr('Ir a Ajustes')),
        onPressed: () { Navigator.pop(ctx); abrirAjustesDeLaApp(); })]));

/// Toma o elige una foto. Si falta el permiso, lo explica con botón a Ajustes y devuelve null.
/// Otros errores del selector se muestran como "No se pudo abrir la cámara/galería".
Future<XFile?> elegirFoto(BuildContext c, ImageSource s, {double? maxWidth, double? maxHeight, int? imageQuality}) async {
  try {
    return await ImagePicker().pickImage(source: s, maxWidth: maxWidth, maxHeight: maxHeight, imageQuality: imageQuality);
  } catch (e) {
    if (!c.mounted) return null;
    if (esPermisoNegado(e)) {
      await avisarPermisoNegado(c, camara: s == ImageSource.camera);
    } else {
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(
          s == ImageSource.camera ? tr('No se pudo abrir la cámara.') : tr('No se pudo abrir la galería.'))));
    }
    return null;
  }
}

/// Android puede cerrar SENDA mientras la cámara está abierta (teléfonos con poca memoria).
/// Al volver a abrir la pantalla, recupera la foto que se tomó (o null).
Future<XFile?> fotoPerdida() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final r = await ImagePicker().retrieveLostData();
    return r.isEmpty ? null : r.file;
  } catch (_) { return null; }
}
