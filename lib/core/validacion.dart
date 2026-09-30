// Validación de credenciales, formularios y verosimilitud de los datos.
// Funciones puras (sin widgets): devuelven el texto del error o null si el dato es válido.
// La API vuelve a validar todo (400 con campos); esto evita envíos inútiles y errores de dedo.

import 'tr.dart';

final _correo = RegExp(r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$");
final _nombre = RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñÄËÏÖäëïöÂÊÎÔÛâêîôûÀÈÌÒÙàèìòù' .-]+$");
final _cedula = RegExp(r'^\d{7,8}$');
final _codigoQr = RegExp(r'^[A-Za-z0-9_-]{4,200}$');

/// Solo dígitos (quita espacios, guiones, paréntesis y la lada +52).
String soloDigitos(String s) => s.replaceAll(RegExp(r'\D'), '');

String? validarCorreo(String s) {
  final t = s.trim();
  if (t.isEmpty) return tr('Escribe tu correo.');
  if (t.length > 254 || !_correo.hasMatch(t)) return tr('Escribe un correo válido, por ejemplo nombre@correo.com.');
  return null;
}

/// Contraseña de cuenta nueva: 8 a 72 caracteres (límite de bcrypt), con letras y números.
String? validarContrasenaNueva(String s) {
  if (s.length < 8) return tr('La contraseña debe tener al menos 8 caracteres.');
  if (s.length > 72) return tr('La contraseña no puede tener más de 72 caracteres.');
  if (!RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]').hasMatch(s) || !RegExp(r'\d').hasMatch(s)) {
    return tr('La contraseña debe combinar letras y números.');
  }
  return null;
}

/// Nombre completo: al menos nombre y apellido, solo letras (con acentos), espacios, apóstrofo, punto y guion.
String? validarNombre(String s, {String? campo}) {
  final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
  final quien = campo ?? tr('tu nombre');
  if (t.isEmpty) return tr('Escribe {campo}.', {'campo': quien});
  if (t.length > 100) return tr('El nombre es demasiado largo.');
  if (!_nombre.hasMatch(t)) return tr('El nombre solo puede llevar letras y espacios.');
  if (t.split(' ').where((p) => p.replaceAll(RegExp(r"[.'-]"), '').length >= 2).length < 2) {
    return tr('Escribe nombre y apellido.');
  }
  return null;
}

/// Teléfono de México: 10 dígitos (se acepta +52 o 52 al inicio). Vacío es válido si no es obligatorio.
String? validarTelefono(String s, {bool obligatorio = false}) {
  var d = soloDigitos(s);
  if (d.isEmpty) return obligatorio ? tr('Escribe un teléfono.') : null;
  if (d.length == 12 && d.startsWith('52')) d = d.substring(2);
  if (d.length != 10) return tr('El teléfono debe tener 10 dígitos.');
  if (RegExp(r'^(\d)\1{9}$').hasMatch(d)) return tr('Revisa el teléfono: no parece real.');
  return null;
}

/// Cédula profesional (SEP): 7 u 8 dígitos. La API la coteja; aquí solo se revisa el formato.
String? validarCedula(String s) =>
    _cedula.hasMatch(s.trim()) ? null : tr('La cédula profesional debe tener 7 u 8 dígitos.');

/// Código QR de la app (token opaco): letras, números, guion y guion bajo. Evita que un QR falso
/// arme otra ruta de la API.
bool codigoQrValido(String s) => _codigoQr.hasMatch(s.trim());

int edadEn(DateTime nacimiento, [DateTime? hoy]) {
  final h = hoy ?? DateTime.now();
  var e = h.year - nacimiento.year;
  if (h.month < nacimiento.month || (h.month == nacimiento.month && h.day < nacimiento.day)) e--;
  return e;
}

String? validarNacimiento(DateTime? f, [DateTime? hoy]) {
  if (f == null) return tr('Elige la fecha de nacimiento.');
  final h = hoy ?? DateTime.now();
  if (f.isAfter(h)) return tr('La fecha de nacimiento no puede ser futura.');
  if (edadEn(f, h) > 120) return tr('Revisa la fecha de nacimiento: la edad pasa de 120 años.');
  return null;
}

/// Coherencia entre programa, sexo y edad (para que el semáforo aplique las reglas correctas).
String? validarProgramas(Set<String> programas, {String? sexo, DateTime? nacimiento, DateTime? hoy}) {
  if (programas.isEmpty) return tr('Elige al menos un programa de cuidado.');
  final edad = nacimiento == null ? null : edadEn(nacimiento, hoy);
  if (programas.contains('embarazo')) {
    if (sexo != null && sexo != 'F') return tr('El programa de embarazo y puerperio solo aplica a mujeres.');
    if (edad != null && (edad < 10 || edad > 60)) return tr('Revisa la fecha de nacimiento: la edad no corresponde a un embarazo.');
  }
  if (programas.contains('adulto_mayor') && edad != null && edad < 60) {
    return tr('El programa de adulto mayor es para personas de 60 años o más.');
  }
  return null;
}

// ---------- verosimilitud de mediciones ----------

/// Límites de lo físicamente posible (fuera de esto es un error de dedo) y zona "inusual",
/// donde el valor es posible pero conviene que la persona confirme el número antes de enviarlo.
class RangoMedicion {
  final num min, max, inusualBajo, inusualAlto; final bool entero;
  const RangoMedicion(this.min, this.max, this.inusualBajo, this.inusualAlto, {this.entero = false});
}

const rangosMedicion = {
  'sistolica': RangoMedicion(50, 300, 80, 180, entero: true),
  'diastolica': RangoMedicion(20, 200, 40, 110, entero: true),
  'glucosa': RangoMedicion(20, 600, 54, 300, entero: true), // los glucómetros leen de 20 a 600 mg/dL
  'peso': RangoMedicion(2, 350, 30, 200),
  'temperatura': RangoMedicion(30, 45, 35, 39.5),
  'frecuencia_cardiaca': RangoMedicion(25, 250, 45, 130, entero: true),
};

String _num(num n) => n % 1 == 0 ? '${n.toInt()}' : '$n';

/// null si el valor es posible; si no, el error para la persona. [variable] usa las claves de [rangosMedicion].
String? validarMedicion(String variable, num valor) {
  final r = rangosMedicion[variable];
  if (r == null) return valor < 0 ? tr('El número no puede ser negativo.') : null;
  if (r.entero && valor % 1 != 0) return tr('Escribe un número entero, sin decimales.');
  if (valor < r.min || valor > r.max) {
    return tr('Revisa el número: debe estar entre {min} y {max}.', {'min': _num(r.min), 'max': _num(r.max)});
  }
  return null;
}

bool medicionInusual(String variable, num valor) {
  final r = rangosMedicion[variable];
  return r != null && (valor < r.inusualBajo || valor >= r.inusualAlto);
}

/// Presión: cada número en su rango y la sistólica mayor que la diastólica.
String? validarPresion(num sistolica, num diastolica) {
  final e = validarMedicion('sistolica', sistolica) ?? validarMedicion('diastolica', diastolica);
  if (e != null) return e;
  if (diastolica >= sistolica) return tr('El número de arriba debe ser mayor que el de abajo.');
  return null;
}

/// Presión posible pero rara (o una diferencia menor a 10 mmHg entre ambos números): se pide confirmar.
bool presionInusual(num sistolica, num diastolica) => medicionInusual('sistolica', sistolica) ||
    medicionInusual('diastolica', diastolica) || sistolica - diastolica < 10;
