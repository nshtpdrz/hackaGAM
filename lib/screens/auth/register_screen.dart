import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/api_modelos.dart';
import '../../core/sync.dart';
import '../../core/validacion.dart';
import '../../core/state.dart';
import '../../core/theme.dart';
import '../../widgets/components.dart';
import '../../widgets/lector_qr.dart';
import '../compartidas/perfil_form.dart';
import '../../core/tr.dart';
import '../../core/escala_texto.dart';

// 1B. Registro de usuario y configuración de perfil
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterState();
}

class _RegisterState extends ConsumerState<RegisterScreen> {
  Role _role = Role.paciente;
  final _p = TextEditingController(), _p2 = TextEditingController(), _cedula = TextEditingController(), _clinica = TextEditingController();

  // Cuidador: resultado de escanear el QR del paciente ({codigo, paciente, cuidador_asignado}).
  Map<String, dynamic>? _vinculo;

  // Mismos datos que "Editar perfil" (nombre, correo, teléfono y, para usuario/paciente,
  // nacimiento, sexo, sangre, alergias, programas y etapa de embarazo).
  final _datos = DatosPerfil()..programas.add('cronico');

  @override
  void dispose() { for (final x in [_p, _p2, _cedula, _clinica]) { x.dispose(); } _datos.dispose(); super.dispose(); }

  String? _err;
  bool _busy = false;

  @override
  Widget build(BuildContext c) {
    final t = ref.watch(trProvider);
    final p = ref.watch(prefsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Crear Cuenta')),
        backgroundColor: C.bg,
        actions: [
          DropdownButton<String>(
            value: p.lang,
            underline: const SizedBox(),
            items: [
              for (final e in {'es': tr('Español'), 'en': tr('English'), 'ote': tr('Hñähñu')}.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value))
            ],
            onChanged: (v) => ref.read(prefsProvider.notifier).state = p.copy(lang: v),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(tr('Registro en SENDA'), style: Theme.of(c).textTheme.headlineMedium?.copyWith(color: C.primary)),
            const SizedBox(height: 8),
            Text(tr('Selecciona tu tipo de usuario para configurar tu cuenta.')),
            const SizedBox(height: 24),

            // Paso 1: Selección de Rol
            Text(tr('Tipo de usuario'), style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 8),
            // Con letra grande los tres botones no caben en una fila: se muestran como opciones que bajan de renglón.
            if (escalaDe(c) >= 1.4)
              ChoiceWrap(options: const {'paciente': 'Usuario', 'cuidador': 'Cuidador', 'equipo': 'Médico'},
                isSel: (k) => _role.name == k, onTap: (k) => setState(() => _role = Role.values.byName(k)))
            else
            SegmentedButton<Role>(
              segments: [
                ButtonSegment(value: Role.paciente, label: Text(tr('Usuario'))),
                ButtonSegment(value: Role.cuidador, label: Text(tr('Cuidador'))),
                ButtonSegment(value: Role.equipo, label: Text(tr('Médico'))),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 24),

            // Paso 2: Formulario General (compartido con Editar perfil)
            DatosPerfilForm(
              key: ValueKey(_role),
              datos: _datos,
              paciente: _role == Role.paciente,
              despuesDeCorreo: [
                CampoContrasena(_p, t('login.pass').text, nueva: true, ayuda: tr('Mínimo 8 caracteres, con letras y números.')),
                CampoContrasena(_p2, tr('Repite la contraseña'), nueva: true)],
            ),

            // Campos adaptativos según el Rol seleccionado
            if (_role == Role.cuidador) ...[
              const SizedBox(height: 8),
              _pacienteACargo(c),
            ] else if (_role == Role.equipo) ...[
              AppField(_cedula, tr('Cédula profesional'), kt: TextInputType.number, maxLength: 8,
                formatos: [FilteringTextInputFormatter.digitsOnly], ayuda: tr('7 u 8 dígitos, como aparece en el Registro Nacional de Profesionistas.')),
              AppField(_clinica, tr('Clínica o Institución médica'), maxLength: 120),
              const SizedBox(height: 8),
              Text(tr('Validaremos tu cédula. Mientras tanto tu perfil mostrará "Cédula en revisión".')),
            ],

            // Paso 3: Pregunta Universal de Accesibilidad
            const Divider(height: 32),
            SwitchListTile(
              title: Text(tr('¿Requieres apoyo de accesibilidad?')),
              subtitle: Text(tr('Activa letra grande, alto contraste y lecturas con audio.')),
              // Refleja las preferencias actuales y las aplica al momento (encender y apagar).
              value: necesitaAccesibilidad(p),
              onChanged: (v) => ref.read(prefsProvider.notifier).state = prefsAccesibilidad(p, v),
            ),

            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_err!, style: const TextStyle(color: C.error), semanticsLabel: tr('Error: {e}', {'e': _err})),
              ),

            const SizedBox(height: 24),
            BigButton(
  tr('Completar Registro'),
  onTap: _busy
      ? null
      : () async {
          // 1. Validación de campos obligatorios y de la contraseña
          final e = _datos.validar(paciente: _role == Role.paciente)
              ?? validarContrasenaNueva(_p.text)
              ?? (_p.text != _p2.text ? tr('Las contraseñas no coinciden.') : null)
              ?? _validarRol();
          if (e != null) {
            setState(() => _err = e);
            return;
          }

          setState(() { _busy = true; _err = null; });

          try {
            // 2. POST /auth/registro. La accesibilidad ya quedó aplicada en prefsProvider al mover el interruptor.
            await ref.read(apiProvider).registro(_cuerpoRegistro());
            if (!mounted) return;
            // 3. Solo se anuncia éxito si el servidor creó la cuenta.
            ScaffoldMessenger.of(c).showSnackBar(SnackBar(
              content: Text(_role == Role.equipo ? tr('Cuenta creada. Tu cédula quedará en revisión. Inicia sesión.')
                  : tr('¡Registro exitoso! Por favor inicia sesión.')),
              backgroundColor: C.primary));
            Navigator.of(c).pop(); // Regresa a LoginScreen
          } catch (e) {
            final x = errorApi(e);
            if (mounted) setState(() => _err = isNetworkError(e) ? tr('Sin conexión. El registro necesita internet.')
                // La guía de la API no incluye registro abierto: las cuentas las crea la clínica.
                : x?.estado == 404 || x?.estado == 405 ? tr('El registro en línea aún no está disponible. Pide tu cuenta a tu clínica.')
                : x?.estado == 409 ? tr('Ya existe una cuenta con ese correo. Inicia sesión o recupera tu contraseña.')
                : mensajeError(e) ?? tr('Error al registrar la cuenta'));
          } finally {
            if (mounted) setState(() => _busy = false);
          }
        },

            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(tr('¿Ya tienes cuenta? Inicia sesión')),
            ),
          ],
        ),
      ),
    );
  }

  /// Cuerpo de POST /auth/registro (no está en la guía de la API; ver docs/CONEXION_BACKEND.md).
  Map<String, dynamic> _cuerpoRegistro() => {
    ..._datos.contacto(), 'contrasena': _p.text,
    'rol': switch (_role) { Role.paciente => 'paciente', Role.cuidador => 'cuidador', Role.equipo => 'medico' },
    if (_role == Role.paciente) ..._datos.clinicos(),
    if (_role == Role.cuidador) 'codigo_qr': _vinculo?['codigo'],
    if (_role == Role.equipo) ...{'cedula_profesional': _cedula.text.trim(), 'clinica': _clinica.text.trim()}};

  /// Médico: cédula (7 u 8 dígitos) y clínica. Cuidador: QR de un paciente que lo tenga asignado.
  String? _validarRol() {
    if (_role == Role.equipo) {
      final e = validarCedula(_cedula.text); if (e != null) return e;
      if (_clinica.text.trim().length < 3) return tr('Escribe tu clínica o institución médica.');
    }
    if (_role == Role.cuidador && _vinculo?['cuidador_asignado'] == null) {
      return tr('Escanea el QR de un paciente que te tenga asignado como cuidador.');
    }
    return null;
  }

  Future<void> _escanear() async {
    final api = ref.read(apiProvider);
    final r = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(builder: (ctx) => Scaffold(
      appBar: AppBar(title: Text(tr('QR del paciente'))),
      body: LectorQr(instruccion: tr('Escanea el código QR que aparece en la app del paciente.'), onCodigo: (codigo) async {
        final d = Map<String, dynamic>.from(await api.qrRegistro(codigo) as Map);
        if (ctx.mounted) Navigator.of(ctx).pop({...d, 'codigo': codigo});
      }))));
    if (r == null || !mounted) return;
    setState(() { _vinculo = r; _err = null; });
    // Si el paciente tiene cuidador asignado, se propone su nombre.
    final asignado = r['cuidador_asignado'] as Map?;
    if (asignado != null && _datos.nombre.text.trim().isEmpty) _datos.nombre.text = '${asignado['nombre'] ?? ''}';
  }

  Widget _pacienteACargo(BuildContext c) {
    final t = Theme.of(c).textTheme; final v = _vinculo; final asignado = v?['cuidador_asignado'] as Map?;
    if (v == null) {
      return InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('Paciente a tu cargo'), style: t.titleMedium), const SizedBox(height: 8),
        Text(tr('Escanea el QR del paciente. Solo puedes registrarte si el equipo de salud ya te asignó como su cuidador.')),
        const SizedBox(height: 12),
        BigButton(tr('Escanear QR del paciente'), icon: Icons.qr_code_scanner, onTap: _escanear)]));
    }
    final ok = asignado != null; final col = ok ? C.success : C.warning;
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: col.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: col, width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(ok ? Icons.check_circle : Icons.warning_amber_rounded, color: col), const SizedBox(width: 8),
          Expanded(child: Text(tr('Paciente: {p}', {'p': v['paciente'] ?? '—'}), style: t.titleMedium))]),
        const SizedBox(height: 8),
        Text(ok ? tr('Cuidador asignado: {nombre}. Te registrarás como su cuidador.', {'nombre': asignado['nombre']})
            : tr('Este paciente aún no tiene un cuidador asignado. Pide al equipo de salud que te registre como su cuidador para continuar.')),
        TextButton.icon(onPressed: _escanear, icon: const Icon(Icons.qr_code_scanner), label: Text(tr('Escanear otro QR')))]));
  }
}

/// El interruptor de accesibilidad está encendido si ya hay alguna ayuda activa.
bool necesitaAccesibilidad(Prefs p) => p.highContrast || p.audio || p.textScale > 1;

/// Encendido: alto contraste, letra 1.25x, audio, pictogramas y botones grandes. Apagado: vuelve a lo normal.
Prefs prefsAccesibilidad(Prefs p, bool on) => p.copy(
    highContrast: on, textScale: on ? 1.25 : 1.0, audio: on, pictograms: on, bigButtons: on);
