// lib/screens/meetings_list_screen.dart
// === INICIO MODIFICACIÓN: Se añade diálogo de confirmación y navegación para editar. ===

import 'package:flutter/material.dart';
import '../models/meeting_model.dart';
import '../services/storage_service.dart';
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
    final loadedMeetings = await StorageService.loadMeetings();
    if (mounted) {
      setState(() {
        _meetings = loadedMeetings;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteMeeting(int index) async {
    _meetings.removeAt(index);
    await StorageService.saveMeetings(_meetings);
    setState(() {}); // Actualiza la UI para reflejar la lista sin el elemento borrado.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acta eliminada.')));
  }

  // --- NUEVA FUNCIÓN PARA EL DIÁLOGO DE CONFIRMACIÓN ---
  Future<bool?> _showConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text('¿Estás seguro de que deseas eliminar esta acta? Esta acción no se puede deshacer.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false), // Devuelve false
            ),
            TextButton(
              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true), // Devuelve true
            ),
          ],
        );
      },
    );
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
              ? const Center(child: Text('No hay borradores guardados.', style: TextStyle(fontSize: 16, color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _meetings.length,
                  itemBuilder: (context, index) {
                    final meeting = _meetings[index];
                    return Dismissible(
                      key: Key(meeting.title + meeting.date + index.toString()),
                      direction: DismissDirection.endToStart,
                      // --- confirmDismiss AHORA MUESTRA EL DIÁLOGO ---
                      confirmDismiss: (direction) async {
                        final bool? confirmed = await _showConfirmationDialog();
                        if (confirmed == true) {
                          _deleteMeeting(index);
                        }
                        return confirmed;
                      },
                      background: Container(
                        color: Colors.red.shade700,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                        child: ListTile(
                          title: Text(meeting.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(meeting.date),
                          trailing: const Icon(Icons.chevron_right),
                          // --- onTap AHORA NAVEGA A LA PANTALLA DE EDICIÓN ---
                          onTap: () async {
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NewMeetingScreen(
                                  meetingToEdit: meeting,
                                  meetingIndex: index,
                                ),
                              ),
                            );
                            if (result == true) {
                              _loadMeetings();
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const NewMeetingScreen()),
          );
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
// === FIN MODIFICACIÓN ===