import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/alarma_tomas.dart';
import '../core/biometria.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../core/tr.dart';
import 'marca.dart';

/// Con "Entrar con huella" activo, si SENDA estuvo en segundo plano más de [despues] se vuelve a pedir la
/// huella o el rostro antes de mostrar datos de salud. No bloquea una alarma de toma que esté sonando.
class BloqueoAlVolver extends ConsumerStatefulWidget {
  final Widget child; final Duration despues;
  const BloqueoAlVolver({super.key, required this.child, this.despues = const Duration(minutes: 5)});
  @override ConsumerState<BloqueoAlVolver> createState() => _BloqueoState();
}

class _BloqueoState extends ConsumerState<BloqueoAlVolver> with WidgetsBindingObserver {
  DateTime? _salio; bool _bloqueado = false, _pidiendo = false; String? _msg;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); alarmaEnCurso.addListener(_alarma); }
  @override
  void dispose() { alarmaEnCurso.removeListener(_alarma); WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  /// La alarma de una toma se atiende sin desbloquear (solo permite marcar la toma).
  void _alarma() { if (alarmaEnCurso.value && _bloqueado) setState(() => _bloqueado = false); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) { _salio ??= DateTime.now(); return; }
    if (s != AppLifecycleState.resumed) return;
    final salio = _salio; _salio = null;
    if (salio != null && DateTime.now().difference(salio) >= widget.despues) _revisar();
  }

  Future<void> _revisar() async {
    if (_bloqueado || ref.read(sessionProvider) == null || alarmaEnCurso.value || !await biometriaActiva()) return;
    if (!mounted) return;
    setState(() { _bloqueado = true; _msg = null; });
    _pedir();
  }

  Future<void> _pedir() async {
    if (_pidiendo) return;
    _pidiendo = true;
    final r = await pedirIdentidad();
    _pidiendo = false;
    if (!mounted) return;
    setState(() { if (r == ResultadoBio.ok) { _bloqueado = false; } else { _msg = mensajeBio(r); } });
  }

  /// Sin huella: se cierra la sesión sin borrar datos ni alarmas (como si hubiera expirado) y se entra con contraseña.
  Future<void> _conContrasena() async {
    await ref.read(sessionProvider.notifier).logout(expirada: true);
    if (mounted) setState(() => _bloqueado = false);
  }

  @override
  Widget build(BuildContext c) {
    ref.listen(sessionProvider, (_, s) { if (s == null && _bloqueado) setState(() => _bloqueado = false); });
    return Stack(children: [
      widget.child,
      if (_bloqueado) Positioned.fill(child: Material(color: C.marca, child: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const EmblemaSenda(tam: 120), const SizedBox(height: 24),
          Semantics(liveRegion: true, child: Text(tr('SENDA está bloqueada'), textAlign: TextAlign.center,
            style: Theme.of(c).textTheme.headlineSmall?.copyWith(color: Colors.white))),
          if (_msg != null) Padding(padding: const EdgeInsets.only(top: 12),
            child: Text(_msg!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white))),
          const SizedBox(height: 24),
          FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: C.marca,
              minimumSize: const Size(220, 56)),
            onPressed: _pedir, icon: const Icon(Icons.fingerprint), label: Text(tr('Desbloquear'))),
          const SizedBox(height: 12),
          TextButton(onPressed: _conContrasena, style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: Text(tr('Entrar con contraseña')))])))))),
    ]);
  }
}
