// Integración con el backend (Guía de conexión del frontend, /api/v1): adaptadores y flujo completo contra el mock,
// que responde con las mismas formas que la API real.
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medmap/core/api.dart';
import 'package:medmap/core/api_modelos.dart';
import 'package:medmap/core/state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('Adaptadores', () {
    test('GET /auth/yo: roles y pacientes a cargo', () {
      final y = normalizarYo({'usuario': {'id': 7, 'nombre': 'Pedro', 'rol': 'cuidador'},
        'pacientes_a_cargo': [{'id': 1, 'nombre': 'María'}, {'id': 3, 'nombre': 'Carmen'}]});
      expect(y['rol'], 'cuidador'); expect(y['paciente_id'], '1'); expect((y['pacientes_a_cargo'] as List).length, 2);
      expect(normalizarYo({'usuario': {'id': 1, 'rol': 'enfermera'}, 'pacientes_a_cargo': []})['rol'], 'equipo');
      final m = normalizarYo({'usuario': {'id': 2, 'rol': 'medico', 'cedula': 'DEMO-0000001'}, 'pacientes_a_cargo': []});
      expect(m['rol_api'], 'medico'); expect(m['cedula_verificada'], true);
    });

    test('Preferencias: lengua ISO 639-3, letra y contraste', () {
      final p = const Prefs(lang: 'ote', textScale: 1.4, highContrast: true, audio: true).toJson();
      expect(p, containsPair('lengua', 'ote')); expect(p['letra'], 'grande'); expect(p['contraste'], 'alto'); expect(p['prefiere_audio'], true);
      final q = Prefs.fromJson({'lengua': 'spa', 'letra': 'muy_grande', 'contraste': 'normal'}, const Prefs(pictograms: true));
      expect(q.lang, 'es'); expect(q.textScale, 1.8); expect(q.pictograms, true); // pictogramas: solo en el teléfono
    });

    test('Registro: lote con id_local y presión en valor_num/valor_num2', () {
      final r = registroParaApi('presion', 'medicion', [150, 95], '2026-09-30T14:00:00Z');
      expect(r['valor_num'], 150); expect(r['valor_num2'], 95); expect(r['tomado_en'], '2026-09-30T14:00:00Z');
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(r['id_local']), true);
      expect(registroParaApi('cefalea', 'sintoma', 3, 'x')['escala'], 3);
    });

    test('Resultado: nivel, mensaje_clave e incompleta', () {
      expect(normalizarResultado({'nivel': 'rojo', 'mensaje_clave': 'res.rojo', 'estado': 'completa'})['semaforo'], 'rojo');
      final inc = normalizarResultado({'nivel': null, 'estado': 'incompleta', 'faltantes': ['cefalea', 'rango:presion']});
      expect(inc['message_key'], 'resultado.faltan_datos'); expect(inc['faltantes'], hasLength(2));
    });

    test('Serie de registros -> historial', () {
      final l = normalizarRegistros({'registros': [
        {'id': 1, 'tipo': 'medicion', 'variable': 'presion', 'valor_num': 130, 'valor_num2': 85, 'tomado_en': '2026-09-29T14:00:00Z', 'nivel': 'verde'},
        {'id': 2, 'tipo': 'medicion', 'variable': 'glucosa', 'valor_num': 110, 'tomado_en': '2026-09-29T14:00:00Z', 'nivel': 'verde'}],
        'siguiente_cursor': null});
      expect(l.first['valores'], {'sistole': 130, 'diastole': 85}); expect(l.last['valores'], {'glucosa': 110});
    });

    test('Horarios: tomas de hoy con horario_id y programada_en; loteToma', () {
      final hoy = DateTime.now(); String utc(int h, [int d = 0]) => DateTime(hoy.year, hoy.month, hoy.day + d, h).toUtc().toIso8601String();
      final t = normalizarHorarios({'horarios': [{'id': 'h1', 'hora_local': '08:00',
          'medicamento': {'nombre_comercial': 'Losartán', 'concentracion': '50 mg', 'dosis': '1 tableta'}}],
        'tomas': [{'horario_id': 'h1', 'programada_en': utc(8), 'estado': 'pendiente'}, {'horario_id': 'h1', 'programada_en': utc(8, 1), 'estado': 'pendiente'}]});
      expect(t, hasLength(1)); // solo hoy
      expect(t.first['hora'], '08:00'); expect(t.first['medicamento'], 'Losartán 50 mg'); expect(t.first['horario_id'], 'h1');
      final lote = loteToma(t.first, 'omitida', motivo: 'olvido');
      final x = (lote['tomas'] as List).first as Map;
      expect(x['horario_id'], 'h1'); expect(x['programada_en'], utc(8)); expect(x['estado'], 'omitida'); expect(x['motivo'], 'olvido');
      expect(x['id_local'], isNotNull);
    });

    test('MEDMAP: propuesta y confirmación (sin sustancia_id nulo)', () {
      final d = normalizarDocumento({'id': 'd1', 'medicamentos': [
        {'nombre_comercial': 'Naproxeno', 'sustancia': {'id': 's1'}, 'concentracion': '250 mg', 'frecuencia_horas': 8, 'horarios_propuestos': ['06:00', '14:00']},
        {'nombre_comercial': 'Xyzamol', 'sustancia': {'id': null}, 'por_revisar': true, 'horarios_propuestos': []}],
        'alertas_medicacion': [{'nivel': 'ambar'}, {'nivel': 'rojo'}]});
      expect(d['advertencias'].first['nivel'], 'rojo'); // rojo primero
      final c = confirmacionDocumento(d['medicamentos']);
      final meds = c['medicamentos'] as List;
      expect(meds.first['sustancia_id'], 's1'); expect(meds.first['horarios'], ['06:00', '14:00']);
      expect((meds.last as Map).containsKey('sustancia_id'), false);
      expect(c['reemplaza'], isEmpty);
    });

    test('Mensajes: cadena de respaldo con aviso de intérprete', () {
      final m = normalizarMensajes({'mensajes': [{'clave': 'res.ambar', 'texto': 'Descansa', 'respaldo': 'espanol', 'requiere_interprete': true}]});
      expect(m.first['key'], 'res.ambar'); expect(m.first['interprete'], true);
    });

    test('Errores {error: {codigo, mensaje, campos}}', () {
      final e = DioException(requestOptions: RequestOptions(path: '/x'), response: Response(requestOptions: RequestOptions(path: '/x'),
        statusCode: 503, data: {'error': {'codigo': 'ocr_no_disponible', 'mensaje': 'OCR apagado'}}));
      expect(errorApi(e)!.codigo, 'ocr_no_disponible');
      expect(mensajeError(e), contains('Escribe la receta'));
    });
  });

  group('Flujo completo en modo demo (mismas formas que la API)', () {
    test('login -> plan -> registro (y reintento sin duplicar) -> tomas -> receta -> alertas', () async {
      final api = Api();
      final l = await api.login('maria@demo.invalid', 'demo');
      expect(l['usuario']['rol'], 'paciente');
      await saveToken(l['token']);
      final yo = await api.yo(); expect(yo['paciente_id'], '1');

      final plan = await api.plan('1');
      expect((plan['preguntas'] as List).map((q) => q['variable']), containsAll(['presion', 'glucosa']));

      final lote = {'registros': [registroParaApi('presion', 'medicion', [150, 95], ahoraUtc()),
        registroParaApi('cefalea', 'sintoma', 4, ahoraUtc())]};
      final r1 = await api.crearRegistro('1', lote);
      expect(r1['semaforo'], 'rojo'); // presión alta + cefalea fuerte en el embarazo
      final r2 = await api.crearRegistro('1', lote); // mismo id_local: no duplica
      expect(r2['repetido'], true);

      final tomas = await api.horarios('1');
      expect(tomas, isNotEmpty); expect(tomas.first['horario_id'], isNotNull);
      final pos = await api.registrarToma('1', loteToma(tomas.first, 'pospuesta'));
      expect(pos, {'local': true}); // "Más tarde" no viaja a la API
      await api.registrarToma('1', loteToma(tomas.first, 'tomada'));
      final despues = await api.horarios('1');
      expect(despues.firstWhere((t) => t['horario_id'] == tomas.first['horario_id'])['estado'], 'tomada');

      final doc = await api.subirDocumento('1', bytes: Uint8List.fromList([1, 2, 3]), nombre: 'receta.jpg');
      expect(doc['id'], isNotNull); // viene en documento.id
      final meds = doc['medicamentos'] as List;
      expect(meds, hasLength(4)); expect(meds.last['por_revisar'], true); expect(meds.last['sustancia_ia'], true);
      expect(meds[1]['discrepancias'], {'dosis': ['2 ml', '12 ml']}); expect(meds[1]['lectura_dudosa'], true);
      expect(meds[1]['dosis'], ''); // null en la API: la persona lo completa
      expect(meds[2]['componentes'], hasLength(2));
      expect((doc['lectura'] as Map)['ilegibles'], 1); expect(doc['message_key'], 'interfaz.revise_que_su_medicina_este_bien');
      expect((doc['advertencias'] as List).first['verificada'], false);
      await api.confirmarDocumento('${doc['id']}', doc['medicamentos']);
      expect((await api.medicamentos('1')).map((m) => m['nombre']), contains('Metformina'));
      await expectLater(api.confirmarDocumento('${doc['id']}', doc['medicamentos']), // segunda vez: 409
          throwsA(predicate((e) => errorApi(e!)?.estado == 409)));
      expect((await api.adherencia('1'))['porcentaje'], 86);

      final alertas = await api.alertas();
      await api.atenderAlerta('${alertas.first['id']}', 'Se contactó al paciente');
      await expectLater(api.atenderAlerta('${alertas.first['id']}', 'otra vez'),
          throwsA(predicate((e) => errorApi(e!)?.estado == 409)));
    });

    test('Equipo: tablero con semáforo y QR', () async {
      final api = Api();
      await saveToken((await api.login('medica@demo.invalid', 'demo'))['token']);
      final yo = await api.yo(); expect(yo['rol'], 'equipo'); expect(yo['cedula_verificada'], true);
      final ps = await api.pacientes();
      expect(ps.first['semaforo'], 'rojo'); // rojos primero
      final q = await api.qrCodigo('PQR-DEMO-carmen-adultomayor');
      expect(q['paciente_id'], '3');
      final p = await api.paciente('3');
      expect(p['nombre'], 'Carmen Demo Sánchez'); expect(p['programas'], containsAll(['cronico', 'adulto_mayor']));
    });
  
  group('Heridas y MEDMAP (guía de integración)', () {
    test('confirmación: vía, días, frecuencia corregida y sustancia de IA sin id', () {
      final c = confirmacionDocumento([{'nombre': 'Paracetamol gotas', 'sustancia_id': null, 'dosis': '2 ml', 'via': 'oral',
        'frecuencia': 'cada 6 h', 'frecuencia_horas': 8, 'duracion_dias': 3, 'horarios': ['06:00']}]);
      final m = (c['medicamentos'] as List).first as Map;
      expect(m['frecuencia_horas'], 6); expect(m['via'], 'oral'); expect(m['dias'], [1, 2, 3, 4, 5, 6, 7]);
      expect(m.containsKey('sustancia_id'), false); expect(m['duracion_dias'], 3);
    });

    test('flujo de herida: registrar, foto con moneda y dos toques, detalle', () async {
      final api = Api();
      await saveToken((await api.login('maria@demo.invalid', 'demo'))['token']);
      final l = await api.crearLesion('1', {'tipo': 'pie_diabetico', 'zona_corporal': 'talon', 'lado': 'izquierdo'});
      expect(l['tipo'], 'pie_diabetico');
      final f = await api.subirFotoLesion('${l['id']}', bytes: Uint8List.fromList([1, 2, 3]), referencia: 'moneda_10_pesos',
          toqueReferencia: [120, 340], toqueLesion: [410, 380]);
      expect(tamanoLesion(f), '3.8 × 0.5 cm'); expect(f['message_key'], 'lesiones.foto_recibida');
      final sinRef = await api.subirFotoLesion('${l['id']}', bytes: Uint8List.fromList([1]), referencia: 'ninguna');
      expect(tamanoLesion(sinRef), isNull); expect(sinRef['message_key'], 'lesiones.use_referencia');
      final d = await api.lesion('${l['id']}');
      expect(d['fotos'], hasLength(2)); expect((await api.lesiones('1')).map((x) => x['id']), contains(l['id']));
    });
  });
});
}
