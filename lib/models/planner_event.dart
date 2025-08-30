// lib/models/planner_event.dart

import 'package:flutter/material.dart';

class PlannerEvent {
  final String title;
  final String subtitle;
  final String time;
  final String day;
  // NOTA: Los colores no vendrán del backend, los asignaremos en el frontend.

  PlannerEvent({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.day,
  });

  // --- ¡NUEVO! Constructor de fábrica ---
  // Este método sabe cómo "leer" un mapa JSON y convertirlo en un objeto PlannerEvent.
  // Asegúrate de que los nombres ('title', 'subtitle', etc.) coincidan
  // con los que te envíe tu compañero del backend.
  factory PlannerEvent.fromJson(Map<String, dynamic> json) {
    return PlannerEvent(
      title: json['title'] ?? 'Sin Título',
      subtitle: json['subtitle'] ?? '',
      time: json['time'] ?? '00:00',
      day: json['day'] ?? 'L',
    );
  }
}