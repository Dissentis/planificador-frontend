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
// MODELO DE USUARIO/DOCENTE ACTUALIZADO
// ============================================================================
class UserModel extends BaseModel {
  String name;
  String lastName;
  String school;
  String province;
  String autonomousCommunity;

  // Campos adicionales para el planificador docente
  final String? firebaseUid;
  final String? email;
  final String? emailInstitucional;
  final String? telefono;
  final int? centroId;
  final int? departamentoId;
  final String? despacho;
  final String? horarioAtencion;
  final String jornada; // 'mañana', 'tarde', 'completa'
  final int anosExperiencia;
  final List<String> especialidades;
  final List<String> titulaciones;
  final List<String> plataformasEducativas;
  final List<String> metodologiasPreferidas;
  final bool isActive;

  UserModel({
    super.id,
    this.name = '',
    this.lastName = '',
    this.school = '',
    this.province = '',
    this.autonomousCommunity = '',
    this.firebaseUid,
    this.email,
    this.emailInstitucional,
    this.telefono,
    this.centroId,
    this.departamentoId,
    this.despacho,
    this.horarioAtencion,
    this.jornada = 'completa',
    this.anosExperiencia = 0,
    this.especialidades = const [],
    this.titulaciones = const [],
    this.plataformasEducativas = const [],
    this.metodologiasPreferidas = const [],
    this.isActive = true,
    super.createdAt,
    super.updatedAt,
    super.syncedAt,
  });

  // ============================================================================
  // COMPATIBILIDAD CON CÓDIGO EXISTENTE
  // ============================================================================

  /// Crea un objeto UserModel desde un Mapa (leído de un JSON) - COMPATIBILIDAD
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'] ?? '',
      lastName: json['lastName'] ?? '',
      school: json['school'] ?? '',
      province: json['province'] ?? '',
      autonomousCommunity: json['autonomousCommunity'] ?? '',
      firebaseUid: json['firebaseUid'],
      email: json['email'],
      emailInstitucional: json['emailInstitucional'],
      telefono: json['telefono'],
      jornada: json['jornada'] ?? 'completa',
      anosExperiencia: json['anosExperiencia'] ?? 0,
      especialidades: json['especialidades'] != null
          ? List<String>.from(json['especialidades'])
          : [],
      titulaciones: json['titulaciones'] != null
          ? List<String>.from(json['titulaciones'])
          : [],
      plataformasEducativas: json['plataformasEducativas'] != null
          ? List<String>.from(json['plataformasEducativas'])
          : [],
      metodologiasPreferidas: json['metodologiasPreferidas'] != null
          ? List<String>.from(json['metodologiasPreferidas'])
          : [],
    );
  }

  /// Convierte un objeto UserModel a un Mapa (para JSON) - COMPATIBILIDAD
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'lastName': lastName,
      'school': school,
      'province': province,
      'autonomousCommunity': autonomousCommunity,
      'firebaseUid': firebaseUid,
      'email': email,
      'emailInstitucional': emailInstitucional,
      'telefono': telefono,
      'jornada': jornada,
      'anosExperiencia': anosExperiencia,
      'especialidades': especialidades,
      'titulaciones': titulaciones,
      'plataformasEducativas': plataformasEducativas,
      'metodologiasPreferidas': metodologiasPreferidas,
    };
  }

  // ============================================================================
  // MÉTODOS SQLITE
  // ============================================================================

  /// Convierte el docente a Map para SQLite
  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firebase_uid': firebaseUid,
      'nombre': name,
      'apellidos': lastName,
      'email': email ?? '',
      'email_institucional': emailInstitucional,
      'telefono': telefono,
      'centro_id': centroId,
      'departamento_id': departamentoId,
      'despacho': despacho,
      'horario_atencion': horarioAtencion,
      'jornada': jornada,
      'años_experiencia': anosExperiencia,
      'especialidades': jsonEncode(especialidades),
      'titulaciones': jsonEncode(titulaciones),
      'plataformas_educativas': jsonEncode(plataformasEducativas),
      'metodologias_preferidas': jsonEncode(metodologiasPreferidas),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt?.millisecondsSinceEpoch ?? currentTimestamp,
      'updated_at': updatedAt?.millisecondsSinceEpoch ?? currentTimestamp,
      // Campos adicionales del modelo original
      'school': school,
      'province': province,
      'autonomous_community': autonomousCommunity,
    };
  }

  /// Crea un UserModel desde Map de SQLite
  static UserModel fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      firebaseUid: map['firebase_uid'],
      name: map['nombre'] ?? '',
      lastName: map['apellidos'] ?? '',
      email: map['email'],
      emailInstitucional: map['email_institucional'],
      telefono: map['telefono'],
      centroId: map['centro_id'],
      departamentoId: map['departamento_id'],
      despacho: map['despacho'],
      horarioAtencion: map['horario_atencion'],
      jornada: map['jornada'] ?? 'completa',
      anosExperiencia: map['años_experiencia'] ?? 0,
      especialidades: map['especialidades'] != null
          ? List<String>.from(jsonDecode(map['especialidades']))
          : [],
      titulaciones: map['titulaciones'] != null
          ? List<String>.from(jsonDecode(map['titulaciones']))
          : [],
      plataformasEducativas: map['plataformas_educativas'] != null
          ? List<String>.from(jsonDecode(map['plataformas_educativas']))
          : [],
      metodologiasPreferidas: map['metodologias_preferidas'] != null
          ? List<String>.from(jsonDecode(map['metodologias_preferidas']))
          : [],
      isActive: (map['is_active'] ?? 1) == 1,
      school: map['school'] ?? '',
      province: map['province'] ?? '',
      autonomousCommunity: map['autonomous_community'] ?? '',
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

  /// Copia el modelo con valores actualizados
  UserModel copyWith({
    int? id,
    String? name,
    String? lastName,
    String? school,
    String? province,
    String? autonomousCommunity,
    String? firebaseUid,
    String? email,
    String? emailInstitucional,
    String? telefono,
    int? centroId,
    int? departamentoId,
    String? despacho,
    String? horarioAtencion,
    String? jornada,
    int? anosExperiencia,
    List<String>? especialidades,
    List<String>? titulaciones,
    List<String>? plataformasEducativas,
    List<String>? metodologiasPreferidas,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      lastName: lastName ?? this.lastName,
      school: school ?? this.school,
      province: province ?? this.province,
      autonomousCommunity: autonomousCommunity ?? this.autonomousCommunity,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      email: email ?? this.email,
      emailInstitucional: emailInstitucional ?? this.emailInstitucional,
      telefono: telefono ?? this.telefono,
      centroId: centroId ?? this.centroId,
      departamentoId: departamentoId ?? this.departamentoId,
      despacho: despacho ?? this.despacho,
      horarioAtencion: horarioAtencion ?? this.horarioAtencion,
      jornada: jornada ?? this.jornada,
      anosExperiencia: anosExperiencia ?? this.anosExperiencia,
      especialidades: especialidades ?? this.especialidades,
      titulaciones: titulaciones ?? this.titulaciones,
      plataformasEducativas:
          plataformasEducativas ?? this.plataformasEducativas,
      metodologiasPreferidas:
          metodologiasPreferidas ?? this.metodologiasPreferidas,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  /// Nombre completo del docente
  String get nombreCompleto => '$name $lastName';

  /// Verificar si el modelo está sincronizado
  bool get estaSincronizado =>
      syncedAt != null && (updatedAt == null || syncedAt!.isAfter(updatedAt!));
}
