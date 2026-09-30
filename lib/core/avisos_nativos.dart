import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Canal con MainActivity.kt (solo Android): permisos y ajustes que los plugins no exponen.
const _canal = MethodChannel('mx.senda.app/avisos');

bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// [pantallaCompleta]: la alarma puede cubrir la pantalla bloqueada (Android 14+ lo pide).
/// [sinRestriccionBateria]: el ahorro de batería no retrasa alarmas ni push.
/// null = no aplica (iOS, web) o no se pudo saber.
typedef EstadoNativo = ({bool? pantallaCompleta, bool? sinRestriccionBateria, String fabricante});

Future<EstadoNativo> estadoNativo() async {
  if (!_android) return (pantallaCompleta: null, sinRestriccionBateria: null, fabricante: '');
  try {
    final m = await _canal.invokeMapMethod<String, dynamic>('estado') ?? const {};
    return (pantallaCompleta: m['pantallaCompleta'] as bool?, sinRestriccionBateria: m['sinRestriccionBateria'] as bool?,
        fabricante: '${m['fabricante'] ?? ''}');
  } catch (_) {
    return (pantallaCompleta: null, sinRestriccionBateria: null, fabricante: '');
  }
}

/// Ficha de la app en Ajustes (permisos, notificaciones, batería).
Future<bool> abrirAjustesApp() async {
  if (!_android) return false;
  try { return await _canal.invokeMethod<bool>('abrirAjustesApp') ?? false; } catch (_) { return false; }
}

/// Lista de "optimización de batería" del sistema (o la ficha de la app si el fabricante la quitó).
Future<bool> abrirAjustesBateria() async {
  if (!_android) return false;
  try { return await _canal.invokeMethod<bool>('abrirAjustesBateria') ?? false; } catch (_) { return false; }
}

/// Marcas que además tienen "Inicio automático" o gestores de batería propios que matan alarmas y push.
bool fabricanteEstricto(String f) =>
    const ['xiaomi', 'redmi', 'poco', 'huawei', 'honor', 'oppo', 'realme', 'vivo', 'oneplus', 'samsung', 'motorola']
        .any(f.contains);
