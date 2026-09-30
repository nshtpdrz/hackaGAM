import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/error_codes.dart' as codigo;
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'tr.dart';

// Entrar con huella, rostro o el bloqueo del teléfono (local_auth).
// El token de la sesión vive en el almacenamiento seguro (Keystore / Keychain); la biometría decide si se usa.
// Android: MainActivity es FlutterFragmentActivity y los temas son AppCompat (ver android/app/src/main).
// iOS: NSFaceIDUsageDescription en ios/Runner/Info.plist.

const _store = FlutterSecureStorage();
final _auth = LocalAuthentication();

/// Resultado de pedir la identidad. [cancelado] no muestra error: la persona decidió no seguir.
enum ResultadoBio { ok, cancelado, noDisponible, sinRegistrar, bloqueado, error }

/// Hay huella, rostro o bloqueo de pantalla que se pueda usar en este teléfono.
Future<bool> biometriaDisponible() async {
  if (kIsWeb) return false;
  try { return await _auth.isDeviceSupported(); } catch (_) { return false; }
}
Future<bool> biometriaActiva() async {
  try { return await _store.read(key: 'bio') == '1'; } catch (_) { return false; }
}
Future<void> activarBiometria(bool v) => v ? _store.write(key: 'bio', value: '1') : _store.delete(key: 'bio');

Future<bool> autenticar() async => await pedirIdentidad() == ResultadoBio.ok;

/// Pide huella o rostro; si el teléfono no tiene, acepta su PIN, patrón o contraseña (más fácil para
/// quien no tiene sensor o no lo usa). Sigue esperando si la app pasa a segundo plano (stickyAuth).
Future<ResultadoBio> pedirIdentidad() async {
  if (kIsWeb) return ResultadoBio.noDisponible;
  try {
    final ok = await _auth.authenticate(
      localizedReason: tr('Confirma que eres tú para entrar a SENDA'),
      authMessages: _mensajes(),
      options: const AuthenticationOptions(stickyAuth: true, useErrorDialogs: true));
    return ok ? ResultadoBio.ok : ResultadoBio.cancelado;
  } on PlatformException catch (e) {
    return switch (e.code) {
      codigo.notAvailable || codigo.passcodeNotSet || codigo.otherOperatingSystem => ResultadoBio.noDisponible,
      codigo.notEnrolled => ResultadoBio.sinRegistrar,
      codigo.lockedOut || codigo.permanentlyLockedOut => ResultadoBio.bloqueado,
      _ => ResultadoBio.error };
  } catch (_) {
    return ResultadoBio.error;
  }
}

/// Texto para la persona según el resultado (null si no hay que mostrar nada).
String? mensajeBio(ResultadoBio r) => switch (r) {
  ResultadoBio.ok || ResultadoBio.cancelado => null,
  ResultadoBio.noDisponible => tr('Este teléfono no tiene huella, rostro ni bloqueo de pantalla. Entra con tu contraseña.'),
  ResultadoBio.sinRegistrar => tr('No hay huella ni rostro registrados en este teléfono. Regístralos en Ajustes o entra con tu contraseña.'),
  ResultadoBio.bloqueado => tr('Hubo demasiados intentos. Espera unos minutos o entra con tu contraseña.'),
  ResultadoBio.error => tr('No se pudo confirmar tu identidad. Entra con tu contraseña.') };

// Textos de los diálogos del sistema en el idioma elegido en la app.
List<AuthMessages> _mensajes() => [
  AndroidAuthMessages(
    signInTitle: tr('Entrar a SENDA'),
    biometricHint: tr('Toca el sensor de huella o mira la cámara'),
    biometricNotRecognized: tr('No se reconoció. Intenta de nuevo.'),
    biometricSuccess: tr('Listo'),
    biometricRequiredTitle: tr('Se necesita tu huella o rostro'),
    deviceCredentialsRequiredTitle: tr('Se necesita el bloqueo de tu teléfono'),
    deviceCredentialsSetupDescription: tr('Configura un bloqueo de pantalla en los Ajustes del teléfono.'),
    goToSettingsButton: tr('Ir a Ajustes'),
    goToSettingsDescription: tr('No hay huella ni rostro registrados. Regístralos en Ajustes > Seguridad.'),
    cancelButton: tr('Cancelar')),
  IOSAuthMessages(
    lockOut: tr('Face ID o Touch ID está bloqueado. Bloquea y desbloquea el teléfono para activarlo.'),
    goToSettingsButton: tr('Ir a Ajustes'),
    goToSettingsDescription: tr('No hay Face ID ni Touch ID configurado. Actívalo en Ajustes.'),
    localizedFallbackTitle: tr('Usar el código del teléfono'),
    cancelButton: tr('Cancelar')),
];
