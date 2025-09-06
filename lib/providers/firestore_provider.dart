// lib/providers/firestore_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../models/sesion_model.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final sesionesStreamProvider = StreamProvider<List<SesionHorario>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.observarSesiones();
});

final materiasStreamProvider = StreamProvider<List<Materia>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.observarMaterias();
});
