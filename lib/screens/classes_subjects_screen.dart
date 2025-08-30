// lib/screens/classes_subjects_screen.dart

import 'package:flutter/material.dart';
import '../services/storage_service.dart'; // Importamos nuestro nuevo servicio

class ClassesSubjectsScreen extends StatefulWidget {
  const ClassesSubjectsScreen({super.key});

  @override
  State<ClassesSubjectsScreen> createState() => _ClassesSubjectsScreenState();
}

class _ClassesSubjectsScreenState extends State<ClassesSubjectsScreen> {
  // Las listas ahora empiezan vacías, se cargarán desde la memoria.
  List<String> _subjects = [];
  List<String> _classes = [];
  bool _isLoading = true; // Para mostrar un indicador de carga al inicio.

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _classController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData(); // Cargamos los datos cuando la pantalla se inicia.
  }

  Future<void> _loadData() async {
    final data = await StorageService.loadLists();
    setState(() {
      _subjects = data['subjects']!;
      _classes = data['classes']!;
      _isLoading = false;
    });
  }

  // Wrapper para guardar los datos después de cada modificación.
  Future<void> _saveData() async {
    await StorageService.saveLists(_subjects, _classes);
  }

  void _addSubject() {
    if (_subjectController.text.isNotEmpty) {
      setState(() {
        _subjects.add(_subjectController.text);
      });
      _subjectController.clear();
      FocusScope.of(context).unfocus();
      _saveData(); // Guardamos después de añadir.
    }
  }

  void _addClass() {
    if (_classController.text.isNotEmpty) {
      setState(() {
        _classes.add(_classController.text);
      });
      _classController.clear();
      FocusScope.of(context).unfocus();
      _saveData(); // Guardamos después de añadir.
    }
  }

  void _removeSubject(int index) {
    setState(() {
      _subjects.removeAt(index);
    });
    _saveData(); // Guardamos después de borrar.
  }

  void _removeClass(int index) {
    setState(() {
      _classes.removeAt(index);
    });
    _saveData(); // Guardamos después de borrar.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Clases y Materias', style: TextStyle(color: Color(0xFF111518), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1.0,
      ),
      // Si está cargando, muestra un círculo. Si no, muestra el contenido.
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // ... el resto del código del layout no cambia ...
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

  // Los widgets _buildSubjectsCard, _buildClassesCard y _buildCard no cambian.
  // Pégalos aquí tal y como estaban en la versión anterior.

  // Widget para la tarjeta de "Materias"
  Widget _buildSubjectsCard() {
    return _buildCard(
      title: 'Materias',
      items: _subjects,
      controller: _subjectController,
      onAdd: _addSubject,
      onRemove: _removeSubject,
      itemColor: const Color(0xFFE0F2FE),
      textColor: const Color(0xFF0C4A6E),
      buttonColor: const Color(0xFF0F9AF0)
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
      itemColor: const Color(0xFFE0E7FF),
      textColor: const Color(0xFF3730A3),
      buttonColor: const Color(0xFF89CFF0)
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
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), spreadRadius: 1, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListView.builder(
            itemCount: items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: itemColor, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(items[index], style: TextStyle(color: textColor, fontWeight: FontWeight.w500))),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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