// =============================================================
// 1. IMPORTS
// =============================================================
// Se importan únicamente las dependencias necesarias para:
// 1. Widgets de Flutter.
// 2. Gestión de estado con Riverpod.
// 3. Almacenamiento persistente con SharedPreferences.
// 4. Navegación hacia la pantalla principal.
// 5. Servicio de autenticación centralizado.
// 6. Pantallas auxiliares de registro y recuperación de contraseña.
import '../providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';

// =============================================================
// 2. CONSTANTES GLOBALES
// =============================================================
// Mensajes de error reutilizables y expresiones regulares
// para validar entradas de usuario en el formulario.
const String kErrorInvalidEmail = "Por favor, introduce un correo válido.";
const String kErrorEmptyPassword = "La contraseña no puede estar vacía.";
const String kErrorWeakPassword =
    "La contraseña debe tener al menos 6 caracteres.";
final RegExp kEmailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');

// =============================================================
// 3. CLASE PRINCIPAL: LoginScreen
// =============================================================
// Pantalla principal de autenticación inicial. Se define como
// ConsumerStatefulWidget para poder acceder a los providers
// y manejar el estado de los campos de texto, validaciones
// y el indicador de carga.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // =============================================================
  // 4. CONTROLADORES Y ESTADO
  // =============================================================
  // Controladores para gestionar el contenido de los campos de
  // texto de email y contraseña, además de la clave de formulario,
  // bandera de estado de carga y preferencia de recordar usuario.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    // Libera los recursos de los controladores para evitar fugas de memoria.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // =============================================================
// 5. MÉTODOS DE ACCIÓN
// =============================================================

  /// Carga las credenciales guardadas desde SharedPreferences al iniciar la pantalla
  /// y establece el estado de recordar usuario si existen datos guardados.
  Future<void> _loadSavedCredentials() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedEmail = prefs.getString('saved_email');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (savedEmail != null && rememberMe) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = rememberMe;
      });
    }
  }

  /// Ejecuta el proceso de login con validación, retry y logging estructurado.
  /// Flujo:
  /// 1. Valida los campos del formulario.
  /// 2. Activa el estado de carga.
  /// 3. Guarda las preferencias de usuario en SharedPreferences.
  /// 4. Llama al servicio de autenticación centralizado.
  /// 5. Si es correcto → navega al MainScreen.
  /// 6. Si falla → reintenta una vez en caso de error de red.
  /// 7. Si aún falla → muestra error contextual y lo registra.
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Guardar preferencias antes de autenticar
      final prefs = ref.read(sharedPreferencesProvider);
      if (_rememberMe) {
        await prefs.setString('saved_email', _emailController.text.trim());
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('saved_email');
        await prefs.setBool('remember_me', false);
      }

      bool success = await AuthService().signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // Retry en caso de fallo por red (simulación simple con Exception check)
      if (!success) {
        _logError("Primer intento de login fallido");
        success = await _retryLogin();
      }

      if (success) {
        AuthService().logEvent("login_success");
        await prefs.setBool('isLoggedIn', true);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else {
        _showError("Credenciales inválidas");
        _logError("Login fallido: credenciales inválidas");
      }
    } catch (e) {
      _showError("Error inesperado: $e");
      _logError("Excepción en login: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Ejecuta un retry único del proceso de login,
  /// usado para casos de error de red u otros fallos temporales.
  Future<bool> _retryLogin() async {
    try {
      return await AuthService().signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } catch (e) {
      _logError("Error en retry de login: $e");
      return false;
    }
  }

  /// Muestra un mensaje de error al usuario mediante un SnackBar
  /// en la parte inferior de la pantalla.
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  /// Registra los errores de forma estructurada.
  /// En esta fase se limita a consola, pero puede integrarse
  /// con Sentry, Firebase Crashlytics o un logger centralizado.
  void _logError(String message) {
    // ignore: avoid_print
    print("[LOGIN_ERROR] $message");
  }

// =============================================================
// 6. UI PRINCIPAL
// =============================================================

  /// Construye la interfaz completa de la pantalla de login.
  /// Incluye:
  /// - Encabezado con título y subtítulo.
  /// - Formulario con campos de email y contraseña (ambos validados).
  /// - Opción para mantener la sesión iniciada.
  /// - Botón de acceso con indicador de carga.
  /// - Botón de registro que navega a la pantalla de registro.
  /// - Enlace a la pantalla de recuperación de contraseña.
  /// - Botón de acceso de desarrollo (puerta trasera).
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
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // -------------------------------------------------
                    // Encabezado
                    // -------------------------------------------------
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

                    // -------------------------------------------------
                    // Campo Email
                    // -------------------------------------------------
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: 'Correo electrónico',
                        prefixIcon: const Icon(
                          Icons.mail_outline,
                          color: Color(0xFF9AAAB6),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF0F3F4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            !kEmailRegex.hasMatch(value)) {
                          return kErrorInvalidEmail;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // -------------------------------------------------
                    // Campo Contraseña
                    // -------------------------------------------------
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      onFieldSubmitted: (value) => _login(),
                      decoration: InputDecoration(
                        hintText: 'Contraseña',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Color(0xFF9AAAB6),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF0F3F4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return kErrorEmptyPassword;
                        }
                        if (value.length < 6) {
                          return kErrorWeakPassword;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // -------------------------------------------------
                    // Opción: Mantener sesión
                    // -------------------------------------------------
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                          activeColor: const Color(0xFF1991E6),
                        ),
                        const Text(
                          'Mantener sesión iniciada',
                          style: TextStyle(
                            color: Color(0xFF111518),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // -------------------------------------------------
                    // Botón de Acceso
                    // -------------------------------------------------
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1991E6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              'Acceder',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // -------------------------------------------------
                    // Botón de Registro
                    // -------------------------------------------------
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => RegisterScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8F5FE),
                        foregroundColor: const Color(0xFF1991E6),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Registrarse',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // -------------------------------------------------
                    // Enlace: Recuperar Contraseña
                    // -------------------------------------------------
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ResetPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(color: Color(0xFF9AAAB6)),
                      ),
                    ),

                    // -------------------------------------------------
                    // BOTÓN DE ACCESO DE DESARROLLO (PUERTA TRASERA)
                    // -------------------------------------------------
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        // Acceso directo sin autenticación
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const MainScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Modo Desarrollo - Acceso Directo',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
