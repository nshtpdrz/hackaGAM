# Pendientes del frontend (app Flutter)

Auditoría de `lib/` y `test/` en la rama `senda-pendientes` (30/09/2026). Solo la app; lo que necesita al backend
está marcado en la columna **Backend** y reunido al final como propuestas.

| Prioridad | Criterio |
|---|---|
| Alta | Se pierden datos, se engaña a la persona, afecta su seguridad o falla en un teléfono real. Resolver antes de empaquetar. |
| Media | Funciona, pero incompleto, confuso o frágil. |
| Baja | Pulido, limpieza o mejora. |

**Ya resuelto en esta rama (no se lista):** Preferencias > Avisos y alarmas (permiso de notificaciones, alarmas exactas,
pantalla completa y ahorro de batería con aviso por marca; `lib/widgets/avisos_settings.dart`,
`lib/core/avisos_nativos.dart`), push con FCM (`iniciarPush` y `ReceptorPush` en `main.dart`; el token se olvida al
cerrar sesión), biometría con resultado por caso (`lib/core/biometria.dart`) y alarma sobre la pantalla bloqueada.

**En edición en otra rama:** `login_screen.dart`, `perfil_screen.dart`, `router.dart`, `traducciones*.dart` y la
pantalla de diagnóstico. Revisar sus puntos (SE4, SE5, SE6, PL8, A6) al integrar.

## Estado al cerrar esta ronda

**Resuelto** (detalle en los commits de la rama `senda-pendientes-xif7dt`):

| # | Cómo quedó |
|---|---|
| D1, D2, D3 | Cola cifrada en el teléfono (`lib/core/almacen_local.dart`, `sync.dart`), por cuenta. 409 = enviada; red, 401, 408, 429 y 5xx se reintentan (cada 2 min y al volver a primer plano); otro 4xx se aparta en "No se pudieron enviar" con Reintentar/Descartar. |
| D4, D5, NA4 | Respuestas del día a las tomas, última copia de horarios/medicamentos/plan/perfil/historial (aviso "Sin conexión…") y leídas se guardan por cuenta. |
| SE1 | "Crear cuenta" envía `POST /auth/registro`; solo con 2xx dice que se creó. 404/405/501: "Por ahora las cuentas las crea tu equipo de salud". |
| SE2, SE3 | Cerrar sesión cancela alarmas y avisos y borra los datos de la cuenta; todo lo que se cargó en memoria depende de `userId`. Con sesión expirada (401) se conservan. |
| SE7 | Con huella activa, tras 5 min en segundo plano se pide otra vez (`widgets/bloqueo_al_volver.dart`); no bloquea una alarma sonando. |
| SE8 | Sin versión del aviso de privacidad no se puede aceptar ni dar de alta (ya no se envía `'1'`). Los textos provisionales siguen hasta tener los oficiales (backend/legal). |
| A1, A2, PL5 | Preferencias guardadas en el teléfono y aplicadas antes de crear los canales; solo el paciente las envía y recibe de la API. |
| A3, A4, A8, A10 | Lector de pantalla activa los botones y dice si están desactivados; "Escuchar" legible; confirmación ante valores poco probables; avisos si falta la voz o el audio; pictograma sin red. |
| A6, T4 | Textos nuevos en `textos_para_traducir.csv/.xlsx`; `test/traduccion_test.dart` falla si un `tr('…')` no tiene inglés. |
| A9 | Documentado en `theme.dart`: `C.marca` solo identidad, `C.primary` interfaz. |
| PL1, PL2, PL3, PL4, PL6, PL7, PL9 | Permisos de cámara/fotos con botón a Ajustes (`core/permisos.dart`); foto recuperada si Android cerró la app; permisos de iOS en inglés (`InfoPlist.strings`); alarmas en la zona del teléfono (`flutter_timezone`); sin drift/sqlite; sin `scheduleMedReminders`; brillo al máximo en el QR. |
| NA1, NA2 | "Pedir ayuda" llama al cuidador (y al 911 en rojo); "Pasaron 30 minutos…" solo si nadie respondió. |
| PA1–PA7 | Formulario del plan de control; "Ver expediente" oculto; código bajo el QR si es corto; Oncología; Hoy sin tomas conserva sus botones; Atrás en la receta regresa un paso o pregunta; PNG se sube como PNG. |
| T1, T5 | `test/cola_y_sesion_test.dart` y `test/pendientes_frontend_test.dart`. |

**Queda:**

- En archivos que se editan en otra rama (no se tocaron): SE4, SE5, SE6 (`login_screen.dart`), PL8 (`router.dart`), A7 (`api_modelos.dart`).
- Necesitan a backend o traductores: A5 (mapa `ote`), NA3 (`fecha_fin`), la omisión automática de NA2, código corto del QR (PA3), textos oficiales y firma del consentimiento (SE8), y confirmar los formatos propuestos abajo.
- T3: pruebas en dispositivo (`integration_test`) y la lista de `docs/EMPAQUETADO.md`.

## Lo más urgente (lista original)

| # | Pendiente | Dónde |
|---|---|---|
| D1 + D2 | La cola sin conexión vive en memoria y un error 4xx la bloquea para siempre | `lib/core/sync.dart:35-57` |
| SE2 + SE3 | Cerrar sesión no cancela las alarmas del paciente ni limpia datos; otra cuenta puede ver datos en caché de la anterior | `lib/core/state.dart:68`, `lib/screens/shared.dart:59-66` |
| SE1 | "Crear cuenta" dice "¡Registro exitoso!" sin enviar nada | `lib/screens/auth/register_screen.dart:140-147` |
| A1 + A2 | Letra grande y contraste no se guardan en el teléfono; el cuidador sobrescribe las preferencias del paciente | `lib/core/state.dart:36`, `lib/screens/compartidas/preferencias_screen.dart:16` |
| PL1 | Con el permiso de cámara negado, receta y herida fallan en silencio | `receta_flow_screen.dart:32`, `heridas_screen.dart:150` |
| NA1 | "Pedir ayuda a mi cuidador" aparece en resultados ámbar y rojo y no hace nada | `lib/screens/paciente/resultado_screen.dart:33` |
| PA1 | Plan de control del médico es un texto técnico, sin formulario | `lib/screens/equipo/plan_control_screen.dart:9` |

## Plataforma y nativo

| # | Prioridad | Dónde | Qué pasa | Qué hacer | Backend |
|---|---|---|---|---|---|
| PL1 | Alta | `lib/screens/compartidas/receta_flow_screen.dart:32`, `lib/screens/compartidas/heridas_screen.dart:150`, `lib/widgets/avatar_perfil.dart:58-67`, `lib/widgets/lector_qr.dart:39` | Permiso de cámara o fotos negado. En receta y herida `pickImage` no tiene `try/catch`: la excepción (`camera_access_denied`, `photo_access_denied`) se pierde y no aparece nada. En avatar sale "No se pudo cambiar la foto". En el lector QR sale "No se pudo abrir la cámara" sin decir que es el permiso. | Atrapar `PlatformException`; decir "Permite la cámara en Ajustes" con botón a `abrirAjustesApp()` (ya existe en `avisos_nativos.dart`, solo Android). En iOS abrir los ajustes de la app (canal nativo o `url_launcher`). En el QR, distinguir `MobileScannerErrorCode.permissionDenied`. | No |
| PL2 | Media | `receta_flow_screen.dart:30-36`, `heridas_screen.dart:149-155` | En teléfonos con poca memoria Android puede cerrar SENDA mientras la cámara está abierta. Al volver, la foto se pierde y la persona vuelve al inicio del flujo. | Llamar `ImagePicker().retrieveLostData()` al abrir receta y herida. Probar en un teléfono de 2–3 GB. | No |
| PL3 | Media | `ios/Runner/Info.plist` | `CFBundleLocalizations` declara `es` y `en`, pero los textos de permisos (cámara, fotos, Face ID) solo están en español. | Agregar `ios/Runner/en.lproj/InfoPlist.strings` con `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` y `NSFaceIDUsageDescription` en inglés (y agregarlo al target en Xcode). | No |
| PL4 | Baja | `lib/core/reminders.dart:170`, `:225` | Las alarmas diarias se programan en UTC (`tz.UTC` + repetir por hora). Si la persona cambia de zona horaria (viaje, horario de verano en la frontera norte), la alarma se corre. | Usar la zona del teléfono (`flutter_timezone` + `tz.setLocalLocation`) y programar con `tz.local`. | No |
| PL5 | Baja | `lib/core/reminders.dart:80-81`, `:98-99` | `initReminders()` corre antes de conocer el idioma (las preferencias no se guardan, ver A1): los botones de la alarma en iOS y el nombre de los canales de Android quedan siempre en español. | Tras A1, leer el idioma guardado antes de `initReminders()`; recrear el canal al cambiar de idioma. | No |
| PL6 | Baja | `pubspec.yaml` | `drift` y `sqlite3_flutter_libs` están instalados y no se usan: agregan una librería nativa al APK sin beneficio. | Conectarlos (D1, D4, D5) o quitarlos hasta usarlos. | No |
| PL7 | Baja | `lib/core/reminders.dart:180` | `scheduleMedReminders` no se llama en ningún lado (lo reemplazó `programarAlarmasTomas`). | Borrarla. | No |
| PL8 | Baja | `lib/core/router.dart:50`, `:54`, `:64`, `:65` | `st.extra as Map`: si la ruta se abre sin `extra` (recarga en web, restauración del sistema, enlace) la app truena. `/heridas/nueva` recibe `"null"` como id. | Aceptar `extra` nulo: volver al inicio o mostrar "no encontrado". | No |
| PL9 | Baja | `lib/screens/paciente/qr_screen.dart` | La pantalla del QR no sube el brillo; con brillo bajo el lector del equipo puede fallar. | Subir el brillo mientras se muestra el QR (plugin de brillo) o avisar "sube el brillo". | No |

## Sesión y seguridad

| # | Prioridad | Dónde | Qué pasa | Qué hacer | Backend |
|---|---|---|---|---|---|
| SE1 | Alta | `lib/screens/auth/register_screen.dart:140-147` | TODO: no llama a la API (`api.registro()` existe en `api.dart:177`), pero muestra "¡Registro exitoso! Por favor inicia sesión." La persona cree que ya tiene cuenta. | Mientras no exista `POST /auth/registro`: con API real (`!useMock`) ocultar "Crear cuenta" o cambiarlo por "Pide tu cuenta a tu equipo de salud". Cuando exista: enviar y mostrar éxito solo con respuesta 2xx. | Sí (`POST /auth/registro`, `GET /registro/qr/:codigo`) |
| SE2 | Alta | `lib/core/state.dart:68` | `logout()` solo borra el token. Siguen en el teléfono: las alarmas de tomas del paciente (suenan cada día aunque entre otra persona), la cola sin conexión con datos de esa cuenta, tomas locales (`alarma_tomas.dart:24`), leídas (`notifs.dart:7`) y la firma de horarios (`reminders.dart:240`). Pasa igual con la sesión expirada (401, `state.dart:42`). | Al cerrar sesión: cancelar ids 700000–809999 y reiniciar `_firma` (función nueva en `reminders.dart`), vaciar o apartar la cola por usuario, reiniciar `tomasLocalesProvider` y `leidasProvider`, invalidar los `FutureProvider`. El push ya se olvida (`push.dart:159`). | Ver "Para backend" (baja del dispositivo) |
| SE3 | Alta | `lib/screens/shared.dart:59-66` | `futureFor` solo se recalcula si cambia `patientId`. Dos cuentas del equipo (sin `patientId`) o dos cuidadores del mismo paciente en el mismo teléfono: la segunda ve el perfil (`/auth/yo`), alertas y pacientes de la primera hasta recargar. | Observar también `userId` (`sessionProvider.select((s) => (s?.userId, s?.patientId))`) o invalidar todo al cambiar de sesión (junto con SE2). | No |
| SE4 | Media | `lib/screens/auth/login_screen.dart:49-54`, `lib/screens/auth/splash_screen.dart:22`, `lib/screens/compartidas/perfil_screen.dart:81` | "Entrar con huella" se ve siempre, aunque el teléfono no tenga biometría o no esté activada. Usan `autenticar()` (sí/no) y muestran un solo mensaje; `pedirIdentidad()` y `mensajeBio()` ya dan el motivo (bloqueado, sin huella registrada, etc.). | Mostrar el botón solo si `biometriaActiva()`; usar `pedirIdentidad()` + `mensajeBio()` en los tres lugares. | No |
| SE5 | Baja | `lib/screens/auth/login_screen.dart:3`, `:58-64`, `:87-99` | Import de `go_router` sin usar (único aviso de `flutter analyze`). Botón de demo "Probar Pantalla de Registro" repite "Crear cuenta". "Crear cuenta" usa `Navigator.push` aunque existe la ruta `/registro`. | Quitar el import y el botón; navegar con `context.push('/registro')`. | No |
| SE6 | Media | `lib/screens/auth/login_screen.dart:35-37` | Contraseña sin botón de mostrar/ocultar, sin `autofillHints` (gestor de contraseñas) y "Enter" no inicia sesión. | Agregar ícono de ojo, `AutofillGroup` + `autofillHints`, `textInputAction` y `onSubmitted`. | No |
| SE7 | Baja | `lib/screens/auth/splash_screen.dart:22` | Con biometría activa solo se pide al abrir la app desde cero. Si queda en segundo plano, cualquiera que tome el teléfono entra. | Pedir identidad al volver a primer plano después de N minutos. | No |
| SE8 | Alta | `lib/core/l10n.dart:34-35`, `:54-55`; `lib/screens/auth/consentimiento_screen.dart:47`; `lib/core/api_modelos.dart:396` | Si `GET /aviso-privacidad` no trae texto, se muestran textos "provisionales". La firma escrita no se envía a la API. Si el aviso falla, el alta manda `version: '1'` inventada. | No permitir el alta sin versión real del aviso. Reemplazar los textos provisionales por los oficiales. Enviar la firma si backend la acepta. | Sí (texto oficial, campo de firma) |

## Notificaciones y alarmas

| # | Prioridad | Dónde | Qué pasa | Qué hacer | Backend |
|---|---|---|---|---|---|
| NA1 | Alta | `lib/screens/paciente/resultado_screen.dart:33` | "Pedir ayuda a mi cuidador" sale con resultado ámbar o rojo y no tiene `onTap`: está desactivado y no hace nada. Es justo cuando la persona necesita ayuda. | Llamar al cuidador (`tel:` con `url_launcher`) con el teléfono de `cuidadores` del paciente; en rojo, ofrecer también 911. Si no hay teléfono, mostrar a quién llamar. | No (el teléfono ya viene en `GET /pacientes/:id`) |
| NA2 | Media | `lib/core/reminders.dart:211`, `lib/screens/paciente/recordatorio_screen.dart:143` | A los 30 min la alarma desaparece, pero la app no registra "omitida" ni cambia el estado. Además el texto "Pasaron 30 minutos sin respuesta…" sale también cuando la persona eligió "No me la tomé". | Acordar si la API marca la omisión sola; si no, enviarla al abrir la app. Mostrar ese texto solo si no hubo respuesta. | Por confirmar |
| NA3 | Media | `lib/core/reminders.dart:244` | Las alarmas diarias solo se actualizan cuando la app abre y carga `/horarios`. Si la persona no abre la app, siguen sonando después de terminar el tratamiento. | Programar con fecha de fin, o alarmas de los próximos N días que se renueven. | Sí (fecha de fin en `/horarios`) |
| NA4 | Baja | `lib/core/notifs.dart:7` | Leídas/no leídas solo en memoria: al reabrir la app todo vuelve a "Nueva". | Guardar los ids leídos en el teléfono (con D1). | Opcional |

## Datos sin conexión

| # | Prioridad | Dónde | Qué pasa | Qué hacer | Backend |
|---|---|---|---|---|---|
| D1 | Alta | `lib/core/sync.dart:35-37` | La cola de registros y tomas sin conexión vive en memoria: se pierde si se cierra la app o Android la mata. Los mensajes prometen lo contrario ("guardado en el teléfono. Se enviará solo", `recordatorio_screen.dart:118`, `registrar_screen.dart:65`; "Lo que registres se guarda en el teléfono", `state_views.dart:35`). | Persistir la cola con Drift (ya en `pubspec.yaml`) detrás de `SyncNotifier`; al arrancar, cargarla y enviar. | No |
| D2 | Alta | `lib/core/sync.dart:53-57` | Si un envío falla por algo que no es la red (403 tras cambiar de cuenta, 422, 500), `flush()` se detiene y ese elemento queda al frente: en cada intento vuelve a fallar y **nada de lo que sigue se envía nunca**. `intentos` se cuenta pero no se usa. | Error de red: reintentar después. 409 o `repetido`: tratar como enviado. Otro 4xx: sacar de la cola, guardarlo aparte y avisar. Seguir con los demás. | No |
| D3 | Media | `lib/core/sync.dart:65` | Solo se reintenta cuando cambia la conectividad o con "Sincronizar ahora". Con Wi-Fi pero el servidor caído, nada reintenta. | Reintentar al volver la app a primer plano y cada pocos minutos mientras haya pendientes. | No |
| D4 | Media | `lib/core/alarma_tomas.dart:24-30` | Lo respondido hoy (tomada, omitida, "Más tarde") vive en memoria. Al reabrir, la toma pospuesta vuelve a "pendiente" y la alarma interna puede sonar otra vez. | Guardar el estado local del día (Drift o almacenamiento del teléfono). | No |
| D5 | Media | `lib/screens/shared.dart:59-66` | Hoy, Medicamentos e Historial dependen de la red: sin internet muestran error aunque las alarmas sí suenen. | Guardar la última respuesta de `/horarios` y `/medicamentos` y mostrarla con aviso "sin conexión". | No |

## Accesibilidad e idioma

| # | Prioridad | Dónde | Qué pasa | Qué hacer | Backend |
|---|---|---|---|---|---|
| A1 | Alta | `lib/core/state.dart:36` | `prefsProvider` no se guarda en el teléfono. Idioma, letra, contraste, pictogramas y botones grandes vuelven a lo normal al abrir la app: siempre antes de iniciar sesión, y después solo se recuperan si `/auth/yo` trae `preferencias` (pictogramas y botones grandes nunca, porque la API no los tiene). La persona mayor ve primero la pantalla que no puede leer. | Guardar `Prefs` en el teléfono y aplicarlas antes de `runApp`. La API solo actualiza encima. | No (ver A2) |
| A2 | Alta | `lib/screens/compartidas/preferencias_screen.dart:16` | Guarda en `PUT /pacientes/{pid}/preferencias`. Para el cuidador `pid` es el paciente a cargo: si el cuidador sube su letra o cambia el idioma, **cambia las del paciente**. Para el equipo manda su id de usuario como paciente (falla en silencio). | Solo el rol paciente guarda en la API; cuidador y equipo, solo en el teléfono (A1), hasta que haya un endpoint propio. | Sí (preferencias por usuario) |
| A3 | Media | `lib/widgets/components.dart:29`, `:66`; `lib/widgets/cards.dart:33`; `lib/widgets/audio_player.dart:32` | `Semantics(excludeSemantics: true)` descarta la acción de tocar y el estado "desactivado" del botón hijo. TalkBack/VoiceOver lo leen como botón pero no dicen si está desactivado, y el doble toque depende del respaldo del sistema. `BigButton` está en casi todas las pantallas. | Pasar `onTap` y `enabled: onTap != null` al `Semantics` (o usar `MergeSemantics`). Probar con TalkBack. | No |
| A4 | Media | `lib/widgets/audio_player.dart:34` | Texto blanco sobre `FilledButton.tonalIcon` (fondo claro): "Escuchar indicaciones" casi no se lee en el detalle de alerta. | Quitar `color: Colors.white` y usar el color del tema. | No |
| A5 | Media | `lib/core/traducciones.dart:3` | Solo hay mapa `'en'`. Con Hñähñu todas las pantallas salen en español; solo los mensajes clínicos vienen de `/mensajes`. | Agregar el mapa `'ote'` cuando haya traducción validada. Textos en `docs/textos_para_traducir.csv` / `.xlsx`. | Audios y textos del catálogo |
| A6 | Baja | `lib/core/traducciones_plataforma.dart` | Los textos nuevos de biometría, push y Avisos ya tienen inglés, pero no están en el CSV para la traducción al Hñähñu. | Agregarlos a `docs/textos_para_traducir.csv` / `.xlsx`. | No |
| A7 | Media | `lib/core/api_modelos.dart:69` | El 422 genérico dice "No se pudo leer la receta" en cualquier pantalla (p. ej. un registro de presión rechazado). | Texto por pantalla, o genérico "Revisa los datos" fuera de MEDMAP. | Ideal: `codigo` específico por error |
| A8 | Media | `lib/screens/paciente/registrar_screen.dart:41-49` | Acepta cualquier número: 1200/80 o glucosa 5 por un error de dedo. | Pedir confirmación ante valores poco probables ("¿Tu presión de arriba es 1200?"). Rangos a acordar con el equipo clínico. | No |
| A9 | Baja | `lib/core/theme.dart:5`, `:10` | La interfaz usa `C.primary` #5F447B y la marca #593286 (arranque, notificaciones, ícono). | Decidir un solo morado principal o documentar cuándo va cada uno. | No |
| A10 | Baja | `lib/widgets/components.dart:16-20`, `:47` | `speak()` no maneja errores ni avisa si el teléfono no tiene voz en español instalada. Los pictogramas (`Image.network`) sin internet muestran un error. | Atrapar errores y avisar "Instala la voz en español en Ajustes"; `errorBuilder` en el pictograma. | No |

## Pantallas

| # | Prioridad | Dónde | Qué pasa | Qué hacer | Backend |
|---|---|---|---|---|---|
| PA1 | Alta | `lib/screens/equipo/plan_control_screen.dart:9` | El médico entra desde el detalle del paciente (`paciente_detalle_screen.dart:49`) y solo ve el texto técnico "mín / máx / frecuencia / meta → PUT /pacientes/:id/plan". `api.plan()` y `api.guardarPlan()` ya existen. | Formulario por variable (mínimo, máximo, frecuencia, meta) con los datos de `GET …/plan`. | Confirmar formato de `PUT …/plan` |
| PA2 | Media | `lib/screens/equipo/expediente_screen.dart:12` | "Ver expediente" (`paciente_detalle_screen.dart:45`) abre una pantalla con "Paciente {id}" y un botón. | Ocultar el botón (el detalle ya muestra casi todo) o construir el expediente. | Por definir |
| PA3 | Media | `lib/screens/paciente/qr_screen.dart:13-14`, `lib/widgets/lector_qr.dart:66` | El lector ofrece "Escribir código" con la etiqueta "Código que aparece bajo el QR", pero la pantalla del paciente no muestra ningún código. El respaldo manual no sirve. | Mostrar el código bajo el QR (si es corto) o cambiar la etiqueta. | Sí si el token es largo (código corto) |
| PA4 | Media | `lib/screens/shared.dart:72-73` | `programasCuidado` no tiene `oncologia`: en Perfil y en el detalle se ve la clave cruda "oncologia" y el alta no permite elegirla. | Agregarla (clave por confirmar, supuesto 3 de `CONEXION_BACKEND.md`). | Confirmar claves |
| PA5 | Media | `lib/screens/paciente/hoy_screen.dart:17` | Sin tomas hoy, `AsyncView` muestra "No hay información todavía" y oculta "Mostrar mi código QR" y "Seguimiento de heridas". | Mensaje propio ("Hoy no tienes tomas") y conservar los botones. | No |
| PA6 | Media | `lib/screens/compartidas/receta_flow_screen.dart`, `lib/screens/equipo/alta_paciente_screen.dart` | El botón Atrás del sistema sale del flujo en cualquier paso y se pierde lo revisado. | `PopScope`: en pasos intermedios, volver un paso o preguntar "¿Salir sin guardar?". | No |
| PA7 | Baja | `lib/screens/compartidas/receta_flow_screen.dart:35` | Siempre se sube como `receta.jpg` / `image/jpeg`, aunque la galería entregue PNG o HEIC. | Verificar en Samsung y iPhone qué formato llega; usar el nombre real o convertir a JPEG. | No |

## Pruebas

| # | Prioridad | Qué falta | Qué hacer |
|---|---|---|---|
| T1 | Media | Sin pruebas de la cola sin conexión (orden, error 4xx, reenvío sin duplicar) ni del cierre de sesión (alarmas, cola, caché). | Pruebas unitarias con `ProviderContainer` y el mock, junto con D1, D2, SE2 y SE3. |
| T3 | Media | Sin pruebas en dispositivo (`integration_test`): alarmas, cámara y permisos solo se prueban a mano. | Seguir la lista de `docs/EMPAQUETADO.md`; agregar `integration_test` para login y registro. |
| T4 | Baja | Nada detecta textos sin traducción. | Prueba que recorra `lib/` y compare `tr('…')` con `traducciones*.dart`. |
| T5 | Baja | Nada prueba que los botones se activen con lector de pantalla (A3). | `tester.ensureSemantics()` y verificar `SemanticsAction.tap` en `BigButton`. |

## Para backend

Propuestas que salen del código de la app. **No son contratos**: hay que acordarlas con quien lleva la API.

| Necesidad | Por qué (app) | Propuesta |
|---|---|---|
| Crear cuenta | `register_screen.dart` (`_cuerpoRegistro`), `api.dart:177` | `POST /auth/registro` con `{rol: paciente\|cuidador\|medico, nombre, correo, telefono, contrasena, preferencias, …}`; paciente agrega `fecha_nacimiento, sexo, tipo_sangre, alergias, programas`; cuidador `codigo_qr`; médico `cedula_profesional, clinica`. 2xx = creada; 409 = correo ya registrado. Si no se hará, responder 404 y la app lo explica (SE1). |
| Plan de control | `plan_control_screen.dart` (PA1) | `GET/PUT /pacientes/:id/plan` con `rangos: [{variable, activo, frecuencia: diaria\|dos_al_dia\|semanal, min, max, min2?, max2?, meta?}]` (presión: `min/max` sistólica, `min2/max2` diastólica). La app también lee `minimo/maximo/valor_min/valor_max`. |
| Registro de cuidador por QR | `register_screen.dart:191` | `GET /registro/qr/:codigo` sin sesión, con datos mínimos (nombre corto y cuidador asignado). |
| Editar perfil y foto | `editar_perfil_screen.dart:29-30`, `avatar_perfil.dart:56-63` | `PATCH /auth/yo`, `PATCH /pacientes/:id`, `POST /auth/yo/foto`. |
| Baja del dispositivo al cerrar sesión | `push.dart:111-115` solo borra el token en el teléfono; el servidor conserva el viejo hasta que FCM lo invalide. | `DELETE /dispositivos/:token_fcm` (o equivalente) que la app llama antes de borrar el JWT. |
| Preferencias de cuidador y equipo | `preferencias_screen.dart:16` (A2) | `PUT /auth/yo/preferencias` (o dentro de `PATCH /auth/yo`). Agregar `pictogramas` y `botones_grandes` (no existen en la API, `state.dart:27-28`). |
| Omisión por falta de respuesta | `reminders.dart:211` (NA2) | Confirmar si la API marca "omitida" sola a los 30 min; si no, motivo `sin_respuesta` en `POST …/tomas`. |
| Fin de tratamiento | `reminders.dart:244` (NA3) | `fecha_fin` (o días restantes) por horario en `GET …/horarios`. |
| Código corto del QR | `qr_screen.dart:13`, `lector_qr.dart:66` (PA3) | `codigo_corto` en `GET /pacientes/:id/qr`, aceptado por `GET /qr/:codigo`. |
| Firma del consentimiento | `consentimiento_screen.dart:47`, `alta_paciente_screen.dart:37` (SE8) | `consentimiento: {version, aceptado, firmado_por, es_representante}` en `POST /pacientes`. |
| Errores 422 con código | `api_modelos.dart:69` (A7) | `error.codigo` específico (p. ej. `valor_fuera_de_rango`) para mostrar el texto correcto. |
| Claves de programa | `shared.dart:72-73` (PA4) | Confirmar `oncologia` y las demás claves de programa. |

`GET /clinicas` (`api.dart:182`) ya no se usa: la clínica del registro es texto libre.
