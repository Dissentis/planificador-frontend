// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'weekly_planner_screen.dart';
import 'classes_subjects_screen.dart';
import 'meetings_list_screen.dart'; // <-- IMPORTACIÓN CORREGIDA
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const WeeklyPlannerScreen(),
    const ClassesSubjectsScreen(),
    const MeetingsListScreen(), // <-- PANTALLA CORREGIDA
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'Planificación'),
          BottomNavigationBarItem(icon: Icon(Icons.class_), label: 'Clases'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Reuniones'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0284C7),
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}