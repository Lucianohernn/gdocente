import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/nota_model.dart';

class NotaDao {
  /// Notas de una evaluación: alumnoId → nota.
  Future<Map<int, NotaModel>> listarPorEvaluacion(int evaluacionId) async {
    final db = await AppDatabase.instance.database;
    final filas = await db.query('notas',
        where: 'evaluacion_id = ?', whereArgs: [evaluacionId]);
    return {
      for (final f in filas) f['alumno_id'] as int: NotaModel.fromMap(f)
    };
  }

  /// Todas las notas de las evaluaciones de una materia.
  Future<List<NotaModel>> listarPorMateria(int materiaId) async {
    final db = await AppDatabase.instance.database;
    final filas = await db.rawQuery('''
      SELECT n.id, n.evaluacion_id, n.alumno_id, n.nota, n.recuperatorio
      FROM notas n
      JOIN evaluaciones e ON e.id = n.evaluacion_id
      WHERE e.materia_id = ?
    ''', [materiaId]);
    return filas.map((f) => NotaModel.fromMap(f)).toList();
  }

  /// Guarda la planilla de notas de una evaluación en una transacción.
  /// Una nota sin valores (ni nota ni recuperatorio) se borra.
  Future<void> guardarPlanilla(List<NotaModel> notas) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      final lote = txn.batch();
      for (final n in notas) {
        if (n.vacia) {
          lote.delete('notas',
              where: 'evaluacion_id = ? AND alumno_id = ?',
              whereArgs: [n.evaluacionId, n.alumnoId]);
        } else {
          lote.insert('notas', n.toMap()..remove('id'),
              // UNIQUE(evaluacion_id, alumno_id): reemplaza la nota anterior.
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await lote.commit(noResult: true);
    });
  }
}
