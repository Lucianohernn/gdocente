import 'package:flutter_test/flutter_test.dart';
import 'package:gdocente/services/backup_service.dart';

void main() {
  group('BackupService', () {
    final ahora = DateTime(2026, 11, 17, 9, 0);

    test('toca backup si nunca se hizo o pasaron 24 horas', () {
      expect(BackupService.tocaBackup(null, ahora), isTrue);
      expect(
          BackupService.tocaBackup(
              ahora.subtract(const Duration(hours: 23)), ahora),
          isFalse);
      expect(
          BackupService.tocaBackup(
              ahora.subtract(const Duration(hours: 24)), ahora),
          isTrue);
    });

    test('conserva los 7 más nuevos y borra el resto', () {
      final todos = [
        for (var i = 0; i < 10; i++)
          BackupDrive('b$i', ahora.subtract(Duration(days: i)), 'Android', 1),
      ]..shuffle();
      final borrar = BackupService.aBorrar(todos, 7);
      expect(borrar.map((b) => b.id), unorderedEquals(['b7', 'b8', 'b9']));
      expect(BackupService.aBorrar(todos.take(3).toList(), 7), isEmpty);
    });

    test('reconoce un archivo SQLite y rechaza otros', () {
      final sqlite = [...'SQLite format 3'.codeUnits, 0, ...List.filled(90, 0)];
      expect(BackupService.esBaseSqlite(sqlite), isTrue);
      expect(BackupService.esBaseSqlite('<html>error</html>'.codeUnits),
          isFalse);
      expect(BackupService.esBaseSqlite(List.filled(200, 0)), isFalse);
    });

    test('nombre del archivo con fecha y origen', () {
      expect(BackupService.nombreArchivo(DateTime(2026, 3, 5, 7, 4), 'Windows'),
          'GDocente 2026-03-05 07.04 (Windows).db');
    });
  });
}
