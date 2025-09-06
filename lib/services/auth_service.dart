// Ruta: lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  // Función para iniciar sesión con email y contraseña
  Future<bool> signIn(String email, String password) async {
    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint("✅ Usuario autenticado: ${userCredential.user?.email}");
      return true;
    } catch (e) {
      debugPrint("❌ Error en el login: $e");
      return false;
    }
  }

  // Función para registrar usuario con email y contraseña
  Future<bool> signUp(String email, String password) async {
    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint("✅ Usuario registrado: ${userCredential.user?.email}");
      return true;
    } catch (e) {
      debugPrint("❌ Error en el registro: $e");
      return false;
    }
  }

  // Función para cerrar sesión
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      debugPrint("✅ Usuario desconectado");
    } catch (e) {
      debugPrint("❌ Error al cerrar sesión: $e");
    }
  }

  // Función para logging de eventos (placeholder)
  void logEvent(String event) {
    debugPrint("📊 Evento registrado: $event");
  }

  // Función para iniciar sesión de forma anónima
  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      debugPrint("✅ Usuario anónimo autenticado: ${userCredential.user?.uid}");
      return userCredential.user;
    } catch (e) {
      debugPrint("❌ Error en el login anónimo: $e");
      return null;
    }
  }

  // Función para obtener el ID Token del usuario actual
  Future<String?> getFirebaseIdToken() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint("⚠️ No hay ningún usuario con la sesión iniciada.");
      return null;
    }

    debugPrint("Obteniendo ID Token...");
    try {
      final String? idToken = await user.getIdToken(true);
      return idToken;
    } catch (e) {
      debugPrint("❌ Error al obtener el ID Token: $e");
      return null;
    }
  }
}
