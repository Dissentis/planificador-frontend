// lib/providers.dart
// ============================================================================
// EXPORTACIONES (DEBEN IR PRIMERO)
// ============================================================================
export 'services/firestore_service.dart';
export 'repositories/sesion_repository_firestore.dart';
export 'repositories/sesion_repository_universal.dart';
export 'providers/firestore_provider.dart';

// ============================================================================
// PROVIDERS (DESPUÉS DE LAS EXPORTACIONES)
// ============================================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Provider de SharedPreferences no inicializado');
});
