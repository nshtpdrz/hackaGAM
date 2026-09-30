import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Datos que la app guarda en el teléfono entre sesiones: cola sin conexión, respuestas del día a las
/// tomas, última copia de horarios y medicamentos, notificaciones leídas y preferencias.
/// Van cifrados (Keystore en Android, Keychain en iOS) porque son datos de salud.
///
/// Claves:
///   senda.cola, senda.rechazadas   cola sin conexión (cada operación lleva el usuario que la creó)
///   senda.prefs                    preferencias del teléfono (letra, contraste, idioma…)
///   senda.u.<usuario>.*            datos de una cuenta: se borran al cerrar sesión
class AlmacenLocal {
  AlmacenLocal([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;

  Future<Object?> leer(String clave) async {
    try {
      final v = await _s.read(key: clave);
      return v == null ? null : jsonDecode(v);
    } catch (_) { return null; } // sin almacén (pruebas, web sin crypto) o dato dañado: como si no existiera
  }

  Future<void> guardar(String clave, Object? valor) async {
    try {
      if (valor == null) { await _s.delete(key: clave); } else { await _s.write(key: clave, value: jsonEncode(valor)); }
    } catch (_) {}
  }

  /// Borra todo lo que empiece con [prefijo].
  Future<void> borrarPrefijo(String prefijo) async {
    try {
      for (final k in (await _s.readAll()).keys) { if (k.startsWith(prefijo)) await _s.delete(key: k); }
    } catch (_) {}
  }
}

/// Único almacén de la app. Las pruebas lo reemplazan con `FlutterSecureStorage.setMockInitialValues`.
final almacen = AlmacenLocal();

/// Clave de un dato que pertenece a una cuenta (se borra al cerrar sesión).
String claveDeUsuario(String usuario, String dato) => 'senda.u.$usuario.$dato';
