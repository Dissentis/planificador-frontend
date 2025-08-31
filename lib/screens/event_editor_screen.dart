// lib/screens/event_editor_screen.dart
// === INICIO MODIFICACIÓN: El formulario ahora usa desplegables cargados desde el almacenamiento local. ===

import 'package:flutter/material.dart';
import '../models/planner_event.dart';
import '../services/event_service.dart';
import '../services/storage_service.dart'; // Importamos el StorageService para leer las listas.

class EventEditorScreen extends StatefulWidget {
  final PlannerEvent? eventToEdit;

  const EventEditorScreen({super.key, this.eventToEdit});

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Listas para las opciones de los desplegables.
  List<String> _availableSubjects = [];
  List<String> _availableClasses = [];
  bool _isLoadingLists = true;

  // Variables para los valores del formulario.
  late String _subject;
  late String _subtitle;
  late String _className;
  late String _selectedTime;
  late String _selectedDay;
  late DateTime _selectedDate;

  final List<String> _timeSlots = ['08:00', '09:00', '10:00', '11:00', '12:00'];
  final List<String> _daySlots = ['L', 'M', 'X', 'J', 'V'];
  bool get _isEditing => widget.eventToEdit != null;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final storedLists = await StorageService.loadLists();
    _availableSubjects = storedLists['subjects']!;
    _availableClasses = storedLists['classes']!;

    if (_isEditing) {
      final event = widget.eventToEdit!;
      _subject = event.subject;
      _subtitle = event.subtitle;
      _className = event.className;
      _selectedTime = event.time;
      _selectedDay = event.day;
      _selectedDate = event.date;
    } else {
      _subject = _availableSubjects.isNotEmpty ? _availableSubjects.first : '';
      _subtitle = '';
      _className = _availableClasses.isNotEmpty ? _availableClasses.first : '';
      _selectedTime = _timeSlots.first;
      _selectedDay = _daySlots.first;
      _selectedDate = DateTime.now();
    }
    
    setState(() { _isLoadingLists = false; });
  }

  Future<void> _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final newEvent = PlannerEvent(
        id: _isEditing ? widget.eventToEdit!.id : DateTime.now().toIso8601String(),
        subject: _subject,
        subtitle: _subtitle,
        className: _className,
        time: _selectedTime,
        day: _selectedDay,
        date: _selectedDate,
      );

      if (_isEditing) {
        await EventService.updateEvent(newEvent);
      } else {
        await EventService.addEvent(newEvent);
      }

      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Evento' : 'Nuevo Evento'),
      ),
      body: _isLoadingLists
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _availableSubjects.contains(_subject) ? _subject : null,
                      items: _availableSubjects.map((subject) => DropdownMenuItem(value: subject, child: Text(subject))).toList(),
                      onChanged: (value) => setState(() => _subject = value!),
                      decoration: const InputDecoration(labelText: 'Materia', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.isEmpty ? 'Debes seleccionar una materia' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _subtitle,
                      decoration: const InputDecoration(labelText: 'Subtítulo (Opcional)', border: OutlineInputBorder()),
                      onSaved: (value) => _subtitle = value ?? '',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _availableClasses.contains(_className) ? _className : null,
                      items: _availableClasses.map((className) => DropdownMenuItem(value: className, child: Text(className))).toList(),
                      onChanged: (value) => setState(() => _className = value!),
                      decoration: const InputDecoration(labelText: 'Clase', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.isEmpty ? 'Debes seleccionar una clase' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedTime,
                      items: _timeSlots.map((time) => DropdownMenuItem(value: time, child: Text(time))).toList(),
                      onChanged: (value) => setState(() => _selectedTime = value!),
                      decoration: const InputDecoration(labelText: 'Hora', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedDay,
                      items: _daySlots.map((day) => DropdownMenuItem(value: day, child: Text(day))).toList(),
                      onChanged: (value) => setState(() => _selectedDay = value!),
                      decoration: const InputDecoration(labelText: 'Día', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveEvent,
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
// === FIN MODIFICACIÓN ===