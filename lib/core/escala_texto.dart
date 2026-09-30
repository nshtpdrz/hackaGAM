import 'package:flutter/widgets.dart';

/// Escala de letra no lineal, como la de Android 14: el texto de lectura (hasta 16 px) crece completo
/// y los títulos, que ya son grandes, crecen cada vez menos (a partir de 32 px, la mitad del aumento).
/// Con 200 %: 16 px -> 32 px, 20 px -> 37 px, 26 px -> 44 px, 32 px -> 48 px. Así la letra grande
/// se lee mejor sin que los encabezados empujen el resto de la pantalla fuera de lugar.
class EscalaTexto extends TextScaler {
  const EscalaTexto(this.factor);
  final double factor;

  @override
  double scale(double fontSize) {
    if (factor <= 1) return fontSize * factor;
    final t = ((fontSize - 16) / 16).clamp(0.0, 1.0); // 0 en texto normal, 1 en títulos grandes
    return fontSize * (1 + (factor - 1) * (1 - 0.5 * t));
  }

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => factor;

  @override
  bool operator ==(Object other) => other is EscalaTexto && other.factor == factor;
  @override
  int get hashCode => factor.hashCode;
}

/// Aumento efectivo del texto normal (16 px): 1.0 = sin aumento. Útil para decidir diseños compactos.
double escalaDe(BuildContext c) => (MediaQuery.textScalerOf(c).scale(16) / 16).clamp(1.0, 3.0);
