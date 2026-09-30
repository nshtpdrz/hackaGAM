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
}};
