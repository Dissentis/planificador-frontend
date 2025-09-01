// Ruta: lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart'; // <-- LA CORRECCIÓN ESTÁ AQUÍ
import 'package:flutter/foundation.dart';

class AuthService {
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
      debugPrint("⚠️ No hay ningún usuario con la sesión iniciada. Intentando login anónimo...");
      await signInAnonymously();
      // Volvemos a comprobar si ahora hay un usuario
      if (FirebaseAuth.instance.currentUser == null) {
        debugPrint("❌ Falló el login anónimo. No se puede obtener el token.");
        return null;
      }
    }
    
    debugPrint("Obteniendo ID Token...");
    try {
      final String? idToken = await FirebaseAuth.instance.currentUser?.getIdToken(true);
      return idToken;
    } catch (e) {
      debugPrint("❌ Error al obtener el ID Token: $e");
      return null;
    }
  }
}