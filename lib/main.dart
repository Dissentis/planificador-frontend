// lib/main.dart
// === INICIO MODIFICACIÓN: Se corrige el error de tipeo en la importación de 'material.dart'. ===

import 'package:flutter/material.dart'; // <-- LA CORRECCIÓN ESTÁ AQUÍ
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);
  runApp(const MyApp());
}

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
          backgroundColor: Color(0xFF0D93F2), // Color azul principal
          foregroundColor: Colors.white,      // Color del icono (blanco)
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español, España
      ],
      home: const LoginScreen(),
    );
  }
}
// === FIN MODIFICACIÓN ===