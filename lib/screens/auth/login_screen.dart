import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/biometria.dart';
import '../../core/mock_api.dart';
import '../../core/state.dart';
import '../../core/theme.dart';
import '../../widgets/components.dart';
import 'register_screen.dart';
import '../../core/tr.dart';
import '../../core/api_modelos.dart';
import '../../core/sync.dart';

// 1. Login (biometría: local_auth desbloqueará el token guardado; pendiente)
class LoginScreen extends ConsumerStatefulWidget { const LoginScreen({super.key});
  @override ConsumerState<LoginScreen> createState() => _LoginState(); }
class _LoginState extends ConsumerState<LoginScreen> {
  final _e = TextEditingController(), _p = TextEditingController(); String? _err; bool _busy = false;
  @override
  Widget build(BuildContext c) {
    final t = ref.watch(trProvider); final p = ref.watch(prefsProvider);
    return Scaffold(body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      Align(alignment: Alignment.centerRight, child: DropdownButton<String>(value: p.lang, underline: const SizedBox(),
        items: [for (final e in {'es': tr('Español'), 'en': tr('English'), 'ote': tr('Hñähñu')}.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) => ref.read(prefsProvider.notifier).state = p.copy(lang: v))),
      const SizedBox(height: 16),
      Text('MEDMAP', style: Theme.of(c).textTheme.headlineLarge?.copyWith(color: C.primary)),
      const MsgText('app.tagline'), const SizedBox(height: 32),
      TextField(controller: _e, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: t('login.email').text)),
      const SizedBox(height: 16),
      TextField(controller: _p, obscureText: true, decoration: InputDecoration(labelText: t('login.pass').text)),
      if (ref.watch(sessionExpiredProvider)) Semantics(liveRegion: true, child: Padding(padding: EdgeInsets.only(top: 12),
        child: Row(children: [Icon(Icons.lock_clock), SizedBox(width: 8), Expanded(child: Text(tr('Tu sesión expiró. Inicia sesión de nuevo.')))]))),
      if (_err != null) Padding(padding: const EdgeInsets.only(top: 12),
          child: Text(_err!, style: const TextStyle(color: C.error), semanticsLabel: tr('Error: {e}', {'e': _err}))),
      const SizedBox(height: 24),
      BigButton(t('login.go').text, onTap: _busy ? null : () async {
        setState(() { _busy = true; _err = null; });
        try { await ref.read(sessionProvider.notifier).login(_e.text.trim(), _p.text); }
        catch (e) { setState(() => _err = isNetworkError(e) ? tr('No hay conexión con el servidor. Revisa el cable o la red.')
            : mensajeError(e) ?? tr('Correo o contraseña incorrectos')); }
        if (mounted) setState(() => _busy = false); }),
      const SizedBox(height: 12), BigButton(t('login.bio').text, icon: Icons.fingerprint, secondary: true, onTap: () async {
        try {
          final ok = await readToken() != null && await biometriaActiva() && await autenticar();
          if (ok) { await ref.read(sessionProvider.notifier).restore(); return; }
        } catch (_) {}
        if (mounted) setState(() => _err = tr('Activa la biometría en tu perfil e inicia sesión con tu contraseña una vez.')); }),


      // 1. Navegación normal al presionar "Registrarse"
            TextButton(
              onPressed: () => Navigator.push(
                c, 
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              ), 
              child: Text(t('login.register').text),
            ),

            if (useMock) ...[
              const Divider(height: 32), 
              Text(tr('Modo demo: entrar sin login')), 
              const SizedBox(height: 8),
              
              for (final e in {Role.paciente: tr('Paciente'), Role.cuidador: tr('Cuidador'), Role.equipo: tr('Equipo de salud')}.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8), 
                  child: BigButton(
                    tr('Entrar como {rol}', {'rol': e.value}),
                    secondary: true, 
                    onTap: _busy ? null : () async {
                      setState(() { _busy = true; _err = null; });
                      try { await ref.read(sessionProvider.notifier).enterDemo(e.key); }
                      catch (x) { if (mounted) setState(() => _err = isNetworkError(x) ? tr('No hay conexión con el servidor. Revisa el cable o la red.')
                          : mensajeError(x) ?? tr('No se pudo entrar con la cuenta de demo.')); }
                      if (mounted) setState(() => _busy = false);
                    },
                  ),
                ),

              // 2. Botón de prueba destacado para probar la pantalla de Registro
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: BigButton(
                  tr('Probar Pantalla de Registro'),
                  secondary: true,
                  icon: Icons.how_to_reg,
                  onTap: () => Navigator.push(
                    c,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


