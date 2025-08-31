// lib/models/planner_event.dart
// === INICIO MODIFICACIÓN: Se renombra 'title' a 'subject' y se añade el campo 'className'. ===

import 'package:flutter/material.dart';

class PlannerEvent {
  final String id;
  final String subject; // ANTERIORMENTE 'title'
  final String subtitle;
  final String className; // <-- NUEVO CAMPO
  final String time;
  final String day;
  final DateTime date;

  PlannerEvent({
    required this.id,
    required this.subject, // ANTERIORMENTE 'title'
    required this.subtitle,
    required this.className, // <-- NUEVO CAMPO
    required this.time,
    required this.day,
    required this.date,
  });

  factory PlannerEvent.fromJson(Map<String, dynamic> json) {
    return PlannerEvent(
      id: json['id'] ?? DateTime.now().toIso8601String(),
      subject: json['subject'] ?? 'Sin Materia', // ANTERIORMENTE 'title'
      subtitle: json['subtitle'] ?? '',
      className: json['className'] ?? 'Sin Clase', // <-- NUEVO CAMPO
      time: json['time'] ?? '00:00',
      day: json['day'] ?? 'L',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject, // ANTERIORMENTE 'title'
      'subtitle': subtitle,
      'className': className, // <-- NUEVO CAMPO
      'time': time,
      'day': day,
      'date': date.toIso8601String(),
    };
  }
}
// === FIN MODIFICACIÓN ===