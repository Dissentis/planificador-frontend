// lib/repositories/sesion_repository_firestore.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../models/sesion_model.dart';
import 'sesion_repository_interface.dart'; // Importar la interfaz

class SesionRepositoryFirestore implements SesionRepository {
  // Implementar interfaz
  final FirestoreService _firestoreService;

  SesionRepositoryFirestore(this._firestoreService);

// ============================================================================
// OPERACIONES CRUD
// ============================================================================

  /// Obtiene todas las sesiones del usuario actual
  @override
  Future<List<SesionHorario>> getAllSesiones({int docenteId = 1}) async {
    final userId = _firestoreService.currentUserId;
    final sesiones = await _firestoreService.observarSesiones().first;

    // Filtrar por userId
    return sesiones.where((s) => s.userId == userId).toList();
  }

  /// Guarda o actualiza una sesión
  @override
  Future<void> saveSesion(SesionHorario sesion) async {
    final userId = _firestoreService.currentUserId ?? 'local';
    final sesionConUser = sesion.copyWith(userId: userId);

    // delega en FirestoreService, que ya maneja clave compuesta
    await _firestoreService.guardarSesion(sesionConUser);
  }

  /// Guarda múltiples sesiones
  @override
  Future<void> saveSesiones(List<SesionHorario> sesiones) async {
    for (final sesion in sesiones) {
      await saveSesion(sesion);
    }
  }

  /// Elimina una sesión
  @override
  Future<void> deleteSesion(String sesionId, {int docenteId = 1}) async {
    // FirestoreService ya maneja el userId internamente y construye el docId
    await _firestoreService.eliminarSesion(sesionId);
  }

  /// Limpia una sesión (elimina contenido pero mantiene estructura)
  @override
  Future<void> limpiarSesion(String sesionId, {int docenteId = 1}) async {
    final userId = _firestoreService.currentUserId ?? 'local';
    final sesiones = await _firestoreService.observarSesiones().first;

    final sesion = sesiones.firstWhere(
      (s) => s.sesionId == sesionId && s.userId == userId,
      orElse: () => SesionHorario(
        sesionId: sesionId,
        docenteId: docenteId,
        dia: '',
        hora: '',
        userId: userId,
      ),
    );

    final sesionLimpia = sesion.copyWith(
      materia: null,
      notas: null,
      actividad: null,
      esExamen: false,
      clearMateria: true,
      clearNotas: true,
      clearActividad: true,
    );

    await saveSesion(sesionLimpia);
  }

// ============================================================================
// MÉTODOS DE UTILIDAD
// ============================================================================

  /// Exporta sesiones a CSV (filtradas por usuario actual)
  @override
  Future<String> exportarCSV({int docenteId = 1}) async {
    final userId = _firestoreService.currentUserId; // 👈 usuario actual
    final sesiones = await _firestoreService.observarSesiones().first;

    // Filtrar por userId
    final sesionesUsuario = sesiones.where((s) => s.userId == userId);

    final buffer = StringBuffer();
    buffer.writeln('Dia,Hora,Materia,Actividad,Notas');

    for (final sesion in sesionesUsuario) {
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

  /// Obtiene estadísticas del horario (filtradas por usuario actual)
  @override
  Future<Map<String, int>> getEstadisticas({int docenteId = 1}) async {
    final userId = _firestoreService.currentUserId; // 👈 usuario actual
    final sesiones = await _firestoreService.observarSesiones().first;

    final sesionesUsuario = sesiones.where((s) => s.userId == userId);

    return {
      'total_sesiones': sesionesUsuario.length,
      'sesiones_con_materia':
          sesionesUsuario.where((s) => s.materia != null).length,
      'examenes_programados': sesionesUsuario.where((s) => s.esExamen).length,
      'sesiones_con_notas':
          sesionesUsuario.where((s) => s.notas?.isNotEmpty == true).length,
    };
  }

  @override
  Future<void> initializeScheduleIfEmpty({int docenteId = 1}) async {
    // Para Firestore no inicializamos nada
  }
}

// Provider para el repositorio de Firestore
final sesionRepositoryFirestoreProvider =
    Provider<SesionRepositoryFirestore>((ref) {
  final firestoreService = FirestoreService();
  return SesionRepositoryFirestore(firestoreService);
});
