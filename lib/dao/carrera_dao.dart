import '../database/app_database.dart';
import '../models/carrera_model.dart';

/// Único lugar donde aparece SQL de la tabla carreras.
class CarreraDao {
  Future<int> insertar(CarreraModel carrera) async {
    final db = await AppDatabase.instance.database;
    return db.insert('carreras', carrera.toMap()..remove('id'));
  }

  Future<List<CarreraModel>> listar() async {
    final db = await AppDatabase.instance.database;
    final filas = await db.rawQuery('''
      SELECT c.id, c.nombre, COUNT(m.id) AS cantidad_materias
      FROM carreras c
      LEFT JOIN materias m ON m.carrera_id = c.id
      GROUP BY c.id, c.nombre
      ORDER BY c.nombre COLLATE NOCASE
    ''');
    return filas.map((f) => CarreraModel.fromMap(f)).toList();
  }

  Future<bool> existeNombre(String nombre, {int? excluirId}) async {
    final db = await AppDatabase.instance.database;
    final filas = await db.query(
      'carreras',
      columns: ['id'],
      where: 'LOWER(nombre) = LOWER(?) AND id != ?',
      whereArgs: [nombre, excluirId ?? -1],
      limit: 1,
    );
    return filas.isNotEmpty;
  }

  Future<int> actualizar(CarreraModel carrera) async {
    final db = await AppDatabase.instance.database;
    return db.update('carreras', carrera.toMap(),
        where: 'id = ?', whereArgs: [carrera.id]);
  }

  Future<int> eliminar(int id) async {
    final db = await AppDatabase.instance.database;
    return db.delete('carreras', where: 'id = ?', whereArgs: [id]);
  }
}
