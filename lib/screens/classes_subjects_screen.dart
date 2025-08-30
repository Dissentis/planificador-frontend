// lib/screens/classes_subjects_screen.dart

import 'package:flutter/material.dart';

class ClassesSubjectsScreen extends StatefulWidget {
  const ClassesSubjectsScreen({super.key});

  @override
  State<ClassesSubjectsScreen> createState() => _ClassesSubjectsScreenState();
}

class _ClassesSubjectsScreenState extends State<ClassesSubjectsScreen> {
  // Listas para guardar las materias y clases. Serán el "estado" de nuestro widget.
  final List<String> _subjects = ['Lenguaje', 'Matemáticas', 'Historia'];
  final List<String> _classes = ['3º A de Primaria', '3º B de Primaria'];

  // Controladores para leer el texto de los campos de entrada.
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _classController = TextEditingController();

  void _addSubject() {
    if (_subjectController.text.isNotEmpty) {
      // setState() es crucial: notifica a Flutter que el estado ha cambiado
      // y que necesita redibujar la pantalla para reflejar la nueva lista.
      setState(() {
        _subjects.add(_subjectController.text);
      });
      _subjectController.clear(); // Limpia el campo de texto.
      FocusScope.of(context).unfocus(); // Oculta el teclado.
    }
  }

  void _addClass() {
    if (_classController.text.isNotEmpty) {
      setState(() {
        _classes.add(_classController.text);
      });
      _classController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _removeSubject(int index) {
    setState(() {
      _subjects.removeAt(index);
    });
  }

  void _removeClass(int index) {
    setState(() {
      _classes.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC), // background-color
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF111518)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Clases y Materias', style: TextStyle(color: Color(0xFF111518), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1.0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        // Usamos un LayoutBuilder para decidir si mostrar en 1 o 2 columnas.
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isWideScreen = constraints.maxWidth > 600;
            if (isWideScreen) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSubjectsCard()),
                  const SizedBox(width: 24),
                  Expanded(child: _buildClassesCard()),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildSubjectsCard(),
                  const SizedBox(height: 24),
                  _buildClassesCard(),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  // Widget para la tarjeta de "Materias"
  Widget _buildSubjectsCard() {
    return _buildCard(
      title: 'Materias',
      items: _subjects,
      controller: _subjectController,
      onAdd: _addSubject,
      onRemove: _removeSubject,
      itemColor: const Color(0xFFE0F2FE), // sky-50
      textColor: const Color(0xFF0C4A6E),  // sky-800
      buttonColor: const Color(0xFF0F9AF0) // primary-color
    );
  }

  // Widget para la tarjeta de "Clases"
  Widget _buildClassesCard() {
    return _buildCard(
      title: 'Clases',
      items: _classes,
      controller: _classController,
      onAdd: _addClass,
      onRemove: _removeClass,
      itemColor: const Color(0xFFE0E7FF), // blue-50
      textColor: const Color(0xFF3730A3),  // blue-800
      buttonColor: const Color(0xFF89CFF0) // secondary-color
    );
  }

  // Widget genérico reutilizable para construir una tarjeta
  Widget _buildCard({
    required String title,
    required List<String> items,
    required TextEditingController controller,
    required VoidCallback onAdd,
    required Function(int) onRemove,
    required Color itemColor,
    required Color textColor,
    required Color buttonColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Usamos ListView.builder para crear la lista de elementos de forma eficiente.
          ListView.builder(
            itemCount: items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: itemColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(items[index], style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.grey),
                        onPressed: () => onRemove(index),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Añadir nueva ${title.toLowerCase().substring(0, title.length -1)}', style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Ej. Ciencias Naturales',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20)
                ),
                child: const Text('Guardar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}