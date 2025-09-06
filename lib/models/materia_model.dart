// lib/models/materia_model.dart
import 'package:flutter/material.dart';

class Materia {
  final int? id;
  final String nombre;
  final Color color;
  final String? codigo;
  final String? descripcion;

  const Materia({
    this.id,
    required this.nombre,
    required this.color,
    this.codigo,
    this.descripcion,
  });

  /// Crea una copia de esta instancia con valores opcionales actualizados.
  Materia copyWith({
    int? id,
    String? nombre,
    Color? color,
    String? codigo,
    String? descripcion,
  }) {
    return Materia(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      color: color ?? this.color,
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'codigo': codigo,
      'color': color.value,
      'descripcion': descripcion,
    };
  }

  static Materia fromMap(Map<String, dynamic> map) {
    return Materia(
      id: map['id'],
      nombre: map['nombre'] ?? '',
      codigo: map['codigo'],
      color: Color(map['color'] ?? Colors.grey.value),
      descripcion: map['descripcion'],
    );
  }
}
