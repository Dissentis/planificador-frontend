// lib/services/storage_service.dart
// === INICIO MODIFICACIÓN: Se actualiza el nombre del parámetro 'imageUrl' a 'imagePath'. ===

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meeting_model.dart';
import '../models/document_model.dart';

class StorageService {
  // --- Métodos para Clases y Materias (sin cambios) ---
  static Future<void> saveLists(List<String> subjects, List<String> classes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('subjects_list', subjects);
    await prefs.setStringList('classes_list', classes);
  }

  static Future<Map<String, List<String>>> loadLists() async {
    final prefs = await SharedPreferences.getInstance();
    final subjects = prefs.getStringList('subjects_list') ?? [];
    final classes = prefs.getStringList('classes_list') ?? [];
    return {'subjects': subjects, 'classes': classes};
  }

  // --- Métodos para Reuniones (sin cambios) ---
  static Future<List<Meeting>> loadMeetings() async {
    final prefs = await SharedPreferences.getInstance();
    final meetingStrings = prefs.getStringList('meeting_drafts') ?? [];
    return meetingStrings
        .map((jsonString) => Meeting.fromJson(jsonDecode(jsonString)))
        .toList();
  }

  static Future<void> saveMeetings(List<Meeting> meetings) async {
    final prefs = await SharedPreferences.getInstance();
    final meetingStrings = meetings
        .map((meeting) => jsonEncode(meeting.toJson()))
        .toList();
    await prefs.setStringList('meeting_drafts', meetingStrings);
  }

  // --- MÉTODOS PARA DOCUMENTOS ---
  static Future<List<DocumentModel>> loadDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final docStrings = prefs.getStringList('documents_list') ?? [];
    if (docStrings.isEmpty) {
      return [
        DocumentModel(id: '1', title: 'Apuntes de clase', description: 'Resumen sobre la Revolución Francesa.', date: '20 de mayo', imagePath: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wzNjc5ODF8MHwxfGFsbHx8fHx8fHx8fDE3MjUwNTg4ODV8&ixlib=rb-4.0.3&q=80&w=1080'),
        DocumentModel(id: '2', title: 'Plan de estudios', description: 'Plan de estudios para el curso de Historia.', date: '15 de mayo', imagePath: 'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wzNjc5ODF8MHwxfGFsbHx8fHx8fHx8fDE3MjUwNTg5MDV8&ixlib=rb-4.0.3&q=80&w=1080'),
      ];
    }
    return docStrings
        .map((jsonString) => DocumentModel.fromJson(jsonDecode(jsonString)))
        .toList();
  }

  static Future<void> saveDocuments(List<DocumentModel> documents) async {
    final prefs = await SharedPreferences.getInstance();
    final docStrings = documents
        .map((doc) => jsonEncode(doc.toJson()))
        .toList();
    await prefs.setStringList('documents_list', docStrings);
  }
}
// === FIN MODIFICACIÓN ===