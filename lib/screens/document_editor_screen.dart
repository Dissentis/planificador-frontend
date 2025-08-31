// lib/screens/document_editor_screen.dart
// === INICIO MODIFICACIÓN: Se reemplaza el campo de texto de URL por un selector de imagen de la galería. ===

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/document_model.dart';
import '../services/storage_service.dart';
import 'package:intl/intl.dart';

class DocumentEditorScreen extends StatefulWidget {
  final DocumentModel? documentToEdit;

  const DocumentEditorScreen({super.key, this.documentToEdit});

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  XFile? _imageFile; // Variable para guardar el archivo de imagen seleccionado.
  String? _initialImagePath;
  
  bool get _isEditing => widget.documentToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final doc = widget.documentToEdit!;
      _titleController.text = doc.title;
      _descriptionController.text = doc.description;
      _initialImagePath = doc.imagePath;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    // Abre la galería para seleccionar una imagen.
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = image;
      });
    }
  }

  Future<void> _saveDocument() async {
    // Validamos que se haya seleccionado una imagen si estamos creando un documento nuevo.
    if (_imageFile == null && !_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona una imagen.')));
      return;
    }

    if (_formKey.currentState!.validate()) {
      final documents = await StorageService.loadDocuments();
      
      final newOrUpdatedDocument = DocumentModel(
        id: _isEditing ? widget.documentToEdit!.id : DateTime.now().toIso8601String(),
        title: _titleController.text,
        description: _descriptionController.text,
        date: DateFormat('dd \'de\' MMMM', 'es_ES').format(DateTime.now()),
        imagePath: _imageFile?.path ?? _initialImagePath!,
      );

      if (_isEditing) {
        final index = documents.indexWhere((doc) => doc.id == newOrUpdatedDocument.id);
        if (index != -1) {
          documents[index] = newOrUpdatedDocument;
        }
      } else {
        documents.add(newOrUpdatedDocument);
      }
      
      await StorageService.saveDocuments(documents);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Documento' : 'Nuevo Documento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'El título es obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (value) => value!.isEmpty ? 'La descripción es obligatoria' : null,
              ),
              const SizedBox(height: 24),
              // --- SECCIÓN DEL SELECTOR DE IMAGEN ---
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: InkWell(
                  onTap: _pickImage,
                  child: _imageFile != null
                    ? Image.file(File(_imageFile!.path), fit: BoxFit.cover)
                    : _initialImagePath != null
                      ? (_initialImagePath!.startsWith('http')
                          ? Image.network(_initialImagePath!, fit: BoxFit.cover)
                          : Image.file(File(_initialImagePath!), fit: BoxFit.cover))
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Seleccionar imagen'),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveDocument,
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