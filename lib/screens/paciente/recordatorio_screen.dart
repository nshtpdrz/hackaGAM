import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import '../../core/alarma_tomas.dart';
import '../../core/api_modelos.dart';
import '../../core/api.dart';
import '../../core/notifs.dart';
import '../../core/reminders.dart';
import '../../core/state.dart';
import '../../core/sync.dart';
import '../../core/theme.dart';
import '../../widgets/components.dart';
import '../../widgets/dialogs.dart';
import '../shared.dart';
import '../../core/tr.dart';

// 5. Detalle de toma / recordatorio: medicamento, dosis, horario, estado y confirmación.
// Con toma['alarma'] == true (abierta por la alarma de la app) suena en bucle, vibra y lo dice en voz alta
// hasta que la persona responde "Ya la tomé" o "Más tarde" (o sale de la pantalla).
class RecordatorioScreen extends ConsumerStatefulWidget { final Map toma; const RecordatorioScreen({super.key, required this.toma});
  @override ConsumerState<RecordatorioScreen> createState() => _RecordatorioState(); }

const _iconos = {'pendiente': Icons.schedule, 'tomada': Icons.check_circle, 'omitida': Icons.event_busy, 'pospuesta': Icons.snooze};

String _pid(ProviderContainer r) { final s = r.read(sessionProvider)!; return s.patientId ?? s.userId; }

/// Opciones de "Más tarde" (minutos).
const minutosPosponer = [10, 30, 60];

class _RecordatorioState extends ConsumerState<RecordatorioScreen> {
  Map get toma => widget.toma;
  bool _sonando = false; AudioPlayer? _player; FlutterTts? _tts; Timer? _vibra, _limite;

  @override
  void initState() {
    super.initState();
    if (toma['alarma'] == true) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _iniciarAlarma(); });
  }

  @override
  void dispose() { _detener(redibujar: false); _player?.dispose(); super.dispose(); }

  Future<void> _iniciarAlarma() async {
    setState(() => _sonando = true); alarmaEnCurso.value = true;
    var n = 0;
    _vibra = Timer.periodic(const Duration(seconds: 1), (_) => (n++ % 2 == 0 ? HapticFeedback.vibrate() : HapticFeedback.heavyImpact()));
    _limite = Timer(const Duration(minutes: 5), _detener); // no suena para siempre
    try {
      _player = AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.play(AssetSource('sonidos/alarma.wav'), volume: 1);
    } catch (_) {} // sin audio (p. ej. el navegador bloquea el sonido automático): quedan vibración y aviso visual
    if (!mounted || !_sonando || !ref.read(prefsProvider).audio) return;
    try {
      _tts = FlutterTts();
      await _tts!.setLanguage(idiomaActual == 'en' ? 'en-US' : 'es-MX');
      await _player?.setVolume(.3);
      await _tts!.speak(tr('Es hora de tomar {med}', {'med': toma['medicamento']}));
    } catch (_) {}
  }

  void _detener({bool redibujar = true}) {
    _vibra?.cancel(); _limite?.cancel(); _vibra = _limite = null;
    if (_sonando || alarmaEnCurso.value) {
      try { _player?.stop(); } catch (_) {}
      try { _tts?.stop(); } catch (_) {}
      alarmaEnCurso.value = false;
    }
    if (redibujar && mounted && _sonando) setState(() => _sonando = false);
  }

  Future<void> _tomada() async {
    _detener();
    final ok = await ConfirmationDialog.show(context,
        titulo: tr('¿Ya tomaste {med}?', {'med': toma['medicamento']}), mensaje: tr('Se registrará la toma de las {hora}.', {'hora': toma['hora']}));
    if (!ok || !mounted) return;
    ref.read(tomasLocalesProvider.notifier).tomada(toma['id']);
    atenderAlarma(toma); // quita la pospuesta y apaga la alarma que esté sonando
    await _send('tomada', tr('Toma registrada.'));
  }

  Future<void> _masTarde() async {
    _detener();
    final min = await elegirMinutosPosponer(context);
    if (min == null || !mounted) return;
    final d = Duration(minutes: min);
    ref.read(tomasLocalesProvider.notifier).pospuesta(toma['id'], d);
    programarPospuesta(toma, d); // alarma del sistema aunque la app se cierre
    // "Más tarde" no existe en la API (solo tomada|omitida): se queda en el teléfono.
    aviso(context, tr('Te lo recordaremos en {n} minutos.', {'n': min}));
    context.go('/hoy');
  }

  /// "No me la tomé": se registra como omitida con su motivo (la API lo usa para la adherencia).
  Future<void> _noLaTome() async {
    _detener();
    final motivo = await elegirMotivoOmision(context);
    if (motivo == null || !mounted) return;
    ref.read(tomasLocalesProvider.notifier).omitida(toma['id']);
    atenderAlarma(toma);
    await _send('omitida', tr('Registramos que no la tomaste.'), motivo: motivo);
  }

  Future<void> _send(String estado, String exito, {String? motivo}) async {
    final c = context; final r = ProviderScope.containerOf(context, listen: false);
    // El lote lleva id_local: si se reenvía desde la cola sin conexión, la API no lo duplica.
    final body = loteToma(toma, estado, motivo: motivo);
    try {
      await r.read(apiProvider).registrarToma(_pid(r), body);
      if (c.mounted) aviso(c, exito);
    } catch (e) {
      if (!isNetworkError(e)) { if (c.mounted) aviso(c, mensajeError(e) ?? tr('No se pudo registrar. Intenta de nuevo.'), ok: false); return; }
      r.read(syncProvider.notifier).encolar('toma', _pid(r), body);
      if (c.mounted) aviso(c, tr('Sin conexión: guardado en el teléfono. Se enviará solo.'));
    }
    r.invalidate(futureFor('horarios')); r.invalidate(notificacionesProvider);
    if (c.mounted) c.go('/hoy');
  }

  @override
  Widget build(BuildContext c) {
    final local = conEstadoLocal([toma], ref.watch(tomasLocalesProvider)).first;
    final est = '${local['estado'] ?? 'pendiente'}'; final e = etiquetasEstado.containsKey(est) ? est : 'pendiente';
    final abierta = est == 'pendiente' || est == 'pospuesta';
    final tt = Theme.of(c).textTheme;
    return page(c, tr('Toma de medicamento'), ListView(padding: const EdgeInsets.all(24), children: [
      if (_sonando) Semantics(liveRegion: true, child: Container(
        margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.warning.withValues(alpha: .15), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.warning, width: 2)),
        child: Row(children: [const Icon(Icons.alarm, color: C.warning, size: 36), const SizedBox(width: 12),
          Expanded(child: Text(tr('¡Es hora de tu medicamento!'), style: tt.titleLarge))]))),
      Text('${toma['medicamento']}', style: tt.headlineMedium),
      const SizedBox(height: 12),
      InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        dato(c, tr('Dosis'), toma['dosis']), dato(c, tr('Horario'), toma['hora']), dato(c, tr('Vía'), tr('${toma['via'] ?? 'oral'}')),
        Row(children: [Icon(_iconos[e], color: C.primary), const SizedBox(width: 8),
          Flexible(child: Text(tr('Estado: {estado}', {'estado': tr(etiquetasEstado[e]!)}), style: tt.labelLarge))])])),
      if (est == 'omitida') Padding(padding: const EdgeInsets.only(top: 12), child: Text(tr('Pasaron 30 minutos sin respuesta y la toma quedó como omitida.'))),
      const SizedBox(height: 24),
      if (abierta) ...[
        BigButton(tr('Ya la tomé'), icon: Icons.check, color: C.success, onTap: _tomada), const SizedBox(height: 12),
        BigButton(tr('Más tarde'), icon: Icons.snooze, color: C.warning, onTap: _masTarde), const SizedBox(height: 12),
        BigButton(tr('No me la tomé'), icon: Icons.close, secondary: true, onTap: _noLaTome)]]), bell: false);
  }
}

/// Hoja "¿En cuánto tiempo te lo recordamos?" con botones grandes 10 / 30 / 60 min. Devuelve los minutos o null.
Future<int?> elegirMinutosPosponer(BuildContext c) => showModalBottomSheet<int>(context: c, showDragHandle: true,
  isScrollControlled: true, useSafeArea: true,
  builder: (ctx) => SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(header: true, child: Text(tr('¿En cuánto tiempo te lo recordamos?'), style: Theme.of(ctx).textTheme.titleLarge)),
      const SizedBox(height: 16),
      for (final m in minutosPosponer) ...[
        BigButton(tr('En {n} minutos', {'n': m}), icon: Icons.snooze, onTap: () => Navigator.pop(ctx, m)), const SizedBox(height: 12)],
      BigButton(tr('Cancelar'), secondary: true, onTap: () => Navigator.pop(ctx))]))));

/// Motivos de "No me la tomé". SUPUESTO: claves de motivo; la guía solo dice "omitida con motivo".
const motivosOmision = {'olvido': 'Se me olvidó', 'sin_medicina': 'No tengo el medicamento', 'efecto_adverso': 'Me hizo sentir mal', 'otro': 'Otro motivo'};

Future<String?> elegirMotivoOmision(BuildContext c) => showModalBottomSheet<String>(context: c, showDragHandle: true,
  isScrollControlled: true, useSafeArea: true,
  builder: (ctx) => SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(header: true, child: Text(tr('¿Por qué no la tomaste?'), style: Theme.of(ctx).textTheme.titleLarge)),
      const SizedBox(height: 16),
      for (final e in motivosOmision.entries) ...[
        BigButton(tr(e.value), secondary: true, onTap: () => Navigator.pop(ctx, e.key)), const SizedBox(height: 12)]]))));
