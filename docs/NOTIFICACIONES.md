# Notificaciones de SENDA

SENDA avisa de dos maneras que no dependen una de la otra:

| | Alarmas de tomas | Notificaciones push |
|---|---|---|
| Para qué | Recordar cada medicamento a su hora | Alertas nuevas, cambios hechos por el equipo |
| Quién la genera | El propio teléfono (`lib/core/reminders.dart`) | El backend, a través de Firebase Cloud Messaging (FCM) |
| Sin internet | Suena igual | No llega hasta que haya conexión |
| Quién la recibe | Paciente | Cuidador y equipo (y el paciente, si backend lo decide) |
| Qué falta para usarla | Nada | Proyecto de Firebase y envío desde el backend |

Las alarmas no deben duplicarse con push: el backend **no** debe mandar push de "te toca tu medicina".

## 1. Qué hace ya la app

| Situación | Comportamiento |
|---|---|
| Al abrir la app | Inicia Firebase si encuentra su configuración. Si no la encuentra, sigue sin push y sin errores (`lib/core/push.dart`, `iniciarPush`). |
| Al iniciar sesión o restaurarla | Pide permiso de notificaciones (Android 13+ e iOS), obtiene el token y lo manda a `POST /dispositivos {token_fcm, plataforma}`. Solo lo manda si el token cambió. |
| Firebase renueva el token | Lo vuelve a mandar a `POST /dispositivos`. |
| Al cerrar sesión o cuando expira | Borra el token del teléfono (`deleteToken`) para que no lleguen avisos de la cuenta anterior, por ejemplo en un teléfono compartido entre paciente y cuidadora. |
| Push con la app abierta | Android no lo muestra solo, así que la app lo muestra en el canal "alertas". En iOS lo muestra el sistema. En los dos casos se recargan alertas, notificaciones, pacientes, horarios y medicamentos. |
| Push con la app en segundo plano o cerrada | Lo muestra el sistema. Los mensajes de solo datos que traen `titulo` también se muestran. |
| Al tocar un push | Abre la pantalla según `data.tipo` (tabla del §4). Si es una alerta con `alerta_id`, abre su detalle. Al cuidador lo cambia al paciente del aviso (`paciente_id`). |
| Preferencias > Avisos y alarmas | Muestra si faltan permisos: notificaciones, alarma exacta, pantalla completa y ahorro de batería (con aviso especial para Xiaomi, Samsung, Huawei y otras marcas), y lleva al ajuste con un botón (`lib/widgets/avisos_settings.dart`). |

Canales de Android:

| Canal | Uso | Importancia |
|---|---|---|
| `alarma_tomas` | Alarma de cada toma: suena y vibra hasta que se responde, a pantalla completa | Máxima |
| `tomas` | Recordatorios diarios simples | Alta |
| `alertas` | Push del backend (es el canal por omisión de FCM en el Manifest) | Alta |

## 2. Configurar Firebase (una vez)

Los archivos de configuración **no se suben al repositorio** (están en `.gitignore`). Se comparten por fuera del repo con quien compile la app.

1. En la [consola de Firebase](https://console.firebase.google.com), crea un proyecto (Analytics no hace falta).
2. **Android:** agrega una app con el paquete `mx.senda.app`. Descarga `google-services.json` y ponlo en `android/app/`. No se necesita la huella SHA-1 para FCM.
3. **iOS** (en una Mac, con cuenta de Apple Developer de pago):
   - Agrega una app con el Bundle ID `mx.senda.app`. Descarga `GoogleService-Info.plist` y arrástralo en Xcode a `Runner` (con "Copy items if needed" y el target Runner marcado).
   - En Apple Developer, crea una llave de APNs (`.p8`). Súbela en Firebase: Configuración del proyecto > Cloud Messaging > Configuración de apps de Apple.
   - En Xcode, en Runner > Signing & Capabilities, agrega **Push Notifications**, **Background Modes** (marca Remote notifications) y **Time Sensitive Notifications**. Esta última hace que la alarma suene aunque esté activo el modo Concentración.
4. Compila de nuevo. El plugin de Gradle `com.google.gms.google-services` se aplica solo si existe `android/app/google-services.json` (`android/app/build.gradle.kts`).
5. **Backend:** en Configuración del proyecto > Cuentas de servicio, genera una llave privada y entrégala por un canal seguro a quien hace el backend. Esa llave es la que permite enviar push. **Nunca va en la app ni en el repositorio.**

La app no usa `lib/firebase_options.dart` (FlutterFire CLI): Firebase se inicia con los archivos nativos. Si alguien corre `flutterfire configure`, ese archivo queda fuera del repo por `.gitignore`.

## 3. Probar sin backend

1. Con Firebase configurado, corre la app en un teléfono en modo debug y entra con cualquier cuenta (también funciona en modo demo):
```bash
flutter run -d <id del teléfono>
```
2. En la consola de `flutter run` aparece `Token FCM (para enviar una prueba desde la consola de Firebase): …`. Copia el token. Solo se imprime en debug.
3. En Firebase, ve a Messaging > Nueva campaña > Notificaciones > "Enviar mensaje de prueba" y pega el token.
4. Prueba los tres estados: app abierta, en segundo plano y cerrada. En "Opciones adicionales > Datos personalizados" agrega `tipo = alerta` para probar a qué pantalla lleva.
5. Cierra sesión y reenvía la prueba al mismo token: ya no debe llegar.

## 4. Propuesta para backend (a acordar)

La app ya consume `POST /dispositivos {token_fcm, plataforma}`. Lo siguiente es la forma que la app espera del mensaje. **Es una propuesta**; si backend define otra, la app se ajusta en `push.dart`.

Mensaje (FCM HTTP v1):

```json
{
  "message": {
    "token": "<token_fcm>",
    "notification": { "title": "Alerta de Carmen", "body": "Hay un registro que revisar." },
    "data": { "tipo": "alerta", "alerta_id": "123", "paciente_id": "45", "message_key": "alerta.presion" },
    "android": { "priority": "high", "notification": { "channel_id": "alertas" } },
    "apns": { "payload": { "aps": { "sound": "default", "interruption-level": "time-sensitive" } } }
  }
}
```

Valores de `data.tipo` y pantalla que abre la app (`rutaDePush`):

| `tipo` | Equipo | Cuidador | Paciente |
|---|---|---|---|
| `alerta` (con `alerta_id` abre el detalle) | Alertas (`/cola`) | Alertas (`/alertas`) | Notificaciones |
| `toma`, `recordatorio`, `horarios` | Notificaciones | Medicamentos | Hoy |
| `receta`, `medicamentos` | Notificaciones | Medicamentos | Medicamentos |
| `herida` | Notificaciones | Heridas | Heridas |
| otro o sin `tipo` | Notificaciones | Notificaciones | Notificaciones |

Reglas sugeridas:

- **Texto en la lengua de quien recibe:** backend ya tiene sus preferencias y el catálogo de `/mensajes`. Manda también `message_key` en `data`.
- **Nada clínico en el texto visible**, porque se lee en la pantalla bloqueada. Mejor "Hay una alerta nueva de Carmen" que el valor de la presión.
- Todos los valores de `data` como texto (FCM solo acepta strings).
- **Quién recibe qué:** cuidador, alertas ámbar de sus familiares; equipo, rojas y ámbar; paciente, solo cambios que haga el equipo (plan, receta revisada) con `tipo: horarios` para que recargue sus tomas. Nunca "te toca tu medicina": eso lo hace la alarma local.
- **Tokens:** una persona puede tener varios teléfonos. Si FCM responde `UNREGISTERED` o `INVALID_ARGUMENT`, borrar ese token.
- **Cerrar sesión:** la app ya borra el token del teléfono, pero conviene que backend también lo desvincule. Se propone `DELETE /dispositivos {token_fcm}`, que hoy no existe en la guía.

## 5. Permisos

| Permiso | Plataforma | Cuándo se pide | Si se niega |
|---|---|---|---|
| Notificaciones | Android 13+ e iOS | Al iniciar sesión | Ni alarmas ni push. Preferencias > Avisos lleva a Ajustes. |
| Alarmas exactas | Android 12+ (en 14+ viene apagado) | Botón en Preferencias > Avisos | Las alarmas pueden llegar unos minutos tarde. |
| Pantalla completa | Android 14+ | Botón en Preferencias > Avisos | La alarma llega como notificación normal (suena y vibra igual). |
| Sin restricción de batería | Android (sobre todo Xiaomi, Samsung, Huawei) | Botón en Preferencias > Avisos | El sistema puede retrasar o descartar alarmas y push. |
| Notificaciones urgentes | iOS | Capacidad en Xcode (§2) | La alarma no suena en modo Concentración. |

La alarma a pantalla completa aparece sobre la pantalla bloqueada **solo** cuando la abre una alarma de toma (`MainActivity.kt`). El resto de la app siempre pide desbloquear el teléfono.

## 6. Problemas comunes

| Síntoma | Causa probable |
|---|---|
| En el log sale "Push sin configurar" | Falta `google-services.json` o `GoogleService-Info.plist`, o se agregó sin recompilar. |
| El ícono sale como un cuadro gris | Se está usando otro ícono. Debe ser `@drawable/ic_stat_senda` (Manifest y `reminders.dart`). |
| Con la app abierta no se ve nada en Android | Es lo normal en FCM: la app lo muestra en el canal `alertas`. Revisa que el permiso de notificaciones esté activo. |
| Xiaomi/Redmi: no llega con la app cerrada | Activa "Inicio automático" y en Ahorro de batería elige "Sin restricciones" para SENDA. Ver https://dontkillmyapp.com. |
| iOS: nunca llega el token | Falta la llave APNs en Firebase o la capacidad Push Notifications, o se está probando en un simulador sin soporte. Prueba en un iPhone. |
| La alarma suena tarde | Falta el permiso de alarmas exactas o hay ahorro de batería (Preferencias > Avisos). |

## 7. Archivos

| Archivo | Qué contiene |
|---|---|
| `lib/core/push.dart` | Firebase, token, mensajes, `rutaDePush`, widget `ReceptorPush` |
| `lib/core/reminders.dart` | Notificaciones locales, canales, permisos, alarmas de tomas |
| `lib/core/avisos_nativos.dart` + `android/.../MainActivity.kt` | Estado de pantalla completa y batería, abrir Ajustes |
| `lib/widgets/avisos_settings.dart` | Preferencias > Avisos y alarmas |
| `android/app/src/main/AndroidManifest.xml` | Permisos, receptores de alarmas, canal e ícono de FCM |
| `ios/Runner/Info.plist`, `ios/Runner/AppDelegate.swift` | Modos en segundo plano y delegado de notificaciones |

## 8. Pendiente

- **Backend:** enviar push con la forma del §4 (necesita la llave de cuenta de servicio de Firebase) y acordar `DELETE /dispositivos`.
- **iOS:** compilar y probar en una Mac. La plantilla de Flutter 3.41 usa escenas (`SceneDelegate`); hay que confirmar que al tocar un push con la app cerrada se abra la pantalla correcta (`getInitialMessage`).
- **Traducción:** el nombre del canal "Alertas de salud" se crea en el idioma que tenga la app la primera vez; si la persona cambia de idioma, Ajustes del sistema lo sigue mostrando en el anterior.
