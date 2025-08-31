// lib/models/document_model.dart
// === INICIO MODIFICACIÓN: Se corrige la sintaxis del constructor. ===

class DocumentModel {
  final String id;
  final String title;
  final String description;
  final String date;
  final String imagePath;

  DocumentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.imagePath,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      date: json['date'] ?? '',
      imagePath: json['imagePath'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'imagePath': imagePath,
    };
  }
}
// === FIN MODIFICACIÓN ===