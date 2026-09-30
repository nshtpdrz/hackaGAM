import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'almacen_local.dart';
import 'api.dart';
import 'api_modelos.dart';
import 'l10n.dart';
import 'mock_api.dart';
import 'push.dart';
import 'reminders.dart';

enum Role { paciente, cuidador, equipo }

class Session {
  /// [rolApi]: paciente | cuidador | enfermera | medico. [patientId]: paciente activo (el cuidador puede cambiarlo).
  final String token, userId; final Role role; final String? patientId, rolApi;
  final List<Map<String, dynamic>> pacientesACargo;
  const Session(this.token, this.userId, this.role, this.patientId, {this.rolApi, this.pacientesACargo = const []});
  bool get esMedico => rolApi == 'medico';
  Session conPaciente(String id) => Session(token, userId, role, id, rolApi: rolApi, pacientesACargo: pacientesACargo);
}

class Prefs {
  final String lang, variant; final bool audio, pictograms, highContrast, bigButtons; final double textScale;
  const Prefs({this.lang = 'es', this.variant = 'valle_del_mezquital', this.audio = false, this.pictograms = false,
      this.highContrast = false, this.bigButtons = false, this.textScale = 1.0});
  Prefs copy({String? lang, String? variant, bool? audio, bool? pictograms, bool? highContrast, bool? bigButtons, double? textScale}) =>
      Prefs(lang: lang ?? this.lang, variant: variant ?? this.variant, audio: audio ?? this.audio,
          pictograms: pictograms ?? this.pictograms, highContrast: highContrast ?? this.highContrast,
          bigButtons: bigButtons ?? this.bigButtons, textScale: textScale ?? this.textScale);
  /// Preferencias de la API {lengua (ISO 639-3), variante, prefiere_audio, letra, contraste}.
  /// Pictogramas y botones grandes no existen en la API: se conservan los del teléfono ([base]).
  factory Prefs.fromJson(Map j, [Prefs base = const Prefs()]) => base.copy(
      lang: j['lengua'] == null ? null : lenguaApp('${j['lengua']}'), variant: j['variante']?.toString(),
      audio: (j['prefiere_audio'] ?? j['audio']) as bool?, highContrast: j['contraste'] == null ? j['alto_contraste'] as bool? : j['contraste'] == 'alto',
      textScale: j['letra'] == null && j['tamano_letra'] == null ? null : escalaLetra(j['letra'] ?? j['tamano_letra'], base.textScale));
  Map<String, dynamic> toJson() => {'lengua': lenguaApi[lang] ?? lang, 'variante': variant, 'prefiere_audio': audio,
      'letra': letraApi(textScale), 'contraste': highContrast ? 'alto' : 'normal'};
  /// Copia completa para guardar en el teléfono (incluye lo que la API no tiene).
  Map<String, dynamic> toLocal() => {'lang': lang, 'variant': variant, 'audio': audio, 'pictograms': pictograms,
      'highContrast': highContrast, 'bigButtons': bigButtons, 'textScale': textScale};
  static Prefs fromLocal(Object? j) {
    if (j is! Map) return const Prefs();
    T? v<T>(String k) => j[k] is T ? j[k] as T : null;
    return const Prefs().copy(lang: v<String>('lang'), variant: v<String>('variant'), audio: v<bool>('audio'),
        pictograms: v<bool>('pictograms'), highContrast: v<bool>('highContrast'), bigButtons: v<bool>('bigButtons'),
        textScale: (j['textScale'] as num?)?.toDouble());
  }
}
/// Preferencias de este teléfono. main() las lee de [almacen] antes de arrancar y se guardan en cada cambio.
final prefsProvider = StateProvider<Prefs>((_) => const Prefs());
const clavePrefs = 'senda.prefs';
Future<Prefs> leerPrefsGuardadas() async => Prefs.fromLocal(await almacen.leer(clavePrefs));
Future<void> guardarPrefs(Prefs p) => almacen.guardar(clavePrefs, p.toLocal());
/// true cuando la API respondió 401: el login muestra "sesión expirada".
final sessionExpiredProvider = StateProvider<bool>((_) => false);

class SessionNotifier extends StateNotifier<Session?> {
  SessionNotifier(this.ref) : super(null) {
    // Sesión expirada: es la misma persona, así que se conservan sus alarmas y datos del teléfono.
    ref.read(apiProvider).onUnauthorized = () { ref.read(sessionExpiredProvider.notifier).state = true; logout(expirada: true); };
  }
  final Ref ref;
  Role _role(String r) => switch (r) { 'paciente' => Role.paciente, 'cuidador' => Role.cuidador, _ => Role.equipo };

  Future<void> login(String correo, String contrasena) async {
    final r = await ref.read(apiProvider).login(correo, contrasena);
    await saveToken(r['token']);
    await restore();
    registrarDispositivoPush(ref.read(apiProvider)); // push: no bloquea el inicio de sesión
  }
  /// GET /auth/yo: el JWT define permisos; aquí solo se decide la navegación y el paciente activo.
  Future<void> restore() async {
    final t = await readToken(); if (t == null) return;
    final y = await ref.read(apiProvider).yo();
    final aCargo = (y['pacientes_a_cargo'] as List).cast<Map<String, dynamic>>();
    final s = Session(t, '${y['id']}', _role('${y['rol']}'), y['paciente_id']?.toString(),
        rolApi: y['rol_api']?.toString(), pacientesACargo: aCargo);
    // Entra otra cuenta en este teléfono (la anterior expiró sin cerrar sesión): fuera sus alarmas.
    final anterior = await almacen.leer(_claveUltimo);
    if (anterior != null && anterior != s.userId) await cancelarAlarmasTomas();
    await almacen.guardar(_claveUltimo, s.userId);
    state = s;
    ref.read(sessionExpiredProvider.notifier).state = false;
    // Las preferencias de la API son las del paciente: solo se aplican en su propio teléfono.
    final p = y['preferencias'];
    if (p is Map && s.role == Role.paciente) ref.read(prefsProvider.notifier).state = Prefs.fromJson(p, ref.read(prefsProvider));
  }
  static const _claveUltimo = 'senda.ultimo_usuario';
  /// Cuidador con varios familiares: cambia el paciente que se ve en todas las pantallas.
  void elegirPaciente(String id) { final s = state; if (s != null) state = s.conPaciente(id); }
  /// Botones "Entrar como…": inician sesión con las cuentas de demo de la semilla del backend (o del mock).
  Future<void> enterDemo(Role role) => login(cuentasDemo[role.name]!, contrasenaDemo);
  /// Cerrar sesión: se borra el token, se cancelan las alarmas de tomas y se borran los datos de la cuenta
  /// guardados en el teléfono (la cola sin conexión se conserva y se envía si vuelve a entrar esa cuenta).
  /// Los datos en memoria (consultas, tomas del día, leídas) se reinician porque dependen de [Session.userId].
  /// Con [expirada] (401) solo se pide iniciar sesión otra vez.
  Future<void> logout({bool expirada = false}) async {
    final u = state?.userId;
    await saveToken(null);
    if (!expirada) {
      await cancelarAlarmasTomas();
      if (u != null) await almacen.borrarPrefijo(claveDeUsuario(u, ''));
      await almacen.guardar(_claveUltimo, null);
    }
    state = null;
  }
}
final sessionProvider = StateNotifierProvider<SessionNotifier, Session?>((r) => SessionNotifier(r));

/// Carga GET /mensajes (sin token) al cambiar de lengua o variante: texto + audio + pictograma por mensaje_clave.
final catalogLoadProvider = FutureProvider<void>((ref) async {
  final p = ref.watch(prefsProvider.select((p) => (p.lang, p.variant)));
  try {
    ref.read(catalogProvider).merge(p.$1, await ref.read(apiProvider).mensajes(p.$1, variante: p.$2));
    ref.read(catalogVersionProvider.notifier).state++;
  } catch (_) {}
});

/// Resolución por message_key con la lengua actual.
final trProvider = Provider<Msg Function(String)>((ref) {
  final p = ref.watch(prefsProvider); final c = ref.watch(catalogProvider);
  ref.watch(catalogVersionProvider);
  return (k) => c.get(p.lang, k);
});
