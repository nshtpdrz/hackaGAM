# SENDA

App Flutter de seguimiento de pacientes entre consultas (HackaTec 2026).

- Modo demo: `flutter run` (sin servidor).
- Con la API: `flutter run --dart-define=API_URL=<URL de la API>`; ver `docs/CONEXION_BACKEND.md`.
- Marca: `assets/marca/` (logotipo, icono y emblema). Icono y arranque de Android/iOS: tras `flutter create --platforms=android,ios .`,
  correr `dart run flutter_launcher_icons` y `dart run flutter_native_splash:create`.
