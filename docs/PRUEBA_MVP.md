# Cómo probar el MVP de SENDA

Rama: `senda-pendientes-xif7dt`. Se puede probar de dos maneras:

- **Modo demo:** sin servidor, con datos de ejemplo. Sirve para enseñar la app y revisar las pantallas.
- **Con el servidor:** usa la API real.

## 1. Preparar (una vez, en la computadora)

```bash
git fetch origin senda-pendientes-xif7dt
git checkout senda-pendientes-xif7dt
git pull origin senda-pendientes-xif7dt
flutter pub get
flutter devices            # el celular debe aparecer (depuración USB activada)
```

Si la compilación falla por caché, corre `flutter clean`, luego `flutter pub get` y repite. En iOS, además: `cd ios && pod install`.

## 2. Instalar en el celular

**Modo demo (sin servidor):**
```bash
flutter run --release -d <id-del-celular>
```

**Con el servidor:** copia `config/api.example.json` a `config/api.json` y escribe ahí la URL y la contraseña de demo
de la guía de integración. Ese archivo no se sube a GitHub. Después:
```bash
flutter run --release -d <id-del-celular> --dart-define-from-file=config/api.json
```

**En el navegador (rápido, sin alarmas ni cámara):** `flutter run -d chrome`.

**Para repartir el APK:** `flutter build apk --release --dart-define-from-file=config/api.json`.
El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`.

## 3. Cuentas de demo

En el inicio de sesión, los botones **"Entrar como…"** entran sin escribir nada.

| Rol | Correo | Qué ve |
|---|---|---|
| Paciente | `maria@demo.invalid` | Hoy, Registrar, Medicamentos, Historial, Perfil |
| Cuidador | `rosa@demo.invalid` | Alertas, Medicamentos e Historial de su familiar |
| Equipo (médica) | `medica@demo.invalid` | Alertas, Pacientes, Escanear QR, Perfil |

- En modo demo cualquier contraseña funciona.
- Con el servidor se usa la contraseña de la guía (la que pusiste en `config/api.json`).
- Códigos QR de demo, para "Escribir código": `PQR-DEMO-maria-embarazo`, `PQR-DEMO-juan-oncologia` y `PQR-DEMO-carmen-adultomayor`.

## 4. Recorrido de prueba (unos 20 min)

Marca cada punto. Si algo falla, anota la pantalla, qué hiciste y una captura.

### Paciente
- [ ] **Hoy:** se ven las tomas del día y los botones "Mostrar mi código QR" y "Seguimiento de heridas".
- [ ] **Registrar presión 120/80:** resultado verde.
- [ ] **Registrar 150/95:** ámbar. **180/110:** rojo. En rojo, "Pedir ayuda a mi cuidador" ofrece llamar a Rosa y al 911.
- [ ] **Registrar 1200/80:** la app lo rechaza o pide confirmar; no se envía sin revisar.
- [ ] **Toma:** "Ya la tomé", "Más tarde" (10/30/60 min) y "No me la tomé" (pide motivo).
- [ ] **Alarma:** crea una toma próxima (o espera una). Debe sonar y vibrar incluso con la pantalla bloqueada.
- [ ] **Receta:** foto o galería, revisar lo leído y confirmar horarios. El botón Atrás regresa un paso.
- [ ] **Cámara sin permiso:** niega el permiso en Ajustes y abre la receta. Debe salir el aviso con el botón "Ir a Ajustes".
- [ ] **QR:** se ve el código y el brillo sube al máximo.
- [ ] **Historial:** gráfica de presión y glucosa por día, semana y mes.
- [ ] **Preferencias:** letra grande, alto contraste e idioma inglés. Cierra la app por completo y ábrela: deben seguir igual.

### Sin internet
- [ ] **Modo avión (o "Simular sin conexión" en Sincronización):** registra una medición. Debe decir "guardado en el teléfono".
- [ ] **Cerrar y abrir sin red:** con la app cerrada por completo, al abrirla sigue el pendiente. Hoy y Medicamentos muestran lo último guardado con el aviso "Sin conexión".
- [ ] **Volver a conectar:** se envía solo y el pendiente desaparece.

### Cuidador
- [ ] **Alertas:** se ven las ámbar de sus familiares. Si tiene más de uno, el selector de paciente arriba cambia todo.
- [ ] **Atender una alerta:** queda atendida. Si otra persona ya la atendió, lo dice.

### Equipo (médica)
- [ ] **Pacientes:** los rojos aparecen primero. Abrir uno muestra perfil, medicación, adherencia e historial.
- [ ] **Plan de control:** activa presión, pon 90–140 / 60–90, frecuencia diaria y guarda. Un mínimo mayor que el máximo debe marcar error.
- [ ] **Escanear QR:** escanea el QR del paciente (desde otro teléfono) o escribe un código de demo.
- [ ] **Alta de paciente:** datos, programa, cuidador, preferencias, consentimiento y QR. Sin conexión no deja continuar.

### Sesión y seguridad
- [ ] **Huella:** actívala en Perfil. Cierra la app y ábrela: pide la huella. En el inicio de sesión, "Entrar con huella" solo aparece si está activa.
- [ ] **Bloqueo al volver:** deja la app más de 5 min en segundo plano y vuelve. Debe pedir la huella.
- [ ] **Cerrar sesión y entrar con otra cuenta:** no quedan datos ni alarmas de la anterior.
- [ ] **Crear cuenta:** el formulario vacío marca errores. Con el servidor, si aún no permite crear cuentas, lo explica.

## 5. Pruebas automáticas

```bash
flutter analyze                                  # sin avisos
flutter test                                     # 100 pruebas
flutter test integration_test -d <id-del-celular>   # inicio de sesión y crear cuenta en el teléfono
```

## 6. Si algo falla con el servidor

En **Perfil > Diagnóstico de conexión** se prueban los endpoints con la sesión actual. Al terminar, "copiar reporte"
genera un texto que solo tiene la forma de las respuestas: sin token, sin URL y sin datos. Ese texto se le manda
a quien lleva el backend, junto con `docs/SOLICITUDES_BACKEND.md`.

## Lo que todavía no funciona igual que en producción

- **Crear cuenta y plan de control:** dependen de endpoints que backend aún no confirma (ver `docs/SOLICITUDES_BACKEND.md`).
- **Aviso de privacidad y consentimiento:** los textos son provisionales.
- **Alarmas:** siguen sonando hasta que se abre la app, aunque el tratamiento ya haya terminado (falta `fecha_fin`).
- **Push:** necesita los archivos de Firebase (`docs/NOTIFICACIONES.md`); sin ellos la app funciona sin push.
- **Hñähñu:** solo están los mensajes clínicos; las pantallas salen en español.
