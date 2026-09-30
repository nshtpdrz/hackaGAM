import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/state.dart';
import '../../core/theme.dart';
import '../../core/biometria.dart';
import '../../widgets/avatar_perfil.dart';
import '../../widgets/components.dart';
import '../../widgets/dialogs.dart';
import '../shared.dart';
import '../../core/tr.dart';

const _rolTxt = {Role.paciente: 'Paciente', Role.cuidador: 'Cuidador', Role.equipo: 'Equipo de salud'};

// Perfil (todos los roles): datos, editar, preferencias, QR y cerrar sesión
class PerfilScreen extends ConsumerWidget { const PerfilScreen({super.key});
  Widget _dato(BuildContext c, String l, Object? v) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l, style: Theme.of(c).textTheme.bodySmall?.copyWith(color: C.text2)),
      Text(v == null || '$v'.isEmpty ? '—' : '$v', style: Theme.of(c).textTheme.bodyMedium)]));
  Widget _tile(IconData i, String t, VoidCallback f) => Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Card(child: ListTile(minVerticalPadding: 12, leading: Icon(i, color: C.primary), title: Text(t),
      trailing: const Icon(Icons.chevron_right), onTap: f)));

  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final s = ref.watch(sessionProvider)!;
    return page(c, tr('Perfil'), AsyncView(ref.watch(futureFor('perfil')), (d) {
      final p = d as Map; final nombre = '${p['nombre'] ?? ''}';
      final tieneFoto = ref.watch(fotoPerfilProvider) != null || '${p['foto_url'] ?? ''}'.isNotEmpty;
      void foto() => cambiarFotoPerfil(c, ref, tieneFoto: tieneFoto);
      final nac = DateTime.tryParse('${p['fecha_nacimiento'] ?? ''}');
      final progs = (p['programas'] as List?)?.map((k) => k == 'embarazo' && p['etapa_embarazo'] == 'puerperio'
          ? tr('Puerperio') : programasCuidado[k] ?? '$k').join(', ');
      return ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: AvatarPerfil(perfil: p, radio: 48, onEditar: foto)),
        const SizedBox(height: 12),
        Center(child: Text(nombre, style: Theme.of(c).textTheme.headlineSmall)),
        Center(child: Text(tr(_rolTxt[s.role]!))),
        if (s.role == Role.equipo) Padding(padding: const EdgeInsets.only(top: 8),
          child: Center(child: InsigniaMedico(verificado: p['cedula_verificada'] == true))),
        const SizedBox(height: 16),
        InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _dato(c, tr('Correo'), p['correo']), _dato(c, tr('Teléfono'), p['telefono']),
          if (s.role == Role.equipo) ...[
            _dato(c, tr('Cédula profesional'), p['cedula_profesional']), _dato(c, tr('Clínica o institución'), p['clinica'])],
          if (s.role == Role.paciente) ...[
            _dato(c, tr('Fecha de nacimiento'), nac == null ? null : fmtFecha(nac)),
            _dato(c, tr('Sexo'), p['sexo'] == 'F' ? tr('Mujer') : p['sexo'] == 'M' ? tr('Hombre') : null),
            _dato(c, tr('Tipo de sangre'), p['tipo_sangre']), _dato(c, tr('Alergias a medicamentos'), textoAlergias(p['alergias'])),
            _dato(c, tr('Programa de cuidado'), progs)]])),
        const SizedBox(height: 16),
        _tile(Icons.edit_outlined, tr('Editar perfil'), () => c.push('/perfil/editar', extra: p)),
        _tile(Icons.add_a_photo_outlined, tr('Cambiar foto de perfil'), foto),
        _tile(Icons.accessibility_new, tr('Preferencias y accesibilidad'), () => c.push('/preferencias')),
        if (s.role != Role.equipo) _tile(Icons.qr_code, tr('Mi código QR'), () => c.push('/qr')),
        if (s.role != Role.equipo) _tile(Icons.healing_outlined, tr('Seguimiento de heridas'), () => c.push('/heridas')),
        const _BioTile(),
        _tile(Icons.network_check, tr('Diagnóstico de conexión'), () => c.push('/diagnostico')),
        _tile(Icons.logout, tr('Cerrar sesión'), () async {
          if (await ConfirmationDialog.show(c, titulo: tr('¿Cerrar sesión?'), mensaje: tr('Tendrás que iniciar sesión otra vez.'))) {
            ref.read(sessionProvider.notifier).logout(); } })]);
    }, onRetry: () => ref.invalidate(futureFor('perfil'))));
  }
}

class _BioTile extends StatefulWidget { const _BioTile();
  @override State<_BioTile> createState() => _BioTileState(); }
class _BioTileState extends State<_BioTile> {
  bool disp = false, activa = false;
  @override
  void initState() { super.initState(); _cargar(); }
  Future<void> _cargar() async {
    final d = await biometriaDisponible(); final a = await biometriaActiva();
    if (mounted) setState(() { disp = d; activa = a; });
  }
  @override
  Widget build(BuildContext c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: SwitchListTile(
    secondary: const Icon(Icons.fingerprint, color: C.primary), title: Text(tr('Entrar con biometría')),
    subtitle: Text(disp ? tr('Pide tu huella o rostro al abrir la app.') : tr('No disponible en este dispositivo.')),
    value: activa && disp, onChanged: disp ? (v) async {
      if (v && !await autenticar()) return;
      await activarBiometria(v); if (mounted) setState(() => activa = v); } : null)));
}
