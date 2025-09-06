// ============================================================================
// IMPORTACIONES
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 👈 AÑADIDO
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'providers.dart';
import 'database/database_helper.dart';

// ============================================================================
// FUNCIÓN PRINCIPAL DE LA APLICACIÓN
// ============================================================================
/**
* Punto de entrada principal de la aplicación Flutter
* Inicializa servicios esenciales antes de ejecutar la app
*/
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // SharedPreferences después de la inicialización de FFI
  final prefs = await SharedPreferences.getInstance();

  // Riverpod + arranque de la app
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

// ============================================================================
// WIDGET PRINCIPAL DE LA APLICACIÓN
// ============================================================================
/**
* Widget raíz de la aplicación que configura el MaterialApp
* Gestiona la inicialización asíncrona de Firebase, localización y base de datos
*/
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AulaPlan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Spline Sans',
        primarySwatch: Colors.blue,
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF0D93F2),
          foregroundColor: Colors.white,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
      ],
      home: FutureBuilder<Map<String, dynamic>>(
        future: _initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorScreen(context, snapshot.error);
          }
          if (snapshot.connectionState == ConnectionState.done) {
            final data = snapshot.data ?? {};
            final bool isLoggedIn = data['isLoggedIn'] ?? false;

            return isLoggedIn ? const MainScreen() : const LoginScreen();
          }
          return _buildLoadingScreen();
        },
      ),
    );
  }

  /// Construye la pantalla de error con opción de reintentar
  Widget _buildErrorScreen(BuildContext context, Object? error) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text('Error inicializando la aplicación:'),
            const SizedBox(height: 8),
            Text('$error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MyApp()),
                );
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye la pantalla de carga inicial
  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Inicializando AulaPlan...'),
          ],
        ),
      ),
    );
  }

// ============================================================================
// MÉTODOS DE INICIALIZACIÓN
// ============================================================================
  Future<Map<String, dynamic>> _initializeApp() async {
    try {
      // 🔹 Inicializar Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print("✅ Firebase inicializado correctamente");

      // 🔹 Configurar persistencia de sesión (solo Web)
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        print("✅ Persistencia configurada en LOCAL (mantener sesión abierta)");
      }

      // 🔹 Inicializar localización
      await initializeDateFormatting('es_ES', null);
      print("✅ Localización 'es_ES' inicializada");

      // 🔹 Inicializar base de datos
      if (kIsWeb) {
        print('🌐 Modo Web: usando Firestore directamente');
      } else {
        try {
          await DatabaseHelper.instance.database;
          print('📱 Modo móvil/escritorio: usando SQLite');
        } catch (dbError) {
          print('⚠️ Error inicializando base de datos local: $dbError');
        }
      }

      // 🔹 Verificar estado de login
      final prefs = await SharedPreferences.getInstance();
      final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      return {'isLoggedIn': isLoggedIn};
    } catch (e, stack) {
      print('❌ Error en _initializeApp: $e');
      print(stack);
      rethrow; // 👉 lo lanzamos para que lo capture el FutureBuilder
    }
  }
}
