// lib/screens/weekly_planner_screen.dart
// === INICIO MODIFICACIÓN: El EventCard ahora muestra 'subject' y 'className'. ===

import 'package:flutter/material.dart';
import '../models/planner_event.dart';
import '../services/event_service.dart';
import 'event_editor_screen.dart';

class EventCard extends StatelessWidget {
  final PlannerEvent event;
  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final colors = _getEventColors(event.subject); // Usa 'subject' para el color.
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: colors['background'],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.subject, style: TextStyle(fontWeight: FontWeight.bold, color: colors['text'], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(event.className, style: TextStyle(color: colors['text']!.withOpacity(0.9), fontSize: 11, fontStyle: FontStyle.italic)),
          const SizedBox(height: 4),
          Text(event.subtitle, style: TextStyle(color: colors['text']!.withOpacity(0.8), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Map<String, Color> _getEventColors(String subject) {
    switch (subject.toLowerCase()) {
      case 'matemáticas':
        return {'background': const Color(0xFFE0F2FE), 'text': const Color(0xFF0C4A6E)};
      case 'historia':
        return {'background': const Color(0xFFDBEAFE), 'text': const Color(0xFF1E40AF)};
      case 'ciencias':
        return {'background': const Color(0xFFCFFAFE), 'text': const Color(0xFF164E63)};
      default:
        return {'background': Colors.grey.shade200, 'text': Colors.black87};
    }
  }
}

// El resto de la clase WeeklyPlannerScreen no necesita cambios en su lógica,
// solo se beneficia de las actualizaciones del modelo y la tarjeta.
class WeeklyPlannerScreen extends StatefulWidget {
  const WeeklyPlannerScreen({super.key});

  @override
  State<WeeklyPlannerScreen> createState() => _WeeklyPlannerScreenState();
}

class _WeeklyPlannerScreenState extends State<WeeklyPlannerScreen> {
  List<PlannerEvent> _allEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshEvents();
  }

  Future<void> _refreshEvents() async {
    setState(() { _isLoading = true; });
    final events = await EventService.fetchEvents();
    if (mounted) {
      setState(() {
        _allEvents = events;
        _isLoading = false;
      });
    }
  }
  
  void _navigateToEditor({PlannerEvent? event}) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => EventEditorScreen(eventToEdit: event)),
    );
    if (result == true) {
      _refreshEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Planificación Semanal', style: TextStyle(color: Color(0xFF1D2939), fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1.0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildPlannerBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPlannerBody() {
    final timeSlots = ['08:00', '09:00', '10:00', '11:00', '12:00'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildDaysHeader(),
          const SizedBox(height: 8),
          ...timeSlots.map((time) => _buildTimeSlotRow(time, _allEvents)),
        ],
      ),
    );
  }

  Widget _buildDaysHeader() {
    return Row(children: [
      const SizedBox(width: 60),
      ...['L', 'M', 'X', 'J', 'V'].map((day) => Expanded(child: Text(day, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)))),
    ]);
  }

  Widget _buildTimeSlotRow(String time, List<PlannerEvent> allEvents) {
    final List<String> days = ['L', 'M', 'X', 'J', 'V'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 60, child: Text(time, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          ...days.map((day) {
            final event = allEvents.firstWhere((e) => e.time == time && e.day == day,
                orElse: () => PlannerEvent(id: '', subject: '', subtitle: '', className: '', time: '', day: '', date: DateTime.now()));
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: event.subject.isNotEmpty
                    ? GestureDetector(
                        onTap: () => _navigateToEditor(event: event),
                        child: EventCard(event: event),
                      )
                    : Container(height: 80), // Aumentamos la altura para mejor alineación
              ),
            );
          }),
        ],
      ),
    );
  }
}
// === FIN MODIFICACIÓN ===