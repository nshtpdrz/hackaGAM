import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/notifs.dart';
import '../../core/sync.dart';
import '../../core/theme.dart';
import '../../widgets/audio_player.dart';
import '../../widgets/components.dart';
import '../../widgets/dialogs.dart';
import '../shared.dart';
import '../../core/tr.dart';
import '../../core/api_modelos.dart';
import '../../core/state.dart';

// Detalle de alerta: paciente, gravedad, motivo, registro origen, hora y acción obligatoria para atenderla.
class AlertaDetalleScreen extends ConsumerStatefulWidget { final Map alerta;
  const AlertaDetalleScreen({super.key, required this.alerta});
  @override ConsumerState<AlertaDetalleScreen> createState() => _AlertaState(); }
class _AlertaState extends ConsumerState<AlertaDetalleScreen> {
  final _accion = TextEditingController(); bool busy = false;
  static const _rapidas = ['Se administró medicamento indicado', 'Se acudió a urgencias', 'Se contactó al paciente'];
  @override
  void dispose() { _accion.dispose(); super.dispose(); }

  Future<void> _atender() async {
    final ok = await ConfirmationDialog.show(context, titulo: tr('¿Marcar como atendida?'), mensaje: tr('Se guardará: "{a}"', {'a': _accion.text.trim()}));
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      await ref.read(apiProvider).atenderAlerta('${widget.alerta['id']}', _accion.text.trim());
      ref.invalidate(futureFor('alertas')); ref.invalidate(notificacionesProvider);
      if (mounted) { aviso(context, tr('Alerta atendida.')); context.pop(); }
    } catch (e) {
      if (!mounted) return;
      if (errorApi(e)?.estado == 409) { // alguien más ya la atendió
        ref.invalidate(futureFor('alertas')); ref.invalidate(notificacionesProvider);
        aviso(context, tr('Esta alerta ya estaba atendida.')); context.pop(); return;
      }
      aviso(context, isNetworkError(e) ? tr('Sin conexión. No se pudo atender la alerta.') : mensajeError(e) ?? tr('No se pudo guardar. Intenta de nuevo.'), ok: false);
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final a = widget.alerta; final r = a['registro'] as Map?; final t = Theme.of(c).textTheme;
    final puedeAtender = ref.watch(sessionProvider)?.role != Role.cuidador || a['nivel'] == 'ambar';
    return page(c, tr('Detalle de alerta'), ListView(padding: const EdgeInsets.all(16), children: [
      InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        dato(c, tr('Paciente'), a['paciente']), Text(tr('Gravedad'), style: t.bodySmall?.copyWith(color: C.text2)), const SizedBox(height: 4),
        Align(alignment: Alignment.centerLeft, child: SemaforoBadge('${a['nivel']}')), dato(c, tr('Hora'), a['hora'])])),
      const SizedBox(height: 12),
      InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Motivo'), style: t.labelLarge), const SizedBox(height: 4), MsgText('${a['message_key']}'), const SizedBox(height: 8), MsgAudioPlayer('${a['message_key']}')])),
      const SizedBox(height: 12),
      InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Registro que la originó'), style: t.labelLarge), const SizedBox(height: 4),
        if (r == null) Text(tr('Sin registro asociado.')) else ...[
          dato(c, tr('Medición'), tr(nombreVariable('${r['variable']}'))), dato(c, tr('Valor'), r['valor']), dato(c, tr('Fecha'), r['fecha'])]])),
      // La guía: el cuidador solo atiende las alertas ámbar; las rojas las atiende el equipo de salud.
      if (!puedeAtender) Padding(padding: const EdgeInsets.only(top: 16), child: InfoCard(child: Row(children: [
        const Icon(Icons.local_hospital_outlined, color: C.error), const SizedBox(width: 12),
        Expanded(child: Text(tr('Esta alerta la atiende el equipo de salud. Si hay una emergencia, llama al 911 o acude a urgencias.')))]))),
      if (puedeAtender) ...[
      SectionLabel(tr('Acción tomada (obligatoria)')),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final s in _rapidas) ActionChip(label: Text(tr(s)), onPressed: () => setState(() => _accion.text = tr(s)))]),
      const SizedBox(height: 12),
      TextField(controller: _accion, onChanged: (_) => setState(() {}), maxLines: 3, decoration: InputDecoration(labelText: tr('Describe la acción'))),
      const SizedBox(height: 16),
      BigButton(tr('Atender alerta'), onTap: busy || _accion.text.trim().isEmpty ? null : _atender)]]), bell: false);
  }
}
