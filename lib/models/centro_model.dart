// ============================================================================
// IMPORTACIONES
// ============================================================================
import 'dart:convert';

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
// MODELO DE CENTRO EDUCATIVO
// ============================================================================
class Centro extends BaseModel {
  final String nombre;
  final String? codigo;
  final String? direccion;
  final String? telefono;
  final String? email;
  final String tipoCentro; // 'publico', 'privado', 'concertado'

  Centro({
    super.id,
    required this.nombre,
    this.codigo,
    this.direccion,
    this.telefono,
    this.email,
    required this.tipoCentro,
    super.createdAt,
    super.updatedAt,
    super.syncedAt,
  });

  // ============================================================================
  // MÉTODOS SQLite
  // ============================================================================

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'codigo': codigo,
      'direccion': direccion,
      'telefono': telefono,
      'email': email,
      'tipo_centro': tipoCentro,
      'created_at': createdAt?.millisecondsSinceEpoch ?? currentTimestamp,
      'updated_at': updatedAt?.millisecondsSinceEpoch ?? currentTimestamp,
      'synced_at': syncedAt?.millisecondsSinceEpoch,
    };
  }

  static Centro fromMap(Map<String, dynamic> map) {
    return Centro(
      id: map['id'],
      nombre: map['nombre'] ?? '',
      codigo: map['codigo'],
      direccion: map['direccion'],
      telefono: map['telefono'],
      email: map['email'],
      tipoCentro: map['tipo_centro'] ?? 'publico',
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
  // MÉTODOS DE INSTANCIA
  // ============================================================================

  /// Crea una copia con valores actualizados
  Centro copyWith({
    int? id,
    String? nombre,
    String? codigo,
    String? direccion,
    String? telefono,
    String? email,
    String? tipoCentro,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
  }) {
    return Centro(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      codigo: codigo ?? this.codigo,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      tipoCentro: tipoCentro ?? this.tipoCentro,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  /// Verifica si el centro está sincronizado
  bool get estaSincronizado =>
      syncedAt != null && (updatedAt == null || syncedAt!.isAfter(updatedAt!));

  /// Obtiene información completa del centro
  String get informacionCompleta {
    final partes = <String>[];
    partes.add(nombre);
    if (codigo != null && codigo!.isNotEmpty) {
      partes.add('($codigo)');
    }
    return partes.join(' ');
  }

  // ============================================================================
  // MÉTODOS ESTÁTICOS AUXILIARES
  // ============================================================================

  /// Obtiene centros de ejemplo/demo
  static List<Centro> getCentrosDemo() {
    return [
      Centro(
        id: 1,
        nombre: 'IES Miguel de Cervantes',
        codigo: '28000001',
        direccion: 'Calle Principal, 1',
        telefono: '912345678',
        email: 'info@iescervantes.edu.es',
        tipoCentro: 'publico',
      ),
      Centro(
        id: 2,
        nombre: 'Colegio San Patricio',
        codigo: '28000002',
        direccion: 'Avenida de la Educación, 25',
        telefono: '913456789',
        email: 'secretaria@sanpatricio.es',
        tipoCentro: 'concertado',
      ),
      Centro(
        id: 3,
        nombre: 'Colegio Internacional Madrid',
        codigo: '28000003',
        direccion: 'Urbanización Las Rozas, 45',
        telefono: '914567890',
        email: 'admissions@cimadrid.com',
        tipoCentro: 'privado',
      ),
    ];
  }

  /// Valida los datos del centro
  static String? validarCentro(Centro centro) {
    if (centro.nombre.isEmpty) {
      return 'El nombre del centro es obligatorio';
    }

    if (centro.nombre.length < 3) {
      return 'El nombre debe tener al menos 3 caracteres';
    }

    final tiposValidos = ['publico', 'privado', 'concertado'];
    if (!tiposValidos.contains(centro.tipoCentro)) {
      return 'Tipo de centro inválido';
    }

    if (centro.email != null && centro.email!.isNotEmpty) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(centro.email!)) {
        return 'Email inválido';
      }
    }

    if (centro.telefono != null && centro.telefono!.isNotEmpty) {
      final telefonoRegex = RegExp(r'^\d{9}$');
      if (!telefonoRegex.hasMatch(centro.telefono!.replaceAll(' ', ''))) {
        return 'Teléfono debe tener 9 dígitos';
      }
    }

    return null; // Sin errores
  }
}

// ============================================================================
// MODELO DE DEPARTAMENTO
// ============================================================================
class Departamento extends BaseModel {
  final String nombre;
  final int? centroId;
  final int? jefeDepartamentoId;

  Departamento({
    super.id,
    required this.nombre,
    this.centroId,
    this.jefeDepartamentoId,
    super.createdAt,
    super.updatedAt,
    super.syncedAt,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'centro_id': centroId,
      'jefe_departamento_id': jefeDepartamentoId,
      'created_at': createdAt?.millisecondsSinceEpoch ?? currentTimestamp,
      'updated_at': updatedAt?.millisecondsSinceEpoch ?? currentTimestamp,
      'synced_at': syncedAt?.millisecondsSinceEpoch,
    };
  }

  static Departamento fromMap(Map<String, dynamic> map) {
    return Departamento(
      id: map['id'],
      nombre: map['nombre'] ?? '',
      centroId: map['centro_id'],
      jefeDepartamentoId: map['jefe_departamento_id'],
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

  /// Crea una copia con valores actualizados
  Departamento copyWith({
    int? id,
    String? nombre,
    int? centroId,
    int? jefeDepartamentoId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
  }) {
    return Departamento(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      centroId: centroId ?? this.centroId,
      jefeDepartamentoId: jefeDepartamentoId ?? this.jefeDepartamentoId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  /// Departamentos típicos de un centro educativo
  static List<Departamento> getDepartamentosDefault() {
    return [
      Departamento(id: 1, nombre: 'Matemáticas'),
      Departamento(id: 2, nombre: 'Lengua y Literatura'),
      Departamento(id: 3, nombre: 'Ciencias Naturales'),
      Departamento(id: 4, nombre: 'Ciencias Sociales'),
      Departamento(id: 5, nombre: 'Idiomas'),
      Departamento(id: 6, nombre: 'Educación Física'),
      Departamento(id: 7, nombre: 'Artes y Música'),
      Departamento(id: 8, nombre: 'Tecnología'),
      Departamento(id: 9, nombre: 'Orientación'),
    ];
  }
}

// ============================================================================
// MODELO DE CURSO/GRUPO
// ============================================================================
class Curso extends BaseModel {
  final String nombre; // '1º ESO A', '2º Bachillerato C'
  final String nivel; // 'ESO', 'Bachillerato', 'FP'
  final String cursoAcademico; // '2024-2025'
  final int? centroId;
  final int? tutorId; // docente que es tutor
  final int numeroAlumnos;
  final bool isActive;

  Curso({
    super.id,
    required this.nombre,
    required this.nivel,
    required this.cursoAcademico,
    this.centroId,
    this.tutorId,
    this.numeroAlumnos = 0,
    this.isActive = true,
    super.createdAt,
    super.updatedAt,
    super.syncedAt,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'nivel': nivel,
      'curso_academico': cursoAcademico,
      'centro_id': centroId,
      'tutor_id': tutorId,
      'numero_alumnos': numeroAlumnos,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt?.millisecondsSinceEpoch ?? currentTimestamp,
      'updated_at': updatedAt?.millisecondsSinceEpoch ?? currentTimestamp,
      'synced_at': syncedAt?.millisecondsSinceEpoch,
    };
  }

  static Curso fromMap(Map<String, dynamic> map) {
    return Curso(
      id: map['id'],
      nombre: map['nombre'] ?? '',
      nivel: map['nivel'] ?? '',
      cursoAcademico: map['curso_academico'] ?? '',
      centroId: map['centro_id'],
      tutorId: map['tutor_id'],
      numeroAlumnos: map['numero_alumnos'] ?? 0,
      isActive: (map['is_active'] ?? 1) == 1,
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

  /// Cursos típicos para un centro
  static List<Curso> getCursosDefault({String cursoAcademico = '2024-2025'}) {
    return [
      // ESO
      Curso(nombre: '1º ESO A', nivel: 'ESO', cursoAcademico: cursoAcademico),
      Curso(nombre: '1º ESO B', nivel: 'ESO', cursoAcademico: cursoAcademico),
      Curso(nombre: '2º ESO A', nivel: 'ESO', cursoAcademico: cursoAcademico),
      Curso(nombre: '2º ESO B', nivel: 'ESO', cursoAcademico: cursoAcademico),
      Curso(nombre: '3º ESO A', nivel: 'ESO', cursoAcademico: cursoAcademico),
      Curso(nombre: '3º ESO B', nivel: 'ESO', cursoAcademico: cursoAcademico),
      Curso(nombre: '4º ESO A', nivel: 'ESO', cursoAcademico: cursoAcademico),
      Curso(nombre: '4º ESO B', nivel: 'ESO', cursoAcademico: cursoAcademico),

      // Bachillerato
      Curso(
          nombre: '1º Bachillerato A',
          nivel: 'Bachillerato',
          cursoAcademico: cursoAcademico),
      Curso(
          nombre: '1º Bachillerato B',
          nivel: 'Bachillerato',
          cursoAcademico: cursoAcademico),
      Curso(
          nombre: '2º Bachillerato A',
          nivel: 'Bachillerato',
          cursoAcademico: cursoAcademico),
      Curso(
          nombre: '2º Bachillerato B',
          nivel: 'Bachillerato',
          cursoAcademico: cursoAcademico),
    ];
  }
}
