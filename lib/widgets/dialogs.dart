import 'package:flutter/material.dart';
import '../core/tr.dart';

/// true si la letra está muy grande o la pantalla es angosta: los botones van apilados a lo ancho.
bool letraGrande(BuildContext c) =>
    MediaQuery.textScalerOf(c).scale(14) / 14 >= 1.3 || MediaQuery.sizeOf(c).width < 360;

/// Márgenes del diálogo: con letra grande se reducen para aprovechar la pantalla.
EdgeInsets margenDialogo(BuildContext c) =>
    letraGrande(c) ? const EdgeInsets.symmetric(horizontal: 12, vertical: 16) : const EdgeInsets.symmetric(horizontal: 32, vertical: 24);

/// Diálogo que se adapta al tamaño de letra: el contenido hace scroll y, con letra grande,
/// los botones se apilan a lo ancho (mínimo 48 px de alto). [acciones] va de la menos a la más importante.
class DialogoAdaptable extends StatelessWidget {
  final Widget? titulo; final Widget? contenido; final List<Widget> acciones;
  const DialogoAdaptable({super.key, this.titulo, this.contenido, this.acciones = const []});

  @override
  Widget build(BuildContext c) {
    final grande = letraGrande(c);
    return AlertDialog(
      scrollable: true, insetPadding: margenDialogo(c), title: titulo, content: contenido,
      actionsOverflowButtonSpacing: 8,
      actions: grande
          // Apilados: el principal arriba, cada uno a todo lo ancho.
          ? [Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final a in acciones.reversed) Padding(padding: const EdgeInsets.only(top: 8), child: a)])]
          : acciones);
  }
}

/// Estilo común de los botones de diálogo (alto mínimo 48 px, texto sin cortar).
ButtonStyle get estiloBotonDialogo => const ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(64, 48)));

class ConfirmationDialog {
  /// Devuelve true solo si la persona confirma explícitamente.
  /// Los textos (en español) se traducen aquí con tr().
  static Future<bool> show(BuildContext context, {required String titulo, required String mensaje,
      String ok = 'Confirmar', String cancel = 'Cancelar'}) async {
    final r = await showDialog<bool>(context: context, builder: (ctx) => DialogoAdaptable(
      titulo: Text(tr(titulo)), contenido: Text(tr(mensaje)),
      acciones: [
        TextButton(style: estiloBotonDialogo, onPressed: () => Navigator.pop(ctx, false), child: Text(tr(cancel), textAlign: TextAlign.center)),
        FilledButton(style: estiloBotonDialogo, onPressed: () => Navigator.pop(ctx, true), child: Text(tr(ok), textAlign: TextAlign.center))]));
    return r ?? false;
  }
}
