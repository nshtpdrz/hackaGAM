import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/state.dart';
import '../../core/sync.dart';
import '../../core/theme.dart';
import '../../widgets/avatar_perfil.dart';
import '../../widgets/components.dart';
import '../shared.dart';
import 'perfil_form.dart';
import '../../core/tr.dart';

// Editar perfil: mismos campos que "Crear cuenta" (ver DatosPerfilForm).
class EditarPerfilScreen extends ConsumerStatefulWidget {
  final Map perfil; const EditarPerfilScreen({super.key, required this.perfil});
  @override ConsumerState<EditarPerfilScreen> createState() => _EditarPerfilState(); }

class _EditarPerfilState extends ConsumerState<EditarPerfilScreen> {
  late final datos = DatosPerfil(widget.perfil); String? err; bool busy = false;
  @override
  void dispose() { datos.dispose(); super.dispose(); }

  Future<void> _guardar(bool esPaciente) async {
    final e = datos.validar(paciente: esPaciente); if (e != null) { setState(() => err = e); return; }
    setState(() { err = null; busy = true; });
    try {
      final api = ref.read(apiProvider);
      if (esPaciente) { await api.actualizarPaciente(pid(ref), {...datos.contacto(), ...datos.clinicos()}); }
      else { await api.actualizarYo(datos.contacto()); }
      ref.invalidate(futureFor('perfil'));
      if (!mounted) return;
      aviso(context, tr('Perfil actualizado.')); context.pop();
    } catch (e) {
      if (mounted) setState(() { busy = false; err = isNetworkError(e) ? tr('Sin conexión. Intenta más tarde.') : tr('No se pudo guardar. Intenta de nuevo.'); });
    }
  }

  @override
  Widget build(BuildContext c) {
    final esPaciente = ref.watch(sessionProvider)?.role == Role.paciente;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Editar perfil')), backgroundColor: C.bg),
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: AvatarPerfil(perfil: widget.perfil, radio: 48, onEditar: () => cambiarFotoPerfil(c, ref,
            tieneFoto: ref.read(fotoPerfilProvider) != null || '${widget.perfil['foto_url'] ?? ''}'.isNotEmpty))),
          const SizedBox(height: 24),
          DatosPerfilForm(datos: datos, paciente: esPaciente)]))),
        if (err != null) Semantics(liveRegion: true, child: Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Text(err!, style: const TextStyle(color: C.error)))),
        BigButton(tr('Guardar cambios'), onTap: busy ? null : () => _guardar(esPaciente))]))));
  }
}
