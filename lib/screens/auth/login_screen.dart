import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/biometria.dart';
import '../../core/mock_api.dart';
import '../../core/state.dart';
import '../../core/theme.dart';
import '../../widgets/components.dart';
import 'package:go_router/go_router.dart';
import '../../core/tr.dart';
import '../../core/api_modelos.dart';
import '../../core/sync.dart';
import '../../widgets/sync_status.dart';
import '../../widgets/marca.dart';
import '../../core/validacion.dart';

// 1. Login (biometría: local_auth desbloqueará el token guardado; pendiente)
class LoginScreen extends ConsumerStatefulWidget { const LoginScreen({super.key});
  @override ConsumerState<LoginScreen> createState() => _LoginState(); }
class _LoginState extends ConsumerState<LoginScreen> {
  final _e = TextEditingController(), _p = TextEditingController(); String? _err; bool _busy = false;
  /// "Entrar con huella" solo si hay una sesión guardada y la biometría está activa en este teléfono (SE4).
  bool _conHuella = false;
  @override
  void initState() {
    super.initState();
    () async {
      try {
        final ok = await readToken() != null && await biometriaActiva();
        if (mounted && ok) setState(() => _conHuella = true);
      } catch (_) {}
    }();
  }
  @override
  void dispose() { _e.dispose(); _p.dispose(); super.dispose(); }

  /// Resultado por caso (bloqueado, sin huella registrada, cancelado…), no un solo mensaje.
  Future<void> _entrarConHuella() async {
    if (_busy) return;
    setState(() { _busy = true; _err = null; });
    try {
      final r = await pedirIdentidad();
      if (r == ResultadoBio.ok) { await ref.read(sessionProvider.notifier).restore(); }
      else if (mounted) { setState(() => _err = mensajeBio(r)); }
    } catch (e) {
      if (mounted) setState(() => _err = isNetworkError(e) ? tr('No hay conexión con el servidor. Revisa el cable o la red.')
          : mensajeError(e) ?? tr('No se pudo entrar. Inicia sesión con tu contraseña.'));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _entrar() async {
    if (_busy) return;
    // Antes de ir al servidor: correo con formato válido y contraseña escrita (evita gastar intentos; hay límite por IP).
    final correo = _e.text.trim().toLowerCase();
    final e = validarCorreo(correo) ?? (_p.text.isEmpty ? tr('Escribe tu contraseña.') : null);
    if (e != null) { setState(() => _err = e); return; }
    setState(() { _busy = true; _err = null; });
    try { await ref.read(sessionProvider.notifier).login(correo, _p.text); }
    // En el login, un 401 es correo o contraseña incorrectos (salvo cuenta desactivada); otros errores no se disfrazan de eso.
    catch (e) { final x = errorApi(e); if (mounted) setState(() => _err = isNetworkError(e) ? tr('No hay conexión con el servidor. Revisa el cable o la red.')
        : x?.estado == 401 && x?.codigo != 'usuario_inactivo' ? tr('Correo o contraseña incorrectos')
        : mensajeError(e) ?? tr('No se pudo iniciar sesión. Intenta de nuevo.')); }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext c) {
    final t = ref.watch(trProvider); final p = ref.watch(prefsProvider);
    return Scaffold(body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      Align(alignment: Alignment.centerRight, child: DropdownButton<String>(value: p.lang, underline: const SizedBox(),
        items: [for (final e in {'es': tr('Español'), 'en': tr('English'), 'ote': tr('Hñähñu')}.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) => ref.read(prefsProvider.notifier).state = p.copy(lang: v))),
      const SizedBox(height: 16),
      Row(children: [const IconoSenda(tam: 64, decorativo: true), const SizedBox(width: 16),
        const Expanded(child: Align(alignment: Alignment.centerLeft, child: LogoSenda(alto: 44)))]),
      const SizedBox(height: 12),
      const MsgText('app.tagline'), const EstadoServidor(), const SizedBox(height: 32),
      AutofillGroup(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: _e, keyboardType: TextInputType.emailAddress, autocorrect: false, maxLength: 254,
          autofillHints: const [AutofillHints.email, AutofillHints.username], textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: t('login.email').text, counterText: '')),
        const SizedBox(height: 16),
        CampoContrasena(_p, t('login.pass').text, alEnviar: (_) => _entrar())])),
      if (ref.watch(sessionExpiredProvider)) Semantics(liveRegion: true, child: Padding(padding: EdgeInsets.only(top: 12),
        child: Row(children: [Icon(Icons.lock_clock), SizedBox(width: 8), Expanded(child: Text(tr('Tu sesión expiró. Inicia sesión de nuevo.')))]))),
      if (_err != null) Padding(padding: const EdgeInsets.only(top: 12),
          child: Text(_err!, style: const TextStyle(color: C.error), semanticsLabel: tr('Error: {e}', {'e': _err}))),
      const SizedBox(height: 24),
      BigButton(t('login.go').text, onTap: _busy ? null : _entrar),
      if (_conHuella) ...[const SizedBox(height: 12),
        BigButton(t('login.bio').text, icon: Icons.fingerprint, secondary: true, onTap: _busy ? null : _entrarConHuella)],


      // 1. Navegación normal al presionar "Registrarse"
            TextButton(onPressed: () => c.push('/registro'), child: Text(t('login.register').text)),

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
            ],
          ],
        ),
      ),
    );
  }
}


