import '../database/app_database.dart';
import '../models/evaluacion_model.dart';

class EvaluacionDao {
  Future<int> insertar(EvaluacionModel evaluacion) async {
    final db = await AppDatabase.instance.database;
    return db.insert('evaluaciones', evaluacion.toMap()..remove('id'));
  }

  Future<List<EvaluacionModel>> listarPorMateria(int materiaId) async {
    final db = await AppDatabase.instance.database;
    final filas = await db.rawQuery('''
      SELECT e.id, e.materia_id, e.nombre, e.fecha,
             COUNT(n.id) AS cantidad_notas
      FROM evaluaciones e
      LEFT JOIN notas n ON n.evaluacion_id = e.id
           -- solo cuentan las notas de alumnos activos (las de los dados
           -- de baja se conservan, pero no se muestran en la planilla)
           AND n.alumno_id IN (SELECT id FROM alumnos WHERE activo = 1)
      WHERE e.materia_id = ?
      GROUP BY e.id, e.materia_id, e.nombre, e.fecha
      ORDER BY e.fecha, e.nombre COLLATE NOCASE
    ''', [materiaId]);
    return filas.map((f) => EvaluacionModel.fromMap(f)).toList();
  }

  Future<bool> existeNombre(int materiaId, String nombre,
      {int? excluirId}) async {
    final db = await AppDatabase.instance.database;
    final filas = await db.query(
      'evaluaciones',
      columns: ['id'],
      where: 'materia_id = ? AND LOWER(nombre) = LOWER(?) AND id != ?',
      whereArgs: [materiaId, nombre, excluirId ?? -1],
      limit: 1,
    );
    return filas.isNotEmpty;
  }

  /// Id de la evaluación con ese nombre en la materia (sin distinguir
  /// mayúsculas), o null si no existe.
  Future<int?> buscarId(int materiaId, String nombre) async {
    final db = await AppDatabase.instance.database;
    final filas = await db.query(
      'evaluaciones',
      columns: ['id'],
      where: 'materia_id = ? AND LOWER(nombre) = LOWER(?)',
      whereArgs: [materiaId, nombre],
      limit: 1,
    );
    return filas.isEmpty ? null : filas.first['id'] as int;
  }

  Future<int> actualizar(EvaluacionModel evaluacion) async {
    final db = await AppDatabase.instance.database;
    return db.update('evaluaciones', evaluacion.toMap(),
        where: 'id = ?', whereArgs: [evaluacion.id]);
  }

  /// Borra la evaluación y, por ON DELETE CASCADE, todas sus notas.
  Future<int> eliminar(int id) async {
    final db = await AppDatabase.instance.database;
    return db.delete('evaluaciones', where: 'id = ?', whereArgs: [id]);
  }
}
