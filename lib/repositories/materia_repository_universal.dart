// ============================================================================
// IMPORTACIONES
// ============================================================================
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/sesion_model.dart';
import '../services/firestore_service.dart';

// ============================================================================
// PROVIDER PRINCIPAL
// ============================================================================
final materiaRepositoryProvider = Provider<MateriaRepository>((ref) {
  if (kIsWeb) {
    final firestoreService = FirestoreService();
    return MateriaRepositoryFirestore(firestoreService);
  } else {
    return MateriaRepository();
  }
});

// ============================================================================
// REPOSITORIO FIRESTORE PARA WEB
// ============================================================================
class MateriaRepositoryFirestore extends MateriaRepository {
  final FirestoreService _firestoreService;

  MateriaRepositoryFirestore(this._firestoreService);

  @override
  Future<List<Materia>> getAllMaterias() async {
    try {
      final materias = await _firestoreService.observarMaterias().first;
      return materias.isNotEmpty ? materias : Materia.getMateriasDefault();
    } catch (e) {
      print('Error cargando materias desde Firestore: $e');
      return Materia.getMateriasDefault();
    }
  }

  @override
  Future<void> saveMateria(Materia materia) async {
    await _firestoreService.guardarMateria(materia);
  }

  @override
  Future<Materia> crearMateria(String nombre, Color color) async {
    final nuevaMateria = Materia(
      id: DateTime.now().millisecondsSinceEpoch,
      nombre: nombre,
      color: color,
    );
    await saveMateria(nuevaMateria);
    return nuevaMateria;
  }

  @override
  Future<void> deleteMateria(int materiaId) async {}

  @override
  Future<Materia?> getMateriaById(int materiaId) async => null;

  @override
  Future<bool> hasMaterias() async => false;

  @override
  Future<Map<String, int>> getEstadisticas() async => {};

  @override
  Future<List<Materia>> buscarMaterias(String query) async => [];

  @override
  Future<List<Materia>> getMateriasPopulares({int limit = 5}) async => [];

  @override
  Future<void> _initializeDefaultMaterias() async {}
}

// ============================================================================
// REPOSITORIO DE MATERIAS ORIGINAL (SQLite) - SIN MODIFICAR
// ============================================================================
class MateriaRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

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

      if (materias.isEmpty) {
        await _initializeDefaultMaterias();
        return await getAllMaterias();
      }

      return materias;
    } catch (e) {
      print('Error cargando materias: $e');
      return Materia.getMateriasDefault();
    }
  }

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

  Future<Materia> crearMateria(String nombre, Color color) async {
    try {
      final db = await _dbHelper.database;
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
      return Materia(
        nombre: nombre,
        color: color,
      );
    }
  }

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

  Future<Map<String, int>> getEstadisticas() async {
    try {
      final materias = await getAllMaterias();
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
