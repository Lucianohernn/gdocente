import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Administra la única conexión a SQLite de la aplicación (patrón Singleton).
class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  static const String _nombreArchivo = 'gdocente.db';
  static const int _version = 2; // v2 (Hito 3): asistencias, evaluaciones y notas

  AppDatabase._init(); // constructor privado: nadie más puede instanciar la clase

  Future<Database> get database async {
    if (_database != null) return _database!; // reutiliza la conexión existente
    _database = await _initDB(_nombreArchivo);
    return _database!;
  }

  Future<Database> _initDB(String nombreArchivo) async {
    final dbPath = await getDatabasesPath(); // almacenamiento privado de la app
    final path = join(dbPath, nombreArchivo);

    return openDatabase(
      path,
      version: _version,
      // Corrección respecto del tutorial: SQLite NO aplica las claves foráneas
      // si no se activan en cada conexión. onConfigure se ejecuta siempre al abrir.
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createDB, // solo la primera vez (instalación nueva)
      onUpgrade: _upgradeDB, // instalaciones existentes: migra sin perder datos
    );
  }

  /// Un CREATE TABLE por llamada a execute (sqflite en Android ejecuta
  /// una sola sentencia por llamada).
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE carreras (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE materias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        carrera_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        anio INTEGER NOT NULL,
        FOREIGN KEY (carrera_id) REFERENCES carreras(id) ON DELETE RESTRICT,
        UNIQUE (carrera_id, nombre, anio)
      )
    ''');

    await db.execute('''
      CREATE TABLE alumnos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        materia_id INTEGER NOT NULL,
        nombre_completo TEXT NOT NULL,
        telefono TEXT NOT NULL,
        fecha_alta TEXT NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (materia_id) REFERENCES materias(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_alumnos_materia ON alumnos(materia_id, activo)');

    await _crearTablasHito3(db);
  }

  /// Migración incremental: cada bloque lleva la base de la versión N a la N+1.
  Future<void> _upgradeDB(Database db, int anterior, int nueva) async {
    if (anterior < 2) await _crearTablasHito3(db);
  }

  /// Hito 3. Las asistencias y notas cuelgan del alumno (borrado lógico: si se
  /// da de baja, sus registros se conservan); las evaluaciones, de la materia.
  Future<void> _crearTablasHito3(Database db) async {
    await db.execute('''
      CREATE TABLE asistencias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        alumno_id INTEGER NOT NULL,
        fecha TEXT NOT NULL,
        estado TEXT NOT NULL CHECK (estado IN ('P', 'A', 'T', 'J')),
        FOREIGN KEY (alumno_id) REFERENCES alumnos(id) ON DELETE CASCADE,
        UNIQUE (alumno_id, fecha)
      )
    ''');

    await db.execute('''
      CREATE TABLE evaluaciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        materia_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        fecha TEXT NOT NULL,
        FOREIGN KEY (materia_id) REFERENCES materias(id) ON DELETE CASCADE,
        UNIQUE (materia_id, nombre)
      )
    ''');

    await db.execute('''
      CREATE TABLE notas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        evaluacion_id INTEGER NOT NULL,
        alumno_id INTEGER NOT NULL,
        nota REAL,
        recuperatorio REAL,
        FOREIGN KEY (evaluacion_id) REFERENCES evaluaciones(id) ON DELETE CASCADE,
        FOREIGN KEY (alumno_id) REFERENCES alumnos(id) ON DELETE CASCADE,
        UNIQUE (evaluacion_id, alumno_id)
      )
    ''');

    await db.execute('CREATE INDEX idx_asistencias_fecha ON asistencias(fecha)');
    await db.execute('CREATE INDEX idx_notas_alumno ON notas(alumno_id)');
  }
}
