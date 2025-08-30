// lib/services/storage_service.dart

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // Guardamos las dos listas en la memoria del teléfono.
  static Future<void> saveLists(List<String> subjects, List<String> classes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('subjects_list', subjects);
    await prefs.setStringList('classes_list', classes);
  }

  // Cargamos las listas desde la memoria del teléfono.
  static Future<Map<String, List<String>>> loadLists() async {
    final prefs = await SharedPreferences.getInstance();
    final subjects = prefs.getStringList('subjects_list') ?? [];
    final classes = prefs.getStringList('classes_list') ?? [];
    return {'subjects': subjects, 'classes': classes};
  }
}