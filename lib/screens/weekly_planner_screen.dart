// lib/screens/weekly_planner_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/planner_event.dart';
import 'classes_subjects_screen.dart'; // <-- Asegúrate de que esta importación esté.

// El widget para las tarjetas de evento no cambia.
class EventCard extends StatelessWidget {
  final PlannerEvent event;
  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final colors = _getEventColors(event.title);
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: colors['background'],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.title, style: TextStyle(fontWeight: FontWeight.bold, color: colors['text'], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(event.subtitle, style: TextStyle(color: colors['text']!.withOpacity(0.8), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Map<String, Color> _getEventColors(String title) {
    switch (title.toLowerCase()) {
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


class WeeklyPlannerScreen extends StatefulWidget {
  const WeeklyPlannerScreen({super.key});

  @override
  State<WeeklyPlannerScreen> createState() => _WeeklyPlannerScreenState();
}

class _WeeklyPlannerScreenState extends State<WeeklyPlannerScreen> {
  late Future<List<PlannerEvent>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _fetchEvents();
  }

  Future<List<PlannerEvent>> _fetchEvents() async {
    const String apiUrl = 'https://TU_API_AQUI.com/events';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => PlannerEvent.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar los eventos del servidor.');
      }
    } catch (e) {
      throw Exception('Error de conexión. Revisa tu conexión a internet.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF5A6B7B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Planificación Semanal', style: TextStyle(color: Color(0xFF1D2939), fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1.0,
        
      ),
      body: FutureBuilder<List<PlannerEvent>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay eventos planificados.'));
          }

          final events = snapshot.data!;
          final timeSlots = ['08:00', '09:00', '10:00', '11:00', '12:00'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildDaysHeader(),
                const SizedBox(height: 8),
                ...timeSlots.map((time) => _buildTimeSlotRow(time, events)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDaysHeader() {
    final List<String> days = ['L', 'M', 'X', 'J', 'V'];
    return Row(children: [
      const SizedBox(width: 60),
      ...days.map((day) => Expanded(child: Text(day, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)))),
    ]);
  }

  Widget _buildTimeSlotRow(String time, List<PlannerEvent> allEvents) {
    final List<String> days = ['L', 'M', 'X', 'J', 'V'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 60, child: Text(time, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
        ...days.map((day) {
          final event = allEvents.firstWhere((e) => e.time == time && e.day == day,
              orElse: () => PlannerEvent(title: '', subtitle: '', time: '', day: ''));
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: event.title.isNotEmpty ? EventCard(event: event) : Container(),
            ),
          );
        }),
      ]),
    );
  }
}