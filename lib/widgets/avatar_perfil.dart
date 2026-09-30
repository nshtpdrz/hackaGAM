import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api.dart';
import '../core/permisos.dart';
import '../core/state.dart';
import '../core/sync.dart';
import '../core/theme.dart';
import '../screens/shared.dart';
import '../core/tr.dart';

/// Foto elegida en este dispositivo (se ve al instante, antes de que la API devuelva foto_url).
/// Se reinicia al cambiar de usuario.
final fotoPerfilProvider = StateProvider<Uint8List?>((ref) {
  ref.watch(sessionProvider.select((s) => s?.userId));
  return null;
});

/// Avatar del perfil: foto local > foto_url de la API > iniciales. Con [onEditar] muestra el botón de cámara.
class AvatarPerfil extends ConsumerWidget {
  final Map perfil; final double radio; final VoidCallback? onEditar;
  const AvatarPerfil({super.key, required this.perfil, this.radio = 44, this.onEditar});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final local = ref.watch(fotoPerfilProvider); final url = '${perfil['foto_url'] ?? ''}';
    final ImageProvider? img = local != null ? MemoryImage(local) : url.isNotEmpty ? NetworkImage(url) as ImageProvider : null;
    final ini = '${perfil['nombre'] ?? ''}'.split(' ').where((w) => w.isNotEmpty && !w.endsWith('.') && w[0].toUpperCase() == w[0])
        .take(2).map((w) => w[0]).join().toUpperCase();
    final avatar = CircleAvatar(radius: radio, backgroundColor: C.p100, foregroundImage: img,
      child: Text(ini, style: TextStyle(fontSize: radio * .7, fontWeight: FontWeight.w700, color: C.primary)));
    if (onEditar == null) return avatar;
    return Semantics(button: true, label: tr('Cambiar foto de perfil'), child: InkWell(customBorder: const CircleBorder(), onTap: onEditar,
      child: Stack(children: [avatar, Positioned(right: 0, bottom: 0, child: Container(padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: C.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
        child: const Icon(Icons.photo_camera, color: Colors.white, size: 20)))])));
  }
}

/// Menú para tomar o elegir la foto de perfil (o quitarla) y subirla a la API.
Future<void> cambiarFotoPerfil(BuildContext c, WidgetRef ref, {required bool tieneFoto}) async {
  // isScrollControlled + scroll: con letra al 200 % las opciones no se desbordan.
  final op = await showModalBottomSheet<String>(context: c, showDragHandle: true, isScrollControlled: true, useSafeArea: true,
    builder: (ctx) => SafeArea(child: SingleChildScrollView(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
      if (!kIsWeb) ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(tr('Tomar foto')),
        onTap: () => Navigator.pop(ctx, 'camara')),
      ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(kIsWeb ? tr('Elegir imagen') : tr('Elegir de la galería')),
        onTap: () => Navigator.pop(ctx, 'galeria')),
      if (tieneFoto) ListTile(leading: const Icon(Icons.delete_outline, color: C.error), title: Text(tr('Quitar foto')),
        onTap: () => Navigator.pop(ctx, 'quitar'))]))));
  if (op == null || !c.mounted) return;
  final api = ref.read(apiProvider); final antes = ref.read(fotoPerfilProvider);
  try {
    if (op == 'quitar') {
      ref.read(fotoPerfilProvider.notifier).state = null;
      await api.actualizarYo({'foto_url': null});
    } else {
      final x = await elegirFoto(c, op == 'camara' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 800, maxHeight: 800, imageQuality: 85); // sin permiso: explica y lleva a Ajustes
      if (x == null) return;
      final bytes = await x.readAsBytes();
      ref.read(fotoPerfilProvider.notifier).state = bytes; // se ve de inmediato
      await api.subirFotoPerfil(bytes, x.name);
    }
    ref.invalidate(futureFor('perfil'));
    if (c.mounted) aviso(c, op == 'quitar' ? tr('Foto eliminada.') : tr('Foto de perfil actualizada.'));
  } catch (e) {
    ref.read(fotoPerfilProvider.notifier).state = antes;
    if (c.mounted) aviso(c, isNetworkError(e) ? tr('Sin conexión. La foto no se guardó.') : tr('No se pudo cambiar la foto.'), ok: false);
  }
}

/// Insignia del médico: verificado (cédula validada por la API) o en revisión.
class InsigniaMedico extends StatelessWidget {
  final bool verificado; const InsigniaMedico({super.key, required this.verificado});
  @override
  Widget build(BuildContext c) {
    final (col, ic, txt) = verificado
        ? (C.info, Icons.verified, tr('Médico verificado')) : (C.text2, Icons.hourglass_top, tr('Cédula en revisión'));
    return Tooltip(message: verificado ? tr('Cédula profesional validada') : tr('Tu cédula profesional se está verificando'),
      child: Semantics(label: txt, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: col.withValues(alpha: .12), borderRadius: BorderRadius.circular(999),
          border: Border.all(color: col, width: 1.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(ic, color: col, size: 22), const SizedBox(width: 8),
          Flexible(child: Text(txt, style: Theme.of(c).textTheme.labelLarge?.copyWith(color: col)))]))));
  }
}
