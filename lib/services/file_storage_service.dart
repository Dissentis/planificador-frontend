// lib/services/file_storage_service.dart
import 'dart:typed_data';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../screens/classes_subjects_screen.dart';

class FileStorageService {
  static const String _storageKey = 'aulaplan_files';

  static Future<List<FileSystemItem>> getDirectoryContents(
      List<String> pathSegments) async {
    if (kIsWeb) {
      // Versión para web usando SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final filesJson = prefs.getString(_storageKey) ?? '{}';
      final Map<String, dynamic> fileStructure = json.decode(filesJson);

      // Navegar a la carpeta actual
      Map<String, dynamic> currentDir = fileStructure;
      for (String segment in pathSegments) {
        currentDir = currentDir[segment] ?? {};
      }

      final items = <FileSystemItem>[];
      for (String name in currentDir.keys) {
        final item = currentDir[name];
        if (item is Map<String, dynamic>) {
          items.add(FileSystemItem(
            name: name,
            isFolder: item['isFolder'] ?? false,
            size: item['size'] ?? 0,
            lastModified: DateTime.parse(
                item['lastModified'] ?? DateTime.now().toIso8601String()),
          ));
        }
      }

      return items
        ..sort((a, b) {
          if (a.isFolder != b.isFolder) {
            return a.isFolder ? -1 : 1;
          }
          return a.name.compareTo(b.name);
        });
    } else {
      // Versión original para móvil/desktop
      // ... código original con path_provider
      return [];
    }
  }

  static Future<void> createFolder(List<String> pathSegments) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final filesJson = prefs.getString(_storageKey) ?? '{}';
      final Map<String, dynamic> fileStructure = json.decode(filesJson);

      // Navegar y crear la carpeta
      Map<String, dynamic> currentDir = fileStructure;
      for (int i = 0; i < pathSegments.length - 1; i++) {
        currentDir = currentDir[pathSegments[i]] ??= {};
      }

      final folderName = pathSegments.last;
      currentDir[folderName] = {
        'isFolder': true,
        'size': 0,
        'lastModified': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_storageKey, json.encode(fileStructure));
    }
  }

  static Future<void> uploadFile(
      List<String> pathSegments, String fileName, Uint8List bytes) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final filesJson = prefs.getString(_storageKey) ?? '{}';
      final Map<String, dynamic> fileStructure = json.decode(filesJson);

      // Navegar a la carpeta de destino
      Map<String, dynamic> currentDir = fileStructure;
      for (String segment in pathSegments) {
        currentDir = currentDir[segment] ??= {};
      }

      // Guardar archivo (solo metadatos en web por limitaciones)
      currentDir[fileName] = {
        'isFolder': false,
        'size': bytes.length,
        'lastModified': DateTime.now().toIso8601String(),
        'data': base64Encode(bytes), // Guardar datos en base64
      };

      await prefs.setString(_storageKey, json.encode(fileStructure));
    }
  }

  static Future<void> deleteItem(
      List<String> pathSegments, bool isFolder) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final filesJson = prefs.getString(_storageKey) ?? '{}';
      final Map<String, dynamic> fileStructure = json.decode(filesJson);

      // Navegar y eliminar
      Map<String, dynamic> currentDir = fileStructure;
      for (int i = 0; i < pathSegments.length - 1; i++) {
        currentDir = currentDir[pathSegments[i]] ?? {};
      }

      currentDir.remove(pathSegments.last);
      await prefs.setString(_storageKey, json.encode(fileStructure));
    }
  }

  // Método para leer archivos (corregido el nombre)
  static Future<Uint8List?> readFile(List<String> pathSegments) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final filesJson = prefs.getString(_storageKey) ?? '{}';
      final Map<String, dynamic> fileStructure = json.decode(filesJson);

      // Navegar al archivo
      Map<String, dynamic> currentDir = fileStructure;
      for (int i = 0; i < pathSegments.length - 1; i++) {
        currentDir = currentDir[pathSegments[i]] ?? {};
      }

      final fileName = pathSegments.last;
      final fileData = currentDir[fileName];

      if (fileData != null && fileData is Map<String, dynamic>) {
        final base64Data = fileData['data'] as String?;
        if (base64Data != null) {
          return base64Decode(base64Data);
        }
      }
      return null;
    } else {
      // Versión para móvil/desktop (si es necesario)
      return null;
    }
  }
}
