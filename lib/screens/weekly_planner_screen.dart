// ============================================================================
// 1. IMPORTACIONES
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'event_editor_screen.dart';
import '../models/sesion_model.dart'; // <-- AÑADE ESTA LÍNEA
import '../models/planner_event.dart';
import '../services/event_service.dart';
import '../services/firestore_service.dart';
import '../repositories/sesion_repository_universal.dart' as SesionRepo;
import '../repositories/materia_repository_universal.dart' as MateriaRepo;

// ============================================================================
// 2. [ELIMINADO - LOS MODELOS ESTÁN DEFINIDOS EN: lib/models/sesion_model.dart]
// ============================================================================

// ============================================================================
// 3. CONTROLADOR DE ESTADO GLOBAL (RIVERPOD) - CON PERSISTENCIA Firestore
// ============================================================================

// Result class implementation
sealed class Result<T> {
  const Result();
  factory Result.ok(T value) = Ok._;
  factory Result.error(Exception error) = Error._;
}

final class Ok<T> extends Result<T> {
  const Ok._(this.value);
  final T value;

  @override
  String toString() => 'Result<$T>.ok($value)';
}

final class Error<T> extends Result<T> {
  const Error._(this.error);
  final Exception error;

  @override
  String toString() => 'Result<$T>.error($error)';
}

class HorarioController extends StateNotifier<List<SesionHorario>> {
  // Repositorios para persistencia
  final SesionRepo.SesionRepositoryFirestoreAdapter _sesionRepo =
      SesionRepo.SesionRepositoryFirestoreAdapter(FirestoreService());
  final MateriaRepo.MateriaRepository _materiaRepo =
      MateriaRepo.MateriaRepository();

  // Lista de materias
  List<Materia> _materiasDisponibles = [];

  // Cache de operaciones pendientes para estado optimista
  final Map<String, SesionHorario> _pendingOperations = {};

  HorarioController() : super([]) {
    _initializeData();
  }

  /// Getter para materias disponibles
  List<Materia> get materiasDisponibles =>
      List.unmodifiable(_materiasDisponibles);

  // ============================================================================
  // INICIALIZACIÓN DE DATOS
  // ============================================================================

  Future<void> _initializeData() async {
    try {
      final userId = FirestoreService().currentUserId ?? 'local';

      _materiasDisponibles = await _materiaRepo.getAllMaterias();

      final sesiones = await _sesionRepo.getAllSesiones();

      if (sesiones.isEmpty) {
        final horarioInicial = _generateInitialSchedule(userId: userId);
        await _sesionRepo.saveSesiones(horarioInicial);
        state = horarioInicial;
      } else {
        state = sesiones.map((s) => s.copyWith(userId: userId)).toList();
      }
    } catch (e) {
      print('Error inicializando datos: $e');
      _materiasDisponibles = _getMateriasDefault();
      state = _generateInitialSchedule(userId: 'local');
    }
  }

  static List<SesionHorario> _generateInitialSchedule(
      {required String userId}) {
    return SesionHorario.generateInitialSchedule(userId: userId);
  }

  List<Materia> _getMateriasDefault() {
    return Materia.getMateriasDefault();
  }

// ============================================================================
// MÉTODOS PRIVADOS - CORE LOGIC
// ============================================================================

  /// Busca una sesión existente o crea una nueva
  SesionHorario _getOrCreateSesion(DateTime fecha, String dia, String hora) {
    final userId = FirestoreService().currentUserId ?? 'local';
    final sesionId = _generateSesionId(fecha, hora, userId);

    // ✅ SOLO buscar, NO modificar el state durante operaciones de lectura
    return state.firstWhere(
      (s) => s.sesionId == sesionId,
      orElse: () => SesionHorario(
        id: sesionId.hashCode,
        dia: dia,
        hora: hora,
        sesionId: sesionId,
        docenteId: 0,
        userId: userId,
      ),
    );
  }

  /// Genera un ID consistente para sesiones basado en fecha completa
  String _generateSesionId(DateTime fecha, String hora, String userId) {
    final fechaKey = "${fecha.year.toString().padLeft(4, '0')}-"
        "${fecha.month.toString().padLeft(2, '0')}-"
        "${fecha.day.toString().padLeft(2, '0')}";
    return "${fechaKey}_${hora}_${userId}";
  }

  /// Aplica actualización optimista y persiste en background
  Future<Result<void>> _applyOptimisticUpdate(
    DateTime fecha,
    String dia,
    String hora,
    SesionHorario Function(SesionHorario) updateFunction,
  ) async {
    final userId = FirestoreService().currentUserId ?? 'local';
    final originalSesion = _getOrCreateSesion(fecha, dia, hora);

    // ✅ CORRECCIÓN: Primero aplicar la updateFunction, luego el userId si es necesario
    var updatedSesion = updateFunction(originalSesion);

    // Solo añadir userId si no tiene uno
    if (updatedSesion.userId.isEmpty) {
      updatedSesion = updatedSesion.copyWith(userId: userId);
    }

    final sesionKey = _generateSesionId(fecha, hora, userId);

    // Aplicar cambio optimista inmediatamente
    _pendingOperations[sesionKey] = updatedSesion;
    _applyStateUpdate(updatedSesion);

    // Intentar persistir en background
    try {
      final result = await _persistSesion(updatedSesion);

      if (result is Ok<void>) {
        // Éxito: limpiar operación pendiente
        _pendingOperations.remove(sesionKey);
        return Result.ok(null);
      } else if (result is Error<void>) {
        // Error: revertir cambio optimista
        _revertOptimisticUpdate(sesionKey, originalSesion);
        return result;
      }
    } catch (e) {
      // Error inesperado: revertir
      _revertOptimisticUpdate(sesionKey, originalSesion);
      return Result.error(Exception('Error inesperado: ${e.toString()}'));
    }

    return Result.error(Exception('Estado de resultado desconocido'));
  }

  /// Aplica actualización al state
  void _applyStateUpdate(SesionHorario updatedSesion) {
    final index = state.indexWhere((s) => s.sesionId == updatedSesion.sesionId);

    if (index != -1) {
      // Reemplazar sesión existente
      final newState = List<SesionHorario>.from(state);
      newState[index] = updatedSesion;
      state = newState;
    } else {
      // Añadir nueva sesión
      state = [...state, updatedSesion];
    }
  }

  /// Revierte una actualización optimista fallida
  void _revertOptimisticUpdate(String sesionKey, SesionHorario originalSesion) {
    _pendingOperations.remove(sesionKey);
    _applyStateUpdate(originalSesion);
  }

  /// Persiste una sesión en el repositorio
  Future<Result<void>> _persistSesion(SesionHorario sesion) async {
    try {
      await _sesionRepo.saveSesion(sesion);
      return Result.ok(null);
    } on Exception catch (e) {
      return Result.error(e);
    } catch (e) {
      return Result.error(Exception('Error de persistencia: ${e.toString()}'));
    }
  }

  /// Valida los datos de una sesión
  bool _validateSesionData(SesionHorario sesion) {
    if (sesion.dia.isEmpty || sesion.hora.isEmpty) {
      return false;
    }

    final validDias = ['L', 'M', 'X', 'J', 'V'];
    if (!validDias.contains(sesion.dia)) {
      return false;
    }

    return true;
  }

// ============================================================================
// MÉTODOS PÚBLICOS - API
// ============================================================================

  Future<Result<void>> asignarMateria(
      DateTime fecha, String dia, String hora, Materia materia) async {
    if (!_validateSesionData(SesionHorario(
      id: 0,
      dia: dia,
      hora: hora,
      sesionId: '',
      docenteId: 0,
      userId: '',
    ))) {
      return Result.error(Exception('Datos de sesión inválidos'));
    }

    return await _applyOptimisticUpdate(
      fecha,
      dia,
      hora,
      (sesion) => sesion.copyWith(materia: materia),
    );
  }

  Future<Result<void>> editarActividad(
      DateTime fecha, String dia, String hora, String actividad) async {
    return await _applyOptimisticUpdate(
      fecha,
      dia,
      hora,
      (sesion) => sesion.copyWith(
        actividad: actividad.isEmpty ? null : actividad,
        clearActividad: actividad.isEmpty,
      ),
    );
  }

  Future<Result<void>> editarNotas(
      DateTime fecha, String dia, String hora, String notas) async {
    return await _applyOptimisticUpdate(
      fecha,
      dia,
      hora,
      (sesion) => sesion.copyWith(
        notas: notas.isEmpty ? null : notas,
        clearNotas: notas.isEmpty,
      ),
    );
  }

  Future<Result<void>> limpiarCelda(
      DateTime fecha, String dia, String hora) async {
    final result = await _applyOptimisticUpdate(
      fecha,
      dia,
      hora,
      (sesion) => sesion.copyWith(
        clearMateria: true,
        clearNotas: true,
        clearActividad: true,
        esExamen: false,
        cursoNombre: null,
      ),
    );

    // Limpiar también en Firestore
    if (result is Ok<void>) {
      try {
        final sesionId = _generateSesionId(
            fecha, hora, FirestoreService().currentUserId ?? 'local');
        await _sesionRepo.limpiarSesion(sesionId);
      } catch (e) {
        print('Error limpiando sesión en Firestore: $e');
        // No fallar la operación por esto, ya que localmente está limpia
      }
    }

    return result;
  }

  Future<Result<void>> agregarMateria(String nombre, Color color) async {
    try {
      final nuevaMateria = Materia(
        id: DateTime.now().millisecondsSinceEpoch,
        nombre: nombre,
        color: color,
      );

      _materiasDisponibles.add(nuevaMateria);
      state = List.from(state); // Trigger rebuild

      await _materiaRepo.saveMateria(nuevaMateria);
      return Result.ok(null);
    } on Exception catch (e) {
      // Revertir cambio local si falla el guardado
      _materiasDisponibles.removeWhere((m) => m.nombre == nombre);
      state = List.from(state);
      return Result.error(e);
    } catch (e) {
      _materiasDisponibles.removeWhere((m) => m.nombre == nombre);
      state = List.from(state);
      return Result.error(
          Exception('Error agregando materia: ${e.toString()}'));
    }
  }

  Future<Result<void>> marcarExamen(
      DateTime fecha, String dia, String hora, bool esExamen) async {
    return await _applyOptimisticUpdate(
      fecha,
      dia,
      hora,
      (sesion) => sesion.copyWith(esExamen: esExamen),
    );
  }

  Future<Result<void>> asignarCurso(
      DateTime fecha, String dia, String hora, String curso) async {
    return await _applyOptimisticUpdate(
      fecha,
      dia,
      hora,
      (sesion) => sesion.copyWith(cursoNombre: curso),
    );
  }

// ============================================================================
// MÉTODOS DE UTILIDAD Y EXPORTACIÓN
// ============================================================================

  String exportarCSV() {
    final buffer = StringBuffer();
    buffer.writeln('Dia,Hora,Materia,Actividad,Notas');
    for (final sesion in state) {
      if (sesion.materia != null || sesion.actividad != null) {
        buffer.writeln(
          [
            sesion.dia,
            sesion.hora,
            '"${sesion.materia?.nombre ?? ''}"',
            '"${sesion.actividad ?? ''}"',
            '"${sesion.notas ?? ''}"',
          ].join(','),
        );
      }
    }
    return buffer.toString();
  }

  Future<void> refrescarDatos() async {
    await _initializeData();
  }

  Future<Result<Map<String, int>>> getEstadisticas() async {
    try {
      final stats = await _sesionRepo.getEstadisticas();
      return Result.ok(stats);
    } on Exception catch (e) {
      return Result.error(e);
    } catch (e) {
      return Result.error(
          Exception('Error obteniendo estadísticas: ${e.toString()}'));
    }
  }

  Future<Result<String>> exportarCSVAsync() async {
    try {
      final csv = await _sesionRepo.exportarCSV();
      return Result.ok(csv);
    } on Exception catch (e) {
      return Result.error(e);
    } catch (e) {
      return Result.error(Exception('Error exportando CSV: ${e.toString()}'));
    }
  }

  /// Obtiene una sesión por día y hora para uso externo
  SesionHorario? getSesionByDiaHora(DateTime fecha, String dia, String hora) {
    return state.firstWhere(
      (s) => s.dia == dia && s.hora == hora,
      orElse: () => _getOrCreateSesion(fecha, dia, hora), // ✅ CORREGIDO
    );
  }

  /// Verifica si hay operaciones pendientes
  bool get hasPendingOperations => _pendingOperations.isNotEmpty;

  /// Obtiene las claves de operaciones pendientes
  List<String> get pendingOperationKeys => _pendingOperations.keys.toList();
}

final horarioProvider =
    StateNotifierProvider<HorarioController, List<SesionHorario>>(
  (ref) => HorarioController(),
);

// ============================================================================
// 4. WIDGET DE TARJETA DE EVENTO (EventCard)
// ============================================================================
class EventCard extends StatelessWidget {
  final SesionHorario sesion;
  final VoidCallback onTap;

  const EventCard({super.key, required this.sesion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = sesion.materia?.color ?? Colors.grey.shade200;
    final textColor = _getTextColorForBackground(backgroundColor);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Stack(
          children: [
            // Posiciona la etiqueta del curso real en la esquina superior derecha.
            Positioned(
              top: 0,
              right: 0,
              child: Text(
                sesion.cursoNombre ??
                    sesion.curso ??
                    'Sin curso', // ← CORREGIDO
                style: TextStyle(
                  color: textColor.withOpacity(0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Posiciona el icono de examen en la esquina superior izquierda.
            if (sesion.esExamen)
              Positioned(
                top: 0,
                left: 0,
                child: Icon(Icons.alarm, size: 16, color: textColor),
              ),

            // Muestra y centra el nombre de la materia.
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sesion.materia != null)
                      Text(
                        sesion.materia!.nombre,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),

            // Posiciona los iconos indicadores en la esquina inferior izquierda.
            Positioned(
              bottom: 0,
              left: 0,
              child: Row(
                children: [
                  if (sesion.notas != null && sesion.notas!.isNotEmpty)
                    const Icon(Icons.notes, size: 12, color: Colors.black54),
                  if (sesion.actividad != null && sesion.actividad!.isNotEmpty)
                    const Icon(
                      Icons.attachment,
                      size: 12,
                      color: Colors.black54,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTextColorForBackground(Color backgroundColor) {
    final brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
    return brightness == Brightness.dark ? Colors.white : Colors.black87;
  }
}

// ============================================================================
// 5. DIÁLOGO DE EDICIÓN COMPLETO - OPTIMIZADO CON RECURSOS FLUTTER
// ============================================================================

class EditarSesionDialog extends ConsumerStatefulWidget {
  final SesionHorario sesion;

  const EditarSesionDialog({super.key, required this.sesion});

  @override
  ConsumerState<EditarSesionDialog> createState() => _EditarSesionDialogState();
}

// ============================================================================
// 5.1. ESTADO Y INICIALIZACIÓN
// ============================================================================
class _EditarSesionDialogState extends ConsumerState<EditarSesionDialog>
    with SingleTickerProviderStateMixin {
  // Controllers
  late final TextEditingController _actividadController;
  late final TextEditingController _notasController;
  late final TextEditingController _nuevaMateriaController;
  late final TextEditingController _nuevoCursoController;

  // Form validation
  final _formKey = GlobalKey<FormState>();

  // Estado local
  Materia? _materiaSeleccionada;
  bool _isEditing = false;
  bool _isExamen = false;
  String? _cursoSeleccionado;
  bool _isSaving = false;
  Color? _colorSeleccionado;

  // Fecha asociada a la sesión (extraída del sesionId o actual como fallback)
  late final DateTime _fechaSesion;

  // Shimmer animation para loading
  late AnimationController _shimmerController;

  final List<String> _cursosDisponibles = [
    '1º ESO',
    '2º ESO',
    '3º ESO',
    '4º ESO',
    '1º Bachillerato',
    '2º Bachillerato',
  ];

  final List<Color> _coloresDisponibles = [
    Colors.blue[100]!,
    Colors.green[100]!,
    Colors.orange[100]!,
    Colors.purple[100]!,
    Colors.cyan[100]!,
    Colors.red[100]!,
    Colors.pink[100]!,
    Colors.amber[100]!,
    Colors.indigo[100]!,
    Colors.teal[100]!,
    Colors.lime[100]!,
    Colors.deepOrange[100]!,
  ];

  @override
  void initState() {
    super.initState();

    // Inicializar controllers con validación en tiempo real
    _actividadController = TextEditingController(
      text: widget.sesion.actividad ?? '',
    );
    _notasController = TextEditingController(text: widget.sesion.notas ?? '');
    _nuevaMateriaController = TextEditingController();
    _nuevoCursoController = TextEditingController();

    // Configurar estado inicial - CORREGIDO: usar cursoNombre
    _materiaSeleccionada = widget.sesion.materia;
    _isExamen = widget.sesion.esExamen;
    _cursoSeleccionado = widget.sesion.cursoNombre ??
        widget.sesion.curso ??
        '1º ESO'; // ← CORRECCIÓN
    _colorSeleccionado = _coloresDisponibles.first;

    // Extraer fecha desde el sesionId (formato esperado: yyyy-MM-dd_HH:mm_userId)
    try {
      final parts = widget.sesion.sesionId.split('_');
      _fechaSesion = DateTime.parse(parts[0]);
    } catch (_) {
      // Fallback si el sesionId no tiene fecha válida
      _fechaSesion = DateTime.now();
    }

    // Abrir en modo edición si la celda está vacía
    if (widget.sesion.materia == null &&
        widget.sesion.actividad == null &&
        widget.sesion.notas == null &&
        !widget.sesion.esExamen) {
      _isEditing = true;
    }

    // Shimmer para loading states
    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(min: -0.5, max: 1.5, period: const Duration(milliseconds: 1000));

    // Listeners para validación en tiempo real
    _actividadController.addListener(_onFieldChanged);
    _notasController.addListener(_onFieldChanged);
  }

// ============================================================================
// 5.2. MÉTODOS DE CICLO DE VIDA
// ============================================================================
  @override
  void dispose() {
    _actividadController.removeListener(_onFieldChanged);
    _notasController.removeListener(_onFieldChanged);
    _actividadController.dispose();
    _notasController.dispose();
    _nuevaMateriaController.dispose();
    _nuevoCursoController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_formKey.currentState != null) {
      _formKey.currentState!.validate();
    }
  }

// ============================================================================
// 5.3. MÉTODOS DE VALIDACIÓN
// ============================================================================
  bool _validateEssentialFields() {
    bool isValid = true;

    // Validar curso siempre
    if (_cursoSeleccionado == null || _cursoSeleccionado!.isEmpty) {
      isValid = false;
    }

    // Si está creando nueva materia, validar ese campo
    if (_materiaSeleccionada == null &&
        _nuevaMateriaController.text.trim().isEmpty) {
      isValid = false;
    }

    return isValid;
  }

// ============================================================================
// 5.4. MÉTODOS DE GUARDADO Y OPERACIONES
// ============================================================================
  Future<void> _guardarCambios() async {
    if (!_validateEssentialFields()) {
      _showErrorSnackbar('Selecciona un curso y una materia o crea una nueva');
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final controlador = ref.read(horarioProvider.notifier);
    final dia = widget.sesion.dia;
    final hora = widget.sesion.hora;

    try {
      final operaciones = <Future<Result<void>>>[];

      // Crear nueva materia si es necesario
      if (_materiaSeleccionada == null &&
          _nuevaMateriaController.text.trim().isNotEmpty) {
        await _crearNuevaMateria();
        final materiasActualizadas =
            ref.read(horarioProvider.notifier).materiasDisponibles;
        _materiaSeleccionada = materiasActualizadas.firstWhere(
          (m) =>
              m.nombre.toLowerCase() ==
              _nuevaMateriaController.text.trim().toLowerCase(),
          orElse: () => materiasActualizadas.last,
        );
      }

      // Guardar materia si fue seleccionada
      if (_materiaSeleccionada != null) {
        operaciones.add(controlador.asignarMateria(
            _fechaSesion, dia, hora, _materiaSeleccionada!));
      }

      // Guardar resto de campos
      operaciones.addAll([
        controlador.editarActividad(
            _fechaSesion, dia, hora, _actividadController.text.trim()),
        controlador.editarNotas(
            _fechaSesion, dia, hora, _notasController.text.trim()),
        controlador.marcarExamen(_fechaSesion, dia, hora, _isExamen),
        controlador.asignarCurso(_fechaSesion, dia, hora, _cursoSeleccionado!),
      ]);

      final resultados = await Future.wait(operaciones);
      final errores =
          resultados.where((r) => r is Error).cast<Error>().toList();

      if (errores.isNotEmpty) {
        _showErrorSnackbar('Error guardando: ${errores.first.error}');
        return;
      }

      _showSuccessSnackbar('Cambios guardados correctamente');
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showErrorSnackbar('Error inesperado: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _limpiarCelda() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await ref.read(horarioProvider.notifier).limpiarCelda(
            _fechaSesion,
            widget.sesion.dia,
            widget.sesion.hora,
          );

      switch (result) {
        case Ok<void>():
          _showSuccessSnackbar('Celda limpiada');
          if (mounted) Navigator.pop(context, true);
        case Error<void>():
          _showErrorSnackbar('Error limpiando: ${result.error}');
      }
    } catch (e) {
      _showErrorSnackbar('Error inesperado: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

// ============================================================================
// 5.5. MÉTODOS DE CREACIÓN Y GESTIÓN
// ============================================================================
  Future<void> _crearNuevaMateria() async {
    final nombre = _nuevaMateriaController.text.trim();
    if (nombre.isEmpty) {
      _showErrorSnackbar('El nombre de la materia no puede estar vacío');
      return;
    }

    final materiasExistentes =
        ref.read(horarioProvider.notifier).materiasDisponibles;
    if (materiasExistentes
        .any((m) => m.nombre.toLowerCase() == nombre.toLowerCase())) {
      _showErrorSnackbar('Ya existe una materia con ese nombre');
      return;
    }

    final colorSeleccionado = _colorSeleccionado ?? _coloresDisponibles.first;

    try {
      final result = await ref.read(horarioProvider.notifier).agregarMateria(
            nombre,
            colorSeleccionado,
          );

      switch (result) {
        case Ok<void>():
          _nuevaMateriaController.clear();
          _colorSeleccionado = _coloresDisponibles.first;
          _showSuccessSnackbar('Materia "$nombre" creada');
          setState(() {});
        case Error<void>():
          _showErrorSnackbar('Error creando materia: ${result.error}');
      }
    } catch (e) {
      _showErrorSnackbar('Error inesperado: ${e.toString()}');
    }
  }

  void _crearNuevoCurso() {
    final nombre = _nuevoCursoController.text.trim();
    if (nombre.isEmpty) return;

    // CORRECCIÓN: Verificar duplicados de manera más robusta
    if (_cursosDisponibles.contains(nombre)) {
      _showErrorSnackbar('Ya existe un curso con ese nombre');
      return;
    }

    setState(() {
      // DOBLE VERIFICACIÓN: Asegurar que no se añadan duplicados
      if (!_cursosDisponibles.contains(nombre)) {
        _cursosDisponibles.add(nombre);
      }
      _cursoSeleccionado = nombre;
      _nuevoCursoController.clear();
    });
    _showSuccessSnackbar('Curso "$nombre" creado');
  }

  /// NUEVO: Método para limpiar lista de cursos de duplicados
  void _limpiarCursosDuplicados() {
    setState(() {
      final cursosUnicos = _cursosDisponibles.toSet().toList();
      _cursosDisponibles.clear();
      _cursosDisponibles.addAll(cursosUnicos);
    });
  }

  /// NUEVO: Validar integridad de la lista de cursos
  bool _validarCursosDisponibles() {
    final cursosUnicos = _cursosDisponibles.toSet();
    if (cursosUnicos.length != _cursosDisponibles.length) {
      _limpiarCursosDuplicados();
      return false;
    }
    return true;
  }

// ============================================================================
// 5.6. MÉTODOS DE UI Y SNACKBARS
// ============================================================================
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).removeCurrentSnackBar(),
          ),
        ),
      );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

// ============================================================================
// 5.7. WIDGETS DE INTERFAZ DE USUARIO
// ============================================================================
  Widget _buildShimmerLoading(
      {required Widget child, required bool isLoading}) {
    if (!isLoading) return child;

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFFEBEBF4),
                Color(0xFFF4F4F4),
                Color(0xFFEBEBF4),
              ],
              stops: const [0.1, 0.3, 0.4],
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              transform: GradientRotation(_shimmerController.value * 2),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: child,
    );
  }

  Widget _buildMateriaSelector() {
    final materiasDisponibles =
        ref.watch(horarioProvider.notifier).materiasDisponibles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Materia:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: materiasDisponibles.map((materia) {
            final estaSeleccionada = _materiaSeleccionada?.id == materia.id;

            return InkWell(
              onTap: () => setState(() {
                _materiaSeleccionada = estaSeleccionada ? null : materia;
              }),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: materia.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: estaSeleccionada
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300]!,
                    width: estaSeleccionada ? 2 : 1,
                  ),
                ),
                child: Text(
                  materia.nombre,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        estaSeleccionada ? FontWeight.bold : FontWeight.normal,
                    color: Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildColorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color:',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _coloresDisponibles.map((color) {
            final estaSeleccionado = _colorSeleccionado == color;

            return InkWell(
              onTap: () => setState(() {
                _colorSeleccionado = color;
              }),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: estaSeleccionado
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300]!,
                    width: estaSeleccionado ? 3 : 1,
                  ),
                ),
                child: estaSeleccionado
                    ? const Icon(
                        Icons.check,
                        color: Colors.black54,
                        size: 16,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNewMateriaForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Crear nueva materia:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _nuevaMateriaController,
                decoration: const InputDecoration(
                  hintText: 'Nombre de la materia',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                validator: (value) {
                  if (_materiaSeleccionada == null &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Ingresa un nombre o selecciona una materia existente';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _crearNuevaMateria(),
              ),
            ),
            const SizedBox(width: 8),
            _buildShimmerLoading(
              isLoading: _isSaving,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _crearNuevaMateria,
                child: const Text('Crear'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildColorSelector(),
      ],
    );
  }

  Widget _buildCourseSelector() {
    final cursosLimpios = _cursosDisponibles.toSet().toList();

    final cursoValido = cursosLimpios.contains(_cursoSeleccionado)
        ? _cursoSeleccionado
        : cursosLimpios.isNotEmpty
            ? cursosLimpios.first
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Curso:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: cursoValido,
          items: cursosLimpios
              .map(
                  (curso) => DropdownMenuItem(value: curso, child: Text(curso)))
              .toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() => _cursoSeleccionado = newValue);
            }
          },
          validator: (value) => value == null ? 'Selecciona un curso' : null,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _nuevoCursoController,
                decoration: const InputDecoration(
                  hintText: 'Crear nuevo curso',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onFieldSubmitted: (_) => _crearNuevoCurso(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _crearNuevoCurso,
              child: const Text('Crear'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReadOnlyView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.sesion.materia?.nombre ?? 'Sin materia',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: widget.sesion.materia?.color ?? Colors.grey[700],
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(
                offset: Offset(1.0, 1.0),
                blurRadius: 1.0,
                color: Colors.black,
              ),
              Shadow(
                offset: Offset(-1.0, -1.0),
                blurRadius: 1.0,
                color: Colors.black,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoRow(
          icon: Icons.school,
          title: 'Curso:',
          content:
              widget.sesion.cursoNombre ?? widget.sesion.curso ?? 'Sin curso',
        ),
        _buildInfoRow(
          icon: widget.sesion.esExamen ? Icons.alarm_on : Icons.alarm_off,
          title: 'Estado:',
          content: widget.sesion.esExamen ? 'Examen' : 'Normal',
        ),
        if (widget.sesion.actividad?.isNotEmpty == true)
          _buildInfoRow(
            icon: Icons.assignment,
            title: 'Actividad:',
            content: widget.sesion.actividad!,
          ),
        if (widget.sesion.notas?.isNotEmpty == true)
          _buildInfoRow(
            icon: Icons.notes,
            title: 'Notas:',
            content: widget.sesion.notas!,
          ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCourseSelector(),
          const SizedBox(height: 16),
          _buildMateriaSelector(),
          const SizedBox(height: 16),
          _buildNewMateriaForm(),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Marcar como examen'),
            value: _isExamen,
            onChanged: (value) => setState(() => _isExamen = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Actividad:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _actividadController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Describe la actividad',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notas:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notasController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Notas o recordatorios',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

// ============================================================================
// 5.8. BUILD PRINCIPAL
// ============================================================================
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sesión de ${widget.sesion.dia} ${widget.sesion.hora}'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: _isEditing ? _buildEditView() : _buildReadOnlyView(context),
        ),
      ),
      actions: [
        if (_isEditing) ...[
          TextButton(
            onPressed: _isSaving ? null : _limpiarCelda,
            child: _buildShimmerLoading(
              isLoading: _isSaving,
              child: const Text('Limpiar'),
            ),
          ),
          TextButton(
            onPressed: _isSaving
                ? null
                : () => setState(() {
                      _isEditing = false;
                    }),
            child: const Text('Cancelar'),
          ),
        ] else ...[
          TextButton(
            onPressed: () => setState(() => _isEditing = true),
            child: const Text('Editar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cerrar'),
          ),
        ],
        if (_isEditing)
          _buildShimmerLoading(
            isLoading: _isSaving,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _guardarCambios,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// 6. PANTALLA PRINCIPAL - PLANIFICADOR SEMANAL CON NAVEGACIÓN
// ============================================================================
class WeeklyPlannerScreen extends ConsumerStatefulWidget {
  const WeeklyPlannerScreen({super.key});

  @override
  ConsumerState<WeeklyPlannerScreen> createState() =>
      _WeeklyPlannerScreenState();
}

class _WeeklyPlannerScreenState extends ConsumerState<WeeklyPlannerScreen> {
  DateTime _fechaInicioSemana = _getInicioSemana(DateTime.now());

// ==========================================================================
// 6.1. MÉTODOS DE NAVEGACIÓN Y FECHAS
// ==========================================================================
  /// Obtiene el inicio de semana (lunes) de una fecha dada
  static DateTime _getInicioSemana(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  /// Formatea fecha para mostrar en el título
  String _formatearFecha(DateTime fecha) {
    const meses = [
      '',
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic'
    ];
    return '${fecha.day} ${meses[fecha.month]}';
  }

  /// Navega a la semana anterior
  void _semanaAnterior() {
    setState(() {
      _fechaInicioSemana = _fechaInicioSemana.subtract(const Duration(days: 7));
    });
  }

  /// Navega a la semana siguiente
  void _semanaSiguiente() {
    setState(() {
      _fechaInicioSemana = _fechaInicioSemana.add(const Duration(days: 7));
    });
  }

  /// Determina si es la semana actual
  bool _esSemanaActual() {
    final ahora = DateTime.now();
    final inicioSemanaActual = _getInicioSemana(ahora);
    return _fechaInicioSemana.year == inicioSemanaActual.year &&
        _fechaInicioSemana.month == inicioSemanaActual.month &&
        _fechaInicioSemana.day == inicioSemanaActual.day;
  }

  /// Verifica si una fecha es hoy
  bool _esHoy(DateTime fecha) {
    final hoy = DateTime.now();
    return fecha.year == hoy.year &&
        fecha.month == hoy.month &&
        fecha.day == hoy.day;
  }

  /// ✅ NUEVO MÉTODO: Genera el ID de sesión igual que en el controlador
  String _generateSesionId(DateTime fecha, String hora, String userId) {
    final fechaKey = "${fecha.year.toString().padLeft(4, '0')}-"
        "${fecha.month.toString().padLeft(2, '0')}-"
        "${fecha.day.toString().padLeft(2, '0')}";
    return "${fechaKey}_${hora}_${userId}";
  }

  // ==========================================================================
// 6.2. BUILD PRINCIPAL
// ==========================================================================
  @override
  Widget build(BuildContext context) {
    final sesiones = ref.watch(horarioProvider);
    final timeSlots = [
      '08:00',
      '09:00',
      '10:00',
      '11:00',
      '12:00',
      '13:00',
      '14:00',
      '15:00',
      '16:00',
      '17:00'
    ];
    final dias = ['L', 'M', 'X', 'J', 'V'];
    final finSemana = _fechaInicioSemana.add(const Duration(days: 6));

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          _semanaAnterior(); // Swipe derecha: semana anterior
        } else if (details.primaryVelocity! < 0) {
          _semanaSiguiente(); // Swipe izquierda: semana siguiente
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(
              Icons.chevron_left,
              color: Colors.grey[700],
              size: 28,
            ),
            onPressed: _semanaAnterior,
            tooltip: 'Semana anterior',
          ),
          title: Column(
            children: [
              Text(
                _esSemanaActual() ? 'Semana actual' : 'Planificación Semanal',
                style: TextStyle(
                  color: const Color(0xFF1D2939),
                  fontWeight: FontWeight.bold,
                  fontSize: _esSemanaActual() ? 16 : 18,
                ),
              ),
              if (!_esSemanaActual())
                Text(
                  '${_formatearFecha(_fechaInicioSemana)} - ${_formatearFecha(finSemana)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
            ],
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 1.0,
          actions: [
            IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: Colors.grey[700],
                size: 28,
              ),
              onPressed: _semanaSiguiente,
              tooltip: 'Semana siguiente',
            ),
            PopupMenuButton<String>(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download_outlined),
                      SizedBox(width: 8),
                      Text('Exportar CSV'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'today',
                  child: Row(
                    children: [
                      Icon(Icons.today_outlined),
                      SizedBox(width: 8),
                      Text('Ir a hoy'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services_outlined),
                      SizedBox(width: 8),
                      Text('Limpiar semana'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy_outlined),
                      SizedBox(width: 8),
                      Text('Copiar semana'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'export') {
                  final csv = ref.read(horarioProvider.notifier).exportarCSV();
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Exportar a CSV'),
                      content: SelectableText(csv),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  );
                } else if (value == 'today') {
                  setState(() {
                    _fechaInicioSemana = _getInicioSemana(DateTime.now());
                  });
                } else if (value == 'clear') {
                  // 🔹 Limpiar semana completa
                  final controlador = ref.read(horarioProvider.notifier);
                  for (int i = 0; i < 5; i++) {
                    final fechaDia = _fechaInicioSemana.add(Duration(days: i));
                    for (final hora in timeSlots) {
                      await controlador.limpiarCelda(fechaDia, dias[i], hora);
                    }
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Semana limpiada')),
                  );
                } else if (value == 'copy') {
                  // 🔹 Copiar semana actual a la siguiente
                  final controlador = ref.read(horarioProvider.notifier);
                  for (int i = 0; i < 5; i++) {
                    final fechaDiaActual =
                        _fechaInicioSemana.add(Duration(days: i));
                    final fechaDiaSiguiente =
                        _fechaInicioSemana.add(Duration(days: 7 + i));

                    for (final hora in timeSlots) {
                      final sesion = controlador.getSesionByDiaHora(
                          fechaDiaActual, dias[i], hora);

                      if (sesion != null && sesion.materia != null) {
                        // Copiar materia + curso, omitir notas/actividad
                        await controlador.asignarMateria(
                            fechaDiaSiguiente, dias[i], hora, sesion.materia!);

                        if (sesion.cursoNombre != null) {
                          await controlador.asignarCurso(fechaDiaSiguiente,
                              dias[i], hora, sesion.cursoNombre!);
                        }
                      }
                    }
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Semana copiada a la siguiente')),
                  );
                }
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Indicador de semana actual
              if (_esSemanaActual())
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.today, size: 16, color: Colors.blue[600]),
                      const SizedBox(width: 6),
                      Text(
                        '${_formatearFecha(_fechaInicioSemana)} - ${_formatearFecha(finSemana)}',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              _buildDaysHeader(),
              const SizedBox(height: 8),
              ...timeSlots.map(
                (time) => _buildTimeSlotRow(context, time, dias, sesiones, ref),
              ),

              // Navegación inferior con gestos
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: _semanaAnterior,
                      icon: const Icon(Icons.arrow_back_ios, size: 16),
                      label: const Text('Anterior'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _esSemanaActual()
                            ? Colors.blue[100]
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _esSemanaActual() ? 'Actual' : 'Semana',
                        style: TextStyle(
                          fontSize: 12,
                          color: _esSemanaActual()
                              ? Colors.blue[700]
                              : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _semanaSiguiente,
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                      label: const Text('Siguiente'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // 6.3. HEADER DE DÍAS
  // ==========================================================================
  Widget _buildDaysHeader() {
    return Row(
      children: [
        const SizedBox(width: 60),
        ...['L', 'M', 'X', 'J', 'V'].asMap().entries.map((entry) {
          final index = entry.key;
          final day = entry.value;
          final fechaDia = _fechaInicioSemana.add(Duration(days: index));
          final esHoy = _esHoy(fechaDia);

          return Expanded(
            child: Column(
              children: [
                Text(
                  day,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: esHoy ? Colors.blue[700] : Colors.grey,
                    fontSize: esHoy ? 14 : 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${fechaDia.day}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: esHoy ? Colors.blue[600] : Colors.grey[500],
                    fontWeight: esHoy ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (esHoy)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==========================================================================
  // 6.4. MÉTODOS DE DIÁLOGO
  // ==========================================================================
  /// Método para mostrar el diálogo de sesión con animación.
  void _showSessionDialog(BuildContext context, SesionHorario sesion) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      pageBuilder: (context, animation, secondaryAnimation) =>
          EditarSesionDialog(sesion: sesion),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

// ==========================================================================
// 6.5. FILAS DE HORARIOS (usando _timeSlots dinámico)
// ==========================================================================
  Widget _buildTimeSlotRow(
    BuildContext context,
    String time,
    List<String> days,
    List<SesionHorario> sesiones,
    WidgetRef ref,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna con la hora
          SizedBox(
            width: 60,
            child: Text(
              time,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          // Celdas por cada día
          ...days.asMap().entries.map((entry) {
            final index = entry.key;
            final day = entry.value;
            final fechaDia = _fechaInicioSemana.add(Duration(days: index));
            final esHoy = _esHoy(fechaDia);

            final userId = FirestoreService().currentUserId ?? 'local';

            // Usamos el mismo generador de IDs que el controlador
            final sesionIdBuscado = ref
                .read(horarioProvider.notifier)
                ._generateSesionId(fechaDia, time, userId);

            final sesionExistente = sesiones.firstWhere(
              (s) => s.sesionId == sesionIdBuscado,
              orElse: () => SesionHorario(
                id: 0,
                dia: day,
                hora: time,
                sesionId: '',
                docenteId: 0,
                userId: userId,
              ),
            );

            final sesion = sesiones.firstWhere(
              (s) => s.sesionId == sesionIdBuscado,
              orElse: () => SesionHorario(
                id: sesionIdBuscado.hashCode,
                dia: day,
                hora: time,
                sesionId: sesionIdBuscado,
                docenteId: 0,
                userId: userId,
                cursoNombre: sesionExistente.cursoNombre,
              ),
            );

            final bool tieneContenido = sesion.materia != null ||
                sesion.actividad != null ||
                sesion.notas != null;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: GestureDetector(
                  onTap: () {
                    final sesionReal = sesiones.firstWhere(
                      (s) => s.sesionId == sesionIdBuscado,
                      orElse: () => ref
                          .read(horarioProvider.notifier)
                          ._getOrCreateSesion(fechaDia, day, time),
                    );
                    _showSessionDialog(context, sesionReal);
                  },
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color:
                              esHoy ? Colors.blue[400]! : Colors.grey.shade300,
                          width: esHoy ? 2 : 1),
                      borderRadius: BorderRadius.circular(4),
                      color: sesion.materia != null
                          ? sesion.materia!.color.withOpacity(0.3)
                          : esHoy
                              ? Colors.blue[25]
                              : Colors.grey.shade100,
                    ),
                    child: Stack(
                      children: [
                        // Contenido principal
                        tieneContenido
                            ? EventCard(
                                sesion: sesion,
                                onTap: () {
                                  final sesionReal = sesiones.firstWhere(
                                    (s) => s.sesionId == sesionIdBuscado,
                                    orElse: () => ref
                                        .read(horarioProvider.notifier)
                                        ._getOrCreateSesion(
                                            fechaDia, day, time),
                                  );
                                  _showSessionDialog(context, sesionReal);
                                },
                              )
                            : Center(
                                child: Icon(
                                  Icons.add,
                                  color: esHoy
                                      ? Colors.blue.shade300
                                      : Colors.grey.shade400,
                                  size: 24,
                                ),
                              ),

                        // Indicador de día actual
                        if (esHoy)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.blue[600],
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
