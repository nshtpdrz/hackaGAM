# Solicitudes de la app al backend

Son **propuestas**, no contratos: dime qué te sirve, qué no y qué nombres prefieres. La app ya tolera nombres
alternativos en casi todo. Detalle y archivos de la app en `docs/PENDIENTES_FRONTEND.md` (sección "Para backend").

## Urgente (bloquea funciones que ya están en la app)

### 1. Crear cuenta: `POST /auth/registro` (sin sesión)

```jsonc
{ "rol": "paciente | cuidador | medico",
  "nombre": "", "correo": "", "telefono": "", "contrasena": "",
  "preferencias": { "lengua": "spa", "variante": null, "prefiere_audio": false, "letra": "normal", "contraste": "normal" },

  // solo paciente:
  "fecha_nacimiento": "1980-05-01", "sexo": "F", "tipo_sangre": "O+", "alergias": ["Penicilina"], "programas": ["cronico"],
  // solo cuidador (QR del paciente que lo tiene asignado):
  "codigo_qr": "...",
  // solo médico:
  "cedula": "1234567", "clinica": "texto libre" }
```

- 2xx = cuenta creada.
- 409 = el correo ya existe.
- Si deciden que las cuentas solo las crea el equipo de salud, respondan 404 y la app muestra "Pide tu cuenta a tu equipo de salud".
- Relacionado: `GET /registro/qr/:codigo` sin sesión, que devuelva `{paciente: "María L.", cuidador_asignado: {nombre} | null}`.

### 2. Plan de control del médico: `GET` y `PUT /pacientes/:id/plan`

```json
{ "rangos": [
  { "variable": "presion", "activo": true, "frecuencia": "diaria",
    "min": 90, "max": 140, "min2": 60, "max2": 90, "meta": "texto opcional" },
  { "variable": "glucosa", "activo": true, "frecuencia": "diaria", "min": 70, "max": 180 } ] }
```

- `frecuencia`: `diaria` | `dos_al_dia` | `semanal`.
- En presión, `min/max` es la sistólica y `min2/max2` la diastólica.
- Variables posibles: `presion`, `glucosa`, `frecuencia_cardiaca`, `temperatura`, `peso`.
- La app también lee `minimo`, `maximo`, `valor_min` y `valor_max`.
- Este `GET` también debe traer las `preguntas` del día, como hoy.

### 3. Consentimiento en `POST /pacientes`

- `GET /aviso-privacidad` debe traer siempre `version` y el `texto` oficial. Hoy llega `texto: null` y la app muestra un texto provisional.
- Sin `version`, la app ya no deja dar de alta al paciente.
- Propuesta para registrar quién firmó: `consentimiento: {version, aceptado: true, firmado_por: "Nombre completo", es_representante: true|false}`.

## Importante

4. **Fin de tratamiento en `GET /pacientes/:id/horarios`:** agregar `fecha_fin` (o `dias_restantes`) por horario. Sin eso, las alarmas siguen sonando hasta que la persona abre la app.
5. **Toma sin respuesta:** ¿la API marca sola como `omitida` una toma sin respuesta a los 30 minutos? Si no, propongo que la app envíe `POST …/tomas` con `estado: omitida, motivo: "sin_respuesta"`.
6. **Código corto del QR:** agregar `codigo_corto` (6 a 8 caracteres) en `GET /pacientes/:id/qr`, y que `GET /qr/:codigo` también lo acepte. Sirve para escribirlo a mano cuando el lector no lee el QR.
7. **Errores 422 con `error.codigo` específico** (por ejemplo `valor_fuera_de_rango` o `documento_ilegible`). Hoy un 422 genérico hace que la app diga "No se pudo leer la receta" en cualquier pantalla.

## Cuando puedan

8. **Preferencias de cuidador y equipo:** `PUT /auth/yo/preferencias` (o dentro de `PATCH /auth/yo`). Hoy solo existe la del paciente, así que la app guarda las de los demás solo en el teléfono. Agregar también `pictogramas` y `botones_grandes`.
9. **Cerrar sesión:** `DELETE /dispositivos/:token_fcm`, para que el teléfono deje de recibir push de esa cuenta.
10. **Editar perfil:** `PATCH /auth/yo`, `PATCH /pacientes/:id` y `POST /auth/yo/foto`.
11. **Claves de programa:** confirmar si la de oncología es `oncologia`, y las demás claves.
12. **Cuidador en `GET /pacientes/:id`:** que `cuidadores[].telefono` venga con número. La app ya lo usa para el botón "Pedir ayuda a mi cuidador".

## Cómo trata la app los errores

- Reenvía los registros sin conexión con el mismo `id_local`: **409 o `repetido: true` = ya estaba guardado**.
- 401, 408, 429 y 5xx se reintentan después.
- Cualquier otro 4xx se aparta y se le avisa a la persona.
