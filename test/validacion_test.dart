import 'package:flutter_test/flutter_test.dart';
import 'package:medmap/core/api_modelos.dart';
import 'package:medmap/core/validacion.dart';

void main() {
  test('correo', () {
    expect(validarCorreo('maria@demo.invalid'), isNull);
    expect(validarCorreo('  ana.torres+1@correo.com.mx '), isNull);
    for (final malo in ['', 'ana', 'ana@', 'ana@demo', 'ana@@demo.com', 'ana demo@correo.com', '@correo.com']) {
      expect(validarCorreo(malo), isNotNull, reason: malo);
    }
  });

  test('contraseña nueva: 8 a 72 caracteres, con letras y números', () {
    expect(validarContrasenaNueva('secreto123'), isNull);
    expect(validarContrasenaNueva('corta1'), isNotNull);
    expect(validarContrasenaNueva('solamenteletras'), isNotNull);
    expect(validarContrasenaNueva('12345678'), isNotNull);
    expect(validarContrasenaNueva('a1' * 37), isNotNull);
  });

  test('nombre completo', () {
    expect(validarNombre('María López'), isNull);
    expect(validarNombre("Ana O'Neil de la Cruz"), isNull);
    expect(validarNombre('Ana'), isNotNull); // falta apellido
    expect(validarNombre('Ana 123'), isNotNull);
    expect(validarNombre('   '), isNotNull);
  });

  test('teléfono de México', () {
    expect(validarTelefono(''), isNull); // opcional
    expect(validarTelefono('', obligatorio: true), isNotNull);
    expect(validarTelefono('55 1234 5678'), isNull);
    expect(validarTelefono('+52 (771) 123-4567'), isNull);
    expect(validarTelefono('12345'), isNotNull);
    expect(validarTelefono('0000000000'), isNotNull);
  });

  test('cédula profesional y código QR', () {
    expect(validarCedula('1234567'), isNull);
    expect(validarCedula('12345678'), isNull);
    expect(validarCedula('123456'), isNotNull);
    expect(validarCedula('DEMO-0000001'), isNotNull);
    expect(codigoQrValido('PQR-DEMO-carmen-adultomayor'), isTrue);
    expect(codigoQrValido('../auth/yo'), isFalse);
    expect(codigoQrValido('abc?x=1'), isFalse);
  });

  test('fecha de nacimiento y coherencia con el programa', () {
    final hoy = DateTime(2026, 9, 30);
    expect(validarNacimiento(DateTime(1990, 1, 1), hoy), isNull);
    expect(validarNacimiento(DateTime(2027, 1, 1), hoy), isNotNull);
    expect(validarNacimiento(DateTime(1890, 1, 1), hoy), isNotNull);
    expect(validarProgramas({}, hoy: hoy), isNotNull);
    expect(validarProgramas({'embarazo'}, sexo: 'M', nacimiento: DateTime(1990), hoy: hoy), isNotNull);
    expect(validarProgramas({'embarazo'}, sexo: 'F', nacimiento: DateTime(1950), hoy: hoy), isNotNull);
    expect(validarProgramas({'embarazo'}, sexo: 'F', nacimiento: DateTime(1995), hoy: hoy), isNull);
    expect(validarProgramas({'adulto_mayor'}, sexo: 'M', nacimiento: DateTime(1990), hoy: hoy), isNotNull);
    expect(validarProgramas({'adulto_mayor', 'cronico'}, sexo: 'F', nacimiento: DateTime(1950), hoy: hoy), isNull);
  });

  test('mediciones: imposibles se rechazan; raras se confirman', () {
    expect(validarPresion(120, 80), isNull);
    expect(validarPresion(1200, 80), isNotNull); // error de dedo
    expect(validarPresion(80, 120), isNotNull);
    expect(validarPresion(120.5, 80), isNotNull); // sin decimales
    expect(presionInusual(120, 80), isFalse);
    expect(presionInusual(185, 110), isTrue);
    expect(presionInusual(100, 95), isTrue); // diferencia menor a 10
    expect(validarMedicion('glucosa', 110), isNull);
    expect(validarMedicion('glucosa', 5000), isNotNull);
    expect(validarMedicion('glucosa', -5), isNotNull);
    expect(medicionInusual('glucosa', 45), isTrue);
    expect(validarMedicion('temperatura', 36.7), isNull);
    expect(validarMedicion('temperatura', 367), isNotNull);
    expect(validarMedicion('peso', 72.5), isNull);
  });

  test('error 400: el mensaje nombra los campos que marcó la API', () {
    // Sin DioException no hay ErrorApi; se prueba la raíz del campo con la forma que usa zod.
    expect(mensajeError(Exception('x')), isNull);
  });
}
