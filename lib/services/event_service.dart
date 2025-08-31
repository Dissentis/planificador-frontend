// lib/services/event_service.dart
// === INICIO MODIFICACIÓN: Se actualizan los datos de prueba para que coincidan con el nuevo modelo de evento. ===

import '../models/planner_event.dart';

class EventService {
  static List<PlannerEvent> _events = [
    PlannerEvent(id: '1', subject: 'Matemáticas', subtitle: 'Revisión de álgebra', className: '3º A de Primaria', time: '08:00', day: 'L', date: DateTime.now()),
    PlannerEvent(id: '2', subject: 'Historia', subtitle: 'Rev. Francesa', className: '3º B de Primaria', time: '08:00', day: 'X', date: DateTime.now().add(const Duration(days: 2))),
    PlannerEvent(id: '3', subject: 'Ciencias', subtitle: 'Experimento', className: '3º A de Primaria', time: '09:00', day: 'M', date: DateTime.now().add(const Duration(days: 1))),
  ];

  static Future<List<PlannerEvent>> fetchEvents() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_events);
  }

  static Future<void> addEvent(PlannerEvent event) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _events.add(event);
  }

  static Future<void> updateEvent(PlannerEvent updatedEvent) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _events.indexWhere((event) => event.id == updatedEvent.id);
    if (index != -1) {
      _events[index] = updatedEvent;
    }
  }

  static Future<void> deleteEvent(String eventId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _events.removeWhere((event) => event.id == eventId);
  }
}
// === FIN MODIFICACIÓN ===