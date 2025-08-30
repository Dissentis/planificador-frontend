// lib/screens/meetings_list_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meeting_model.dart';
import 'new_meeting_screen.dart';

class MeetingsListScreen extends StatefulWidget {
  const MeetingsListScreen({super.key});

  @override
  State<MeetingsListScreen> createState() => _MeetingsListScreenState();
}

class _MeetingsListScreenState extends State<MeetingsListScreen> {
  List<Meeting> _meetings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  Future<void> _loadMeetings() async {
    final prefs = await SharedPreferences.getInstance();
    // Leemos la lista de borradores guardados.
    final meetingStrings = prefs.getStringList('meeting_drafts') ?? [];
    setState(() {
      _meetings = meetingStrings
          .map((jsonString) => Meeting.fromJson(jsonDecode(jsonString)))
          .toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Actas de Reunión', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _meetings.isEmpty
              ? const Center(
                  child: Text(
                    'No hay borradores guardados.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _meetings.length,
                  itemBuilder: (context, index) {
                    final meeting = _meetings[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                      child: ListTile(
                        title: Text(meeting.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(meeting.date),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Abrir una pantalla para ver/editar el acta.
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Navegamos a la pantalla de crear acta y esperamos a que vuelva.
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const NewMeetingScreen()),
          );
          // Si vuelve con 'true' (porque se guardó un acta), recargamos la lista.
          if (result == true) {
            _loadMeetings();
          }
        },
        backgroundColor: const Color(0xFF0D93F2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}