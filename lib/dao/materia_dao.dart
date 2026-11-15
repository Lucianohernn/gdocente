import '../database/app_database.dart';
import '../models/materia_model.dart';

class MateriaDao {
  Future<int> insertar(MateriaModel materia) async {
    final db = await AppDatabase.instance.database;
    return db.insert('materias', materia.toMap()..remove('id'));
  }

  Future<List<MateriaModel>> listarPorCarrera(int carreraId) async {
    final db = await AppDatabase.instance.database;
    final filas = await db.rawQuery('''
      SELECT m.id, m.carrera_id, m.nombre, m.anio,
             COUNT(a.id) AS cantidad_alumnos
      FROM materias m
      LEFT JOIN alumnos a ON a.materia_id = m.id AND a.activo = 1
      WHERE m.carrera_id = ?
      GROUP BY m.id, m.carrera_id, m.nombre, m.anio
      ORDER BY m.anio, m.nombre COLLATE NOCASE
    ''', [carreraId]);
    return filas.map((f) => MateriaModel.fromMap(f)).toList();
  }

  Future<bool> existe(int carreraId, String nombre, int anio,
      {int? excluirId}) async {
    final db = await AppDatabase.instance.database;
    final filas = await db.query(
      'materias',
      columns: ['id'],
      where: 'carrera_id = ? AND LOWER(nombre) = LOWER(?) AND anio = ? AND id != ?',
      whereArgs: [carreraId, nombre, anio, excluirId ?? -1],
      limit: 1,
    );
    return filas.isNotEmpty;
  }

  Future<int> actualizar(MateriaModel materia) async {
    final db = await AppDatabase.instance.database;
    return db.update('materias', materia.toMap(),
        where: 'id = ?', whereArgs: [materia.id]);
  }

  Future<int> eliminar(int id) async {
    final db = await AppDatabase.instance.database;
    return db.delete('materias', where: 'id = ?', whereArgs: [id]);
  }
}
