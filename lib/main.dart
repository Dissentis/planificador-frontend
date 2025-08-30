// lib/main.dart

import 'package:flutter/material.dart';
// Asegúrate de que la ruta de importación coincida con la estructura de tu proyecto.
import 'screens/login_screen.dart'; 

// La función main() es el punto de entrada de toda aplicación en Flutter.
void main() {
  // runApp() toma el widget principal de tu app y lo muestra en la pantalla.
  runApp(const MyApp());
}

// MyApp es el widget raíz de tu aplicación.
class MyApp extends StatelessWidget {
  // El constructor, key es un identificador para el widget.
  const MyApp({super.key});

  // El método build() describe cómo mostrar el widget.
  // Es llamado por el framework de Flutter cada vez que el widget necesita ser renderizado.
  @override
  Widget build(BuildContext context) {
    // MaterialApp es un widget que envuelve varias de las funcionalidades
    // que comúnmente se necesitan en una aplicación, como la navegación y los temas.
    return MaterialApp(
      // Este título es usado por el sistema operativo para identificar la app.
      title: 'AulaPlan',
      
      // Con esta línea quitamos el banner de "DEBUG" que aparece en la esquina superior derecha.
      debugShowCheckedModeBanner: false,
      
      // ThemeData te permite definir un tema visual para toda tu aplicación.
      // Aquí establecemos la fuente por defecto para que coincida con tus diseños.
      theme: ThemeData(
        fontFamily: 'Spline Sans',
        // Puedes definir más propiedades del tema aquí, como los colores primarios.
        primarySwatch: Colors.blue,
      ),
      
      // La propiedad 'home' define cuál será la primera pantalla que se muestre
      // cuando la aplicación se inicie.
      home: const LoginScreen(),
    );
  }
}