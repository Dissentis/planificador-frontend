// lib/screens/classes_subjects_screen.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/file_storage_service.dart';

class ClassesSubjectsScreen extends StatefulWidget {
  const ClassesSubjectsScreen({super.key});

  @override
  State<ClassesSubjectsScreen> createState() => _ClassesSubjectsScreenState();
}

class _ClassesSubjectsScreenState extends State<ClassesSubjectsScreen> {
  List<FileSystemItem> _items = [];
  List<String> _currentPath = []; // Para navegación de carpetas
  bool _isLoading = true;

  final TextEditingController _folderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentDirectory();
  }

  Future<void> _loadCurrentDirectory() async {
    setState(() => _isLoading = true);
    final items = await FileStorageService.getDirectoryContents(_currentPath);
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _createFolder() async {
    if (_folderController.text.isNotEmpty) {
      await FileStorageService.createFolder(
          [..._currentPath, _folderController.text]);
      _folderController.clear();
      FocusScope.of(context).unfocus();
      _loadCurrentDirectory();
    }
  }

  Future<void> _uploadFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'txt',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'jpg',
        'png'
      ],
    );

    if (result != null) {
      for (PlatformFile file in result.files) {
        if (file.bytes != null) {
          await FileStorageService.uploadFile(
              _currentPath, file.name, file.bytes!);
        }
      }
      _loadCurrentDirectory();
    }
  }

  void _navigateToFolder(String folderName) {
    setState(() {
      _currentPath.add(folderName);
    });
    _loadCurrentDirectory();
  }

  void _navigateBack() {
    if (_currentPath.isNotEmpty) {
      setState(() {
        _currentPath.removeLast();
      });
      _loadCurrentDirectory();
    }
  }

  Future<void> _deleteItem(FileSystemItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar ${item.isFolder ? 'carpeta' : 'archivo'}'),
        content: Text('¿Estás seguro de que quieres eliminar "${item.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm == true) {
      await FileStorageService.deleteItem(
          [..._currentPath, item.name], item.isFolder);
      _loadCurrentDirectory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Documentos',
            style: TextStyle(
                color: Color(0xFF111518), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1.0,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _uploadFiles,
            tooltip: 'Subir archivos',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildNavigationBar(),
                _buildCreateFolderSection(),
                Expanded(child: _buildFileList()),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadFiles,
        backgroundColor: const Color(0xFF0F9AF0),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          if (_currentPath.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _navigateBack,
            ),
          Expanded(
            child: Text(
              _currentPath.isEmpty ? 'Raíz' : _currentPath.join(' / '),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateFolderSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _folderController,
              decoration: InputDecoration(
                hintText: 'Nombre de la nueva carpeta',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.folder),
              ),
              onSubmitted: (_) => _createFolder(),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _createFolder,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F9AF0),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Crear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No hay archivos ni carpetas',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              item.isFolder ? Icons.folder : _getFileIcon(item.name),
              color: item.isFolder ? Colors.amber : Colors.blue,
              size: 32,
            ),
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: item.isFolder
                ? const Text('Carpeta')
                : Text(
                    '${_getFileExtension(item.name).toUpperCase()} • ${_formatFileSize(item.size)}'),
            onTap: item.isFolder
                ? () => _navigateToFolder(item.name)
                : () => _openFile(item),
            trailing: PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  child: const Row(
                    children: [
                      Icon(Icons.delete),
                      SizedBox(width: 8),
                      Text('Eliminar')
                    ],
                  ),
                ),
                if (!item.isFolder)
                  PopupMenuItem(
                    value: 'download',
                    child: const Row(
                      children: [
                        Icon(Icons.download),
                        SizedBox(width: 8),
                        Text('Descargar')
                      ],
                    ),
                  ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'delete':
                    _deleteItem(item);
                    break;
                  case 'download':
                    _downloadFile(item);
                    break;
                }
              },
            ),
          ),
        );
      },
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = _getFileExtension(fileName).toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getFileExtension(String fileName) {
    return fileName.split('.').last;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _openFile(FileSystemItem file) {
    // Implementar apertura de archivo según el tipo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Abriendo ${file.name}...')),
    );
  }

  void _downloadFile(FileSystemItem file) {
    // Implementar descarga de archivo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Descargando ${file.name}...')),
    );
  }
}

// Modelo de datos para archivos y carpetas
class FileSystemItem {
  final String name;
  final bool isFolder;
  final int size;
  final DateTime lastModified;

  FileSystemItem({
    required this.name,
    required this.isFolder,
    this.size = 0,
    required this.lastModified,
  });
}
