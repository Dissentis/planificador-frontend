// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sesion_model.dart';
import 'package:flutter/material.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================================
  // GETTER AUXILIAR
  // ============================================================================

  String? get currentUserId {
    return _auth.currentUser?.uid;
  }

  // ============================================================================
  // COLECCIONES
  // ============================================================================

  CollectionReference get _sesionesCollection =>
      _firestore.collection('sesiones');

  CollectionReference get _materiasCollection =>
      _firestore.collection('materias');

// ============================================================================
// SESIONES
// ============================================================================

  /// Guardar o actualizar sesión en Firestore
  Future<void> guardarSesion(SesionHorario sesion) async {
    print('🟢 GUARDANDO SESIÓN: ${sesion.toFirestore()}');
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    // 👇 Clave única por usuario + celda del calendario
    final docId = '${user.uid}_${sesion.sesionId}';
    print('📝 Document ID: $docId');

    final sesionData = {
      'id': sesion.sesionId, // usamos el sesionId lógico
      'dia': sesion.dia,
      'hora': sesion.hora,
      'materia': sesion.materia != null
          ? {
              'id': sesion.materia!.id,
              'nombre': sesion.materia!.nombre,
              'color': sesion.materia!.color.value,
            }
          : null,
      'actividad': sesion.actividad,
      'notas': sesion.notas,
      'esExamen': sesion.esExamen,
      'cursoNombre': sesion.cursoNombre,
      'userId': user.uid, // 👈 obligatorio para distinguir usuarios
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 👇 merge evita sobreescribir campos ya existentes
    await _sesionesCollection
        .doc(docId)
        .set(sesionData, SetOptions(merge: true));
  }

  /// Obtener sesiones en tiempo real
  Stream<List<SesionHorario>> observarSesiones() {
    print('🎯 ESCUCHANDO CAMBIOS EN FIRESTORE');
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ USUARIO NULL - RETORNANDO STREAM VACÍO');
      return Stream.value([]);
    }

    print('👤 USUARIO AUTENTICADO: ${user.uid}');

    return _sesionesCollection
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      print('📦 DATOS RECIBIDOS: ${snapshot.docs.length} sesiones');
      final sesiones = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        print('📄 Documento: ${doc.id} - Data: $data');

        return SesionHorario(
          sesionId: data['id']?.toString() ?? doc.id.split('_').last,
          docenteId: data['docenteId'] ?? 1,
          dia: data['dia'] ?? '',
          hora: data['hora'] ?? '',
          materia: data['materia'] != null
              ? Materia(
                  id: data['materia']['id'],
                  nombre: data['materia']['nombre'],
                  color: Color(data['materia']['color']),
                )
              : null,
          actividad: data['actividad'],
          notas: data['notas'],
          esExamen: data['esExamen'] ?? false,
          cursoNombre: data['cursoNombre'],
          userId: data['userId']?.toString() ?? user.uid,
        );
      }).toList();

      // 👇 Ordenamos en memoria
      sesiones.sort((a, b) {
        final cmpDia = a.dia.compareTo(b.dia);
        if (cmpDia != 0) return cmpDia;
        return a.hora.compareTo(b.hora);
      });

      return sesiones;
    });
  }

  /// Eliminar sesión
  Future<void> eliminarSesion(String sesionId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final docId = '${user.uid}_$sesionId';
    print('🗑️ ELIMINANDO SESIÓN: $docId');
    await _sesionesCollection.doc(docId).delete();
  }

// ============================================================================
// MATERIAS
// ============================================================================

  Future<void> guardarMateria(Materia materia) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final materiaData = {
      'id': materia.id,
      'nombre': materia.nombre,
      'color': materia.color.value,
      'userId': user.uid, // 👈 obligatorio para filtrar por usuario
      'updatedAt': FieldValue.serverTimestamp(),
    };

    print('🟢 GUARDANDO MATERIA: ${materia.id} -> $materiaData');

    await _materiasCollection
        .doc(materia.id.toString())
        .set(materiaData, SetOptions(merge: true)); // 👈 merge habilitado
  }

  Stream<List<Materia>> observarMaterias() {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ USUARIO NULL - RETORNANDO STREAM VACÍO');
      return Stream.value([]);
    }

    print('👤 ESCUCHANDO MATERIAS DE: ${user.uid}');

    return _materiasCollection
        .where('userId', isEqualTo: user.uid)
        .orderBy('nombre')
        .snapshots()
        .map((snapshot) {
      print('📦 DATOS RECIBIDOS (Materias): ${snapshot.docs.length}');
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        print('📄 Materia: ${doc.id} -> $data');

        // 👇 ahora usamos el helper Materia.fromFirestore
        return Materia.fromFirestore(data, user.uid);
      }).toList();
    });
  }

// ============================================================================
// SINCRONIZACIÓN INICIAL
// ============================================================================

  Future<void> sincronizarDatosExistentes(
      List<SesionHorario> sesiones, List<Materia> materias) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final batch = _firestore.batch();

    // 🔹 Sincronizar sesiones
    for (final sesion in sesiones) {
      final docId = '${user.uid}_${sesion.sesionId}'; // 👈 clave compuesta
      final docRef = _sesionesCollection.doc(docId);

      final data = {
        'id': sesion.sesionId,
        'dia': sesion.dia,
        'hora': sesion.hora,
        'materia': sesion.materia != null
            ? {
                'id': sesion.materia!.id,
                'nombre': sesion.materia!.nombre,
                'color': sesion.materia!.color.value,
              }
            : null,
        'actividad': sesion.actividad,
        'notas': sesion.notas,
        'esExamen': sesion.esExamen,
        'cursoNombre': sesion.cursoNombre,
        'userId': user.uid, // 👈 coherente con sesiones guardadas
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print('⬆️ [SYNC] Sesión -> $docId : $data');
      batch.set(docRef, data, SetOptions(merge: true)); // 👈 merge habilitado
    }

    // 🔹 Sincronizar materias
    for (final materia in materias) {
      final docRef = _materiasCollection.doc(materia.id.toString());
      final data = {
        'id': materia.id,
        'nombre': materia.nombre,
        'color': materia.color.value,
        'userId': user.uid, // 👈 coherente con sesiones
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print('⬆️ [SYNC] Materia -> ${materia.id} : $data');
      batch.set(docRef, data, SetOptions(merge: true)); // 👈 merge habilitado
    }

    await batch.commit();
    print('✅ [SYNC] Sincronización completada correctamente');
  }
}
