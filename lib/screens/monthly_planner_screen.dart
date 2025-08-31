// lib/screens/monthly_planner_screen.dart
// === INICIO MODIFICACIÓN: La lista de eventos ahora muestra 'subject' y 'className'. ===

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/planner_event.dart';
import '../services/event_service.dart';

class MonthlyPlannerScreen extends StatefulWidget {
  const MonthlyPlannerScreen({super.key});

  @override
  State<MonthlyPlannerScreen> createState() => _MonthlyPlannerScreenState();
}

class _MonthlyPlannerScreenState extends State<MonthlyPlannerScreen> with WidgetsBindingObserver {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<PlannerEvent>> _eventsByDay = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadEvents();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadEvents();
    }
  }

  void _loadEvents() async {
    final events = await EventService.fetchEvents();
    final Map<DateTime, List<PlannerEvent>> eventsMap = {};

    for (var event in events) {
      final dateKey = DateTime.utc(event.date.year, event.date.month, event.date.day);
      if (eventsMap[dateKey] == null) {
        eventsMap[dateKey] = [];
      }
      eventsMap[dateKey]!.add(event);
    }

    if (mounted) {
      setState(() {
        _eventsByDay = eventsMap;
      });
    }
  }

  List<PlannerEvent> _getEventsForDay(DateTime day) {
    final dateKey = DateTime.utc(day.year, day.month, day.day);
    return _eventsByDay[dateKey] ?? [];
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Planificación Mensual', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TableCalendar<PlannerEvent>(
              locale: 'es_ES',
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              eventLoader: _getEventsForDay,
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(color: Colors.blue.shade200, shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
                weekendTextStyle: TextStyle(color: Colors.red.shade400),
                markerDecoration: const BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: _buildEventList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventList() {
    if (_selectedDay == null) return Container();

    final selectedEvents = _getEventsForDay(_selectedDay!);

    if (selectedEvents.isEmpty) {
      return Center(
        child: Text('No hay eventos para este día.', style: TextStyle(color: Colors.grey.shade600)),
      );
    }

    return ListView.builder(
      itemCount: selectedEvents.length,
      itemBuilder: (context, index) {
        final event = selectedEvents[index];
        return ListTile(
          leading: Text(event.time, style: const TextStyle(fontWeight: FontWeight.bold)),
          title: Text(event.subject), // Usa 'subject' en lugar de 'title'
          subtitle: Text('${event.className} - ${event.subtitle}'), // Muestra la clase y el subtítulo
        );
      },
    );
  }
}
// === FIN MODIFICACIÓN ===