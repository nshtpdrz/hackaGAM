# Conexión de la app con el backend

La app sigue la *Guía de conexión del frontend* (API `/api/v1`, 30/09/2026). Todas las respuestas pasan por
`lib/core/api_modelos.dart`, que las convierte al formato de las pantallas. Si el backend cambia un nombre de
campo, se corrige solo en ese archivo.

## Cómo correrla

```bash
# Teléfono por USB (con la API corriendo y adb reverse tcp:3000 tcp:3000)
flutter run --dart-define=API_URL=http://localhost:3000/api/v1
# Emulador Android
flutter run --dart-define=API_URL=http://10.0.2.2:3000/api/v1
# Sin API_URL: modo demo (lib/core/mock_api.dart), con las mismas formas de respuesta que la API
flutter run
```

- En el Manifest, `android:usesCleartextTraffic="true"` es obligatorio; ver `docs/android_manifest_snippet.xml`.
- Los botones "Entrar como…" del login usan las cuentas de la semilla (`maria@`, `pedro@`, `medica@demo.invalid` / `Demo2026!`).

## Qué ya sigue la guía

| Tema | Implementación |
|---|---|
| Sesión | `POST /auth/login {correo, contrasena}` y `GET /auth/yo`. Los roles `enfermera` y `medico` comparten las pantallas del equipo. El cuidador con varios familiares tiene un selector de paciente en la barra superior. Un 401 borra el token y regresa al login. |
| Errores | Se lee `{error: {codigo, mensaje, campos}}`. Al paciente se le muestra un texto propio según el `codigo` (400, 401, 403, 404, 409, 422, 429, 503). |
| Textos | `GET /mensajes?lengua=spa\|eng\|ote&variante=`. Si `respaldo=espanol` y `requiere_interprete`, se muestra en español con un aviso de intérprete. Sin `audio_url`, la voz del teléfono solo se usa en español o inglés. |
| Registros | `POST …/registros {registros:[{id_local (UUID v4), tipo, variable, valor_num, valor_num2, escala, tomado_en}]}`: un lote por episodio. La presión va como `valor_num`/`valor_num2`; los síntomas con `escala` 0–4. La cola sin conexión reenvía el mismo lote. `estado: incompleta` muestra qué falta y nunca afirma que todo está bien. |
| Gráficas | `GET …/registros?variable=presion\|glucosa&desde=&limite=&cursor=`, siguiendo `siguiente_cursor`. |
| Tomas | `GET …/horarios`: solo se usan las tomas de hoy; las alarmas diarias se programan por horario. `POST …/tomas {tomas:[{id_local, horario_id, programada_en, estado: tomada\|omitida, motivo?, confirmada_en}]}`. "Más tarde" es local y no se envía. `GET …/tomas?dias=14` alimenta la adherencia. |
| MEDMAP | `POST …/documentos` (multipart `archivo` y/o `texto`, `tipo`). Los `por_revisar` se muestran en ámbar, las `alertas_medicacion` con el rojo primero y también `alergias_en_documento`. Con 503/422 se ofrece escribir la receta. `POST /documentos/:id/confirmar` no manda `sustancia_id` si es null; después se vuelven a pedir los horarios. |
| Equipo | `GET /pacientes?q=&semaforo=`, `GET /qr/:codigo`, `GET /pacientes/:id`, medicación con cruces. `GET …/resumen` solo para el médico. `PATCH /alertas/:id {accion}` trata el 409 como "ya atendida". El cuidador solo atiende alertas ámbar. |
| Alta | `POST /pacientes` con perfil, programas, cuidador y `consentimiento {version, aceptado}`. La versión sale de `GET /aviso-privacidad`. Las credenciales temporales se muestran una sola vez. |
| Push | `POST /dispositivos {token_fcm, plataforma}` después del login. Se omite si Firebase no está configurado. |

## Supuestos por confirmar con los ejemplos (`api/ejemplos/*.json`)

Donde la guía no fija el nombre exacto, el adaptador acepta variantes. Hay que confirmar:

1. **`/auth/yo`:** el médico "verificado" se deduce de que tenga `cedula`, porque la guía no define un campo de verificación.
2. **`/horarios`:** cada horario trae `hora_local` y el medicamento (anidado en `medicamento` o plano con `nombre_comercial`, `dosis`, `concentracion`); cada toma trae `horario_id`, `programada_en` y `estado`.
3. **Claves de programa:** se asumió `embarazo`, `cronicas`, `adulto_mayor` y `oncologia`. En la app, `cronicas` se muestra como "Crónico-degenerativas".
4. **Motivos de "omitida":** `olvido`, `sin_medicina`, `efecto_adverso` y `otro`.
5. **`POST /pacientes`:**
   - Perfil plano (`nombre`, `fecha_nacimiento`, `sexo`, `tipo_sangre`, `alergias`, `diagnosticos`).
   - `programas: [{programa}]` y `cuidador: {nombre, telefono}`.
   - Respuesta: `{paciente, codigo_qr, credenciales}`.
6. **`GET /pacientes/:id`:** `{paciente: {id, perfil: {…}, semaforo}, programas, cuidadores, …}`.
7. **Listas paginadas:** los elementos vienen en `pacientes`, `registros` o `alertas`; también se acepta una lista sin envoltura.
8. **Alertas:** `paciente {id, nombre}`, `creada_en` y `registro {variable, valor_num, valor_num2, tomado_en}`.

## Funciones de la app que la guía todavía no cubre

Funcionan en modo demo. Con la API real regresan 404 y la app avisa. Hay que acordarlas con backend:

| Función en la app | Petición que usa la app | Nota |
|---|---|---|
| Crear cuenta desde la app | `POST /auth/registro` | En la guía las cuentas las crea el admin (personal) o el equipo (pacientes). |
| Registro de cuidador escaneando el QR del paciente | `GET /registro/qr/:codigo` (sin sesión) | Debe regresar datos mínimos: nombre corto del paciente y cuidador asignado. |
| Lista de clínicas en el registro de médico | `GET /clinicas` | |
| Editar perfil propio | `PATCH /auth/yo`, `PATCH /pacientes/:id` | |
| Foto de perfil | `POST /auth/yo/foto` (multipart `foto`) → `{foto_url}` | |
| Preferencias elegidas por el equipo en el alta | `PUT /pacientes/:id/preferencias` | La guía solo permite este endpoint a paciente y cuidador; hoy la app lo intenta y, si falla, lo ignora. |
