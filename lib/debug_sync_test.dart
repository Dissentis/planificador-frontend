import 'package:planificador_frontend/services/firestore_service.dart';
import 'package:planificador_frontend/models/sesion_model.dart';

Future<void> main() async {
  final firestoreService = FirestoreService();

  print('=== 🔎 TEST DE SINCRONIZACIÓN ===');

  // 1. Obtenemos todas las sesiones en tiempo real (primer snapshot)
  firestoreService.observarSesiones().first.then((sesiones) {
    print('📦 Total sesiones encontradas: ${sesiones.length}');
    for (final sesion in sesiones) {
      print('➡️ SesiónID: ${sesion.sesionId}');
      print('   Día: ${sesion.dia}, Hora: ${sesion.hora}');
      print('   Materia: ${sesion.materia?.nombre ?? "Sin materia"}');
      print('   Actividad: ${sesion.actividad ?? "N/A"}');
      print('   Notas: ${sesion.notas ?? "N/A"}');
      print('   Curso: ${sesion.cursoNombre ?? "N/A"}');
      print('   Es examen: ${sesion.esExamen}');
      print('   UserId: ${sesion.userId}');
      print('------------------------------');
    }
  }).catchError((e) {
    print('❌ ERROR al leer sesiones: $e');
  });
}
