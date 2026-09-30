// Traducciones de biometría, notificaciones push y Preferencias > Avisos y alarmas
// (se mantienen aparte para trabajar en paralelo). Clave = texto en español tal como aparece en tr('...').
const Map<String, Map<String, String>> traduccionesPlataforma = {'en': {
  // Biometría (lib/core/biometria.dart)
  'Confirma que eres tú para entrar a SENDA': 'Confirm it is you to open SENDA',
  'Este teléfono no tiene huella, rostro ni bloqueo de pantalla. Entra con tu contraseña.':
      'This phone has no fingerprint, face or screen lock. Log in with your password.',
  'No hay huella ni rostro registrados en este teléfono. Regístralos en Ajustes o entra con tu contraseña.':
      'No fingerprint or face is registered on this phone. Add one in Settings or log in with your password.',
  'Hubo demasiados intentos. Espera unos minutos o entra con tu contraseña.':
      'Too many attempts. Wait a few minutes or log in with your password.',
  'No se pudo confirmar tu identidad. Entra con tu contraseña.': 'We could not confirm it is you. Log in with your password.',
  'Entrar a SENDA': 'Open SENDA',
  'Toca el sensor de huella o mira la cámara': 'Touch the fingerprint sensor or look at the camera',
  'No se reconoció. Intenta de nuevo.': 'Not recognized. Try again.',
  'Se necesita tu huella o rostro': 'Your fingerprint or face is needed',
  'Se necesita el bloqueo de tu teléfono': 'Your phone lock is needed',
  'Configura un bloqueo de pantalla en los Ajustes del teléfono.': 'Set up a screen lock in your phone Settings.',
  'Ir a Ajustes': 'Go to Settings',
  'No hay huella ni rostro registrados. Regístralos en Ajustes > Seguridad.':
      'No fingerprint or face is registered. Add one in Settings > Security.',
  'Face ID o Touch ID está bloqueado. Bloquea y desbloquea el teléfono para activarlo.':
      'Face ID or Touch ID is locked. Lock and unlock your phone to turn it back on.',
  'No hay Face ID ni Touch ID configurado. Actívalo en Ajustes.': 'Face ID or Touch ID is not set up. Turn it on in Settings.',
  'Usar el código del teléfono': 'Use phone passcode',
  // Notificaciones (lib/core/reminders.dart, lib/core/push.dart)
  'Alertas de salud': 'Health alerts',
  'Avisos del equipo de salud y de tus familiares.': 'Messages from your health team and your family.',
  // Preferencias > Avisos y alarmas (lib/widgets/avisos_settings.dart)
  'Avisos y alarmas': 'Notifications and alarms',
  'Permitidas.': 'Allowed.',
  'Desactivadas: no sonarán las alarmas de tus medicinas ni llegarán avisos.':
      'Turned off: your medicine alarms will not ring and you will not get messages.',
  'Desactivadas: no llegarán los avisos de alertas.': 'Turned off: you will not get alert messages.',
  'Permitir': 'Allow',
  'Alarmas a la hora exacta': 'Alarms at the exact time',
  'Activadas.': 'Turned on.',
  'Las alarmas pueden sonar unos minutos tarde.': 'Alarms may ring a few minutes late.',
  'Activar': 'Turn on',
  'Alarma en pantalla completa': 'Full-screen alarm',
  'La alarma aparece aunque el teléfono esté bloqueado.': 'The alarm shows up even when the phone is locked.',
  'La alarma llegará como notificación, sin cubrir la pantalla.': 'The alarm will arrive as a notification, without covering the screen.',
  'Ahorro de batería': 'Battery saver',
  'Sin restricciones para SENDA.': 'No restrictions for SENDA.',
  'El teléfono puede retrasar o silenciar las alarmas y avisos. Elige "Sin restricciones" para SENDA.':
      'The phone may delay or silence alarms and messages. Choose "Unrestricted" for SENDA.',
  'En este teléfono activa también "Inicio automático" para SENDA.': 'On this phone also turn on "Autostart" for SENDA.',
  'Abrir ajustes': 'Open settings',
  'Falta': 'Missing',
  // Cola sin conexión (lib/core/sync.dart, pendientes_screen.dart)
  'No se pudieron enviar': 'Could not be sent',
  'Descartar': 'Discard',
  'Algunos datos no se pudieron enviar': 'Some data could not be sent',
  // Crear cuenta (register_screen.dart)
  'Por ahora las cuentas las crea tu equipo de salud. Pídeles tu usuario y contraseña.': 'For now, accounts are created by your health team. Ask them for your username and password.',
  'Sin conexión. Revisa tu internet e intenta de nuevo.': 'No connection. Check your internet and try again.',
  'Ya existe una cuenta con ese correo. Inicia sesión.': 'An account with that email already exists. Log in.',
  // Permisos de cámara y fotos (lib/core/permisos.dart, lector_qr.dart)
  'SENDA no tiene permiso de usar la cámara': 'SENDA does not have permission to use the camera',
  'SENDA no tiene permiso de ver tus fotos': 'SENDA does not have permission to see your photos',
  'Para tomar la foto, permite la cámara en los Ajustes del teléfono y vuelve a intentarlo.': 'To take the photo, allow the camera in your phone Settings and try again.',
  'Para elegir una foto, permite el acceso a fotos en los Ajustes del teléfono y vuelve a intentarlo.': 'To choose a photo, allow access to photos in your phone Settings and try again.',
  'Ahora no': 'Not now',
  'No se pudo abrir la cámara.': 'Could not open the camera.',
  'No se pudo abrir la galería.': 'Could not open the gallery.',
  'SENDA no tiene permiso de usar la cámara. Permítelo en Ajustes o usa "Escribir código".': 'SENDA does not have permission to use the camera. Allow it in Settings or use "Type code".',
  // Pedir ayuda al cuidador (lib/widgets/pedir_ayuda.dart)
  'No se pudo abrir el teléfono. Marca al {n}.': 'Could not open the phone app. Dial {n}.',
  'Pedir ayuda': 'Ask for help',
  'No tenemos el teléfono de tu cuidador. Pide a tu equipo de salud que lo registre.': 'We do not have your caregiver\'s phone number. Ask your health team to add it.',
  'No tenemos el teléfono de {nombre}. Pide a tu equipo de salud que lo registre.': 'We do not have {nombre}\'s phone number. Ask your health team to add it.',
  'Vamos a llamar a {nombre} al {tel}.': 'We will call {nombre} at {tel}.',
  'tu cuidador': 'your caregiver',
  'Si te sientes muy mal, llama al 911.': 'If you feel very sick, call 911.',
  'Llamar al 911': 'Call 911',
  'Llamar a mi cuidador': 'Call my caregiver',
  'Llamar a {nombre}': 'Call {nombre}',
  // Plan de control (lib/screens/equipo/plan_control_screen.dart)
  'Una vez al día': 'Once a day',
  'Dos veces al día': 'Twice a day',
  'Una vez a la semana': 'Once a week',
  '{v}: escribe el mínimo y el máximo{e}.': '{v}: enter the minimum and maximum{e}.',
  '{v}: los valores deben estar entre {a} y {b}.': '{v}: values must be between {a} and {b}.',
  '{v}: el mínimo debe ser menor que el máximo{e}.': '{v}: the minimum must be lower than the maximum{e}.',
  '(sistólica)': '(systolic)',
  '(diastólica)': '(diastolic)',
  'Plan de control guardado.': 'Monitoring plan saved.',
  'Mínimo': 'Minimum',
  'Máximo': 'Maximum',
  'Se le pide al paciente': 'Requested from the patient',
  'No se le pide': 'Not requested',
  'Sistólica (arriba)': 'Systolic (top)',
  'Rango normal': 'Normal range',
  'Diastólica (abajo)': 'Diastolic (bottom)',
  'Meta (opcional)': 'Goal (optional)',
  'Ej. bajar a menos de 130/80 en 3 meses': 'E.g. get below 130/80 in 3 months',
  'Elige qué mediciones pedir, cada cuándo y en qué rango están bien. Fuera de rango, el registro avisa a tu equipo.': 'Choose which measurements to request, how often and which range is fine. Out of range, the reading alerts your team.',
  'Guardando…': 'Saving…',
  'Guardar plan': 'Save plan',
  // Aviso de privacidad (consentimiento_screen.dart, alta_paciente_screen.dart)
  'No se recibió la versión del aviso de privacidad. Intenta más tarde.': 'The privacy notice version was not received. Try again later.',
  'No se pudo cargar el aviso de privacidad. Sin él no se puede continuar.': 'The privacy notice could not be loaded. You cannot continue without it.',
  // Copia sin conexión y Hoy sin tomas (shared.dart, hoy_screen.dart)
  'Sin conexión. Mostramos lo último guardado ({fecha} {hora}).': 'No connection. Showing the last saved data ({fecha} {hora}).',
  'Hoy no tienes tomas de medicamento.': 'You have no medication doses today.',
  // Valores poco probables al registrar (registrar_screen.dart)
  '¿Tu presión de arriba es {n}?': 'Is your top blood pressure number {n}?',
  '¿Tu presión de abajo es {n}?': 'Is your bottom blood pressure number {n}?',
  '¿Tu {v} es {n} {u}?': 'Is your {v} {n} {u}?',
  'Revisa el número': 'Check the number',
  'Si es correcto, confírmalo; si no, corrígelo.': 'If it is correct, confirm it; if not, fix it.',
  'Sí, es correcto': 'Yes, it is correct',
  'Corregir': 'Fix it',
  // Código bajo el QR y programa Oncología
  'Código': 'Code',
  'Oncología': 'Oncology',
  // Salir del flujo de receta (receta_flow_screen.dart)
  '¿Salir de la receta?': 'Leave the prescription?',
  'Se perderá lo que ya se leyó y revisaste.': 'What was read and what you reviewed will be lost.',
  'Salir': 'Leave',
  'Seguir aquí': 'Stay here',
}};
