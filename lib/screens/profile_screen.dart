// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Controladores para los campos del formulario
  final _nameController = TextEditingController(text: 'Laura');
  final _lastNameController = TextEditingController(text: 'García');
  final _schoolController = TextEditingController(text: 'CEIP Cervantes');
  // ... puedes añadir más controladores para los otros campos

  @override
  void dispose() {
    // Es buena práctica liberar los recursos de los controladores.
    _nameController.dispose();
    _lastNameController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // slate-50
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Perfil', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))), // slate-800
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () { /* TODO: Lógica para guardar perfil */ },
              icon: const Icon(Icons.save, size: 20),
              label: const Text('Guardar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D93F2), // primary-color
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isWide = constraints.maxWidth > 700;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildProfileCard()),
                  const SizedBox(width: 24),
                  Expanded(flex: 3, child: _buildFormCard()),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 24),
                  _buildFormCard(),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  // Widget para la tarjeta de la foto de perfil
  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              const CircleAvatar(
                radius: 70,
                // Puedes usar NetworkImage para cargar una imagen desde una URL
                backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=lauragarcia'),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF0D93F2),
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                    onPressed: () { /* TODO: Lógica para cambiar foto */ },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Laura García', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          const Text('Profesora de Primaria', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }

  // Widget para la tarjeta del formulario de datos
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildFormTextField(label: 'Nombre', controller: _nameController),
          const SizedBox(height: 16),
          _buildFormTextField(label: 'Apellidos', controller: _lastNameController),
          const SizedBox(height: 16),
          _buildFormTextField(label: 'Centro Escolar', controller: _schoolController),
          const SizedBox(height: 16),
          _buildFormTextField(label: 'Provincia', placeholder: 'Introduce tu provincia'),
          const SizedBox(height: 16),
          _buildFormTextField(label: 'Comunidad Autónoma', placeholder: 'Introduce tu comunidad'),
        ],
      ),
    );
  }

  // Widget reutilizable para los campos de texto del formulario
  Widget _buildFormTextField({required String label, TextEditingController? controller, String? placeholder}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: placeholder,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }
}