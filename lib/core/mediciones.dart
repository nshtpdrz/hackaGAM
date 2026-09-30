// Mediciones de presión y glucosa: modelo y rangos de referencia.
// El semáforo oficial lo decide la API (motor de programas); estos rangos solo
// se usan para colorear gráficas, calcular "% en meta" y en el modo demo.

class Medicion {
  final DateTime fecha; final num? sistole, diastole, glucosa; final String semaforo;
  const Medicion(this.fecha, {this.sistole, this.diastole, this.glucosa, this.semaforo = 'verde'});

  /// Formato de la API: {fecha: ISO-8601, valores: {sistole, diastole, glucosa}, semaforo}
  static Medicion? fromJson(Map m) {
    final f = DateTime.tryParse('${m['fecha']}'); if (f == null) return null;
    final v = (m['valores'] as Map?) ?? const {};
    num? n(String k) => v[k] is num ? v[k] as num : num.tryParse('${v[k] ?? ''}');
    return Medicion(f.toLocal(), sistole: n('sistole'), diastole: n('diastole'), glucosa: n('glucosa'),
        semaforo: '${m['semaforo'] ?? nivelMedicion(n('sistole'), n('diastole'), n('glucosa'))}');
  }
  bool get tienePresion => sistole != null && diastole != null;
  bool get tieneGlucosa => glucosa != null;
}

/// Meta de presión: menor a 140/90 mmHg. Glucosa: 70–139 mg/dL.
const metaSistole = 140, metaDiastole = 90, metaGlucosaMin = 70, metaGlucosaMax = 140;

String nivelPresion(num s, num d) => (s >= 180 || d >= 110) ? 'rojo' : (s >= metaSistole || d >= metaDiastole) ? 'ambar' : 'verde';
String nivelGlucosa(num g) => (g < 54 || g >= 250) ? 'rojo' : (g < metaGlucosaMin || g >= metaGlucosaMax) ? 'ambar' : 'verde';

/// El peor nivel entre las variables presentes.
String nivelMedicion(num? s, num? d, num? g) {
  const orden = ['verde', 'ambar', 'rojo'];
  final ns = [if (s != null && d != null) nivelPresion(s, d), if (g != null) nivelGlucosa(g)];
  return ns.isEmpty ? 'verde' : ns.reduce((a, b) => orden.indexOf(a) >= orden.indexOf(b) ? a : b);
}
