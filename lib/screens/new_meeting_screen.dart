// lib/screens/new_meeting_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meeting_model.dart';

// --- NOMBRE DE LA CLASE CORREGIDO ---
class NewMeetingScreen extends StatefulWidget {
  const NewMeetingScreen({super.key});

  @override
  State<NewMeetingScreen> createState() => _NewMeetingScreenState();
}

class _NewMeetingScreenState extends State<NewMeetingScreen> {
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _attendeesController = TextEditingController();
  final _topicsController = TextEditingController();
  final _agreementsController = TextEditingController();
  
  DateTime? _selectedDate;

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _attendeesController.dispose();
    _topicsController.dispose();
    _agreementsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd \'de\' MMMM \'de\' yyyy', 'es_ES').format(picked);
      });
    }
  }

  Future<void> _saveMeetingDraft() async {
    if (_titleController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El título es obligatorio.')),
        );
        return;
    }

    final newMeeting = Meeting(
      title: _titleController.text,
      date: _dateController.text,
      attendees: _attendeesController.text,
      topics: _topicsController.text,
      agreements: _agreementsController.text,
    );

    final prefs = await SharedPreferences.getInstance();
    final existingMeetings = prefs.getStringList('meeting_drafts') ?? [];
    existingMeetings.add(jsonEncode(newMeeting.toJson()));
    await prefs.setStringList('meeting_drafts', existingMeetings);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Borrador de acta guardado.')),
    );
    
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Nueva Acta', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1.0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildTextField(label: 'Título/Motivo', controller: _titleController),
            const SizedBox(height: 24),
            _buildDateField(label: 'Fecha', controller: _dateController),
            const SizedBox(height: 24),
            _buildTextField(label: 'Asistentes', controller: _attendeesController, maxLines: 4),
            const SizedBox(height: 24),
            _buildTextField(label: 'Asuntos Tratados', controller: _topicsController, maxLines: 7),
            const SizedBox(height: 24),
            _buildTextField(label: 'Acuerdos', controller: _agreementsController, maxLines: 7),
          ],
        ),
      ),
      bottomNavigationBar: _buildFooter(),
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDateField({required String label, required TextEditingController controller}) {
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: () => _selectDate(context),
          decoration: InputDecoration(
            hintText: 'Seleccionar fecha',
            suffixIcon: const Icon(Icons.calendar_today),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _saveMeetingDraft,
            child: const Text('Guardar Borrador', style: TextStyle(color: Colors.black87)),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.ios_share, size: 18),
            label: const Text('Exportar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D93F2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}