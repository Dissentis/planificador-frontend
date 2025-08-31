// lib/screens/profile_screen.dart
// === INICIO MODIFICACIÓN: Se añade un botón para navegar a la pantalla de documentos. ===

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'documents_screen.dart'; // <-- AÑADE ESTA IMPORTACIÓN

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel _user = UserModel();
  bool _isLoading = true;

  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _schoolController = TextEditingController();
  final _provinceController = TextEditingController();
  final _communityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _schoolController.dispose();
    _provinceController.dispose();
    _communityController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userJson = prefs.getString('user_profile');

    if (userJson != null) {
      _user = UserModel.fromJson(jsonDecode(userJson));
    }

    _nameController.text = _user.name;
    _lastNameController.text = _user.lastName;
    _schoolController.text = _user.school;
    _provinceController.text = _user.province;
    _communityController.text = _user.autonomousCommunity;

    setState(() { _isLoading = false; });
  }

  Future<void> _saveProfileData() async {
    _user.name = _nameController.text;
    _user.lastName = _lastNameController.text;
    _user.school = _schoolController.text;
    _user.province = _provinceController.text;
    _user.autonomousCommunity = _communityController.text;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', jsonEncode(_user.toJson()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil guardado con éxito.')),
    );
    FocusScope.of(context).unfocus();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Perfil', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _saveProfileData,
              icon: const Icon(Icons.save, size: 20),
              label: const Text('Guardar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D93F2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
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

  Widget _buildProfileCard() {
    String displayName = _nameController.text.isNotEmpty || _lastNameController.text.isNotEmpty
        ? '${_nameController.text} ${_lastNameController.text}'.trim()
        : 'Nombre Apellido';

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
                    onPressed: () {},
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          const Text('Profesora de Primaria', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFormTextField(label: 'Nombre', controller: _nameController),
          const SizedBox(height: 16),
          _buildFormTextField(label: 'Apellidos', controller: _lastNameController),
          const SizedBox(height: 16),
          _buildFormTextField(label: 'Centro Escolar', controller: _schoolController),
          const SizedBox(height: 16),
          _buildFormTextField(label: 'Provincia', controller: _provinceController, placeholder: 'Introduce tu provincia'),
          const SizedBox(height: 16),
          _buildFormTextField(label: 'Comunidad Autónoma', controller: _communityController, placeholder: 'Introduce tu comunidad'),
          const SizedBox(height: 24), // Espacio antes del nuevo botón
          ElevatedButton.icon(
            icon: const Icon(Icons.description),
            label: const Text('Ver Mis Documentos'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const DocumentsScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.grey.shade800,
              backgroundColor: Colors.grey.shade200,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
      ],
    );
  }
}
// === FIN MODIFICACIÓN ===