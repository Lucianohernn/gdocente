import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/asistencia_model.dart';

class AsistenciaDao {
  /// Asistencias de una materia en una fecha: alumnoId → estado.
  Future<Map<int, EstadoAsistencia>> estadosDelDia(
      int materiaId, String fecha) async {
    final db = await AppDatabase.instance.database;
    final filas = await db.rawQuery('''
      SELECT s.alumno_id, s.estado
      FROM asistencias s
      JOIN alumnos a ON a.id = s.alumno_id
      WHERE a.materia_id = ? AND s.fecha = ?
    ''', [materiaId, fecha]);
    return {
      for (final f in filas)
        f['alumno_id'] as int: EstadoAsistencia.desdeCodigo(f['estado'] as String)
    };
  }

  /// Guarda la planilla de un día en una sola transacción: si algo falla,
  /// no queda la mitad guardada. Un estado null borra el registro del alumno.
  Future<void> guardarDia(
      String fecha, Map<int, EstadoAsistencia?> estados) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      final lote = txn.batch();
      estados.forEach((alumnoId, estado) {
        if (estado == null) {
          lote.delete('asistencias',
              where: 'alumno_id = ? AND fecha = ?',
              whereArgs: [alumnoId, fecha]);
        } else {
          lote.insert(
            'asistencias',
            {'alumno_id': alumnoId, 'fecha': fecha, 'estado': estado.codigo},
            // UNIQUE(alumno_id, fecha): si ya existía, se reemplaza.
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      await lote.commit(noResult: true);
    });
  }

  /// Todas las asistencias de la materia (alumnos activos y dados de baja).
  Future<List<AsistenciaModel>> listarPorMateria(int materiaId) async {
    final db = await AppDatabase.instance.database;
    final filas = await db.rawQuery('''
      SELECT s.id, s.alumno_id, s.fecha, s.estado
      FROM asistencias s
      JOIN alumnos a ON a.id = s.alumno_id
      WHERE a.materia_id = ?
      ORDER BY s.fecha
    ''', [materiaId]);
    return filas.map((f) => AsistenciaModel.fromMap(f)).toList();
  }

  /// Fechas con al menos un registro, de la más reciente a la más vieja.
  Future<List<String>> fechasConRegistro(int materiaId) async {
    final db = await AppDatabase.instance.database;
    final filas = await db.rawQuery('''
      SELECT DISTINCT s.fecha
      FROM asistencias s
      JOIN alumnos a ON a.id = s.alumno_id
      WHERE a.materia_id = ?
      ORDER BY s.fecha DESC
    ''', [materiaId]);
    return filas.map((f) => f['fecha'] as String).toList();
  }

  /// Borra la clase completa de una fecha (p. ej. si se cargó por error).
  Future<void> eliminarDia(int materiaId, String fecha) async {
    final db = await AppDatabase.instance.database;
    await db.rawDelete('''
      DELETE FROM asistencias
      WHERE fecha = ?
        AND alumno_id IN (SELECT id FROM alumnos WHERE materia_id = ?)
    ''', [fecha, materiaId]);
  }
}
