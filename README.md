# SENDA

App Flutter de seguimiento de pacientes entre consultas (HackaTec 2026). Android 7.0+ e iOS 13+ (paquete `mx.senda.app`).

- Modo demo: `flutter run` (sin servidor).
- Con la API: `flutter run --dart-define=API_URL=<URL de la API>`; ver `docs/CONEXION_BACKEND.md`.
- Alarmas de tomas y notificaciones push (Firebase): `docs/NOTIFICACIONES.md`.
- Compilar, firmar y probar en un teléfono: `docs/EMPAQUETADO.md`.
- Marca: `assets/marca/` (logotipo, icono y emblema). Íconos y arranque nativos ya generados; si cambian los PNG,
  correr `dart run flutter_launcher_icons` y `dart run flutter_native_splash:create`.
