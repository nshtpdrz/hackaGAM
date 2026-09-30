import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api.dart';
import 'mock_api.dart';

/// Guía: después del login, POST /dispositivos {token_fcm, plataforma}. Es opcional para la app:
/// si Firebase no está configurado (falta google-services.json / GoogleService-Info.plist), no pasa nada.
Future<void> registrarDispositivoPush(Api api) async {
  if (kIsWeb || useMock) return;
  final plataforma = switch (defaultTargetPlatform) { TargetPlatform.iOS => 'ios', TargetPlatform.android => 'android', _ => null };
  if (plataforma == null) return;
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await api.registrarDispositivo(token, plataforma);
  } catch (e) {
    debugPrint('Push no disponible: $e');
  }
}
