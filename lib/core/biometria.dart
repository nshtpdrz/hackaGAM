import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

const _store = FlutterSecureStorage();
final _auth = LocalAuthentication();

Future<bool> biometriaDisponible() async {
  try { return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics; } catch (_) { return false; }
}
Future<bool> biometriaActiva() async => await _store.read(key: 'bio') == '1';
Future<void> activarBiometria(bool v) => v ? _store.write(key: 'bio', value: '1') : _store.delete(key: 'bio');
Future<bool> autenticar() async {
  try { return await _auth.authenticate(localizedReason: 'Confirma tu identidad para entrar'); } catch (_) { return false; }
}
