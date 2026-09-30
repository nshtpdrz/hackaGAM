import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Idiomas MVP. 'ote' = Hñähñu/Otomí del Mezquital (parte de accesibilidad, no un traductor).
const langs = {'es': 'Español', 'en': 'English', 'ote': 'Hñähñu (Otomí del Mezquital)'};

class Msg {
  /// [interprete]: la frase aún no está validada en la lengua pedida; se muestra en español con aviso de intérprete.
  final String text; final String? audioUrl, pictogram; final bool interprete;
  const Msg(this.text, {this.audioUrl, this.pictogram, this.interprete = false});
}

/// Catálogo local + GET /mensajes. La API solo devuelve message_key.
class Catalog {
  final Map<String, Map<String, Msg>> _m = {};
  static const _base = <String, Map<String, String>>{
    'es': {'app.tagline': 'Tu tratamiento, más claro.', 'login.email': 'Correo electrónico',
      'login.pass': 'Contraseña', 'login.go': 'Iniciar sesión', 'login.bio': 'Entrar con huella',
      'login.register': 'Crear cuenta', 'listen': 'Escuchar indicaciones', 'semaforo.verde': 'Estable',
      'semaforo.ambar': 'Precaución', 'semaforo.rojo': 'Alerta: busca ayuda',
      'help.caregiver': 'Pedir ayuda a mi cuidador', 'next': 'Siguiente', 'prev': 'Anterior', 'save': 'Guardar',
      'preg.sistole': '¿Cuánto marca la presión de arriba (sístole)?', 'preg.diastole': '¿Cuánto marca la presión de abajo (diástole)?',
      'preg.glucosa': '¿Cuánto marca tu glucosa?', 'preg.presion': '¿Cuánto marca tu presión? Escribe el número de arriba y el de abajo.',
      'preg.cefalea': '¿Tienes dolor de cabeza?', 'resultado.faltan_datos': 'Guardamos tus datos, pero faltan algunos para evaluarlos. Contesta las preguntas que faltan.',
      'resultado.registrado': 'Guardamos tu registro. Tu equipo de salud lo revisará.', 'res.verde': 'Tus valores están bien. Sigue con tu tratamiento.',
      'res.ambar': 'Tu presión está un poco alta. Descansa y mídete de nuevo en 30 minutos.',
      'res.rojo': 'Tu presión está muy alta. Llama a tu cuidador o acude a urgencias.',
      'med.losartan': 'Losartán: toma una tableta por la mañana.', 'med.metformina': 'Metformina: toma una tableta cada 12 horas con alimentos.',
      'adv.revisar': 'Revisa con tu médico antes de confirmar este medicamento.',
      'alerta.presion': 'Presión muy alta registrada.', 'alerta.omision': 'Dos tomas de medicamento omitidas seguidas.',
      'consent.privacidad': 'Texto provisional: tus datos de salud se usan solo para dar seguimiento a tu tratamiento. Solo los ve tu equipo de salud y las personas que tú autorices. Sustituir por el aviso de privacidad oficial.',
      'consent.informado': 'Texto provisional: aceptas que esta app registre tus mediciones y tomas de medicamento, y que tu equipo de salud las revise. Puedes retirar tu consentimiento. Sustituir por el texto oficial.'},
    'en': {'app.tagline': 'Your treatment, made clear.', 'login.email': 'Email', 'login.pass': 'Password',
      'login.go': 'Sign in', 'login.bio': 'Use fingerprint', 'login.register': 'Create account',
      'listen': 'Listen to instructions', 'semaforo.verde': 'Stable', 'semaforo.ambar': 'Caution',
      'semaforo.rojo': 'Alert: get help', 'help.caregiver': 'Ask my caregiver for help',
      'next': 'Next', 'prev': 'Back', 'save': 'Save',
      'preg.sistole': 'What is your top blood pressure number (systolic)?', 'preg.diastole': 'What is your bottom blood pressure number (diastolic)?',
      'preg.glucosa': 'What is your glucose reading?', 'preg.presion': 'What is your blood pressure? Enter the top and bottom numbers.',
      'preg.cefalea': 'Do you have a headache?', 'resultado.faltan_datos': 'We saved your data, but some is missing to evaluate it. Answer the remaining questions.',
      'resultado.registrado': 'We saved your record. Your health team will review it.', 'res.verde': 'Your values are fine. Keep following your treatment.',
      'res.ambar': 'Your pressure is a bit high. Rest and measure again in 30 minutes.',
      'res.rojo': 'Your pressure is very high. Call your caregiver or go to the emergency room.',
      'med.losartan': 'Losartan: take one tablet in the morning.', 'med.metformina': 'Metformin: take one tablet every 12 hours with food.',
      'adv.revisar': 'Check with your doctor before confirming this medication.',
      'alerta.presion': 'Very high blood pressure recorded.', 'alerta.omision': 'Two medication doses missed in a row.',
      'consent.privacidad': 'Provisional text: your health data is used only to follow your treatment. Only your health team and the people you authorize can see it. Replace with the official privacy notice.',
      'consent.informado': 'Provisional text: you agree that this app records your measurements and medication intake and that your health team reviews them. You can withdraw consent. Replace with the official text.'},
    'ote': {}, // se llena desde /mensajes (texto + audio + pictograma); cae a español si falta
  };
  Catalog() { _base.forEach((l, e) => _m[l] = {for (final k in e.keys) k: Msg(e[k]!)}); }

  /// Recibe la lista ya normalizada de GET /mensajes ([{key, text, audio_url, pictogram, interprete}]).
  void merge(String lang, dynamic json) {
    for (final e in (json as List)) {
      if (e['key'] == null) continue;
      (_m[lang] ??= {})[e['key']] = Msg('${e['text'] ?? ''}', audioUrl: e['audio_url'], pictogram: e['pictogram'],
          interprete: e['interprete'] == true);
    }
  }
  bool tiene(String lang, String key) => _m[lang]?[key] != null || _m['es']?[key] != null;
  /// Si la clave no existe en ningún catálogo se usa [respaldo] (o la propia clave).
  Msg get(String lang, String key, {String? respaldo}) => _m[lang]?[key] ?? _m['es']?[key] ?? Msg(respaldo ?? key);
}

final catalogProvider = Provider<Catalog>((_) => Catalog());

/// Sube cuando se carga /mensajes, para que los textos se refresquen.
final catalogVersionProvider = StateProvider<int>((_) => 0);
