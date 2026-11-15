import '../database/app_database.dart';
import '../models/alumno_model.dart';

class AlumnoDao {
  Future<int> insertar(AlumnoModel alumno) async {
    final db = await AppDatabase.instance.database;
    return db.insert('alumnos', alumno.toMap()..remove('id'));
  }

  Future<List<AlumnoModel>> listarActivosPorMateria(int materiaId) async {
    final db = await AppDatabase.instance.database;
    final filas = await db.query(
      'alumnos',
      where: 'materia_id = ? AND activo = 1',
      whereArgs: [materiaId],
      orderBy: 'nombre_completo COLLATE NOCASE',
    );
    return filas.map((f) => AlumnoModel.fromMap(f)).toList();
  }

  /// ¿Hay otro alumno ACTIVO en la misma materia con ese teléfono?
  Future<bool> existeTelefonoEnMateria(int materiaId, String telefono,
      {int? excluirId}) async {
    final db = await AppDatabase.instance.database;
    final filas = await db.query(
      'alumnos',
      columns: ['id'],
      where: 'materia_id = ? AND telefono = ? AND activo = 1 AND id != ?',
      whereArgs: [materiaId, telefono, excluirId ?? -1],
      limit: 1,
    );
    return filas.isNotEmpty;
  }

  Future<int> actualizar(AlumnoModel alumno) async {
    final db = await AppDatabase.instance.database;
    return db.update('alumnos', alumno.toMap(),
        where: 'id = ?', whereArgs: [alumno.id]);
  }

  /// Borrado lógico: el registro se conserva para futuras asistencias y notas.
  Future<int> darDeBaja(int id) async {
    final db = await AppDatabase.instance.database;
    return db.update('alumnos', {'activo': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> reactivar(int id) async {
    final db = await AppDatabase.instance.database;
    return db.update('alumnos', {'activo': 1},
        where: 'id = ?', whereArgs: [id]);
  }
}
