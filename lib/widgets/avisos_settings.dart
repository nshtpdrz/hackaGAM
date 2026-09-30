import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/avisos_nativos.dart';
import '../core/reminders.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../core/tr.dart';
import 'components.dart';

typedef EstadoPermisos = ({EstadoAvisos avisos, EstadoNativo nativo});

Future<EstadoPermisos> _leer() async => (avisos: await estadoAvisos(), nativo: await estadoNativo());

/// Preferencias > Avisos y alarmas: dice en palabras simples qué falta para que las alarmas de tomas
/// y los avisos lleguen a tiempo, con un botón que lleva al ajuste. Se revisa otra vez al volver de Ajustes.
/// Solo muestra lo que se puede saber en este teléfono (en web no aparece nada).
class AvisosSettings extends ConsumerStatefulWidget {
  /// Para pruebas: sustituye la lectura de los permisos del teléfono.
  final Future<EstadoPermisos> Function() leer;
  const AvisosSettings({super.key, this.leer = _leer});
  @override ConsumerState<AvisosSettings> createState() => _AvisosState();
}

class _AvisosState extends ConsumerState<AvisosSettings> with WidgetsBindingObserver {
  EstadoPermisos? _e;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _cargar(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) { if (s == AppLifecycleState.resumed) _cargar(); }

  Future<void> _cargar() async { final e = await widget.leer(); if (mounted) setState(() => _e = e); }
  Future<void> _y(Future<Object?> Function() f) async { await f(); await _cargar(); }

  @override
  Widget build(BuildContext c) {
    final e = _e; if (e == null) return const SizedBox.shrink();
    final paciente = ref.watch(sessionProvider)?.role == Role.paciente;
    final a = e.avisos, n = e.nativo;
    final filas = <Widget>[
      if (a.notificaciones != null) _Fila(ok: a.notificaciones!, titulo: tr('Notificaciones'),
        bien: tr('Permitidas.'),
        mal: paciente ? tr('Desactivadas: no sonarán las alarmas de tus medicinas ni llegarán avisos.')
                      : tr('Desactivadas: no llegarán los avisos de alertas.'),
        accion: tr('Permitir'),
        onTap: () => _y(() async { if (!await pedirPermisoNotificaciones()) await abrirAjustesApp(); return null; })),
      if (paciente && a.exactas != null) _Fila(ok: a.exactas!, titulo: tr('Alarmas a la hora exacta'),
        bien: tr('Activadas.'), mal: tr('Las alarmas pueden sonar unos minutos tarde.'),
        accion: tr('Activar'), onTap: () => _y(pedirAlarmasExactas)),
      if (paciente && n.pantallaCompleta != null) _Fila(ok: n.pantallaCompleta!, titulo: tr('Alarma en pantalla completa'),
        bien: tr('La alarma aparece aunque el teléfono esté bloqueado.'),
        mal: tr('La alarma llegará como notificación, sin cubrir la pantalla.'),
        accion: tr('Activar'), onTap: () => _y(pedirPantallaCompleta)),
      if (n.sinRestriccionBateria != null) _Fila(ok: n.sinRestriccionBateria!, titulo: tr('Ahorro de batería'),
        bien: tr('Sin restricciones para SENDA.'),
        mal: '${tr('El teléfono puede retrasar o silenciar las alarmas y avisos. Elige "Sin restricciones" para SENDA.')}'
            '${fabricanteEstricto(n.fabricante) ? ' ${tr('En este teléfono activa también "Inicio automático" para SENDA.')}' : ''}',
        accion: tr('Abrir ajustes'), onTap: () => _y(abrirAjustesBateria)),
    ];
    if (filas.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 16), const SectionLabel('Avisos y alarmas'),
      for (final f in filas) Padding(padding: const EdgeInsets.only(bottom: 8), child: f)]);
  }
}

class _Fila extends StatelessWidget {
  final bool ok; final String titulo, bien, mal, accion; final VoidCallback onTap;
  const _Fila({required this.ok, required this.titulo, required this.bien, required this.mal, required this.accion, required this.onTap});
  @override
  Widget build(BuildContext c) {
    final t = Theme.of(c).textTheme;
    return InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MergeSemantics(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ok ? Icons.check_circle : Icons.warning_amber_rounded, color: ok ? C.success : C.warning,
          semanticLabel: ok ? tr('Listo') : tr('Falta')),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: t.labelLarge), const SizedBox(height: 4),
          Text(ok ? bien : mal, style: t.bodyMedium)]))])),
      if (!ok) Padding(padding: const EdgeInsets.only(top: 8),
        child: Align(alignment: AlignmentDirectional.centerEnd, child: OutlinedButton(onPressed: onTap, child: Text(accion))))]));
  }
}
