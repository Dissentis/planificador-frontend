// lib/repositories/sesion_repository_interface.dart
import '../models/sesion_model.dart';

abstract class SesionRepository {
  Future<List<SesionHorario>> getAllSesiones({int docenteId = 1});
  Future<void> saveSesion(SesionHorario sesion);
  Future<void> saveSesiones(List<SesionHorario> sesiones);
  Future<void> deleteSesion(String sesionId, {int docenteId = 1});
  Future<void> limpiarSesion(String sesionId, {int docenteId = 1});
  Future<String> exportarCSV({int docenteId = 1});
  Future<Map<String, int>> getEstadisticas({int docenteId = 1});
  Future<void> initializeScheduleIfEmpty({int docenteId = 1});
}
