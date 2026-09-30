import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/tr.dart';
import '../screens/shared.dart';
import 'dialogs.dart';

/// Número que se puede marcar (dígitos y un + inicial) o null si no parece teléfono (p. ej. un correo).
String? telefonoMarcable(Object? v) {
  final s = '${v ?? ''}'.trim();
  final n = (s.startsWith('+') ? '+' : '') + s.replaceAll(RegExp(r'\D'), '');
  return n.replaceAll('+', '').length >= 7 ? n : null;
}

/// Abre el marcador del teléfono. Si no se puede (web, tableta sin línea), avisa el número para marcarlo a mano.
Future<void> llamar(BuildContext c, String numero) async {
  var ok = false;
  try { ok = await launchUrl(Uri(scheme: 'tel', path: numero)); } catch (_) {}
  if (!ok && c.mounted) aviso(c, tr('No se pudo abrir el teléfono. Marca al {n}.', {'n': numero}), ok: false);
}

/// "Pedir ayuda a mi cuidador" (resultado ámbar o rojo): llama al cuidador registrado del paciente
/// (GET /pacientes/:id -> cuidadores[].telefono). En rojo ofrece también el 911.
Future<void> pedirAyuda(BuildContext c, {required bool urgente}) => showDialog<void>(context: c, builder: (ctx) =>
  Consumer(builder: (ctx, ref, _) {
    final perfil = ref.watch(futureFor('perfil'));
    final cu = perfil.valueOrNull is Map ? (perfil.valueOrNull as Map)['cuidador'] : null;
    final nombre = cu is Map && '${cu['nombre'] ?? ''}'.trim().isNotEmpty ? '${cu['nombre']}'.trim() : null;
    final tel = cu is Map ? telefonoMarcable(cu['contacto'] ?? cu['telefono']) : null;
    return DialogoAdaptable(
      titulo: Text(tr('Pedir ayuda')),
      contenido: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (perfil.isLoading) const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator()))
        else if (tel == null) Text(nombre == null
            ? tr('No tenemos el teléfono de tu cuidador. Pide a tu equipo de salud que lo registre.')
            : tr('No tenemos el teléfono de {nombre}. Pide a tu equipo de salud que lo registre.', {'nombre': nombre}))
        else Text(tr('Vamos a llamar a {nombre} al {tel}.', {'nombre': nombre ?? tr('tu cuidador'), 'tel': cu['contacto'] ?? tel})),
        if (urgente) Padding(padding: const EdgeInsets.only(top: 12),
          child: Text(tr('Si te sientes muy mal, llama al 911.'), style: Theme.of(ctx).textTheme.titleMedium)),
      ]),
      acciones: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancelar'))),
        if (urgente) FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: C.error),
          icon: const Icon(Icons.emergency), label: Text(tr('Llamar al 911')),
          onPressed: () { Navigator.pop(ctx); llamar(c, '911'); }),
        if (tel != null) FilledButton.icon(icon: const Icon(Icons.phone),
          label: Text(nombre == null ? tr('Llamar a mi cuidador') : tr('Llamar a {nombre}', {'nombre': nombre.split(' ').first})),
          onPressed: () { Navigator.pop(ctx); llamar(c, tel); }),
      ]);
  }));
