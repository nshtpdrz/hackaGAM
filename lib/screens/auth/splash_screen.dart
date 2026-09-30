import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/biometria.dart';
import '../../core/state.dart';
import '../../core/theme.dart';
import '../../core/tr.dart';
import '../../widgets/marca.dart';

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
  Widget build(BuildContext c) {
    final ancho = MediaQuery.sizeOf(c).width;
    return Scaffold(backgroundColor: C.marca, body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        EmblemaSenda(tam: (ancho * .45).clamp(120.0, 220.0)),
        const SizedBox(height: 28),
        LogoSenda(alto: (ancho * .11).clamp(36.0, 56.0), blanco: true),
        const SizedBox(height: 12),
        Text(ref.watch(trProvider)('app.tagline').text, textAlign: TextAlign.center,
          style: Theme.of(c).textTheme.bodyLarge?.copyWith(color: Colors.white)),
        const SizedBox(height: 32),
        Semantics(label: tr('Cargando'), child: const CircularProgressIndicator(color: Colors.white))])))));
  }
}
