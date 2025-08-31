// lib/screens/documents_screen.dart
// === INICIO MODIFICACIÓN: La tarjeta ahora puede mostrar imágenes locales desde una ruta de archivo. ===

import 'dart:io'; // <-- AÑADE ESTA IMPORTACIÓN
import 'package:flutter/material.dart';
import '../models/document_model.dart';
import '../services/storage_service.dart';
import 'document_editor_screen.dart';

// La clase DocumentsScreen y su estado no cambian.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<DocumentModel> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() { _isLoading = true; });
    final docs = await StorageService.loadDocuments();
    if (mounted) {
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteDocument(String id) async {
    _documents.removeWhere((doc) => doc.id == id);
    await StorageService.saveDocuments(_documents);
    _loadData();
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documento eliminado.')));
  }

  Future<void> _navigateAndRefresh(Widget screen) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _confirmDelete(String id) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text('¿Estás seguro de que deseas eliminar este documento?'),
          actions: <Widget>[
            TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop(false)),
            TextButton(child: const Text('Eliminar', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(context).pop(true)),
          ],
        );
      },
    );

    if (confirmed == true) {
      _deleteDocument(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Documentos'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 0.7,
              ),
              itemCount: _documents.length,
              itemBuilder: (context, index) {
                return _DocumentCard(
                  document: _documents[index],
                  onDelete: () => _confirmDelete(_documents[index].id),
                  onTap: () => _navigateAndRefresh(DocumentEditorScreen(documentToEdit: _documents[index])),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateAndRefresh(const DocumentEditorScreen()),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _DocumentCard({required this.document, required this.onDelete, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // --- LÓGICA DE IMAGEN ACTUALIZADA ---
    final imageProvider = document.imagePath.startsWith('http')
        ? NetworkImage(document.imagePath) as ImageProvider // Si es una URL, usa NetworkImage
        : FileImage(File(document.imagePath)); // Si es una ruta local, usa FileImage

    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Image( // Usamos el widget 'Image' genérico
                    image: imageProvider,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(document.date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                         const SizedBox(height: 4),
                         Text(document.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                         const SizedBox(height: 4),
                         Text(document.description, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 4,
              right: 4,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.black.withOpacity(0.5),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, color: Colors.white, size: 14),
                  onPressed: onDelete,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
// === FIN MODIFICACIÓN ===