// lib/repositories/sesion_repository_universal.dart

// ============================================================================
// IMPORTACIONES
// ============================================================================
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sesion_repository_interface.dart'; // Interface
import '../services/firestore_service.dart'; // Firestore
import '../models/sesion_model.dart';
import 'sesion_repository_firestore.dart'; // Repositorio Firestore concreto

// ============================================================================
// PROVIDER PRINCIPAL
// ============================================================================

/// Selecciona el repositorio adecuado según la plataforma:
/// - Web → usa Firestore
/// - Móvil/Escritorio → usa SQLite (a través de FirestoreService adaptado)
final sesionRepositoryProvider = Provider<SesionRepository>((ref) {
  if (kIsWeb) {
    final firestoreService = FirestoreService();
    return SesionRepositoryFirestoreAdapter(firestoreService);
  } else {
    final firestoreService = FirestoreService();
    return SesionRepositoryFirestore(firestoreService);
  }
});

// ============================================================================
// ADAPTADOR DE FIRESTORE A SESIONREPOSITORY
// ============================================================================

class SesionRepositoryFirestoreAdapter implements SesionRepository {
  final FirestoreService _firestoreService;

  SesionRepositoryFirestoreAdapter(this._firestoreService);

  // ============================================================================
  // OPERACIONES CRUD
  // ============================================================================

  @override
  Future<List<SesionHorario>> getAllSesiones({int docenteId = 1}) async {
    return await _firestoreService.observarSesiones().first;
  }

  @override
  Future<void> saveSesion(SesionHorario sesion) async {
    await _firestoreService.guardarSesion(sesion);
  }

  @override
  Future<void> saveSesiones(List<SesionHorario> sesiones) async {
    for (final sesion in sesiones) {
      await saveSesion(sesion);
    }
  }

  @override
  Future<void> deleteSesion(String sesionId, {int docenteId = 1}) async {
    await _firestoreService.eliminarSesion(sesionId);
  }

  @override
  Future<void> limpiarSesion(String sesionId, {int docenteId = 1}) async {
    final sesiones = await getAllSesiones();
    final sesion = sesiones.firstWhere(
      (s) => s.sesionId == sesionId,
      orElse: () => SesionHorario(
        sesionId: sesionId,
        docenteId: docenteId,
        dia: '',
        hora: '',
        userId: 'local', // 👈 añadido para cumplir con el modelo
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

  @override
  Future<String> exportarCSV({int docenteId = 1}) async {
    final sesiones = await getAllSesiones();
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

  @override
  Future<Map<String, int>> getEstadisticas({int docenteId = 1}) async {
    final sesiones = await getAllSesiones();
    return {
      'total_sesiones': sesiones.length,
      'sesiones_con_materia': sesiones.where((s) => s.materia != null).length,
      'examenes_programados': sesiones.where((s) => s.esExamen).length,
      'sesiones_con_notas':
          sesiones.where((s) => s.notas?.isNotEmpty == true).length,
    };
  }

  @override
  Future<void> initializeScheduleIfEmpty({int docenteId = 1}) async {
    // Para Firestore, no necesitamos inicializar
  }
}
