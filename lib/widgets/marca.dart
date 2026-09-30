import 'package:flutter/material.dart';

// Marca SENDA. Imágenes en assets/marca/ (generadas desde el logotipo y el icono originales, con fondo transparente).

/// Logotipo "SENDA" (morado o blanco para fondos morados).
class LogoSenda extends StatelessWidget {
  final double alto; final bool blanco;
  const LogoSenda({super.key, this.alto = 44, this.blanco = false});
  @override
  Widget build(BuildContext c) => Image.asset(blanco ? 'assets/marca/senda_logo_blanco.png' : 'assets/marca/senda_logo.png',
      height: alto, fit: BoxFit.contain, semanticLabel: 'SENDA', filterQuality: FilterQuality.medium);
}

/// Icono de la app (cuadro morado redondeado con el emblema).
class IconoSenda extends StatelessWidget {
  final double tam; final bool decorativo;
  const IconoSenda({super.key, this.tam = 40, this.decorativo = false});
  @override
  Widget build(BuildContext c) => Image.asset('assets/marca/senda_icono_redondeado.png', width: tam, height: tam,
      semanticLabel: decorativo ? null : 'SENDA', excludeFromSemantics: decorativo, filterQuality: FilterQuality.medium);
}

/// Emblema blanco (para fondos morados: pantalla de arranque).
class EmblemaSenda extends StatelessWidget {
  final double tam; const EmblemaSenda({super.key, this.tam = 180});
  @override
  Widget build(BuildContext c) => Image.asset('assets/marca/senda_emblema.png', width: tam, height: tam,
      fit: BoxFit.contain, excludeFromSemantics: true, filterQuality: FilterQuality.medium);
}
