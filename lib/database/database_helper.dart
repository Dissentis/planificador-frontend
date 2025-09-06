// ============================================================================
// IMPORTACIONES
// ============================================================================
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

// ============================================================================
// GESTOR PRINCIPAL DE BASE DE DATOS
// ============================================================================
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static const String _databaseName = 'planificador_docente.db';
  static const int _databaseVersion = 1;

  Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static DatabaseHelper get instance => _instance;

  /// Getter para obtener la instancia de la base de datos
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  // ============================================================================
// INICIALIZACIÓN DE LA BASE DE DATOS
// ============================================================================
  /// Inicializa la base de datos y crea las tablas necesarias
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  /// Crea todas las tablas de la base de datos
  Future<void> _createTables(Database db, int version) async {
    await _createDocentesTable(db);
    await _createCentrosTable(db);
    await _createDepartamentosTable(db);
    await _createMateriasTable(db);
    await _createCursosTable(db);
    await _createSesionesTable(db);
    await _createActasTable(db);
    await _createNotificacionesTable(db);
    await _createConfiguracionTable(db);
  }

  /// Maneja las actualizaciones de esquema de la base de datos
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Ejecuta migraciones progresivas según la versión
    if (oldVersion < 2 && newVersion >= 2) {
      // Ejemplo: añadir columna "descripcion" a materias
      await db.execute('ALTER TABLE materias ADD COLUMN descripcion TEXT');
    }

    if (oldVersion < 3 && newVersion >= 3) {
      // Ejemplo: añadir columna "synced_at" a sesiones
      await db.execute('ALTER TABLE sesiones ADD COLUMN synced_at INTEGER');
    }

    // Aquí puedes seguir añadiendo bloques similares
    // cada vez que subas _databaseVersion en la clase
  }

  // ============================================================================
// DEFINICIÓN DE TABLAS
// ============================================================================

  /// Tabla de centros educativos
  Future<void> _createCentrosTable(Database db) async {
    await db.execute('''
      CREATE TABLE centros (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        codigo TEXT UNIQUE,
        direccion TEXT,
        telefono TEXT,
        email TEXT,
        tipo_centro TEXT, -- 'publico', 'privado', 'concertado'
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
      )
    ''');
  }

  /// Tabla de departamentos
  Future<void> _createDepartamentosTable(Database db) async {
    await db.execute('''
      CREATE TABLE departamentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        centro_id INTEGER,
        jefe_departamento_id INTEGER,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        FOREIGN KEY (centro_id) REFERENCES centros (id) ON DELETE CASCADE
      )
    ''');
  }

  /// Tabla principal de docentes
  Future<void> _createDocentesTable(Database db) async {
    await db.execute('''
      CREATE TABLE docentes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_uid TEXT UNIQUE NOT NULL,
        nombre TEXT NOT NULL,
        apellidos TEXT NOT NULL,
        email TEXT NOT NULL,
        email_institucional TEXT,
        telefono TEXT,
        centro_id INTEGER,
        departamento_id INTEGER,
        despacho TEXT,
        horario_atencion TEXT,
        jornada TEXT, -- 'mañana', 'tarde', 'completa'
        años_experiencia INTEGER DEFAULT 0,
        especialidades TEXT, -- JSON array
        titulaciones TEXT, -- JSON array
        plataformas_educativas TEXT, -- JSON array
        metodologias_preferidas TEXT, -- JSON array
        is_active INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        FOREIGN KEY (centro_id) REFERENCES centros (id) ON DELETE SET NULL,
        FOREIGN KEY (departamento_id) REFERENCES departamentos (id) ON DELETE SET NULL
      )
    ''');
  }

  /// Tabla de materias que puede impartir un docente
  Future<void> _createMateriasTable(Database db) async {
    await db.execute('''
      CREATE TABLE materias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        codigo TEXT,
        color INTEGER NOT NULL,
        descripcion TEXT,
        departamento_id INTEGER,
        is_active INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        FOREIGN KEY (departamento_id) REFERENCES departamentos (id) ON DELETE SET NULL
      )
    ''');
  }

  /// Tabla de cursos/grupos
  Future<void> _createCursosTable(Database db) async {
    await db.execute('''
      CREATE TABLE cursos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL, -- '1º ESO A', '2º Bachillerato C'
        nivel TEXT NOT NULL, -- 'ESO', 'Bachillerato', 'FP'
        curso_academico TEXT NOT NULL, -- '2024-2025'
        centro_id INTEGER,
        tutor_id INTEGER, -- docente que es tutor
        numero_alumnos INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        FOREIGN KEY (centro_id) REFERENCES centros (id) ON DELETE CASCADE,
        FOREIGN KEY (tutor_id) REFERENCES docentes (id) ON DELETE SET NULL
      )
    ''');
  }

  /// Tabla de sesiones de horario (mejorada)
  Future<void> _createSesionesTable(Database db) async {
    await db.execute('''
      CREATE TABLE sesiones (
        id TEXT PRIMARY KEY,
        docente_id INTEGER NOT NULL,
        dia TEXT NOT NULL,
        hora TEXT NOT NULL,
        materia_id INTEGER,
        curso_id INTEGER,
        aula TEXT,
        notas TEXT,
        actividad TEXT,
        es_examen INTEGER DEFAULT 0,
        es_tutoria INTEGER DEFAULT 0,
        recursos_necesarios TEXT, -- JSON array
        tipo_sesion TEXT DEFAULT 'clase', -- 'clase', 'tutoria', 'reunion', 'guardia'
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        synced_at INTEGER,
        FOREIGN KEY (docente_id) REFERENCES docentes (id) ON DELETE CASCADE,
        FOREIGN KEY (materia_id) REFERENCES materias (id) ON DELETE SET NULL,
        FOREIGN KEY (curso_id) REFERENCES cursos (id) ON DELETE SET NULL
      )
    ''');
  }

  /// Tabla de actas y documentos
  Future<void> _createActasTable(Database db) async {
    await db.execute('''
      CREATE TABLE actas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT NOT NULL,
        tipo TEXT NOT NULL, -- 'reunion_departamento', 'evaluacion', 'tutoria', 'claustro'
        contenido TEXT,
        fecha INTEGER NOT NULL,
        docente_id INTEGER NOT NULL,
        curso_id INTEGER,
        departamento_id INTEGER,
        asistentes TEXT, -- JSON array de IDs de docentes
        acuerdos_tomados TEXT,
        archivo_adjunto TEXT, -- ruta del archivo si existe
        exportado INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        synced_at INTEGER,
        FOREIGN KEY (docente_id) REFERENCES docentes (id) ON DELETE CASCADE,
        FOREIGN KEY (curso_id) REFERENCES cursos (id) ON DELETE SET NULL,
        FOREIGN KEY (departamento_id) REFERENCES departamentos (id) ON DELETE SET NULL
      )
    ''');
  }

  /// Tabla de notificaciones entre docentes
  Future<void> _createNotificacionesTable(Database db) async {
    await db.execute('''
      CREATE TABLE notificaciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_docente_id INTEGER NOT NULL,
        to_docente_id INTEGER NOT NULL,
        titulo TEXT NOT NULL,
        mensaje TEXT NOT NULL,
        tipo TEXT DEFAULT 'mensaje', -- 'mensaje', 'urgente', 'recordatorio'
        leido INTEGER DEFAULT 0,
        fecha_envio INTEGER NOT NULL,
        fecha_leido INTEGER,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        FOREIGN KEY (from_docente_id) REFERENCES docentes (id) ON DELETE CASCADE,
        FOREIGN KEY (to_docente_id) REFERENCES docentes (id) ON DELETE CASCADE
      )
    ''');
  }

  /// Tabla de configuración de la aplicación
  Future<void> _createConfiguracionTable(Database db) async {
    await db.execute('''
      CREATE TABLE configuracion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        docente_id INTEGER NOT NULL,
        clave TEXT NOT NULL,
        valor TEXT,
        tipo TEXT DEFAULT 'string', -- 'string', 'int', 'bool', 'json'
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        FOREIGN KEY (docente_id) REFERENCES docentes (id) ON DELETE CASCADE,
        UNIQUE(docente_id, clave)
      )
    ''');
  }

  // ============================================================================
// MÉTODOS AUXILIARES
// ============================================================================

  /// Cierra la conexión a la base de datos
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Elimina completamente la base de datos (para desarrollo/testing)
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  /// Obtiene información sobre las tablas existentes
  Future<List<String>> getTableNames() async {
    final db = await database;
    final result = await db.query(
      'sqlite_master',
      where: 'type = ?',
      whereArgs: ['table'],
    );
    return result.map((row) => row['name'] as String).toList();
  }

  /// Ejecuta una consulta SQL personalizada (para debugging)
  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  /// Obtiene el timestamp actual en milisegundos
  int get currentTimestamp => DateTime.now().millisecondsSinceEpoch;

  /// Inserta un registro garantizando timestamps
  Future<int> insertWithTimestamps(
      String table, Map<String, dynamic> values) async {
    final db = await database;
    final now = currentTimestamp;
    values['created_at'] ??= now;
    values['updated_at'] ??= now;
    return await db.insert(table, values,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Actualiza un registro refrescando updated_at
  Future<int> updateWithTimestamp(String table, Map<String, dynamic> values,
      String where, List<dynamic> whereArgs) async {
    final db = await database;
    values['updated_at'] = currentTimestamp;
    return await db.update(table, values, where: where, whereArgs: whereArgs);
  }
}
