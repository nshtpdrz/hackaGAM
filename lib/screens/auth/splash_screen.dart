import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/biometria.dart';
import '../../core/state.dart';
import '../../core/theme.dart';
import '../../core/tr.dart';

// 0. Splash: restaura la sesión (con biometría si está activa) y decide a dónde ir.
class SplashScreen extends ConsumerStatefulWidget { const SplashScreen({super.key});
  @override ConsumerState<SplashScreen> createState() => _SplashState(); }
class _SplashState extends ConsumerState<SplashScreen> {
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _arrancar()); }

  Future<void> _arrancar() async {
    await Future.delayed(const Duration(milliseconds: 900));
    try {
      if (await readToken() != null) {
        if (await biometriaActiva() && !await autenticar()) { if (mounted) context.go('/login'); return; }
        await ref.read(sessionProvider.notifier).restore(); // si hay sesión, el router redirige al inicio del rol
      }
    } catch (_) {}
    if (mounted && ref.read(sessionProvider) == null) context.go('/login');
  }

  @override
  Widget build(BuildContext c) => Scaffold(backgroundColor: C.p100, body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Text('MEDMAP', style: Theme.of(c).textTheme.headlineLarge?.copyWith(color: C.primary)),
    const SizedBox(height: 8), Text(ref.watch(trProvider)('app.tagline').text, style: Theme.of(c).textTheme.bodyLarge),
    const SizedBox(height: 32), Semantics(label: tr('Cargando'), child: const CircularProgressIndicator())])));
}
