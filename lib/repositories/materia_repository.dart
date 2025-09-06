// ============================================================================
// IMPORTACIONES
// ============================================================================
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/sesion_model.dart'; // Import directo sin alias

// ============================================================================
// REPOSITORIO DE MATERIAS - SIN DUPLICADOS
// ============================================================================
class MateriaRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ============================================================================
  // OPERACIONES CRUD
  // ============================================================================

  /// Obtiene todas las materias disponibles
  Future<List<Materia>> getAllMaterias() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'materias',
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'nombre',
      );

      final materias = result.map((row) => Materia.fromMap(row)).toList();

      // Si no hay materias, crear las por defecto
      if (materias.isEmpty) {
        await _initializeDefaultMaterias();
        return await getAllMaterias(); // Recursive call después de inicializar
      }

      return materias;
    } catch (e) {
      print('Error cargando materias: $e');
      return Materia.getMateriasDefault(); // Usar método estático del modelo
    }
  }

  /// Guarda o actualiza una materia
  Future<void> saveMateria(Materia materia) async {
    try {
      final db = await _dbHelper.database;

      await db.insert(
        'materias',
        materia.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error guardando materia: $e');
    }
  }

  /// Crea una nueva materia
  Future<Materia> crearMateria(String nombre, Color color) async {
    try {
      final db = await _dbHelper.database;

      // Generar nuevo ID
      final result =
          await db.rawQuery('SELECT MAX(id) as max_id FROM materias');
      final maxId = result.first['max_id'] as int? ?? 0;
      final nuevoId = maxId + 1;

      final nuevaMateria = Materia(
        id: nuevoId,
        nombre: nombre,
        color: color,
      );

      await saveMateria(nuevaMateria);
      return nuevaMateria;
    } catch (e) {
      print('Error creando materia: $e');
      // Fallback: crear con timestamp
      return Materia(
        nombre: nombre,
        color: color,
      );
    }
  }

  /// Elimina una materia (soft delete)
  Future<void> deleteMateria(int materiaId) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'materias',
        {
          'is_active': 0,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [materiaId],
      );
    } catch (e) {
      print('Error eliminando materia: $e');
    }
  }

  /// Obtiene una materia por ID
  Future<Materia?> getMateriaById(int materiaId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'materias',
        where: 'id = ? AND is_active = ?',
        whereArgs: [materiaId, 1],
        limit: 1,
      );

      if (result.isEmpty) return null;
      return Materia.fromMap(result.first);
    } catch (e) {
      print('Error obteniendo materia: $e');
      return null;
    }
  }

  // ============================================================================
  // MÉTODOS DE INICIALIZACIÓN
  // ============================================================================

  /// Inicializa las materias por defecto si no existen
  Future<void> _initializeDefaultMaterias() async {
    try {
      final materiasDefault = Materia.getMateriasDefault();
      final db = await _dbHelper.database;
      final batch = db.batch();

      for (final materia in materiasDefault) {
        batch.insert(
          'materias',
          materia.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      await batch.commit();
    } catch (e) {
      print('Error inicializando materias default: $e');
    }
  }

  // ============================================================================
  // MÉTODOS DE UTILIDAD
  // ============================================================================

  /// Verifica si la base de datos tiene materias
  Future<bool> hasMaterias() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM materias WHERE is_active = 1');
      final count = result.first['count'] as int;
      return count > 0;
    } catch (e) {
      print('Error verificando materias: $e');
      return false;
    }
  }

  /// Obtiene estadísticas de materias
  Future<Map<String, int>> getEstadisticas() async {
    try {
      final materias = await getAllMaterias();

      // Contar cuántas sesiones usa cada materia
      final db = await _dbHelper.database;
      final sesionesResult = await db.rawQuery('''
        SELECT materia_id, COUNT(*) as count 
        FROM sesiones 
        WHERE materia_id IS NOT NULL 
        GROUP BY materia_id
      ''');

      return {
        'total_materias': materias.length,
        'materias_en_uso': sesionesResult.length,
        'materias_sin_usar': materias.length - sesionesResult.length,
      };
    } catch (e) {
      print('Error obteniendo estadísticas: $e');
      return {
        'total_materias': 0,
        'materias_en_uso': 0,
        'materias_sin_usar': 0
      };
    }
  }

  /// Busca materias por nombre
  Future<List<Materia>> buscarMaterias(String query) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'materias',
        where: 'nombre LIKE ? AND is_active = ?',
        whereArgs: ['%$query%', 1],
        orderBy: 'nombre',
      );

      return result.map((row) => Materia.fromMap(row)).toList();
    } catch (e) {
      print('Error buscando materias: $e');
      return [];
    }
  }

  /// Obtiene materias más utilizadas
  Future<List<Materia>> getMateriasPopulares({int limit = 5}) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery('''
        SELECT m.*, COUNT(s.id) as uso_count
        FROM materias m
        LEFT JOIN sesiones s ON m.id = s.materia_id
        WHERE m.is_active = 1
        GROUP BY m.id
        ORDER BY uso_count DESC, m.nombre
        LIMIT ?
      ''', [limit]);

      return result.map((row) => Materia.fromMap(row)).toList();
    } catch (e) {
      print('Error obteniendo materias populares: $e');
      return [];
    }
  }
}
