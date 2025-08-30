// lib/models/meeting_model.dart

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

  // Convierte un objeto Meeting a un Mapa (para luego convertir a JSON)
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'date': date,
      'attendees': attendees,
      'topics': topics,
      'agreements': agreements,
    };
  }

  // Crea un objeto Meeting desde un Mapa (leído de un JSON)
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