// lib/models/meeting_model.dart
// === INICIO MODIFICACIÓN: Se asegura que el archivo contenga únicamente la definición de la clase Meeting. ===

import 'dart:convert';

class Meeting {
  final String title;
  final String date;
  final String attendees;
  final String topics;
  final String agreements;

  Meeting({
    required this.title,
    required this.date,
    required this.attendees,
    required this.topics,
    required this.agreements,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'date': date,
      'attendees': attendees,
      'topics': topics,
      'agreements': agreements,
    };
  }

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      title: json['title'] ?? '',
      date: json['date'] ?? '',
      attendees: json['attendees'] ?? '',
      topics: json['topics'] ?? '',
      agreements: json['agreements'] ?? '',
    );
  }
}
// === FIN MODIFICACIÓN ===