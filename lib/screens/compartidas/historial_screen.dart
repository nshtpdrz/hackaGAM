import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/mediciones.dart';
import '../../core/theme.dart';
import '../../widgets/components.dart';
import '../../widgets/state_views.dart';
import '../shared.dart';
import '../../core/tr.dart';
import '../../core/state.dart';
import '../../core/escala_texto.dart';

enum _Var { presion, glucosa }
enum _Per { dia, semana, mes }

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _rango = {_Per.dia: 'Últimos 14 días', _Per.semana: 'Últimas 12 semanas', _Per.mes: 'Últimos 6 meses'};
const _unidad = {_Per.dia: 'día', _Per.semana: 'semana', _Per.mes: 'mes'};

/// Un punto de la gráfica: todas las mediciones de un día, una semana o un mes.
class _Grupo {
  final DateTime ini, fin; final String etiqueta; final meds = <Medicion>[];
  _Grupo(this.ini, this.fin, this.etiqueta);
  double? prom(num? Function(Medicion) f) {
    final v = [for (final m in meds) if (f(m) != null) f(m)!];
    return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  }
}

List<_Grupo> _grupos(_Per p, DateTime ahora) {
  String dm(DateTime d) => '${d.day}/${d.month}';
  final h = DateTime(ahora.year, ahora.month, ahora.day);
  switch (p) {
    case _Per.dia:
      return [for (var i = 13; i >= 0; i--) () { final d = DateTime(h.year, h.month, h.day - i);
        return _Grupo(d, DateTime(d.year, d.month, d.day + 1), dm(d)); }()];
    case _Per.semana:
      final lunes = DateTime(h.year, h.month, h.day - (h.weekday - 1));
      return [for (var i = 11; i >= 0; i--) () { final d = DateTime(lunes.year, lunes.month, lunes.day - 7 * i);
        return _Grupo(d, DateTime(d.year, d.month, d.day + 7), dm(d)); }()];
    case _Per.mes:
      return [for (var i = 5; i >= 0; i--) () { final d = DateTime(h.year, h.month - i, 1);
        return _Grupo(d, DateTime(d.year, d.month + 1, 1), tr(_meses[d.month - 1])); }()];
  }
}

/// Escala de letra elegida en Preferencias (1.0 = normal). Las gráficas la usan para reservar espacio en los ejes.
double _escala(BuildContext c) => escalaDe(c).clamp(1.0, 2.0);
/// Poco espacio para la letra actual (celular con letra grande): se apilan datos y se muestran menos etiquetas.
bool _estrecho(BuildContext c) => MediaQuery.sizeOf(c).width / _escala(c) < 320;

String _fechaHora(DateTime d) =>
    '${tr(_dias[d.weekday - 1])} ${fmtFecha(d)} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// 7. Historial de mediciones: presión y glucosa, tendencia y frecuencia por día, semana o mes.
class HistorialScreen extends StatelessWidget { const HistorialScreen({super.key});
  @override
  Widget build(BuildContext c) => page(c, tr('Historial'), const HistorialContenido());
}

/// Historial reutilizable. Sin [pacienteId] muestra el del paciente de la sesión (paciente o cuidador);
/// el médico lo usa en el detalle del paciente, con los datos del paciente como [encabezado].
class HistorialContenido extends ConsumerStatefulWidget {
  final String? pacienteId; final List<Widget> encabezado;
  const HistorialContenido({super.key, this.pacienteId, this.encabezado = const []});
  @override ConsumerState<HistorialContenido> createState() => _HistorialState(); }

class _HistorialState extends ConsumerState<HistorialContenido> {
  _Var v = _Var.presion; _Per per = _Per.dia; int mostrar = 20;
  bool get _propio => widget.pacienteId == null;

  @override
  Widget build(BuildContext c) {
    ref.watch(sessionProvider.select((s) => s?.patientId)); // cuidador: cambia al elegir otro familiar
    final id = widget.pacienteId ?? pid(ref);
    Widget lista(List<Widget> hijos) => RefreshIndicator(onRefresh: () => ref.refresh(historialProvider(id).future),
      child: ListView(padding: const EdgeInsets.all(16), children: [...widget.encabezado, ...hijos]));
    return ref.watch(historialProvider(id)).when(
      loading: () => lista([Semantics(label: tr('Cargando'), child: const Padding(padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator())))]),
      error: (e, _) => lista([SizedBox(height: 360, child: ErrorView(error: e, onRetry: () => ref.invalidate(historialProvider(id))))]),
      data: (d) {
        final todas = [for (final m in d as List) if (m is Map) Medicion.fromJson(m)].whereType<Medicion>()
            .where((m) => v == _Var.presion ? m.tienePresion : m.tieneGlucosa).toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));
        final gs = _grupos(per, DateTime.now());
        for (final m in todas) {
          for (final g in gs) { if (!m.fecha.isBefore(g.ini) && m.fecha.isBefore(g.fin)) { g.meds.add(m); break; } }
        }
        return lista([
          _selectores(),
          const SizedBox(height: 16),
          if (todas.isEmpty) _vacio(c) else ...[
            _resumen(c, gs), const SizedBox(height: 16),
            _tarjeta(c, tr('Tendencia'), v == _Var.presion ? tr('Promedio de presión por {u}', {'u': tr(_unidad[per]!)}) : tr('Promedio de glucosa por {u}', {'u': tr(_unidad[per]!)}),
              _Tendencia(grupos: gs, v: v, per: per), leyenda: _leyenda()),
            const SizedBox(height: 16),
            _tarjeta(c, tr('Frecuencia de mediciones'), tr(_propio ? 'Cuántas veces te mediste por {u}' : 'Cuántas veces se midió por {u}', {'u': tr(_unidad[per]!)}),
              _Frecuencia(grupos: gs, per: per)),
            const SizedBox(height: 24),
            Text(tr('Todas las mediciones'), style: Theme.of(c).textTheme.headlineSmall), const SizedBox(height: 8),
            for (final m in todas.take(mostrar)) _fila(c, m),
            if (todas.length > mostrar) Padding(padding: const EdgeInsets.only(top: 8),
              child: BigButton(tr('Ver más'), icon: Icons.expand_more, secondary: true, onTap: () => setState(() => mostrar += 20)))]]);
      });
  }

  Widget _selectores() {
    const alto = ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(0, 52)));
    final ic = 18 * _escala(context);
    Widget txt(String t) => FittedBox(fit: BoxFit.scaleDown, child: Text(t, maxLines: 1, softWrap: false));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SegmentedButton<_Var>(style: alto, showSelectedIcon: false, selected: {v},
        onSelectionChanged: (s) => setState(() { v = s.first; mostrar = 20; }),
        segments: [ButtonSegment(value: _Var.presion, label: txt(tr('Presión')), icon: Icon(Icons.favorite_outline, size: ic)),
          ButtonSegment(value: _Var.glucosa, label: txt(tr('Glucosa')), icon: Icon(Icons.water_drop_outlined, size: ic))]),
      const SizedBox(height: 8),
      SegmentedButton<_Per>(style: alto, showSelectedIcon: false, selected: {per}, onSelectionChanged: (s) => setState(() => per = s.first),
        segments: [ButtonSegment(value: _Per.dia, label: txt(tr('Día'))), ButtonSegment(value: _Per.semana, label: txt(tr('Semana'))),
          ButtonSegment(value: _Per.mes, label: txt(tr('Mes')))])]);
  }

  Widget _vacio(BuildContext c) => InfoCard(child: Column(children: [
    Icon(v == _Var.presion ? Icons.favorite_outline : Icons.water_drop_outlined, size: 40, color: C.text2), const SizedBox(height: 8),
    Text(v == _Var.presion ? tr('Aún no hay mediciones de presión.') : tr('Aún no hay mediciones de glucosa.'), textAlign: TextAlign.center)]));

  Widget _resumen(BuildContext c, List<_Grupo> gs) {
    final meds = [for (final g in gs) ...g.meds]; final pres = v == _Var.presion;
    String r(double? x) => x == null ? '—' : '${x.round()}';
    final prom = pres ? '${r(_prom(meds, (m) => m.sistole))}/${r(_prom(meds, (m) => m.diastole))} mmHg' : '${r(_prom(meds, (m) => m.glucosa))} mg/dL';
    final enMeta = meds.where((m) => (pres ? nivelPresion(m.sistole!, m.diastole!) : nivelGlucosa(m.glucosa!)) == 'verde').length;
    final pct = meds.isEmpty ? null : (100 * enMeta / meds.length).round();
    // Progreso: promedio de la segunda mitad del rango contra la primera (menos sensible a un día aislado).
    num? f(Medicion m) => pres ? m.sistole : m.glucosa;
    final mitad = gs.length ~/ 2;
    final antes = _prom([for (final g in gs.take(mitad)) ...g.meds], f), despues = _prom([for (final g in gs.skip(mitad)) ...g.meds], f);
    final delta = antes == null || despues == null ? null : despues - antes;
    final t = Theme.of(c).textTheme;
    Widget stat(String l, String val) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l, style: t.bodySmall?.copyWith(color: C.text2)), Text(val, style: t.labelLarge)]);
    // Con letra grande, un dato por renglón; si no, dos columnas.
    Widget par(Widget a, Widget b) => _estrecho(c)
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [a, const SizedBox(height: 12), b])
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), Expanded(child: b)]);
    return InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr(_rango[per]!), style: t.bodySmall?.copyWith(color: C.text2)), const SizedBox(height: 8),
      par(stat(tr('Promedio'), meds.isEmpty ? '—' : prom), stat(tr('Mediciones'), '${meds.length}')),
      const SizedBox(height: 12),
      par(stat(tr('En meta'), pct == null ? '—' : '$pct %'),
        stat(tr('Meta'), pres ? tr('Menor a {s}/{d}', {'s': metaSistole, 'd': metaDiastole}) : '$metaGlucosaMin–${metaGlucosaMax - 1} mg/dL')),
      if (delta != null) ...[const Divider(height: 24), _progreso(c, delta, pres ? 'mmHg' : 'mg/dL')]]));
  }

  Widget _progreso(BuildContext c, double delta, String u) {
    final d = delta.round().abs(); final refTxt = {_Per.dia: tr('la semana anterior'), _Per.semana: tr('las 6 semanas anteriores'), _Per.mes: tr('los 3 meses anteriores')};
    final (ic, col, txt) = d < 2 ? (Icons.trending_flat, C.info, tr('Estable respecto a {ref}', {'ref': refTxt[per]}))
        : delta < 0 ? (Icons.trending_down, C.success, tr('Bajó {d} {u} respecto a {ref}', {'d': d, 'u': u, 'ref': refTxt[per]}))
        : (Icons.trending_up, C.warning, tr('Subió {d} {u} respecto a {ref}', {'d': d, 'u': u, 'ref': refTxt[per]}));
    return Semantics(liveRegion: true, child: Row(children: [Icon(ic, color: col, size: 28 * _escala(c)), const SizedBox(width: 12),
      Expanded(child: Text(v == _Var.presion ? tr('{txt} (sistólica)', {'txt': txt}) : txt, style: Theme.of(c).textTheme.bodyLarge))]));
  }

  Widget _tarjeta(BuildContext c, String titulo, String sub, Widget grafica, {Widget? leyenda}) => InfoCard(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: Theme.of(c).textTheme.headlineSmall),
      Text(sub, style: Theme.of(c).textTheme.bodySmall?.copyWith(color: C.text2)),
      const SizedBox(height: 16),
      // Los números de ejes y avisos crecen hasta 130 %; más allá aplastan el área de dibujo.
      SizedBox(height: 210 + 90 * (_escala(c) - 1), child: MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(math.min(_escala(c), 1.3))), child: grafica)),
      if (leyenda != null) ...[const SizedBox(height: 12), leyenda]]));

  Widget _leyenda() {
    Widget item(Color col, String l, {bool linea = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: linea ? 18 : 12, height: linea ? 3 : 12, decoration: BoxDecoration(color: col,
        borderRadius: BorderRadius.circular(linea ? 2 : 6))), const SizedBox(width: 6), Flexible(child: Text(l))]);
    return Wrap(spacing: 16, runSpacing: 8, children: v == _Var.presion
      ? [item(C.primary, tr('Sistólica')), item(C.info, tr('Diastólica')), item(C.warning, tr('Límite de meta'), linea: true)]
      : [item(C.primary, tr('Glucosa')), item(C.success.withValues(alpha: .35), tr('Rango de meta'))]);
  }

  Widget _fila(BuildContext c, Medicion m) {
    final pres = v == _Var.presion; final t = Theme.of(c).textTheme;
    final badge = SemaforoBadge(pres ? nivelPresion(m.sistole!, m.diastole!) : nivelGlucosa(m.glucosa!));
    final datos = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(pres ? '${m.sistole}/${m.diastole} mmHg' : '${m.glucosa} mg/dL', style: t.labelLarge),
      Text(_fechaHora(m.fecha), style: t.bodyMedium?.copyWith(color: C.text2))]);
    final icono = Icon(pres ? Icons.favorite_outline : Icons.water_drop_outlined, color: C.primary, size: 24 * _escala(c));
    // Con letra grande el semáforo baja a su propia línea para no apretar ni recortar el texto.
    final grande = _estrecho(c);
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: Padding(padding: const EdgeInsets.all(16),
      child: grande
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [icono, const SizedBox(width: 12), Expanded(child: datos)]), const SizedBox(height: 12),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: badge)])
        : Row(children: [icono, const SizedBox(width: 16), Expanded(child: datos), const SizedBox(width: 8), Flexible(child: badge)]))));
  }
}

double? _prom(List<Medicion> ms, num? Function(Medicion) f) {
  final v = [for (final m in ms) if (f(m) != null) f(m)!];
  return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
}

/// Etiquetas del eje X: se salta algunas para que no se encimen.
/// Con letra grande reserva más espacio y muestra menos etiquetas; cada etiqueta va en una sola línea.
SideTitles _ejeX(List<_Grupo> gs, _Per per, double esc, bool estrecho) => SideTitles(showTitles: true, interval: 1, reservedSize: 28 * esc,
  getTitlesWidget: (x, meta) {
    final i = x.round(); final paso = (per == _Per.mes ? 1 : per == _Per.semana ? 3 : 2) * (estrecho && per != _Per.mes ? 2 : 1);
    if (i < 0 || i >= gs.length || x != i || (gs.length - 1 - i) % paso != 0) return const SizedBox.shrink();
    return SideTitleWidget(axisSide: meta.axisSide, child: Text(gs[i].etiqueta, maxLines: 1, softWrap: false, style: const TextStyle(fontSize: 12, color: C.text2)));
  });

SideTitles _ejeY(double intervalo, double esc) => SideTitles(showTitles: true, reservedSize: 34 * esc + 6, interval: intervalo,
  getTitlesWidget: (y, meta) => SideTitleWidget(axisSide: meta.axisSide,
    child: Text('${y.round()}', maxLines: 1, softWrap: false, style: const TextStyle(fontSize: 12, color: C.text2))));

const _sinEje = AxisTitles(sideTitles: SideTitles(showTitles: false));
FlGridData _rejilla(double intervalo) => FlGridData(drawVerticalLine: false, horizontalInterval: intervalo,
  getDrawingHorizontalLine: (_) => const FlLine(color: C.border, strokeWidth: 1));

class _Tendencia extends StatelessWidget {
  final List<_Grupo> grupos; final _Var v; final _Per per;
  const _Tendencia({required this.grupos, required this.v, required this.per});

  @override
  Widget build(BuildContext c) {
    final pres = v == _Var.presion;
    final a = [for (final g in grupos) g.prom((m) => pres ? m.sistole : m.glucosa)];
    final b = [for (final g in grupos) pres ? g.prom((m) => m.diastole) : null];
    // Escala: incluye los datos y las líneas de meta, redondeada a decenas.
    final vals = [...a, ...b].whereType<double>().toList();
    final lo = [...vals, pres ? metaDiastole.toDouble() : metaGlucosaMin.toDouble()].reduce(math.min);
    final hi = [...vals, pres ? metaSistole.toDouble() : metaGlucosaMax.toDouble()].reduce(math.max);
    final intervalo = math.max(10.0, ((hi - lo + 10) / 4 / 10).ceil() * 10.0);
    final minY = ((lo - 5) / intervalo).floor() * intervalo, maxY = ((hi + 5) / intervalo).ceil() * intervalo;
    Color nivel(int i) {
      final n = pres ? nivelPresion(a[i]!, b[i] ?? 0) : nivelGlucosa(a[i]!);
      return n == 'verde' ? C.success : n == 'ambar' ? C.warning : C.error;
    }
    LineChartBarData linea(List<double?> ys, Color col, {bool colorPorNivel = false}) => LineChartBarData(
      spots: [for (var i = 0; i < ys.length; i++) ys[i] == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), ys[i]!)],
      isCurved: true, preventCurveOverShooting: true, color: col, barWidth: 3,
      dotData: FlDotData(getDotPainter: (s, _, __, ___) => FlDotCirclePainter(radius: 5,
        color: colorPorNivel ? nivel(s.x.round()) : col, strokeWidth: 2, strokeColor: Colors.white)));
    HorizontalLine meta(num y) => HorizontalLine(y: y.toDouble(), color: C.warning, strokeWidth: 1.5, dashArray: [6, 4],
      label: HorizontalLineLabel(show: true, alignment: Alignment.topRight, labelResolver: (_) => '$y',
        style: const TextStyle(fontSize: 11, color: C.warning, fontWeight: FontWeight.w600)));

    final ultimo = grupos.lastWhere((g) => g.meds.isNotEmpty, orElse: () => grupos.last);
    final desc = pres
        ? tr('Gráfica de presión. Último promedio: {s} sobre {d}.', {'s': ultimo.prom((m) => m.sistole)?.round() ?? tr('sin datos'), 'd': ultimo.prom((m) => m.diastole)?.round()})
        : tr('Gráfica de glucosa. Último promedio: {g} mg/dL.', {'g': ultimo.prom((m) => m.glucosa)?.round() ?? tr('sin datos')});
    return Semantics(label: desc, child: ExcludeSemantics(child: LineChart(LineChartData(
      minX: 0, maxX: grupos.length - 1.0, minY: minY, maxY: maxY,
      lineBarsData: [linea(a, C.primary, colorPorNivel: true), if (pres) linea(b, C.info)],
      extraLinesData: ExtraLinesData(horizontalLines: pres ? [meta(metaSistole), meta(metaDiastole)] : []),
      rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: pres ? [] : [HorizontalRangeAnnotation(
        y1: metaGlucosaMin.toDouble(), y2: metaGlucosaMax.toDouble(), color: C.success.withValues(alpha: .12))]),
      titlesData: FlTitlesData(bottomTitles: AxisTitles(sideTitles: _ejeX(grupos, per, _escala(c), _estrecho(c))),
        leftTitles: AxisTitles(sideTitles: _ejeY(intervalo, _escala(c))), topTitles: _sinEje, rightTitles: _sinEje),
      gridData: _rejilla(intervalo), borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => C.text, maxContentWidth: 260,
        fitInsideHorizontally: true, fitInsideVertically: true,
        getTooltipItems: (ss) => [for (final s in ss) LineTooltipItem(
          '${s.barIndex == 0 ? '${grupos[s.x.round()].etiqueta}\n' : ''}${tr(pres ? (s.barIndex == 0 ? 'Sistólica' : 'Diastólica') : 'Glucosa')}: ${s.y.round()}',
          const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))]))))));
  }
}

class _Frecuencia extends StatelessWidget {
  final List<_Grupo> grupos; final _Per per;
  const _Frecuencia({required this.grupos, required this.per});

  @override
  Widget build(BuildContext c) {
    final n = [for (final g in grupos) g.meds.length];
    final maxN = n.reduce(math.max);
    // Paso "redondo" (1, 2, 5, 10, 20, 50...) y tope en múltiplo del paso, para que el eje no muestre valores raros.
    final crudo = math.max(1.0, maxN / 4); final base = math.pow(10, (math.log(crudo) / math.ln10).floor()).toDouble();
    final intervalo = [1, 2, 5, 10].map((m) => m * base).firstWhere((x) => x >= crudo);
    final total = n.fold(0, (a, b) => a + b);
    return Semantics(label: tr('Gráfica de frecuencia: {n} mediciones, en promedio {p} por {u}.', {'n': total, 'p': (total / grupos.length).toStringAsFixed(1), 'u': tr(_unidad[per]!)}),
      child: ExcludeSemantics(child: BarChart(BarChartData(
        maxY: ((maxN / intervalo).floor() + 1) * intervalo, alignment: BarChartAlignment.spaceAround,
        barGroups: [for (var i = 0; i < n.length; i++) BarChartGroupData(x: i, barRods: [BarChartRodData(toY: n[i].toDouble(),
          color: C.p600, width: per == _Per.mes ? 24 : 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))])],
        titlesData: FlTitlesData(bottomTitles: AxisTitles(sideTitles: _ejeX(grupos, per, _escala(c), _estrecho(c))),
          leftTitles: AxisTitles(sideTitles: _ejeY(intervalo, _escala(c))), topTitles: _sinEje, rightTitles: _sinEje),
        gridData: _rejilla(intervalo), borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(getTooltipColor: (_) => C.text, fitInsideHorizontally: true, maxContentWidth: 260,
          getTooltipItem: (g, _, rod, __) => BarTooltipItem('${grupos[g.x].etiqueta}\n${rod.toY.round()} ${tr(rod.toY.round() == 1 ? 'medición' : 'mediciones')}',
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))))))));
  }
}
