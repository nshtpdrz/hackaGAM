import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api.dart';
import '../../core/api_modelos.dart';
import '../../core/permisos.dart';
import '../../core/state.dart';
import '../../core/sync.dart';
import '../../core/theme.dart';
import '../../core/tr.dart';
import '../../widgets/components.dart';
import '../shared.dart';

// Seguimiento fotográfico de heridas (guía de integración §6). La IA describe y compara la foto nueva con
// la anterior; no diagnostica. Paciente y cuidador solo ven estado y mensaje; el equipo ve el detalle.

final lesionesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) => ref.read(apiProvider).lesiones(id));
final lesionProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) => ref.read(apiProvider).lesion(id));

bool _esEquipo(WidgetRef ref) => ref.read(sessionProvider)?.role == Role.equipo;
String _ubicacion(Map l) => [tr(zonasCorporales['${l['zona_corporal']}'] ?? '${l['zona_corporal'] ?? ''}'),
  if (l['lado'] != null && l['lado'] != 'centro') tr(ladosCuerpo['${l['lado']}'] ?? '${l['lado']}').toLowerCase()].join(', ');

/// Lista de heridas en seguimiento de un paciente ([pacienteId] null = el paciente activo de la sesión).
class HeridasScreen extends ConsumerWidget { final String? pacienteId;
  const HeridasScreen({super.key, this.pacienteId});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    ref.watch(sessionProvider.select((s) => s?.patientId));
    final id = pacienteId ?? pid(ref);
    return page(c, tr('Heridas en seguimiento'), AsyncView(ref.watch(lesionesProvider(id)), (d) => RefreshIndicator(
      onRefresh: () => ref.refresh(lesionesProvider(id).future),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), children: [
        for (final l in d as List) Padding(padding: const EdgeInsets.only(bottom: 12), child: Semantics(button: true, child: InkWell(
          borderRadius: BorderRadius.circular(16), onTap: () => c.push('/herida/${l['id']}'),
          child: InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(tiposLesion['${l['tipo']}'] ?? '${l['tipo']}'), style: Theme.of(c).textTheme.titleMedium),
            Text(_ubicacion(l)),
            const SizedBox(height: 6),
            Text(l['ultima_foto'] == null ? tr('Sin fotos todavía') : tr('Última foto: {f}', {'f': l['ultima_foto']['fecha'] ?? ''}),
              style: Theme.of(c).textTheme.bodySmall?.copyWith(color: C.text2))])))))]),
    ), onRetry: () => ref.invalidate(lesionesProvider(id)), emptyTitle: tr('Sin heridas en seguimiento'),
      emptyMessage: tr('Registra una herida para darle seguimiento con fotos.')),
      fab: FloatingActionButton.extended(icon: const Icon(Icons.add), label: Text(tr('Registrar herida')),
        onPressed: () => c.push('/heridas/nueva', extra: id)));
  }
}

/// Registrar una herida (una sola vez): tipo, zona, lado y descripción opcional.
class NuevaHeridaScreen extends ConsumerStatefulWidget { final String pacienteId;
  const NuevaHeridaScreen({super.key, required this.pacienteId});
  @override ConsumerState<NuevaHeridaScreen> createState() => _NuevaHeridaState(); }
class _NuevaHeridaState extends ConsumerState<NuevaHeridaScreen> {
  String? tipo, zona, lado = 'centro', err; bool busy = false; final _desc = TextEditingController();
  @override
  void dispose() { _desc.dispose(); super.dispose(); }
  Future<void> _guardar() async {
    if (tipo == null || zona == null) { setState(() => err = tr('Elige el tipo de herida y la zona del cuerpo.')); return; }
    setState(() { busy = true; err = null; });
    try {
      final l = await ref.read(apiProvider).crearLesion(widget.pacienteId, {'tipo': tipo, 'zona_corporal': zona, 'lado': lado,
        if (_desc.text.trim().isNotEmpty) 'descripcion': _desc.text.trim()});
      ref.invalidate(lesionesProvider(widget.pacienteId));
      if (mounted) context.pushReplacement('/herida/${l['id']}');
    } catch (e) {
      if (mounted) setState(() { busy = false; err = isNetworkError(e) ? tr('Sin conexión. Intenta más tarde.') : mensajeError(e) ?? tr('No se pudo guardar. Intenta de nuevo.'); });
    }
  }
  @override
  Widget build(BuildContext c) => page(c, tr('Registrar herida'), Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
      SectionLabel(tr('Tipo de herida')),
      ChoiceWrap(options: tiposLesion, isSel: (k) => tipo == k, onTap: (k) => setState(() => tipo = k)),
      SectionLabel(tr('Zona del cuerpo')),
      DropdownButtonFormField<String>(initialValue: zona, isExpanded: true, menuMaxHeight: 400,
        decoration: InputDecoration(labelText: tr('Zona del cuerpo')),
        items: [for (final e in zonasCorporales.entries) DropdownMenuItem(value: e.key, child: Text(tr(e.value)))],
        onChanged: (v) => setState(() => zona = v)),
      SectionLabel(tr('Lado')),
      ChoiceWrap(options: ladosCuerpo, isSel: (k) => lado == k, onTap: (k) => setState(() => lado = k)),
      const SizedBox(height: 16),
      AppField(_desc, tr('Descripción (opcional)'))])),
    if (err != null) Semantics(liveRegion: true, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(err!, style: const TextStyle(color: C.error, fontWeight: FontWeight.w600)))),
    Padding(padding: const EdgeInsets.all(16), child: BigButton(tr('Guardar'), icon: Icons.check, onTap: busy ? null : _guardar))]), bell: false);
}

/// Detalle de una herida: fotos, tamaño y (para el equipo) descripción de la IA, escala y evolución.
class HeridaDetalleScreen extends ConsumerWidget { final String id;
  const HeridaDetalleScreen({super.key, required this.id});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final equipo = _esEquipo(ref); final t = Theme.of(c).textTheme;
    return page(c, tr('Herida'), AsyncView(ref.watch(lesionProvider(id)), (d) {
      final l = d as Map; final fotos = (l['fotos'] as List? ?? const []);
      final evol = l['evolucion'];
      return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), children: [
        InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(tiposLesion['${l['tipo']}'] ?? '${l['tipo']}'), style: t.headlineSmall), Text(_ubicacion(l)),
          if ('${l['descripcion'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${l['descripcion']}'))])),
        const SizedBox(height: 12),
        InfoCard(child: Row(children: [const Icon(Icons.info_outline, color: C.info), const SizedBox(width: 12),
          Expanded(child: Text(tr('La IA describe y compara las fotos; no diagnostica. Todo queda para revisión del equipo de salud.')))])),
        if (equipo && evol is Map && evol['resumen'] != null) Padding(padding: const EdgeInsets.only(top: 12), child: InfoCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tr('Evolución'), style: t.labelLarge), Text('${evol['resumen']}')]))),
        const SizedBox(height: 16),
        Text(tr('Fotos'), style: t.headlineSmall), const SizedBox(height: 8),
        if (fotos.isEmpty) Text(tr('Sin fotos todavía')),
        for (final f in fotos) Padding(padding: const EdgeInsets.only(bottom: 12), child: InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${f['fecha'] ?? ''}', style: t.labelLarge),
          if (equipo && tamanoLesion(f) != null) dato(c, tr('Tamaño'), tamanoLesion(f)),
          dato(c, tr('Estado'), tr(f['estado'] == 'para_revision' ? 'Para revisión del equipo' : '${f['estado'] ?? '—'}')),
          if (equipo && f['descripcion_ia'] != null) dato(c, tr('Descripción de la IA'), f['descripcion_ia']),
          if (equipo && f['escala'] is Map) _Escala(fotoId: '${f['id']}', escala: f['escala'] as Map, lesionId: id)])))]);
    }, onRetry: () => ref.invalidate(lesionProvider(id))),
      fab: FloatingActionButton.extended(icon: const Icon(Icons.add_a_photo_outlined), label: Text(tr('Foto de seguimiento')),
        onPressed: () => c.push('/herida/$id/foto')));
  }
}

/// Escala propuesta (PUSH o REEDA) y confirmación del equipo.
/// SUPUESTO: PATCH /fotos-lesion/:id/escala recibe {nombre, puntaje, confirmada: true}.
class _Escala extends ConsumerWidget { final String fotoId, lesionId; final Map escala;
  const _Escala({required this.fotoId, required this.escala, required this.lesionId});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final ok = escala['confirmada'] == true;
    return Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
      Expanded(child: Text(tr('Escala {n}: {p}', {'n': escala['nombre'] ?? '', 'p': escala['puntaje'] ?? '—'}) + (ok ? ' · ${tr('confirmada')}' : ''))),
      if (!ok) TextButton(child: Text(tr('Confirmar')), onPressed: () async {
        try {
          await ref.read(apiProvider).confirmarEscalaLesion(fotoId, {'nombre': escala['nombre'], 'puntaje': escala['puntaje'], 'confirmada': true});
          ref.invalidate(lesionProvider(lesionId));
          if (c.mounted) aviso(c, tr('Escala confirmada.'));
        } catch (e) { if (c.mounted) aviso(c, mensajeError(e) ?? tr('No se pudo guardar. Intenta de nuevo.'), ok: false); }
      })]));
  }
}

/// Foto de seguimiento: consejos, referencia, foto y dos toques (moneda y herida) en píxeles de la foto ORIGINAL.
class FotoHeridaScreen extends ConsumerStatefulWidget { final String lesionId;
  const FotoHeridaScreen({super.key, required this.lesionId});
  @override ConsumerState<FotoHeridaScreen> createState() => _FotoHeridaState(); }
class _FotoHeridaState extends ConsumerState<FotoHeridaScreen> {
  String referencia = 'moneda_10_pesos'; Uint8List? bytes; Size? tamano; Offset? toqueRef, toqueLesion;
  bool busy = false; String? err; Map<String, dynamic>? resultado;

  @override
  void initState() {
    super.initState();
    // Si Android cerró SENDA con la cámara abierta, la foto que se tomó se recupera aquí.
    fotoPerdida().then((f) { if (f != null) _usar(f); });
  }

  Future<void> _tomar(ImageSource s) async {
    final f = await elegirFoto(context, s, maxWidth: 2000, imageQuality: 85); // JPEG; sin permiso: explica y lleva a Ajustes
    if (f != null) await _usar(f);
  }
  Future<void> _usar(XFile f) async {
    final b = await f.readAsBytes();
    final img = await decodeImageFromList(b); // tamaño real de la foto que se va a subir
    if (!mounted) return;
    setState(() { bytes = b; tamano = Size(img.width.toDouble(), img.height.toDouble()); toqueRef = null; toqueLesion = null; err = null; });
  }

  bool get _necesitaToques => referencia != 'ninguna';
  String get _instruccion => !_necesitaToques ? tr('Revisa la foto y envíala.')
      : toqueRef == null ? tr(referencia == 'tarjeta' ? 'Toca la tarjeta en la foto.' : 'Toca la moneda en la foto.')
      : toqueLesion == null ? tr('Ahora toca la herida.') : tr('Listo. Puedes enviar la foto o tocar de nuevo para corregir.');

  void _toque(Offset enImagen) => setState(() {
    if (toqueRef == null || (toqueRef != null && toqueLesion != null)) { toqueRef = enImagen; toqueLesion = null; }
    else { toqueLesion = enImagen; }
  });

  Future<void> _enviar() async {
    setState(() { busy = true; err = null; });
    try {
      List<num>? px(Offset? o) => o == null ? null : [o.dx.round(), o.dy.round()];
      final r = await ref.read(apiProvider).subirFotoLesion(widget.lesionId, bytes: bytes!, referencia: referencia,
          toqueReferencia: _necesitaToques ? px(toqueRef) : null, toqueLesion: _necesitaToques ? px(toqueLesion) : null);
      ref.invalidate(lesionProvider(widget.lesionId));
      if (mounted) setState(() { resultado = r; busy = false; });
    } catch (e) {
      if (mounted) setState(() { busy = false; err = isNetworkError(e) ? tr('Sin conexión. La foto no se envió.') : mensajeError(e) ?? tr('No se pudo enviar la foto.'); });
    }
  }

  @override
  Widget build(BuildContext c) {
    final t = Theme.of(c).textTheme; final equipo = _esEquipo(ref);
    if (resultado != null) {
      final r = resultado!;
      return page(c, tr('Foto enviada'), ListView(padding: const EdgeInsets.all(16), children: [
        if (r['message_key'] != null) InfoCard(child: MsgText('${r['message_key']}')),
        const SizedBox(height: 12),
        if (equipo && tamanoLesion(r) != null) InfoCard(child: dato(c, tr('Tamaño medido'), tamanoLesion(r))),
        if (equipo && r['comparacion'] is Map && (r['comparacion'] as Map)['resumen'] != null) Padding(padding: const EdgeInsets.only(top: 12),
          child: InfoCard(child: dato(c, tr('Comparación con la foto anterior'), (r['comparacion'] as Map)['resumen']))),
        const SizedBox(height: 16),
        BigButton(tr('Listo'), onTap: () => c.pop()),
        const SizedBox(height: 12),
        BigButton(tr('Tomar otra foto'), secondary: true, onTap: () => setState(() { resultado = null; bytes = null; }))]), bell: false);
    }
    return page(c, tr('Foto de seguimiento'), Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
        if (bytes == null) ...[
          InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Para una buena foto'), style: t.labelLarge),
            Text('• ${tr('De frente y con buena luz.')}'),
            Text('• ${tr('La moneda en el mismo plano que la herida.')}'),
            Text('• ${tr('Toda la herida dentro del cuadro.')}')])),
          SectionLabel(tr('Referencia de tamaño')),
          ChoiceWrap(options: referenciasFoto, isSel: (k) => referencia == k, onTap: (k) => setState(() => referencia = k)),
          const SizedBox(height: 16),
          BigButton(tr('Tomar foto'), icon: Icons.photo_camera, onTap: () => _tomar(ImageSource.camera)),
          const SizedBox(height: 12),
          BigButton(tr('Elegir de la galería'), icon: Icons.photo_library_outlined, secondary: true, onTap: () => _tomar(ImageSource.gallery)),
        ] else ...[
          Semantics(liveRegion: true, child: Text(_instruccion, style: t.titleMedium)),
          const SizedBox(height: 12),
          _FotoConToques(bytes: bytes!, tamano: tamano!, toques: [if (toqueRef != null) toqueRef!, if (toqueLesion != null) toqueLesion!],
            onToque: _necesitaToques ? _toque : null),
          TextButton.icon(onPressed: () => setState(() { bytes = null; }), icon: const Icon(Icons.refresh), label: Text(tr('Tomar otra foto'))),
        ]])),
      if (err != null) Semantics(liveRegion: true, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(err!, style: const TextStyle(color: C.error, fontWeight: FontWeight.w600)))),
      if (bytes != null) Padding(padding: const EdgeInsets.all(16), child: BigButton(busy ? tr('Enviando…') : tr('Enviar foto'), icon: Icons.send,
        onTap: busy || (_necesitaToques && toqueLesion == null) ? null : _enviar))]), bell: false);
  }
}

/// Muestra la foto completa (sin recortar) y convierte cada toque de pantalla a píxeles de la imagen original.
class _FotoConToques extends StatelessWidget {
  final Uint8List bytes; final Size tamano; final List<Offset> toques; final ValueChanged<Offset>? onToque;
  const _FotoConToques({required this.bytes, required this.tamano, required this.toques, this.onToque});
  @override
  Widget build(BuildContext c) => LayoutBuilder(builder: (_, box) {
    final ancho = box.maxWidth; final alto = ancho * tamano.height / tamano.width; // misma proporción: sin bordes
    final escala = tamano.width / ancho;
    return GestureDetector(
      onTapDown: onToque == null ? null : (d) => onToque!(Offset(
        (d.localPosition.dx * escala).clamp(0, tamano.width - 1), (d.localPosition.dy * escala).clamp(0, tamano.height - 1))),
      child: SizedBox(width: ancho, height: alto, child: Stack(children: [
        Positioned.fill(child: Image.memory(bytes, fit: BoxFit.fill, semanticLabel: tr('Foto de la herida'))),
        for (var i = 0; i < toques.length; i++) Positioned(left: toques[i].dx / escala - 16, top: toques[i].dy / escala - 16,
          child: IgnorePointer(child: Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle,
            color: (i == 0 ? C.info : C.error).withValues(alpha: .35), border: Border.all(color: i == 0 ? C.info : C.error, width: 3)),
            child: Center(child: Text(i == 0 ? 'R' : 'H', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))))))])));
  });
}
