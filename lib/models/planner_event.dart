// ============================================================================
// IMPORTACIONES
// ============================================================================
import 'package:flutter/material.dart';

// ============================================================================
// MODELO BASE PARA EVENTOS CON SQLite
// ============================================================================
abstract class BaseModel {
  dynamic id; // CAMBIADO: de int? a dynamic para mayor flexibilidad
  DateTime? createdAt;
  DateTime? updatedAt;
  DateTime? syncedAt;

  BaseModel({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.syncedAt,
  });

  /// Convierte el modelo a Map para SQLite
  Map<String, dynamic> toMap();

  /// Obtiene timestamp actual
  int get currentTimestamp => DateTime.now().millisecondsSinceEpoch;
}

// ============================================================================
// MODELO DE EVENTO ACTUALIZADO CON SQLite
// ============================================================================
class PlannerEvent extends BaseModel {
  final String eventId; // ID único del evento
  final String subject; // Materia/Asignatura
  final String subtitle; // Descripción adicional
  final String className; // Clase/Grupo
  final String time; // Hora
  final String day; // Día de la semana
  final DateTime date; // Fecha completa

  // Campos adicionales para SQLite
  final int? docenteId;
  final int? materiaId;
  final int? cursoId;
  final String? aula;
  final String? notas;
  final bool esExamen;
  final bool esTutoria;
  final String tipoEvento; // 'clase', 'reunion', 'examen', 'tutoria'

  PlannerEvent({
    super.id,
    required this.eventId,
    required this.subject,
    required this.subtitle,
    required this.className,
    required this.time,
    required this.day,
    required this.date,
    this.docenteId,
    this.materiaId,
    this.cursoId,
    this.aula,
    this.notas,
    this.esExamen = false,
    this.esTutoria = false,
    this.tipoEvento = 'clase',
    super.createdAt,
    super.updatedAt,
    super.syncedAt,
  }) {
    // Asegurar que el id de la clase base sea consistente
    id = eventId;
  }

  // ============================================================================
  // COMPATIBILIDAD CON CÓDIGO EXISTENTE
  // ============================================================================

  /// Constructor legacy para compatibilidad (mantiene la API original)
  PlannerEvent.legacy({
    required String id,
    required this.subject,
    required this.subtitle,
    required this.className,
    required this.time,
    required this.day,
    required this.date,
  })  : eventId = id,
        docenteId = null,
        materiaId = null,
        cursoId = null,
        aula = null,
        notas = null,
        esExamen = false,
        esTutoria = false,
        tipoEvento = 'clase' {
    this.id = id;
  }

  /// Getter para compatibilidad con código existente - CORREGIDO
  String get idString => eventId;

  /// Factory desde JSON - MANTIENE COMPATIBILIDAD
  factory PlannerEvent.fromJson(Map<String, dynamic> json) {
    return PlannerEvent(
      eventId: json['id'] ?? DateTime.now().toIso8601String(),
      subject: json['subject'] ?? 'Sin Materia',
      subtitle: json['subtitle'] ?? '',
      className: json['className'] ?? 'Sin Clase',
      time: json['time'] ?? '00:00',
      day: json['day'] ?? 'L',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      docenteId: json['docenteId'],
      materiaId: json['materiaId'],
      cursoId: json['cursoId'],
      aula: json['aula'],
      notas: json['notas'],
      esExamen: json['esExamen'] ?? false,
      esTutoria: json['esTutoria'] ?? false,
      tipoEvento: json['tipoEvento'] ?? 'clase',
    );
  }

  /// Conversión a JSON - MANTIENE COMPATIBILIDAD
  Map<String, dynamic> toJson() {
    return {
      'id': eventId,
      'subject': subject,
      'subtitle': subtitle,
      'className': className,
      'time': time,
      'day': day,
      'date': date.toIso8601String(),
      'docenteId': docenteId,
      'materiaId': materiaId,
      'cursoId': cursoId,
      'aula': aula,
      'notas': notas,
      'esExamen': esExamen,
      'esTutoria': esTutoria,
      'tipoEvento': tipoEvento,
    };
  }

  // ============================================================================
  // MÉTODOS SQLite
  // ============================================================================

  /// Convierte el evento a Map para SQLite
  @override
  Map<String, dynamic> toMap() {
    return {
      'id': eventId,
      'docente_id': docenteId,
      'subject': subject,
      'subtitle': subtitle,
      'class_name': className,
      'time': time,
      'day': day,
      'date': date.toIso8601String(),
      'materia_id': materiaId,
      'curso_id': cursoId,
      'aula': aula,
      'notas': notas,
      'es_examen': esExamen ? 1 : 0,
      'es_tutoria': esTutoria ? 1 : 0,
      'tipo_evento': tipoEvento,
      'created_at': createdAt?.millisecondsSinceEpoch ?? currentTimestamp,
      'updated_at': updatedAt?.millisecondsSinceEpoch ?? currentTimestamp,
      'synced_at': syncedAt?.millisecondsSinceEpoch,
    };
  }

  /// Crea un PlannerEvent desde Map de SQLite
  static PlannerEvent fromMap(Map<String, dynamic> map) {
    return PlannerEvent(
      eventId: map['id'] ?? '',
      subject: map['subject'] ?? 'Sin Materia',
      subtitle: map['subtitle'] ?? '',
      className: map['class_name'] ?? 'Sin Clase',
      time: map['time'] ?? '00:00',
      day: map['day'] ?? 'L',
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      docenteId: map['docente_id'],
      materiaId: map['materia_id'],
      cursoId: map['curso_id'],
      aula: map['aula'],
      notas: map['notas'],
      esExamen: (map['es_examen'] ?? 0) == 1,
      esTutoria: (map['es_tutoria'] ?? 0) == 1,
      tipoEvento: map['tipo_evento'] ?? 'clase',
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'])
          : null,
      syncedAt: map['synced_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['synced_at'])
          : null,
    );
  }

  // ============================================================================
  // MÉTODOS AUXILIARES
  // ============================================================================

  /// Crea una copia con valores actualizados
  PlannerEvent copyWith({
    dynamic id,
    String? eventId,
    int? docenteId,
    String? subject,
    String? subtitle,
    String? className,
    String? time,
    String? day,
    DateTime? date,
    int? materiaId,
    int? cursoId,
    String? aula,
    String? notas,
    bool? esExamen,
    bool? esTutoria,
    String? tipoEvento,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
  }) {
    return PlannerEvent(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      docenteId: docenteId ?? this.docenteId,
      subject: subject ?? this.subject,
      subtitle: subtitle ?? this.subtitle,
      className: className ?? this.className,
      time: time ?? this.time,
      day: day ?? this.day,
      date: date ?? this.date,
      materiaId: materiaId ?? this.materiaId,
      cursoId: cursoId ?? this.cursoId,
      aula: aula ?? this.aula,
      notas: notas ?? this.notas,
      esExamen: esExamen ?? this.esExamen,
      esTutoria: esTutoria ?? this.esTutoria,
      tipoEvento: tipoEvento ?? this.tipoEvento,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  /// Verifica si el evento está sincronizado
  bool get estaSincronizado =>
      syncedAt != null && (updatedAt == null || syncedAt!.isAfter(updatedAt!));

  /// Obtiene descripción completa del evento
  String get descripcionCompleta {
    final partes = <String>[];
    partes.add(subject);
    if (className.isNotEmpty && className != 'Sin Clase') {
      partes.add('($className)');
    }
    if (subtitle.isNotEmpty) {
      partes.add('- $subtitle');
    }
    return partes.join(' ');
  }

  /// Verifica si es un evento especial
  bool get esEventoEspecial => esExamen || esTutoria || tipoEvento != 'clase';
}
