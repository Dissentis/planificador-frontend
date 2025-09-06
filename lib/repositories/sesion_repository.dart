// ============================================================================
// IMPORTACIONES
// ============================================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sesion_model.dart';

// ============================================================================
// REPOSITORIO DE SESIONES CON FIRESTORE
// ============================================================================
class SesionRepositoryFirestore {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================================
  // COLECCIONES
  // ============================================================================

  CollectionReference get _sesionesCollection =>
      _firestore.collection('sesiones');

  CollectionReference get _materiasCollection =>
      _firestore.collection('materias');

  // ============================================================================
  // OPERACIONES CRUD
  // ============================================================================

  /// Obtiene todas las sesiones del usuario actual
  Stream<List<SesionHorario>> getAllSesiones() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _sesionesCollection
        .where('userId', isEqualTo: user.uid)
        .orderBy('dia')
        .orderBy('hora')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SesionHorario.fromFirestore(doc))
            .toList());
  }

  /// Guarda o actualiza una sesión
  Future<void> saveSesion(SesionHorario sesion) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final sesionData = _sesionToMap(sesion, user.uid);

    await _sesionesCollection.doc(sesion.id.toString()).set(sesionData);
  }

  /// Guarda múltiples sesiones
  Future<void> saveSesiones(List<SesionHorario> sesiones) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final batch = _firestore.batch();

    for (final sesion in sesiones) {
      final sesionData = _sesionToMap(sesion, user.uid);
      final docRef = _sesionesCollection.doc(sesion.id.toString());
      batch.set(docRef, sesionData);
    }

    await batch.commit();
  }

  /// Elimina una sesión
  Future<void> deleteSesion(String sesionId) async {
    await _sesionesCollection.doc(sesionId).delete();
  }

  /// Limpia una sesión (elimina contenido pero mantiene estructura)
  Future<void> limpiarSesion(String sesionId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    await _sesionesCollection.doc(sesionId).update({
      'materia': null,
      'notas': null,
      'actividad': null,
      'esExamen': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================================
  // MÉTODOS DE CONVERSIÓN
  // ============================================================================

  /// Convierte SesionHorario a Map para Firestore
  Map<String, dynamic> _sesionToMap(SesionHorario sesion, String userId) {
    return {
      'id': sesion.id,
      'dia': sesion.dia,
      'hora': sesion.hora,
      'materia': sesion.materia != null
          ? {
              'id': sesion.materia!.id,
              'nombre': sesion.materia!.nombre,
              'color': sesion.materia!.color.value,
              'descripcion': sesion.materia!.descripcion,
            }
          : null,
      'actividad': sesion.actividad,
      'notas': sesion.notas,
      'esExamen': sesion.esExamen,
      'cursoNombre': sesion.cursoNombre,
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ============================================================================
  // MÉTODOS DE UTILIDAD
  // ============================================================================

  /// Exporta sesiones a CSV
  Future<String> exportarCSV() async {
    final snapshot = await _sesionesCollection.get();
    final sesiones =
        snapshot.docs.map((doc) => SesionHorario.fromFirestore(doc)).toList();

    final buffer = StringBuffer();
    buffer.writeln('Dia,Hora,Materia,Actividad,Notas');

    for (final sesion in sesiones) {
      if (sesion.materia != null || sesion.actividad != null) {
        buffer.writeln([
          sesion.dia,
          sesion.hora,
          '"${sesion.materia?.nombre ?? ''}"',
          '"${sesion.actividad ?? ''}"',
          '"${sesion.notas ?? ''}"'
        ].join(','));
      }
    }

    return buffer.toString();
  }

  /// Obtiene estadísticas del horario
  Future<Map<String, int>> getEstadisticas() async {
    final snapshot = await _sesionesCollection.get();
    final sesiones =
        snapshot.docs.map((doc) => SesionHorario.fromFirestore(doc)).toList();

    return {
      'total_sesiones': sesiones.length,
      'sesiones_con_materia': sesiones.where((s) => s.materia != null).length,
      'examenes_programados': sesiones.where((s) => s.esExamen).length,
      'sesiones_con_notas':
          sesiones.where((s) => s.notas?.isNotEmpty == true).length,
    };
  }
}
