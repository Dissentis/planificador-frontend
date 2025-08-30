// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'main_screen.dart'; // Importamos la pantalla principal con la navegación.

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Título y Subtítulo ---
                  const Text(
                    '¡Bienvenido a AulaPlan!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111518),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Organiza tus cursos y tareas de forma eficiente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF9AAAB6),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- Campo de Correo Electrónico ---
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Correo electrónico',
                      prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFF9AAAB6)),
                      filled: true,
                      fillColor: const Color(0xFFF0F3F4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // --- Campo de Contraseña ---
                  TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF9AAAB6)),
                      filled: true,
                      fillColor: const Color(0xFFF0F3F4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- Botón de Acceder ---
                  ElevatedButton(
                    onPressed: () {
                      // Usamos pushReplacement para que el usuario no pueda "volver atrás"
                      // a la pantalla de login una vez ha iniciado sesión.
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const MainScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1991E6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Acceder', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),

                  // --- Botón de Registrarse ---
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Implementar la navegación a la pantalla de registro.
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8F5FE),
                      foregroundColor: const Color(0xFF1991E6),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Registrarse', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                  
                  // --- Enlace de Olvidaste tu contraseña ---
                  TextButton(
                    onPressed: (){
                      // TODO: Implementar la lógica de recuperación de contraseña.
                    },
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                       style: TextStyle(color: Color(0xFF9AAAB6)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}