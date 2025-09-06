// ============================================================================
// IMPORTACIONES
// ============================================================================
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================================
// MODELO BASE PARA ENTIDADES CON SQLite
// ============================================================================
abstract class BaseModel {
  int? id;
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
// MODELO DE MATERIA PARA SESIONES
// ============================================================================
class Materia {
  final int? id;
  final String nombre;
  final Color color;
  final String? codigo;
  final String? descripcion;
  final String userId; // 👈 añadido

  const Materia({
    this.id,
    required this.nombre,
    required this.color,
    this.codigo,
    this.descripcion,
    this.userId = 'local', // 👈 valor por defecto si no viene de Firestore
  });

  /// Crea una copia de esta instancia con valores opcionales actualizados.
  Materia copyWith({
    int? id,
    String? nombre,
    Color? color,
    String? codigo,
    String? descripcion,
    String? userId,
  }) {
    return Materia(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      color: color ?? this.color,
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      userId: userId ?? this.userId, // 👈 propagamos userId
    );
  }

  /// Obtiene las materias predeterminadas
  static List<Materia> getMateriasDefault() {
    return [
      Materia(id: 1, nombre: 'Matemáticas', color: Colors.blue[100]!),
      Materia(id: 2, nombre: 'Lengua', color: Colors.green[100]!),
      Materia(id: 3, nombre: 'Ciencias', color: Colors.orange[100]!),
      Materia(id: 4, nombre: 'Historia', color: Colors.purple[100]!),
      Materia(id: 5, nombre: 'Inglés', color: Colors.cyan[100]!),
      Materia(id: 6, nombre: 'Ed. Física', color: Colors.red[100]!),
      Materia(id: 7, nombre: 'Arte', color: Colors.pink[100]!),
      Materia(id: 8, nombre: 'Música', color: Colors.amber[100]!),
      Materia(id: 9, nombre: 'Tutoría', color: Colors.indigo[100]!),
      Materia(id: 10, nombre: 'Recreo', color: Colors.grey[200]!),
    ];
  }

  /// Convierte a Map para SQLite/Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'codigo': codigo,
      'color': color.value,
      'descripcion': descripcion,
      'userId': userId, // 👈 se guarda también
    };
  }

  /// Crea una Materia desde SQLite
  static Materia fromMap(Map<String, dynamic> map) {
    return Materia(
      id: map['id'],
      nombre: map['nombre'] ?? '',
      codigo: map['codigo'],
      color: Color(map['color'] ?? Colors.grey.value),
      descripcion: map['descripcion'],
      userId: map['userId'] ?? 'local', // 👈 fallback
    );
  }

  /// Crea una Materia desde Firestore
  static Materia fromFirestore(
      Map<String, dynamic> data, String fallbackUserId) {
    return Materia(
      id: data['id'],
      nombre: data['nombre'] ?? '',
      color: Color(data['color'] ?? Colors.grey.value),
      codigo: data['codigo'],
      descripcion: data['descripcion'],
      userId: data['userId']?.toString() ?? fallbackUserId, // 👈 seguro
    );
  }
}

// ============================================================================
// MODELO DE SESIÓN HORARIO COMPLETO
// ============================================================================
class SesionHorario extends BaseModel {
  final String sesionId; // ID compuesto como 'L_08:00'
  final int docenteId;
  final String dia;
  final String hora;
  final int? materiaId;
  final int? cursoId;
  final String? aula;
  final String? notas;
  final String? actividad;
  final bool esExamen;
  final bool esTutoria;
  final List<String> recursosNecesarios;
  final String tipoSesion;

  // 🔹 Nuevo campo para relacionar con el usuario autenticado
  final String userId;

  // Campos relacionados (no se almacenan en SQLite directamente)
  final Materia? materia;
  final String? cursoNombre; // Para compatibilidad con código existente

  SesionHorario({
    super.id,
    required this.sesionId,
    required this.docenteId,
    required this.dia,
    required this.hora,
    this.materiaId,
    this.cursoId,
    this.aula,
    this.notas,
    this.actividad,
    this.esExamen = false,
    this.esTutoria = false,
    this.recursosNecesarios = const [],
    this.tipoSesion = 'clase',
    required this.userId, // 🔹 requerido
    this.materia,
    this.cursoNombre,
    super.createdAt,
    super.updatedAt,
    super.syncedAt,
  });

// ============================================================================
// COMPATIBILIDAD CON weekly_planner_screen.dart
// ============================================================================

  /// Constructor para compatibilidad total con código existente
  SesionHorario.legacy({
    required String id,
    required this.dia,
    required this.hora,
    this.materia,
    this.notas,
    this.actividad,
    String? curso,
    this.esExamen = false,
  })  : sesionId = id,
        docenteId = 1, // ID temporal por defecto
        materiaId = materia?.id,
        cursoId = null,
        cursoNombre = curso,
        aula = null,
        esTutoria = false,
        recursosNecesarios = const [],
        tipoSesion = 'clase',
        userId = 'local'; // 👈 añadido para compatibilidad mínima

  /// Getter para compatibilidad: devuelve el ID de sesión - CORREGIDO
  @override
  int? get id => sesionId.hashCode;

  /// Getter para compatibilidad: devuelve el nombre del curso
  String? get curso => cursoNombre;

  /// Crea una copia de esta instancia con valores opcionales actualizados.
  /// Los parámetros `clear...` permiten establecer un campo en `null` explícitamente.
  SesionHorario copyWith({
    int? id,
    String? sesionId,
    int? docenteId,
    String? dia,
    String? hora,
    int? materiaId,
    int? cursoId,
    String? aula,
    String? notas,
    String? actividad,
    bool? esExamen,
    bool? esTutoria,
    List<String>? recursosNecesarios,
    String? tipoSesion,
    Materia? materia,
    String? cursoNombre,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
    bool clearMateria = false,
    bool clearNotas = false,
    bool clearActividad = false,
    String? userId, // 👈 añadido aquí también
  }) {
    return SesionHorario(
      id: id ?? this.id,
      sesionId: sesionId ?? this.sesionId,
      docenteId: docenteId ?? this.docenteId,
      dia: dia ?? this.dia,
      hora: hora ?? this.hora,
      materiaId: clearMateria ? null : (materiaId ?? this.materiaId),
      cursoId: cursoId ?? this.cursoId,
      aula: aula ?? this.aula,
      notas: clearNotas ? null : (notas ?? this.notas),
      actividad: clearActividad ? null : (actividad ?? this.actividad),
      esExamen: esExamen ?? this.esExamen,
      esTutoria: esTutoria ?? this.esTutoria,
      recursosNecesarios: recursosNecesarios ?? this.recursosNecesarios,
      tipoSesion: tipoSesion ?? this.tipoSesion,
      materia: clearMateria ? null : (materia ?? this.materia),
      cursoNombre: cursoNombre ?? this.cursoNombre,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      userId: userId ?? this.userId, // 👈 aseguramos que se propague
    );
  }

  // ============================================================================
  // MÉTODOS FIRESTORE
  // ============================================================================

  /// Constructor desde Firestore
  factory SesionHorario.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final materiaData = data['materia'] as Map<String, dynamic>?;

    Materia? materia;
    if (materiaData != null) {
      materia = Materia(
        id: materiaData['id'],
        nombre: materiaData['nombre'],
        color: Color(materiaData['color']),
        descripcion: materiaData['descripcion'],
      );
    }

    return SesionHorario(
      sesionId: data['id']?.toString() ?? doc.id,
      docenteId: data['docenteId'] ?? 1,
      dia: data['dia'] ?? '',
      hora: data['hora'] ?? '',
      materiaId: materiaData?['id'],
      materia: materia,
      notas: data['notas'],
      actividad: data['actividad'],
      esExamen: data['esExamen'] ?? false,
      cursoNombre: data['cursoNombre'],
      userId: data['userId'] ?? '', // 🔹 añadido
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  /// Convierte a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': sesionId,
      'docenteId': docenteId,
      'dia': dia,
      'hora': hora,
      'materia': materia != null
          ? {
              'id': materia!.id,
              'nombre': materia!.nombre,
              'color': materia!.color.value,
              'descripcion': materia!.descripcion,
            }
          : null,
      'notas': notas,
      'actividad': actividad,
      'esExamen': esExamen,
      'cursoNombre': cursoNombre,
      'userId': userId, // 🔹 añadido
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// 🔹 Auxiliar para timestamps que puede ser Timestamp, DateTime o null
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  // ============================================================================
// MÉTODOS SQLite
// ============================================================================

  /// Convierte la sesión a Map para SQLite
  @override
  Map<String, dynamic> toMap() {
    return {
      'id': sesionId,
      'docente_id': docenteId,
      'dia': dia,
      'hora': hora,
      'materia_id': materiaId,
      'curso_id': cursoId,
      'aula': aula,
      'notas': notas,
      'actividad': actividad,
      'es_examen': esExamen ? 1 : 0,
      'es_tutoria': esTutoria ? 1 : 0,
      'recursos_necesarios': jsonEncode(recursosNecesarios),
      'tipo_sesion': tipoSesion,
      'user_id': userId, // 👈 persistencia local de usuario
      'created_at': createdAt?.millisecondsSinceEpoch ?? currentTimestamp,
      'updated_at': updatedAt?.millisecondsSinceEpoch ?? currentTimestamp,
      'synced_at': syncedAt?.millisecondsSinceEpoch,
    };
  }

  /// Crea una SesionHorario desde Map de SQLite
  static SesionHorario fromMap(
    Map<String, dynamic> map, {
    Materia? materia,
    String? cursoNombre,
  }) {
    return SesionHorario(
      id: map['id'],
      sesionId: map['id']?.toString() ?? '', // 👈 conversión segura
      docenteId: map['docente_id'] ?? 1,
      dia: map['dia'] ?? '',
      hora: map['hora'] ?? '',
      materiaId: map['materia_id'],
      cursoId: map['curso_id'],
      aula: map['aula'],
      notas: map['notas'],
      actividad: map['actividad'],
      esExamen: (map['es_examen'] ?? 0) == 1,
      esTutoria: (map['es_tutoria'] ?? 0) == 1,
      recursosNecesarios: map['recursos_necesarios'] != null
          ? List<String>.from(jsonDecode(map['recursos_necesarios']))
          : [],
      tipoSesion: map['tipo_sesion'] ?? 'clase',
      userId: map['user_id'] ?? 'local', // 👈 valor por defecto si falta
      materia: materia,
      cursoNombre: cursoNombre,
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

  /// Genera horario inicial vacío para compatibilidad con weekly_planner_screen.dart
  static List<SesionHorario> generateInitialSchedule({
    int docenteId = 1,
    String userId = 'local', // 👈 añadido para persistencia
  }) {
    const dias = ['L', 'M', 'X', 'J', 'V'];
    const horas = ['08:00', '09:00', '10:00', '11:00', '12:00'];

    return dias
        .expand((dia) => horas.map((hora) => SesionHorario(
              sesionId: '${dia}_$hora',
              docenteId: docenteId,
              dia: dia,
              hora: hora,
              userId: userId, // 👈 añadido en cada instancia
            )))
        .toList();
  }

  /// Verifica si el evento está sincronizado
  bool get estaSincronizado =>
      syncedAt != null && (updatedAt == null || syncedAt!.isAfter(updatedAt!));

  /// Verifica si la sesión tiene contenido
  bool get tieneContenido =>
      materia != null || actividad != null || notas != null;

  /// Descripción completa de la sesión
  String get descripcionCompleta {
    final partes = <String>[];
    if (materia != null) partes.add(materia!.nombre);
    if (cursoNombre != null && cursoNombre!.isNotEmpty)
      partes.add('($cursoNombre)');
    if (actividad != null && actividad!.isNotEmpty) partes.add('- $actividad');
    return partes.join(' ');
  }
}
