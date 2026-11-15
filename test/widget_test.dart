// Pruebas unitarias de la lógica que no depende de la UI ni de SQLite.
// Ejecutar con: flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:gdocente/utils/telefono.dart';

void main() {
  group('Telefono.normalizar', () {
    test('acepta área + número (10 dígitos)', () {
      expect(Telefono.normalizar('379 412-3456'), '5493794123456');
    });

    test('quita el 0 del código de área', () {
      expect(Telefono.normalizar('0379 4123456'), '5493794123456');
    });

    test('agrega el 9 si viene +54 sin 9', () {
      expect(Telefono.normalizar('+54 379 4123456'), '5493794123456');
    });

    test('deja igual un número ya normalizado', () {
      expect(Telefono.normalizar('+54 9 379 412 3456'), '5493794123456');
    });

    test('rechaza números incompletos', () {
      expect(Telefono.normalizar('4123456'), isNull);
      expect(Telefono.validar(''), isNotNull);
    });
  });

  test('Telefono.formatear', () {
    expect(Telefono.formatear('5493794123456'), '+54 9 379 412-3456');
  });
}
