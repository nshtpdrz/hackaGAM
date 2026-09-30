# Empaquetado de SENDA (Android e iOS)

Guía para generar la app que se instala en teléfonos. El empaquetado final se hace **solo cuando la app ya habla con el
backend real**; antes de eso, solo builds de prueba por USB. La URL del servidor nunca se escribe en el código ni en
los documentos: se pasa al compilar (ver "URL del servidor").

Relacionados: `docs/CONEXION_BACKEND.md` (API), `docs/NOTIFICACIONES.md` (push con Firebase),
`docs/PENDIENTES_FRONTEND.md` (lo que falta en la app).

## Compatibilidad

| Plataforma | Mínimo | Dónde se fija | Qué cubre |
|---|---|---|---|
| Android | 7.0 (API 24) | `minSdk = 24` en `android/app/build.gradle.kts` | La gran mayoría de los Android en uso. El porcentaje actualizado está en Android Studio (asistente de nuevo proyecto, "Help me choose"). |
| iOS | 13.0 | `IPHONEOS_DEPLOYMENT_TARGET = 13.0` en `ios/Runner.xcodeproj/project.pbxproj` | iPhone 6s / SE (1.ª gen.) y posteriores. |

- `minSdk = 24` es el mínimo que piden `local_auth`, `image_picker` y `flutter_tts`.
- `compileSdk` y `targetSdk` son los de Flutter 3.41 (36). Java 17 y desugaring activados (`flutter_local_notifications` usa `java.time` en Android 7).
- Cámara no obligatoria (`uses-feature ... required="false"`): se instala en tabletas y equipos sin cámara; el QR se puede escribir a mano.
- Sin respaldo ni traspaso de datos (`allowBackup="false"` + `res/xml/reglas_respaldo.xml`): al cambiar de teléfono hay que volver a iniciar sesión.
- Huawei y Honor sin servicios de Google: no reciben push (FCM) ni tienen Play Store. Las alarmas de tomas sí funcionan (son locales). Se reparte por APK.

### Arquitecturas

| ABI | Teléfonos | Nota |
|---|---|---|
| `arm64-v8a` | Casi todos los Android de los últimos años | El APK recomendado si no sabes cuál usar. |
| `armeabi-v7a` | Teléfonos viejos o económicos de 32 bits (incluye algunos Android Go) | Probar en uno si la población usa equipos baratos. |
| `x86_64` | Emuladores y algunas Chromebook | No hace falta repartirlo. |
| iOS `arm64` | Todos los iPhone con iOS 13+ | Único. |

Para saber la ABI de un teléfono conectado por USB:

```bash
adb shell getprop ro.product.cpu.abi
```

### Identificador y versión

| Dato | Valor | Dónde |
|---|---|---|
| Paquete Android | `mx.senda.app` | `namespace` y `applicationId` en `android/app/build.gradle.kts` |
| Bundle iOS | `mx.senda.app` | `PRODUCT_BUNDLE_IDENTIFIER` en `project.pbxproj` |
| Nombre visible | SENDA | `android:label` (Manifest), `CFBundleDisplayName` (Info.plist) |
| Versión | `version: 1.0.0+1` | `pubspec.yaml`: nombre (`versionName` / `CFBundleShortVersionString`) + número (`versionCode` / `CFBundleVersion`) |

- **Sube el número (`+N`) en cada APK, AAB o IPA que se reparta.** Android no instala encima una versión con número igual o menor, y las tiendas la rechazan.
- También se puede fijar al compilar con `--build-name=1.0.1 --build-number=2`.
- El paquete antes era `com.example.medmap`: para Android es otra app. Desinstala la vieja en los teléfonos de prueba (si no, quedan dos iconos y alarmas repetidas).

## Antes de empaquetar (requiere backend real)

- [ ] La API responde por **HTTPS** con certificado válido (no autofirmado).
- [ ] Quitar `android:usesCleartextTraffic="true"` de `android/app/src/main/AndroidManifest.xml`.
- [ ] Quitar el bloque `NSAppTransportSecurity` / `NSAllowsArbitraryLoads` de `ios/Runner/Info.plist`. Con él, App Store pide justificarlo.
- [ ] URL de producción pasada al compilar (`--dart-define` o `--dart-define-from-file`), nunca en `lib/`.
- [ ] En el inicio de sesión aparece "Conectado al servidor". Si dice "Modo demo (sin servidor)" el build se hizo sin `API_URL`.
- [ ] Funciones que la API aún no tiene (`docs/CONEXION_BACKEND.md`, "Funciones de la app que la guía todavía no cubre"): acordadas con backend u ocultas en la app (p. ej. "Crear cuenta").
- [ ] Firebase del proyecto real: `android/app/google-services.json` y `ios/Runner/GoogleService-Info.plist`; backend con credenciales de FCM; llave APNs en Firebase. Ver `docs/NOTIFICACIONES.md`.
- [ ] Aviso de privacidad y consentimiento oficiales: `GET /aviso-privacidad` trae `texto` y `version`. Los textos de respaldo de `lib/core/l10n.dart` (`consent.*`) dicen "Texto provisional".
- [ ] URL pública del aviso de privacidad (la piden Google Play y App Store).
- [ ] Pendientes de prioridad Alta de `docs/PENDIENTES_FRONTEND.md` resueltos o aceptados.
- [ ] Versión subida en `pubspec.yaml`.
- [ ] Llave de firma lista (`android/key.properties`).
- [ ] Lista de prueba en teléfono físico completa (abajo).

## URL del servidor

La app lee `API_URL` al compilar (`lib/core/api.dart`). Sin `API_URL` arranca en **modo demo** con datos falsos
(`lib/core/mock_api.dart`), también en release.

```bash
flutter build apk --release --dart-define=API_URL=<URL de la API>
```

También puede venir de un archivo local JSON (`{"API_URL": "<URL de la API>"}`):

```bash
flutter build apk --release --dart-define-from-file=config/api.json
```

- `config/api.json` es local y no se sube (debe estar en `.gitignore`). La plantilla es `config/api.example.json` (en la rama de la pantalla de diagnóstico).
- Todo lo que va en `--dart-define` queda dentro del APK/IPA y se puede extraer. No pongas contraseñas reales ni llaves. La contraseña de las cuentas de demo solo en builds de demo.
- Forzar modo demo o real: `--dart-define=MOCK=true` o `MOCK=false`.

## Firma de Android

Sin `android/key.properties`, el release se firma con la llave de debug: sirve para `flutter run --release`, pero
Google Play lo rechaza y no se puede actualizar encima con otra firma.

### 1. Crear la llave (una sola vez)

Guárdala **fuera del repositorio**. `keytool` viene con el JDK; si no está en el PATH, `flutter doctor -v` muestra
la ruta de Java (en Android Studio: `jbr/bin/keytool`).

```bash
keytool -genkey -v -keystore C:/Users/<usuario>/llaves/senda-subida.jks -keyalg RSA -keysize 2048 -validity 10000 -alias senda
```

### 2. `android/key.properties`

```properties
storePassword=<contraseña del almacén>
keyPassword=<contraseña de la llave>
keyAlias=senda
storeFile=C:/Users/<usuario>/llaves/senda-subida.jks
```

- Ruta absoluta con `/`. Una ruta relativa se toma desde `android/app/`.
- `key.properties`, `*.jks` y `*.keystore` ya están en `android/.gitignore`. Nunca los subas.
- Respalda la llave y las contraseñas en un lugar seguro. Sin ella no se pueden publicar actualizaciones de los APK ya repartidos (hay que desinstalar e instalar de nuevo).
- En Google Play esta es la **llave de subida**; Play firma la app con su propia llave (Firma de apps de Play).

### 3. Verificar la firma

```bash
<SDK de Android>/build-tools/<versión>/apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

En Windows el archivo es `apksigner.bat` y el SDK suele estar en `C:/Users/<usuario>/AppData/Local/Android/Sdk`.
Si el certificado dice `CN=Android Debug`, no se leyó `key.properties`.

## Probar en un teléfono Android por USB-C

### Activar depuración USB

1. Ajustes > Acerca del teléfono > tocar 7 veces "Número de compilación". En Xiaomi/Redmi/POCO es "Versión de MIUI" o "Versión de HyperOS"; en Samsung, Información de software > Número de compilación.
2. Ajustes > Sistema (o Ajustes adicionales) > Opciones de desarrollador > **Depuración USB**.
3. Xiaomi/Redmi/POCO (MIUI/HyperOS) además piden, en Opciones de desarrollador:
   - **Instalar vía USB** (sin esto falla la instalación).
   - **Depuración USB (ajustes de seguridad)** (sin esto no funcionan toques ni permisos desde la PC).
   - Ambas pueden pedir cuenta Xiaomi iniciada y, en algunos modelos, SIM insertada.
4. Conectar el cable, elegir "Transferencia de archivos" si lo pregunta, y aceptar "¿Permitir depuración USB?" en el teléfono.

### Comandos

Ver el teléfono y su id:

```bash
flutter devices
```

Si aparece como `unauthorized`, acepta el aviso en el teléfono y revisa con:

```bash
adb devices
```

Correr en release contra el servidor:

```bash
flutter run --release -d <id> --dart-define=API_URL=<URL de la API>
```

Con la API corriendo en la PC (solo desarrollo, requiere `usesCleartextTraffic`). `adb` está en
`<SDK de Android>/platform-tools`; el túnel se pierde al desconectar el cable:

```bash
adb reverse tcp:3000 tcp:3000
```

```bash
flutter run --release -d <id> --dart-define=API_URL=http://localhost:3000/api/v1
```

Instalar un APK ya compilado sin volver a correr la app:

```bash
flutter build apk --release --dart-define=API_URL=<URL de la API>
```

```bash
flutter install -d <id>
```

O con `adb` (el `-r` reemplaza la instalación y conserva los datos):

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Si falla con "conflicto de firma" (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`), la instalada tiene otra llave: desinstala y vuelve a instalar.

## APK para repartir directo

| Opción | Comando | Archivos | Cuándo |
|---|---|---|---|
| Por arquitectura | `--split-per-abi` | `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, `app-x86_64-release.apk` | Reparto controlado: cada APK pesa bastante menos. Das `arm64-v8a` a casi todos y `armeabi-v7a` a teléfonos viejos. |
| Universal | sin opción | `app-release.apk` | No sabes qué teléfono tiene la persona (WhatsApp, USB, enlace). Un solo archivo que funciona en todos. |

Salen en `build/app/outputs/flutter-apk/`.

```bash
flutter build apk --release --split-per-abi --dart-define=API_URL=<URL de la API>
```

```bash
flutter build apk --release --dart-define=API_URL=<URL de la API>
```

- En el teléfono hay que permitir "Instalar apps desconocidas" para la app que abre el APK (Archivos, Chrome, WhatsApp).
- Play Protect puede avisar que la app no es conocida: "Más detalles" > "Instalar de todas formas".
- Google anunció que las apps instaladas fuera de Play exigirán desarrollador verificado, por países a partir de 2026. Revisa si ya aplica en México antes de repartir APK.
- Con `--split-per-abi`, Flutter le da a cada APK su propio número de versión: no se pisan entre sí.

## Google Play (AAB)

```bash
flutter build appbundle --release --dart-define=API_URL=<URL de la API>
```

Opcional, código ofuscado (más difícil de leer si alguien abre el AAB):

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/simbolos --dart-define=API_URL=<URL de la API>
```

- Sale en `build/app/outputs/bundle/release/app-release.aab`.
- Guarda `build/simbolos` de cada versión fuera del repositorio: sin ellos no se pueden leer los errores de esa versión ofuscada (`flutter symbolize`).
- R8 (minify y shrink) lo activa Flutter en release. Las reglas de `android/app/proguard-rules.pro` son obligatorias: sin ellas las alarmas fallan en release al reprogramarse (Gson de `flutter_local_notifications`). Prueba las alarmas en el build release, no solo en debug.

### Play Console

| Sección | Qué poner |
|---|---|
| Firma de apps de Play | Activada. Subes con la llave de `key.properties`. |
| Política de privacidad | URL pública del aviso de privacidad. |
| Seguridad de los datos | Datos de salud, fotos (recetas, heridas, perfil), nombre, correo y teléfono; cifrados en tránsito (HTTPS); quién los ve. |
| Declaración de apps de salud | La pide Play Console en "Contenido de la app"; describir el seguimiento entre consultas. |
| Pantalla completa (`USE_FULL_SCREEN_INTENT`) | Declaración obligatoria. Justificar: alarma de toma de medicamentos. Si Play no la concede, la persona la activa en Ajustes (la app la lleva desde Preferencias > Avisos y alarmas). |
| Alarmas exactas (`SCHEDULE_EXACT_ALARM`) | Si Play Console lo pregunta: recordatorios de medicamentos que la persona programa. No agregar `USE_EXACT_ALARM` (Play solo lo permite a apps de alarma o calendario). |
| Pruebas | Subir primero a Prueba interna y probar la lista de abajo con el AAB de Play. |

Antes de subir, revisa en Android Studio (pestaña "Merged Manifest" de `AndroidManifest.xml`) que los plugins no
agreguen permisos inesperados (almacenamiento, `AD_ID`). Si Play Console avisa sobre páginas de memoria de 16 KB,
revisa qué librería nativa marca (p. ej. `sqlite3_flutter_libs` o ML Kit de `mobile_scanner`) y sube la versión de
ese plugin.

## Permisos

### Android

| Permiso | Qué lo usa | Android | Qué ve la persona | Revisión de Google Play |
|---|---|---|---|---|
| `INTERNET` | API (`dio`) y push | Todos | Nada | No |
| `ACCESS_NETWORK_STATE` | Saber si hay internet para la cola sin conexión (`connectivity_plus`) | Todos | Nada | No |
| `CAMERA` | Escanear QR (`mobile_scanner`); foto de receta, herida y perfil (`image_picker`) | Se pide al usarla (6.0+) | Aviso del sistema al abrir la cámara | No; se declara en Seguridad de los datos (fotos) |
| `USE_BIOMETRIC` | Entrar con huella, rostro o bloqueo (`local_auth`) | 9+ | Nada | No |
| `USE_FINGERPRINT` | Lo mismo en Android 7 y 8 | 7–8 | Nada | No |
| `POST_NOTIFICATIONS` | Alarmas de tomas y push | 13+ | Aviso del sistema después de iniciar sesión; se puede activar después en Preferencias > Avisos y alarmas | No |
| `SCHEDULE_EXACT_ALARM` | Alarma a la hora exacta | 12+; en 14+ viene negado a apps nuevas | Ajustes > Apps > Acceso especial > Alarmas y recordatorios (la app lleva ahí). Sin él, la alarma puede llegar unos minutos tarde | Política de alarmas exactas (ver Play Console) |
| `RECEIVE_BOOT_COMPLETED` | Reprogramar alarmas al reiniciar o actualizar la app | Todos | Nada | No |
| `VIBRATE` | Vibración de la alarma | Todos | Nada | No |
| `WAKE_LOCK` | Encender la pantalla con la alarma; procesar push | Todos | Nada | No |
| `USE_FULL_SCREEN_INTENT` | Alarma a pantalla completa sobre el bloqueo | 14+ solo concedido a apps de alarma o llamadas | Ajustes > Apps > Acceso especial > Notificaciones de pantalla completa (la app lleva ahí). Sin él, llega como notificación que suena y vibra | Sí: declaración en Play Console |

No se declaran: almacenamiento ni fotos (la galería usa el selector del sistema), ubicación, ni
`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (Play lo restringe; la app abre la lista de ahorro de batería del sistema).

### iOS

| Clave o capacidad | Qué lo usa | Qué ve la persona |
|---|---|---|
| `NSCameraUsageDescription` | QR, receta, herida, foto de perfil | Aviso al abrir la cámara |
| `NSPhotoLibraryUsageDescription` | Elegir foto de la galería | Aviso al abrir la galería |
| `NSFaceIDUsageDescription` | Entrar con Face ID | Aviso la primera vez |
| Notificaciones (sin clave) | Alarmas y push | Aviso después de iniciar sesión |
| `UIBackgroundModes` `remote-notification` | Push con la app cerrada | Nada |
| Time Sensitive Notifications | La alarma suena aunque esté activo "Concentración" | Se puede desactivar en Ajustes |

Los textos de los avisos están solo en español (falta `en.lproj/InfoPlist.strings`; ver PENDIENTES_FRONTEND.md).

## iOS

No se ha compilado iOS (no hay Mac). El proyecto se creó con Flutter 3.41 (plantilla con `SceneDelegate`).

Requisitos: Mac con Xcode y CocoaPods, y **cuenta de Apple Developer de pago** (el equipo personal gratuito no
permite Push Notifications ni TestFlight). Sin Mac propio: una Mac prestada o un servicio de CI con macOS.

1. En la Mac, dentro del proyecto:

   ```bash
   flutter pub get
   ```

   ```bash
   pod install --project-directory=ios
   ```

   Si el `ios/Podfile` generado trae `# platform :ios, '13.0'` comentado, descoméntalo.
2. Abrir `ios/Runner.xcworkspace` (no el `.xcodeproj`).
3. Runner > Signing & Capabilities: elegir el Team, dejar "Automatically manage signing" y el bundle `mx.senda.app`.
4. "+ Capability": **Push Notifications**, **Background Modes** (marcar Remote notifications) y **Time Sensitive Notifications**. Xcode crea `Runner.entitlements`.
5. `GoogleService-Info.plist`: agregarlo desde Xcode (arrastrar a Runner, marcar "Copy items if needed" y el target Runner). Copiarlo a la carpeta no basta.
6. Llave APNs (.p8) subida a Firebase: ver `docs/NOTIFICACIONES.md`.
7. Probar en un iPhone (iOS 16+: Ajustes > Privacidad y seguridad > Modo de desarrollador):

   ```bash
   flutter run --release -d <id> --dart-define=API_URL=<URL de la API>
   ```

8. Generar el IPA para TestFlight:

   ```bash
   flutter build ipa --release --dart-define=API_URL=<URL de la API>
   ```

   Sale en `build/ios/ipa/`. Se sube con la app Transporter o desde Xcode > Organizer (`build/ios/archive/Runner.xcarchive`).
9. App Store Connect: etiquetas de privacidad (datos de salud, fotos, contacto), URL del aviso de privacidad y cuenta de prueba para la revisión de Apple.
10. Si App Store Connect avisa `ITMS-91053` (APIs con motivo declarado), agregar `PrivacyInfo.xcprivacy` al target Runner.

## Lista de prueba en teléfono físico

Con el build release y el servidor real. De preferencia en un teléfono económico (2–3 GB de RAM) y en un Xiaomi o Samsung.

Instalación y sesión
- [ ] Instala encima de la versión anterior sin perder la sesión.
- [ ] Icono, nombre "SENDA" y pantalla de arranque correctos (modo claro y oscuro del sistema).
- [ ] Inicio de sesión muestra "Conectado al servidor"; entra con paciente, cuidador y equipo.
- [ ] Contraseña incorrecta muestra el error; sesión expirada (401) regresa al login con aviso.

Biometría
- [ ] Activar en Perfil y entrar con huella.
- [ ] Entrar con rostro (donde exista) y con PIN o patrón del teléfono.
- [ ] Cancelar el diálogo: regresa al login sin error.
- [ ] Demasiados intentos: mensaje de esperar o usar contraseña.
- [ ] Teléfono sin huella registrada: el interruptor dice "No disponible" o explica qué hacer.

Cámara y fotos
- [ ] Escanear el QR de un paciente (equipo) y el del registro de cuidador.
- [ ] "Escribir código" cuando la cámara no abre.
- [ ] Foto de receta con cámara y desde galería; lectura y confirmación.
- [ ] Foto de herida con moneda: dos toques y envío.
- [ ] Foto de perfil: tomar, elegir y quitar.
- [ ] Negar el permiso de cámara: la app lo explica (hoy no en todos los casos; ver PENDIENTES_FRONTEND.md).

Alarma de toma
- [ ] Suena con la app abierta (pantalla de alarma con sonido, vibración y voz).
- [ ] Suena con la app en segundo plano.
- [ ] Suena con la app cerrada (quitada de Recientes).
- [ ] Suena con el teléfono bloqueado y aparece sobre el bloqueo (pantalla completa).
- [ ] Suena después de reiniciar el teléfono sin abrir la app.
- [ ] "Ya la tomé" registra la toma y apaga la alarma.
- [ ] "Más tarde" desde la notificación con la app cerrada vuelve a sonar a los 10 min.
- [ ] Preferencias > Avisos y alarmas muestra lo que falta y cada botón abre el ajuste correcto.

Permisos negados
- [ ] Negar notificaciones: Preferencias > Avisos y alarmas lo marca y "Permitir" lleva a Ajustes.
- [ ] Negar alarmas exactas (Android 14+): la alarma llega, aunque puede retrasarse.
- [ ] Negar pantalla completa: llega como notificación que suena y vibra.

Sin internet
- [ ] Modo avión: registrar mediciones y una toma; aparece "pendientes de enviar".
- [ ] Al volver la red se envían solos y no se duplican.
- [ ] Cerrar la app con pendientes y reabrir (hoy se pierden; ver PENDIENTES_FRONTEND.md).

Accesibilidad
- [ ] Letra del sistema al 200 % y letra de la app al 200 %: nada se corta ni se encima.
- [ ] Alto contraste.
- [ ] TalkBack (Android) y VoiceOver (iOS): todos los botones se leen y se activan con doble toque.
- [ ] Modo oscuro del sistema: la app se ve completa (usa tema claro).
- [ ] Idioma inglés y Hñähñu.

Push (con Firebase configurado)
- [ ] Llega con la app en primer plano, en segundo plano y cerrada.
- [ ] Tocarlo abre la pantalla correcta.

Cierre de sesión
- [ ] Al cerrar sesión e iniciar con otra cuenta no llegan avisos de la cuenta anterior.
- [ ] No suenan alarmas del paciente anterior (hoy sí suenan; ver PENDIENTES_FRONTEND.md).

## Fabricantes que cierran la app

Algunas marcas cierran apps en segundo plano y retrasan o bloquean alarmas y push. La app lo detecta en
Preferencias > Avisos y alarmas (fila "Ahorro de batería", con aviso de "Inicio automático" en estas marcas).
Los menús cambian según versión; las rutas son aproximadas. Guía por modelo: https://dontkillmyapp.com

| Marca | Qué ajustar | Ruta aproximada |
|---|---|---|
| Xiaomi, Redmi, POCO (MIUI / HyperOS) | Batería sin restricciones | Ajustes > Apps > Administrar apps > SENDA > Ahorro de batería > Sin restricciones |
| | Inicio automático | Misma ficha > Inicio automático (activar) |
| | Pantalla de bloqueo y ventanas | Misma ficha > Otros permisos > Mostrar en pantalla de bloqueo; Mostrar ventanas emergentes en segundo plano |
| | No cerrarla al limpiar | Recientes > mantener presionada SENDA > candado |
| Samsung (One UI) | Batería sin restricciones | Ajustes > Aplicaciones > SENDA > Batería > Sin restricciones |
| | Quitar de apps en suspensión | Ajustes > Batería > Límites de uso en segundo plano > quitar SENDA de "en suspensión" y "en suspensión profunda"; agregarla a "nunca en suspensión" |
| Huawei, Honor (EMUI / MagicOS) | Inicio manual | Ajustes > Batería > Inicio de aplicaciones > SENDA > Administrar manualmente (activar inicio automático, inicio secundario y en segundo plano) |
| | Sin Google | Sin servicios de Google no llega el push; las alarmas sí |
| Oppo, Realme (ColorOS) | Segundo plano | Ajustes > Batería > Más ajustes > Optimizar uso de batería > SENDA > No optimizar; Ajustes > Apps > SENDA > Inicio automático |
| Vivo (Funtouch / OriginOS) | Segundo plano | Ajustes > Batería > Consumo alto en segundo plano > SENDA; Ajustes > Apps > SENDA > Inicio automático |

## Si Gradle falla en Windows

Error típico: `Unable to establish loopback connection` (causado por `Invalid argument: connect`).

Causa: Java 17 en Windows abre sus conexiones internas con sockets tipo Unix que crea en la carpeta temporal (`%TEMP%`). Si esa carpeta no los admite, Gradle no puede hablar con su propio proceso. No es un problema del proyecto.

Solución: indicar a Java otra carpeta para esos sockets, solo en la terminal donde se compila. En Git Bash:

```bash
mkdir -p ~/.gradle/uds
```

```bash
export JAVA_TOOL_OPTIONS="-Djdk.net.unixdomain.tmpdir=$HOME/.gradle/uds"
```

En PowerShell (crear antes la carpeta `.gradle\uds` en tu usuario):

```powershell
$env:JAVA_TOOL_OPTIONS = "-Djdk.net.unixdomain.tmpdir=$env:USERPROFILE\.gradle\uds"
```

Después se compila normal (`flutter run`, `flutter build apk`). Java muestra "Picked up JAVA_TOOL_OPTIONS": es normal.

Si sigue fallando:

1. Detener los procesos de Gradle (`.\gradlew --stop` dentro de `android/`) y correr `flutter clean`.
2. Revisar antivirus, firewall o VPN que bloqueen `127.0.0.1`.
3. Revisar Java con `flutter doctor -v` (JDK 17 o el de Android Studio).
4. Si la PC tiene poca RAM, bajar `-Xmx8G` a `-Xmx4G` en `org.gradle.jvmargs` de `android/gradle.properties`.
