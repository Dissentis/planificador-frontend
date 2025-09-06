// ============================================================================
// SISTEMA MONTHLY PLANNER COMPLETO
// Vista Anual (Selector Sept-Junio) + Vista Mensual (Expandible Semanal)
// Conectado al HorarioController existente
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/sesion_model.dart';
import 'weekly_planner_screen.dart';
import '../services/firestore_service.dart';

// ============================================================================
// 1. MODELOS Y UTILIDADES
// ============================================================================

/// Información de mes académico para el selector anual
class MonthInfo {
  final int month;
  final int year;
  final String name;
  final Color color;
  final String tag; // Para Hero animation

  const MonthInfo({
    required this.month,
    required this.year,
    required this.name,
    required this.color,
    required this.tag,
  });
}

/// Utilidades para manejo de calendario académico
class AcademicCalendar {
  /// Genera los meses del año académico (Sept-Junio)
  static List<MonthInfo> generateAcademicMonths() {
    final currentYear = DateTime.now().year;
    final colors = [
      Colors.orange[200]!, // Septiembre
      Colors.amber[200]!, // Octubre
      Colors.brown[200]!, // Noviembre
      Colors.blue[200]!, // Diciembre
      Colors.indigo[200]!, // Enero
      Colors.purple[200]!, // Febrero
      Colors.pink[200]!, // Marzo
      Colors.green[200]!, // Abril
      Colors.teal[200]!, // Mayo
      Colors.cyan[200]!, // Junio
    ];

    return [
      // Sept-Dic del año actual
      MonthInfo(
          month: 9,
          year: currentYear,
          name: 'Septiembre',
          color: colors[0],
          tag: 'sept'),
      MonthInfo(
          month: 10,
          year: currentYear,
          name: 'Octubre',
          color: colors[1],
          tag: 'oct'),
      MonthInfo(
          month: 11,
          year: currentYear,
          name: 'Noviembre',
          color: colors[2],
          tag: 'nov'),
      MonthInfo(
          month: 12,
          year: currentYear,
          name: 'Diciembre',
          color: colors[3],
          tag: 'dic'),
      // Ene-Jun del siguiente año
      MonthInfo(
          month: 1,
          year: currentYear + 1,
          name: 'Enero',
          color: colors[4],
          tag: 'ene'),
      MonthInfo(
          month: 2,
          year: currentYear + 1,
          name: 'Febrero',
          color: colors[5],
          tag: 'feb'),
      MonthInfo(
          month: 3,
          year: currentYear + 1,
          name: 'Marzo',
          color: colors[6],
          tag: 'mar'),
      MonthInfo(
          month: 4,
          year: currentYear + 1,
          name: 'Abril',
          color: colors[7],
          tag: 'abr'),
      MonthInfo(
          month: 5,
          year: currentYear + 1,
          name: 'Mayo',
          color: colors[8],
          tag: 'may'),
      MonthInfo(
          month: 6,
          year: currentYear + 1,
          name: 'Junio',
          color: colors[9],
          tag: 'jun'),
    ];
  }

  /// Obtiene los días del mes con información de semana
  static List<DateTime> getMonthDays(int month, int year) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final days = <DateTime>[];

    for (int i = 1; i <= lastDay.day; i++) {
      days.add(DateTime(year, month, i));
    }

    return days;
  }

  /// Obtiene el rango de semana para una fecha dada
  static List<DateTime> getWeekRange(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }
}

/// CustomPainter para crear patrón cebrado diagonal
class StripedPainter extends CustomPainter {
  final Color color;
  final double stripeWidth;
  final double spacing;

  StripedPainter({
    required this.color,
    this.stripeWidth = 3.0,
    this.spacing = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stripeWidth
      ..style = PaintingStyle.stroke;

    final totalSpacing = stripeWidth + spacing;
    final numStripes = (size.width + size.height) ~/ totalSpacing + 1;

    for (int i = 0; i < numStripes; i++) {
      final offset = i * totalSpacing;
      canvas.drawLine(
        Offset(-size.height + offset, size.height),
        Offset(offset, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 2. PANTALLA 1: SELECTOR ANUAL (YearViewScreen) - VISTA CALENDARIO COMPLETO
// ============================================================================

class YearViewScreen extends ConsumerStatefulWidget {
  const YearViewScreen({super.key});

  @override
  ConsumerState<YearViewScreen> createState() => _YearViewScreenState();
}

class _YearViewScreenState extends ConsumerState<YearViewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;
  final List<MonthInfo> _months = AcademicCalendar.generateAcademicMonths();

  // NUEVO: Variables para gestión de festivos
  Map<DateTime, String> _festivosNacionales = {};
  Map<DateTime, String> _festivosRegionales = {};
  Set<DateTime> _diasLibreDisposicion = {};
  bool _festivosLoaded = false;

  // NUEVO: Configuración de colores por tipo de día
  final Map<String, Color> _dayTypeColors = {
    'laborable': Colors.white,
    'festivoNacional': Colors.red[100]!,
    'festivoRegional': Colors.orange[100]!,
    'libreDisposicion': Colors.transparent,
    'finDeSemana': Colors.grey[100]!,
  };

  @override
  void initState() {
    super.initState();
    // Animación staggered para la aparición de meses (#15)
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();

    // NUEVO: Cargar festivos al inicializar
    _loadFestivos();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  // NUEVO: Carga de festivos desde almacenamiento o valores por defecto
  Future<void> _loadFestivos() async {
    try {
      await _loadFestivosFromStorage();
      if (_festivosNacionales.isEmpty && _festivosRegionales.isEmpty) {
        await _loadDefaultFestivos();
      }
      setState(() {
        _festivosLoaded = true;
      });
    } catch (e) {
      await _loadDefaultFestivos();
      setState(() {
        _festivosLoaded = true;
      });
    }
  }

  Future<void> _loadFestivosFromStorage() async {
    final prefs = await SharedPreferences.getInstance();

    final festivosNacionalesJson = prefs.getString('festivosNacionales');
    if (festivosNacionalesJson != null) {
      final Map<String, dynamic> decoded = json.decode(festivosNacionalesJson);
      _festivosNacionales = decoded
          .map((key, value) => MapEntry(DateTime.parse(key), value.toString()));
    }

    final festivosRegionalesJson = prefs.getString('festivosRegionales');
    if (festivosRegionalesJson != null) {
      final Map<String, dynamic> decoded = json.decode(festivosRegionalesJson);
      _festivosRegionales = decoded
          .map((key, value) => MapEntry(DateTime.parse(key), value.toString()));
    }

    final diasLibreJson = prefs.getStringList('diasLibreDisposicion') ?? [];
    _diasLibreDisposicion =
        diasLibreJson.map((dateStr) => DateTime.parse(dateStr)).toSet();
  }

  Future<void> _loadDefaultFestivos() async {
    final currentYear = DateTime.now().year;
    final nextYear = currentYear + 1;

    _festivosNacionales = {
      DateTime(currentYear, 1, 1): 'Año Nuevo',
      DateTime(currentYear, 1, 6): 'Reyes Magos',
      DateTime(currentYear, 5, 1): 'Día del Trabajo',
      DateTime(currentYear, 8, 15): 'Asunción de la Virgen',
      DateTime(currentYear, 10, 12): 'Fiesta Nacional',
      DateTime(currentYear, 11, 1): 'Todos los Santos',
      DateTime(currentYear, 12, 6): 'Día de la Constitución',
      DateTime(currentYear, 12, 8): 'Inmaculada Concepción',
      DateTime(currentYear, 12, 25): 'Navidad',
      DateTime(nextYear, 1, 1): 'Año Nuevo',
      DateTime(nextYear, 1, 6): 'Reyes Magos',
      DateTime(nextYear, 5, 1): 'Día del Trabajo',
      DateTime(nextYear, 8, 15): 'Asunción de la Virgen',
      DateTime(nextYear, 10, 12): 'Fiesta Nacional',
      DateTime(nextYear, 11, 1): 'Todos los Santos',
      DateTime(nextYear, 12, 6): 'Día de la Constitución',
      DateTime(nextYear, 12, 8): 'Inmaculada Concepción',
      DateTime(nextYear, 12, 25): 'Navidad',
    };

    _festivosRegionales = {
      DateTime(currentYear, 4, 23): 'Sant Jordi',
      DateTime(currentYear, 6, 24): 'Sant Joan',
      DateTime(currentYear, 9, 11): 'Diada Nacional',
      DateTime(currentYear, 12, 26): 'Sant Esteve',
      DateTime(nextYear, 4, 23): 'Sant Jordi',
      DateTime(nextYear, 6, 24): 'Sant Joan',
      DateTime(nextYear, 9, 11): 'Diada Nacional',
      DateTime(nextYear, 12, 26): 'Sant Esteve',
    };
  }

  /// Navega a la vista mensual con Hero animation (#6)
  void _navigateToMonth(MonthInfo monthInfo) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MonthViewScreen(monthInfo: monthInfo),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const curve = Curves.easeOutCubic;
          return ScaleTransition(
            scale: Tween<double>(begin: 0.5, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: curve),
            ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Calendario Académico 2024-2025',
          style: TextStyle(
            color: Color(0xFF1D2939),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1.0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8.0),
        child: _buildYearCalendarGrid(),
      ),
    );
  }

  // ============================================================================
  // 2.1. CONSTRUCCIÓN DE LA VISTA ANUAL COMPLETA
  // ============================================================================

  /// Vista de calendario anual completo como en la imagen de referencia
  Widget _buildYearCalendarGrid() {
    if (!_festivosLoaded) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(50.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        // NUEVO: Leyenda de tipos de días
        _buildYearLegend(),
        const SizedBox(height: 16),

        // NUEVO: Layout de todos los meses académicos
        _buildAllMonthsLayout(),

        const SizedBox(height: 16),

        // NUEVO: Información adicional de vacaciones y festivos
        _buildYearSummaryInfo(),
      ],
    );
  }

// ============================================================================
// 2.2. LEYENDA DE TIPOS DE DÍAS
// ============================================================================

  /// Leyenda de colores para tipos de días (como en la imagen de referencia)
  Widget _buildYearLegend() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tipos de días:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _buildLegendItem(
                  'Laborable', _dayTypeColors['laborable']!, Colors.grey[700]!),
              _buildLegendItem('F. Nacional',
                  _dayTypeColors['festivoNacional']!, Colors.red[700]!),
              _buildLegendItem('F. Regional',
                  _dayTypeColors['festivoRegional']!, Colors.orange[700]!),
              _buildLegendItem('Libre Disp.',
                  _dayTypeColors['libreDisposicion']!, Colors.purple[700]!),
              _buildLegendItem('Fin Semana', _dayTypeColors['finDeSemana']!,
                  Colors.grey[600]!),
            ],
          ),
        ],
      ),
    );
  }

  /// Item individual de la leyenda
  Widget _buildLegendItem(
      String label, Color backgroundColor, Color textColor) {
    final bool isLibreDisposicion = label == 'Libre Disp.';

    if (isLibreDisposicion) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.purple[100]!.withOpacity(0.3),
              Colors.purple[200]!.withOpacity(0.5),
              Colors.purple[100]!.withOpacity(0.3),
            ],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.purple[400]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.purple[800]!,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.grey[400]!,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  // ============================================================================
  // 2.3. LAYOUT DE TODOS LOS MESES ACADÉMICOS
  // ============================================================================

  /// Layout que muestra todos los 10 meses académicos en formato compacto
  Widget _buildAllMonthsLayout() {
    // Dividir los 10 meses en filas de 3-4 meses cada una
    final monthRows = <List<MonthInfo>>[];

    // Primera fila: 3 meses (Septiembre, Octubre, Noviembre)
    monthRows.add(_months.sublist(0, 3));

    // Segunda fila: 3 meses (Diciembre, Enero, Febrero)
    monthRows.add(_months.sublist(3, 6));

    // Tercera fila: 2 meses (Marzo, Abril)
    monthRows.add(_months.sublist(6, 8));

    // Cuarta fila: 2 meses (Mayo, Junio)
    monthRows.add(_months.sublist(8, 10));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: monthRows.asMap().entries.map((entry) {
            final rowIndex = entry.key;
            final rowMonths = entry.value;

            return AnimatedBuilder(
              animation: _staggerController,
              builder: (context, child) {
                final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _staggerController,
                    curve: Interval(
                      (rowIndex * 0.15).clamp(0.0, 1.0),
                      ((rowIndex * 0.15) + 0.4).clamp(0.0, 1.0),
                      curve: Curves.easeOutQuart,
                    ),
                  ),
                );

                return Transform.translate(
                  offset: Offset(0, 20 * (1 - animation.value)),
                  child: Opacity(
                    opacity: animation.value,
                    child: Column(
                      children: [
                        if (rowIndex > 0) const SizedBox(height: 8),
                        _buildMonthRow(rowMonths),
                      ],
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Construye una fila de meses
  Widget _buildMonthRow(List<MonthInfo> rowMonths) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rowMonths.asMap().entries.map((entry) {
          final index = entry.key;
          final month = entry.value;

          return Expanded(
            child: Row(
              children: [
                if (index > 0) const SizedBox(width: 6),
                Expanded(child: _buildCompactMonthCalendar(month)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================================
  // 2.4. CALENDARIO MENSUAL COMPACTO CON COLORES
  // ============================================================================

  /// Calendario mensual compacto con colores aplicados según tipo de día
  Widget _buildCompactMonthCalendar(MonthInfo monthInfo) {
    final sesiones = ref.watch(horarioProvider);
    final days = AcademicCalendar.getMonthDays(monthInfo.month, monthInfo.year);

    return Hero(
      tag: 'month_${monthInfo.tag}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToMonth(monthInfo),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cabecera del mes con color distintivo
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: monthInfo.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      monthInfo.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: monthInfo.color.withOpacity(0.9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Días de la semana (muy compactos)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['L', 'M', 'X', 'J', 'V', 'S', 'D'].map((day) {
                      return SizedBox(
                        width: 14,
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 2),

                  // Grid de días del mes con colores
                  _buildCompactMonthDays(days, sesiones, monthInfo),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

// ============================================================================
// 2.5. GRID DE DÍAS CON COLORES APLICADOS
// ============================================================================

  /// Grid de días para el calendario compacto con colores según tipo de día
  Widget _buildCompactMonthDays(
      List<DateTime> days, List<SesionHorario> sesiones, MonthInfo monthInfo) {
    // Calcular padding para completar semanas
    final firstDay = days.first;
    final startPadding = (firstDay.weekday - 1) % 7;
    final totalCells = startPadding + days.length;
    final endPadding = (7 - (totalCells % 7)) % 7;

    final allCells = <DateTime?>[]
      ..addAll(List.filled(startPadding, null))
      ..addAll(days)
      ..addAll(List.filled(endPadding, null));

    // Calcular número de filas necesarias
    final rowCount = (allCells.length / 7).ceil();

    return Column(
      children: List.generate(rowCount, (rowIndex) {
        final startIndex = rowIndex * 7;
        final endIndex = (startIndex + 7).clamp(0, allCells.length);
        final rowCells = allCells.sublist(startIndex, endIndex);

        return Container(
          height: 16, // Altura muy compacta para cada fila
          margin: const EdgeInsets.only(bottom: 1),
          child: Row(
            children: rowCells.map((day) {
              if (day == null) {
                return const Expanded(child: SizedBox());
              }

              return Expanded(
                child: _buildCompactDayCell(day, sesiones),
              );
            }).toList(),
          ),
        );
      }),
    );
  }

  /// Celda individual de día con colores aplicados según tipo
  Widget _buildCompactDayCell(DateTime day, List<SesionHorario> sesiones) {
    final hasContent = _hasContentOnDay(sesiones, day);
    final isToday = _isToday(day);
    final dayType = _getDayType(day);
    final dayColor = _getDayColor(day);

    // Color especial para libre disposición en celdas pequeñas
    Color finalColor;
    if (isToday) {
      finalColor = Colors.blue[600]!;
    } else if (dayType == 'libreDisposicion') {
      finalColor = Colors.purple[200]!.withOpacity(0.7);
    } else {
      finalColor = dayColor;
    }

    // Color del texto
    Color textColor;
    if (isToday) {
      textColor = Colors.white;
    } else if (dayType == 'festivoNacional') {
      textColor = Colors.red[800]!;
    } else if (dayType == 'festivoRegional') {
      textColor = Colors.orange[800]!;
    } else if (dayType == 'libreDisposicion') {
      textColor = Colors.purple[800]!;
    } else if (dayType == 'finDeSemana') {
      textColor = Colors.grey[600]!;
    } else {
      textColor = Colors.grey[800]!;
    }

    return Container(
      margin: const EdgeInsets.all(0.5),
      decoration: BoxDecoration(
        color: finalColor,
        borderRadius: BorderRadius.circular(2),
        border: isToday
            ? Border.all(color: Colors.blue[700]!, width: 1.5)
            : dayType != 'laborable'
                ? Border.all(
                    color: dayType == 'festivoNacional'
                        ? Colors.red[400]!
                        : dayType == 'festivoRegional'
                            ? Colors.orange[400]!
                            : dayType == 'libreDisposicion'
                                ? Colors.purple[400]!
                                : Colors.grey[400]!,
                    width: 0.8)
                : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 7,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          // Pequeño indicador de contenido (punto azul) sin cambiar color de fondo
          if (hasContent && !isToday)
            Positioned(
              top: 1,
              right: 1,
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  shape: BoxShape.circle,
                ),
              ),
            ),
          // Indicador especial para libre disposición (pequeña marca)
          if (dayType == 'libreDisposicion' && !isToday)
            Positioned(
              top: 1,
              left: 1,
              child: Container(
                width: 4,
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.purple[700],
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
        ],
      ),
    );
  }

// ============================================================================
// 2.6. INFORMACIÓN ADICIONAL DEL AÑO ACADÉMICO (EXPANDIBLE)
// ============================================================================

  /// Información de resumen del año académico con expansión detallada
  Widget _buildYearSummaryInfo() {
    final totalFestivos =
        _festivosNacionales.length + _festivosRegionales.length;
    final totalLibreDisposicion = _diasLibreDisposicion.length;

    return ExpansionTile(
      initiallyExpanded: false,
      backgroundColor: Colors.blue[25],
      collapsedBackgroundColor: Colors.blue[25],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.blue[200]!, width: 1),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.blue[200]!, width: 1),
      ),
      leading: Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
      title: Text(
        'Resumen del año académico',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
        ),
      ),
      subtitle: Text(
        '${totalFestivos + totalLibreDisposicion} días no lectivos • Toca para ver detalles',
        style: TextStyle(
          fontSize: 11,
          color: Colors.blue[600],
          fontStyle: FontStyle.italic,
        ),
      ),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Estadísticas rápidas
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!, width: 1),
                ),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    _buildSummaryItem('Festivos nacionales:',
                        '${_festivosNacionales.length}', Colors.red[600]!),
                    _buildSummaryItem('Festivos regionales:',
                        '${_festivosRegionales.length}', Colors.orange[600]!),
                    if (totalLibreDisposicion > 0)
                      _buildSummaryItem('Días libre disposición:',
                          '$totalLibreDisposicion', Colors.purple[600]!),
                    _buildSummaryItem(
                        'Total no lectivos:',
                        '${totalFestivos + totalLibreDisposicion}',
                        Colors.grey[700]!),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Botón para gestionar días especiales
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => _showManagementDialog(),
                  icon: Icon(Icons.settings, size: 18),
                  label: const Text('Gestionar días especiales'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Lista detallada de festivos nacionales
              if (_festivosNacionales.isNotEmpty) ...[
                _buildFestivosSection(
                  'Festivos Nacionales',
                  _festivosNacionales,
                  Colors.red[600]!,
                  Icons.flag,
                ),
                const SizedBox(height: 12),
              ],

              // Lista detallada de festivos regionales
              if (_festivosRegionales.isNotEmpty) ...[
                _buildFestivosSection(
                  'Festivos Regionales',
                  _festivosRegionales,
                  Colors.orange[600]!,
                  Icons.location_on,
                ),
                const SizedBox(height: 12),
              ],

              // Lista de días de libre disposición
              if (_diasLibreDisposicion.isNotEmpty) ...[
                _buildLibreDisposicionSection(),
                const SizedBox(height: 12),
              ],

              // Períodos de vacaciones principales
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.beach_access,
                            size: 16, color: Colors.green[700]),
                        const SizedBox(width: 6),
                        Text(
                          'Períodos de Vacaciones',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Navidad: 23 diciembre - 7 enero\n'
                      '• Semana Santa: 30 marzo - 5 abril\n'
                      '• Verano: A partir del 21 junio',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Sección expandible para mostrar festivos por categoría
  Widget _buildFestivosSection(
    String titulo,
    Map<DateTime, String> festivos,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                '$titulo (${festivos.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...festivos.entries.map((entry) {
            final fecha = entry.key;
            final nombre = entry.value;
            final mesNombre = _getMonthName(fecha.month);

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF374151),
                        ),
                        children: [
                          TextSpan(
                            text: '${fecha.day} $mesNombre: ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: nombre),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// Sección para días de libre disposición
  Widget _buildLibreDisposicionSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_calendar, size: 16, color: Colors.purple[700]),
              const SizedBox(width: 6),
              Text(
                'Días de Libre Disposición (${_diasLibreDisposicion.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_diasLibreDisposicion.isEmpty)
            Text(
              'No hay días marcados como libre disposición',
              style: TextStyle(
                fontSize: 11,
                color: Colors.purple[600],
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _diasLibreDisposicion.map((fecha) {
                final mesNombre = _getMonthName(fecha.month);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple[300]!, width: 1),
                  ),
                  child: Text(
                    '${fecha.day} $mesNombre',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.purple[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  /// Item de resumen con icono (mantenido para compatibilidad)
  Widget _buildSummaryItem(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $value',
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF374151),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Diálogo para gestión masiva de días especiales
  void _showManagementDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.settings, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text('Gestión de Días Especiales'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.edit_calendar, color: Colors.purple[600]),
                  title: const Text('Gestionar Libre Disposición'),
                  subtitle:
                      const Text('Añadir o quitar días de libre disposición'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showLibreDisposicionManager();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.celebration, color: Colors.orange[600]),
                  title: const Text('Gestionar Festivos'),
                  subtitle: const Text('Añadir festivos personalizados'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showFestivosManager();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.import_export, color: Colors.green[600]),
                  title: const Text('Importar/Exportar'),
                  subtitle: const Text('Gestionar datos de días especiales'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showImportExportDialog();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  /// Gestor de días de libre disposición
  void _showLibreDisposicionManager() {
    // TODO: Implementar gestor masivo de días de libre disposición
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gestor de Libre Disposición'),
        content: const Text('Funcionalidad en desarrollo'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Gestor de festivos personalizados
  void _showFestivosManager() {
    // TODO: Implementar gestor de festivos personalizados
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gestor de Festivos'),
        content: const Text('Funcionalidad en desarrollo'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Diálogo de importar/exportar
  void _showImportExportDialog() {
    // TODO: Implementar importación y exportación de datos
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importar/Exportar Datos'),
        content: const Text('Funcionalidad en desarrollo'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Obtener nombre del mes
  String _getMonthName(int month) {
    const months = [
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
    return months[month];
  }

  // ============================================================================
  // 2.7. MÉTODOS AUXILIARES PARA FESTIVOS Y TIPOS DE DÍAS
  // ============================================================================

  /// Determinar el tipo de día
  String _getDayType(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);

    if (_diasLibreDisposicion.contains(normalizedDay)) {
      return 'libreDisposicion';
    }

    if (_festivosNacionales.containsKey(normalizedDay)) {
      return 'festivoNacional';
    }

    if (_festivosRegionales.containsKey(normalizedDay)) {
      return 'festivoRegional';
    }

    if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
      return 'finDeSemana';
    }

    return 'laborable';
  }

  /// Obtener color del día según su tipo
  Color _getDayColor(DateTime day) {
    final dayType = _getDayType(day);
    return _dayTypeColors[dayType] ?? Colors.white;
  }

  /// Verifica si una fecha es hoy
  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  /// Verifica si hay contenido en un día específico
  bool _hasContentOnDay(List<SesionHorario> sesiones, DateTime day) {
    final fechaKey = "${day.year.toString().padLeft(4, '0')}-"
        "${day.month.toString().padLeft(2, '0')}-"
        "${day.day.toString().padLeft(2, '0')}";

    return sesiones.any((s) =>
        s.sesionId.startsWith(fechaKey) &&
        (s.materia != null || s.actividad != null || s.notas != null));
  }

  /// Convierte número de día de semana a código
  String _getDayOfWeekCode(int weekday) {
    const codes = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return codes[(weekday - 1) % 7];
  }

  /// Widget que crea un patrón cebrado diagonal
  Widget _buildStripedPattern({
    required Color color,
    required Widget child,
    double stripeWidth = 3.0,
    double spacing = 3.0,
  }) {
    return CustomPaint(
      painter: StripedPainter(
        color: color.withOpacity(0.4),
        stripeWidth: stripeWidth,
        spacing: spacing,
      ),
      child: child,
    );
  }

  /// Verifica si hay contenido en el mes (mantenido para compatibilidad)
  bool _hasContentInMonth(List<SesionHorario> sesiones, MonthInfo monthInfo) {
    return sesiones.any(
        (s) => s.materia != null || s.actividad != null || s.notas != null);
  }
}

// ============================================================================
// 3. PANTALLA 2: VISTA MENSUAL EXPANDIBLE (MonthViewScreen)
// ============================================================================

// ============================================================================
// 3.1. CLASE PRINCIPAL Y ESTADO
// ============================================================================

class MonthViewScreen extends ConsumerStatefulWidget {
  final MonthInfo monthInfo;

  const MonthViewScreen({super.key, required this.monthInfo});

  @override
  ConsumerState<MonthViewScreen> createState() => _MonthViewScreenState();
}

class _MonthViewScreenState extends ConsumerState<MonthViewScreen>
    with TickerProviderStateMixin {
  // Controladores de animación
  late AnimationController _expansionController;
  late AnimationController _parallaxController;
  late AnimationController
      _dayExpansionController; // NUEVO: para expansión diaria

  // Variables de estado para expansión semanal
  DateTime? _selectedDay;
  List<DateTime>? _expandedWeekDays;
  bool _isWeekExpanded = false;

  // Variables para el efecto persiana orgánico
  int? _selectedWeekRow;
  List<List<DateTime?>> _calendarRows = [];
  bool _isInserting = false;

  // NUEVO: Variables de estado para expansión diaria
  DateTime? _selectedDayForExpansion;
  String? _selectedDayCode; // 'L', 'M', 'X', 'J', 'V'
  bool _isDayExpanded = false;

  // NUEVO: Gestión de festivos y días especiales
  Map<DateTime, String> _festivosNacionales = {};
  Map<DateTime, String> _festivosRegionales = {};
  Set<DateTime> _diasLibreDisposicion = {};
  bool _festivosLoaded = false;

  // NUEVO: Configuración de colores por tipo de día
  final Map<String, Color> _dayTypeColors = {
    'laborable': Colors.white,
    'festivoNacional': Colors.red[100]!,
    'festivoRegional': Colors.orange[100]!,
    'libreDisposicion': Colors.transparent,
    'finDeSemana': Colors.grey[100]!,
  };

  @override
  void initState() {
    super.initState();

    // Controladores de animación
    _expansionController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _parallaxController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // NUEVO: Controlador para animación diaria
    _dayExpansionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // NUEVO: Cargar festivos al inicializar
    _loadFestivos();
  }

  @override
  void dispose() {
    _expansionController.dispose();
    _parallaxController.dispose();
    _dayExpansionController.dispose(); // NUEVO
    super.dispose();
  }

  /// Carga los días festivos desde el almacenamiento local o establece valores por defecto.
  Future<void> _loadFestivos() async {
    try {
      // Cargar festivos desde SharedPreferences o API
      await _loadFestivosFromStorage();

      // Si no hay festivos guardados, cargar valores por defecto
      if (_festivosNacionales.isEmpty && _festivosRegionales.isEmpty) {
        await _loadDefaultFestivos();
      }

      setState(() {
        _festivosLoaded = true;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error cargando festivos: $e');
      // Cargar festivos por defecto como fallback
      await _loadDefaultFestivos();
      setState(() {
        _festivosLoaded = true;
      });
    }
  }

  /// Carga los festivos y días de libre disposición desde SharedPreferences.
  Future<void> _loadFestivosFromStorage() async {
    final prefs = await SharedPreferences.getInstance();

    // Cargar festivos nacionales
    final festivosNacionalesJson = prefs.getString('festivosNacionales');
    if (festivosNacionalesJson != null) {
      final Map<String, dynamic> decoded = json.decode(festivosNacionalesJson);
      _festivosNacionales = Map<DateTime, String>.fromEntries(decoded.entries
          .map((entry) =>
              MapEntry(DateTime.parse(entry.key), entry.value.toString())));
    }

    // Cargar festivos regionales
    final festivosRegionalesJson = prefs.getString('festivosRegionales');
    if (festivosRegionalesJson != null) {
      final Map<String, dynamic> decoded = json.decode(festivosRegionalesJson);
      _festivosRegionales = Map<DateTime, String>.fromEntries(decoded.entries
          .map((entry) =>
              MapEntry(DateTime.parse(entry.key), entry.value.toString())));
    }

    // Cargar días de libre disposición
    final diasLibreJson = prefs.getStringList('diasLibreDisposicion') ?? [];
    _diasLibreDisposicion =
        diasLibreJson.map((dateStr) => DateTime.parse(dateStr)).toSet();
  }

  /// Establece una lista de festivos por defecto si no hay datos guardados.
  Future<void> _loadDefaultFestivos() async {
    final currentYear = DateTime.now().year;
    final nextYear = currentYear + 1;

    // Festivos nacionales fijos
    _festivosNacionales = {
      DateTime(currentYear, 1, 1): 'Año Nuevo',
      DateTime(currentYear, 1, 6): 'Reyes Magos',
      DateTime(currentYear, 5, 1): 'Día del Trabajo',
      DateTime(currentYear, 8, 15): 'Asunción de la Virgen',
      DateTime(currentYear, 10, 12): 'Fiesta Nacional',
      DateTime(currentYear, 11, 1): 'Todos los Santos',
      DateTime(currentYear, 12, 6): 'Día de la Constitución',
      DateTime(currentYear, 12, 8): 'Inmaculada Concepción',
      DateTime(currentYear, 12, 25): 'Navidad',

      // Año siguiente
      DateTime(nextYear, 1, 1): 'Año Nuevo',
      DateTime(nextYear, 1, 6): 'Reyes Magos',
      DateTime(nextYear, 5, 1): 'Día del Trabajo',
      DateTime(nextYear, 8, 15): 'Asunción de la Virgen',
      DateTime(nextYear, 10, 12): 'Fiesta Nacional',
      DateTime(nextYear, 11, 1): 'Todos los Santos',
      DateTime(nextYear, 12, 6): 'Día de la Constitución',
      DateTime(nextYear, 12, 8): 'Inmaculada Concepción',
      DateTime(nextYear, 12, 25): 'Navidad',
    };

    // Festivos regionales (ejemplo para Cataluña)
    _festivosRegionales = {
      DateTime(currentYear, 4, 23): 'Sant Jordi',
      DateTime(currentYear, 6, 24): 'Sant Joan',
      DateTime(currentYear, 9, 11): 'Diada Nacional de Cataluña',
      DateTime(currentYear, 12, 26): 'Sant Esteve',

      // Año siguiente
      DateTime(nextYear, 4, 23): 'Sant Jordi',
      DateTime(nextYear, 6, 24): 'Sant Joan',
      DateTime(nextYear, 9, 11): 'Diada Nacional de Cataluña',
      DateTime(nextYear, 12, 26): 'Sant Esteve',
    };

    // Guardar en almacenamiento local
    await _saveFestivosToStorage();
  }

  /// Guarda la configuración actual de festivos en SharedPreferences.
  Future<void> _saveFestivosToStorage() async {
    final prefs = await SharedPreferences.getInstance();

    // Guardar festivos nacionales
    final festivosNacionalesJson = json.encode(Map.fromEntries(
        _festivosNacionales.entries
            .map((e) => MapEntry(e.key.toIso8601String(), e.value))));
    await prefs.setString('festivosNacionales', festivosNacionalesJson);

    // Guardar festivos regionales
    final festivosRegionalesJson = json.encode(Map.fromEntries(
        _festivosRegionales.entries
            .map((e) => MapEntry(e.key.toIso8601String(), e.value))));
    await prefs.setString('festivosRegionales', festivosRegionalesJson);

    // Guardar días de libre disposición
    final diasLibreList =
        _diasLibreDisposicion.map((date) => date.toIso8601String()).toList();
    await prefs.setStringList('diasLibreDisposicion', diasLibreList);
  }

  /// Determina el tipo de día (laborable, festivo, etc.) para una fecha dada.
  String _getDayType(DateTime day) {
    // Normalizar fecha (solo año, mes, día)
    final normalizedDay = DateTime(day.year, day.month, day.day);

    // Verificar días de libre disposición
    if (_diasLibreDisposicion.contains(normalizedDay)) {
      return 'libreDisposicion';
    }

    // Verificar festivos nacionales
    if (_festivosNacionales.containsKey(normalizedDay)) {
      return 'festivoNacional';
    }

    // Verificar festivos regionales
    if (_festivosRegionales.containsKey(normalizedDay)) {
      return 'festivoRegional';
    }

    // Verificar fin de semana
    if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
      return 'finDeSemana';
    }

    return 'laborable';
  }

  /// Obtiene el color de fondo correspondiente a un tipo de día.
  Color _getDayColor(DateTime day) {
    final dayType = _getDayType(day);
    return _dayTypeColors[dayType]!;
  }

  /// Obtiene el nombre de un festivo si la fecha corresponde a uno.
  String? _getFestivoName(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);

    if (_festivosNacionales.containsKey(normalizedDay)) {
      return _festivosNacionales[normalizedDay];
    }

    if (_festivosRegionales.containsKey(normalizedDay)) {
      return _festivosRegionales[normalizedDay];
    }

    return null;
  }

  /// Añade o elimina una fecha del conjunto de días de libre disposición.
  void _toggleLibreDisposicion(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);

    setState(() {
      if (_diasLibreDisposicion.contains(normalizedDay)) {
        _diasLibreDisposicion.remove(normalizedDay);
      } else {
        _diasLibreDisposicion.add(normalizedDay);
      }
    });

    // Guardar cambios de forma asíncrona para no bloquear la UI
    _saveFestivosToStorage().then((_) {
      // Forzar actualización adicional después de guardar
      if (mounted) {
        setState(() {});
      }
    });
  }

  /// Muestra un modal para configurar una fecha como día de libre disposición.
  void _showDayConfigModal(DateTime day) {
    final dayType = _getDayType(day);
    final festivoName = _getFestivoName(day);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Configurar día ${day.day}/${day.month}/${day.year}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tipo actual: ${_getDayTypeDisplayName(dayType)}'),
              if (festivoName != null) Text('Festivo: $festivoName'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _toggleLibreDisposicion(day);
                  Navigator.of(context).pop();
                },
                child: Text(dayType == 'libreDisposicion'
                    ? 'Quitar libre disposición'
                    : 'Marcar como libre disposición'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  /// Devuelve el nombre legible para un tipo de día.
  String _getDayTypeDisplayName(String dayType) {
    const names = {
      'laborable': 'Día laborable',
      'festivoNacional': 'Festivo nacional',
      'festivoRegional': 'Festivo regional',
      'libreDisposicion': 'Libre disposición',
      'finDeSemana': 'Fin de semana',
    };
    return names[dayType] ?? dayType;
  }

// ============================================================================
// 3.2. LÓGICA DE EXPANSIÓN SEMANAL
// ============================================================================

  /// Expande la semana con lógica toggle corregida
  Future<void> _expandWeek(DateTime selectedDay) async {
    final selectedRow = _getWeekRowIndex(selectedDay);
    final isSameWeek = _selectedWeekRow == selectedRow;

    // Si hay semana expandida y es diferente, cambiar a nueva semana
    if (_isWeekExpanded && !isSameWeek) {
      await _collapseWeek();
      await _expandNewWeek(selectedDay, selectedRow);
    }
    // Si es la misma semana, solo colapsar
    else if (_isWeekExpanded && isSameWeek) {
      await _collapseWeek();
      return;
    }
    // Si no hay semana expandida, expandir nueva
    else {
      await _expandNewWeek(selectedDay, selectedRow);
    }
  }

  /// Expande una nueva semana
  Future<void> _expandNewWeek(DateTime selectedDay, int selectedRow) async {
    // Colapsar día si estaba expandido
    if (_isDayExpanded) {
      await _collapseDay();
    }

    setState(() {
      _selectedDay = selectedDay;
      _expandedWeekDays = AcademicCalendar.getWeekRange(selectedDay);
      _isWeekExpanded = true;
      _selectedWeekRow = selectedRow;
      _isInserting = true;
    });

    // Animación de expansión
    await _expansionController.forward();

    setState(() {
      _isInserting = false;
    });
  }

  /// Colapsa la semana expandida
  Future<void> _collapseWeek() async {
    // Primero colapsar día si está expandido
    if (_isDayExpanded) {
      await _collapseDay();
    }

    setState(() {
      _isInserting = true;
    });

    await _expansionController.reverse();

    setState(() {
      _expandedWeekDays = null;
      _isWeekExpanded = false;
      _selectedDay = null;
      _selectedWeekRow = null;
      _isInserting = false;
    });
  }

  /// Colapsa la vista diaria expandida
  Future<void> _collapseDay() async {
    await _dayExpansionController.reverse();

    setState(() {
      _selectedDayForExpansion = null;
      _selectedDayCode = null;
      _isDayExpanded = false;
    });
  }

  /// Obtiene el índice de la fila que contiene el día seleccionado
  int _getWeekRowIndex(DateTime selectedDay) {
    for (int rowIndex = 0; rowIndex < _calendarRows.length; rowIndex++) {
      final row = _calendarRows[rowIndex];
      if (row.any((day) => day?.day == selectedDay.day)) {
        return rowIndex;
      }
    }
    return 0;
  }

  /// Expande un día específico de la semana expandida
  Future<void> _expandDay(String dayCode) async {
    // Si el mismo día está expandido, colapsar
    if (_isDayExpanded && _selectedDayCode == dayCode) {
      await _collapseDay();
      return;
    }

    // Si otro día está expandido, colapsar primero
    if (_isDayExpanded) {
      await _collapseDay();
    }

    // Encontrar el DateTime correspondiente al día
    final dayDateTime = _expandedWeekDays?.firstWhere(
      (date) => _getDayOfWeekCode(date.weekday) == dayCode,
      orElse: () => DateTime.now(),
    );

    setState(() {
      _selectedDayForExpansion = dayDateTime;
      _selectedDayCode = dayCode;
      _isDayExpanded = true;
    });

    await _dayExpansionController.forward();
  }

  /// Convierte número de día de semana a código
  String _getDayOfWeekCode(int weekday) {
    const codes = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return codes[(weekday - 1) % 7];
  }

// ============================================================================
// 3.4. INTERFAZ DE USUARIO PRINCIPAL
// ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: CustomScrollView(
        slivers: [
          // App bar flotante
          SliverAppBar(
            title: Text(
              '${widget.monthInfo.name} ${widget.monthInfo.year}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: widget.monthInfo.color,
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.monthInfo.color,
                      widget.monthInfo.color.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () {
                if (_isDayExpanded) {
                  _collapseDay();
                } else if (_isWeekExpanded) {
                  _collapseWeek();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          // Calendario mensual dinámico
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: _buildOrganicCalendar(),
            ),
          ),
        ],
      ),
    );
  }

// ============================================================================
// 3.5. CONSTRUCCIÓN DEL CALENDARIO ORGÁNICO (MEJORADO CON INFORMACIÓN EXPANDIBLE)
// ============================================================================

  /// Construye el widget principal del calendario del mes.
  ///
  /// Este método organiza la disposición de la leyenda de colores, la cabecera
  /// de los días de la semana y el contenido dinámico del calendario.
  Widget _buildOrganicCalendar() {
    final days = AcademicCalendar.getMonthDays(
        widget.monthInfo.month, widget.monthInfo.year);
    final sesiones = ref.watch(horarioProvider);

    // Prepara las filas del calendario para su renderización.
    _prepareCalendarRows(days);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDayTypeLegend(),
            const SizedBox(height: 12),
            _buildWeekHeader(),
            const SizedBox(height: 16),
            _buildDynamicCalendarContent(sesiones),
            if (_festivosLoaded) _buildExpandableMonthInfo(),
          ],
        ),
      ),
    );
  }

  /// Construye la leyenda de colores que identifica los tipos de días.
  Widget _buildDayTypeLegend() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          _buildLegendItem(
              'Laborable', _dayTypeColors['laborable']!, Colors.grey[800]!),
          _buildLegendItem('F. Nacional', _dayTypeColors['festivoNacional']!,
              Colors.red[800]!),
          _buildLegendItem('F. Regional', _dayTypeColors['festivoRegional']!,
              Colors.orange[800]!),
          _buildLegendItem('Libre Disp.', _dayTypeColors['libreDisposicion']!,
              Colors.purple[800]!),
          _buildLegendItem(
              'Fin Semana', _dayTypeColors['finDeSemana']!, Colors.grey[600]!),
        ],
      ),
    );
  }

  /// Construye un item individual para la leyenda de colores
  Widget _buildLegendItem(
      String label, Color backgroundColor, Color textColor) {
    final bool isLibreDisposicion = label == 'Libre Disp.';

    if (isLibreDisposicion) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.purple[100]!.withOpacity(0.3),
              Colors.purple[200]!.withOpacity(0.5),
              Colors.purple[100]!.withOpacity(0.3),
            ],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.purple[400]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.purple[800]!,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.grey[400]!,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  /// Construye la cabecera de la semana con las iniciales de los días (L, M, X...).
  Widget _buildWeekHeader() {
    const dayNames = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final dayColors = [
      Colors.blue[700]!, // L
      Colors.blue[700]!, // M
      Colors.blue[700]!, // X
      Colors.blue[700]!, // J
      Colors.blue[700]!, // V
      Colors.grey[600]!, // S
      Colors.grey[600]!, // D
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: dayNames.asMap().entries.map((entry) {
          final index = entry.key;
          final day = entry.value;
          return Expanded(
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: dayColors[index],
                fontSize: 14,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Construye el cuerpo del calendario, que maneja las animaciones de expansión.
  ///
  /// Renderiza las filas del calendario y gestiona la inserción animada de
  /// la vista semanal o diaria cuando se selecciona una fila o un día.
  Widget _buildDynamicCalendarContent(List<SesionHorario> sesiones) {
    if (_calendarRows.isEmpty) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      child: Column(
        children: [
          // Filas superiores (antes de la semana expandida)
          if (_selectedWeekRow != null)
            ..._buildCalendarRowsRange(sesiones, 0, _selectedWeekRow!),

          // Fila seleccionada
          if (_selectedWeekRow != null)
            _buildCalendarRowWidget(
                _calendarRows[_selectedWeekRow!], _selectedWeekRow!, sesiones),

          // Vista semanal expandida (se inserta dinámicamente)
          if (_isWeekExpanded)
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              height: _expansionController.value * 500,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _expansionController.value,
                child: _buildInsertedWeeklyView(),
              ),
            ),

          // NUEVO: Vista diaria expandida (se inserta después de la semanal)
          if (_isDayExpanded && _isWeekExpanded)
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              height: _dayExpansionController.value *
                  600, // Altura para vista diaria completa
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _dayExpansionController.value,
                child: _buildDailyExpandedView(),
              ),
            ),

          // Filas inferiores (después de las expansiones)
          if (_selectedWeekRow != null)
            ..._buildCalendarRowsRange(
                sesiones, _selectedWeekRow! + 1, _calendarRows.length),

          // Si no hay semana expandida, mostrar todas las filas normalmente
          if (!_isWeekExpanded)
            ..._buildCalendarRowsRange(sesiones, 0, _calendarRows.length),
        ],
      ),
    );
  }

  /// Construye una sección expandible con información resumen del mes.
  ///
  /// Muestra el total de festivos y días de libre disposición y permite
  /// expandir para ver una lista detallada.
  Widget _buildExpandableMonthInfo() {
    final currentMonthFestivos = <MapEntry<DateTime, String>>[];
    final currentYear = widget.monthInfo.year;
    final currentMonth = widget.monthInfo.month;

    // Recopilar festivos del mes actual
    _festivosNacionales.entries
        .where((entry) =>
            entry.key.year == currentYear && entry.key.month == currentMonth)
        .forEach((entry) => currentMonthFestivos.add(entry));

    _festivosRegionales.entries
        .where((entry) =>
            entry.key.year == currentYear && entry.key.month == currentMonth)
        .forEach((entry) => currentMonthFestivos.add(entry));

    // Obtener días de libre disposición del mes
    final diasLibreMes = _diasLibreDisposicion
        .where((date) => date.year == currentYear && date.month == currentMonth)
        .toList();

    // Total de días especiales
    final totalDiasEspeciales =
        currentMonthFestivos.length + diasLibreMes.length;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: ExpansionTile(
        initiallyExpanded: false,
        backgroundColor: Colors.blue[25],
        collapsedBackgroundColor: Colors.blue[25],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.blue[200]!, width: 1),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.blue[200]!, width: 1),
        ),
        leading: Icon(Icons.calendar_month, size: 20, color: Colors.blue[700]),
        title: Text(
          'Información de ${widget.monthInfo.name}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
        subtitle: Text(
          totalDiasEspeciales == 0
              ? 'Sin días especiales • Toca para gestionar'
              : '$totalDiasEspeciales día${totalDiasEspeciales > 1 ? 's' : ''} especial${totalDiasEspeciales > 1 ? 'es' : ''} • Toca para detalles',
          style: TextStyle(
            fontSize: 11,
            color: Colors.blue[600],
            fontStyle: FontStyle.italic,
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Resumen rápido con estadísticas
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[100]!, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMonthStat(
                        'Festivos',
                        '${currentMonthFestivos.length}',
                        Icons.celebration,
                        Colors.orange[600]!,
                      ),
                      _buildMonthStat(
                        'Libre Disp.',
                        '${diasLibreMes.length}',
                        Icons.edit_calendar,
                        Colors.purple[600]!,
                      ),
                      _buildMonthStat(
                        'Total',
                        '$totalDiasEspeciales',
                        Icons.event_busy,
                        Colors.grey[700]!,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Botón para gestión rápida del mes
                Center(
                  child: TextButton.icon(
                    onPressed: () => _showMonthManagementDialog(),
                    icon:
                        Icon(Icons.settings, size: 16, color: Colors.blue[700]),
                    label: Text(
                      'Gestionar días de ${widget.monthInfo.name}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.blue[50],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Mensaje para meses sin días especiales
                if (totalDiasEspeciales == 0) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Este mes no tiene festivos oficiales. Puedes añadir días de libre disposición usando el botón superior.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Lista detallada de festivos nacionales
                if (_festivosNacionales.entries
                    .where((entry) =>
                        entry.key.year == currentYear &&
                        entry.key.month == currentMonth)
                    .isNotEmpty) ...[
                  _buildMonthFestivosSection(
                    'Festivos Nacionales',
                    _festivosNacionales.entries
                        .where((entry) =>
                            entry.key.year == currentYear &&
                            entry.key.month == currentMonth)
                        .toList(),
                    Colors.red[600]!,
                    Icons.flag,
                  ),
                  const SizedBox(height: 12),
                ],

                // Lista detallada de festivos regionales
                if (_festivosRegionales.entries
                    .where((entry) =>
                        entry.key.year == currentYear &&
                        entry.key.month == currentMonth)
                    .isNotEmpty) ...[
                  _buildMonthFestivosSection(
                    'Festivos Regionales',
                    _festivosRegionales.entries
                        .where((entry) =>
                            entry.key.year == currentYear &&
                            entry.key.month == currentMonth)
                        .toList(),
                    Colors.orange[600]!,
                    Icons.location_on,
                  ),
                  const SizedBox(height: 12),
                ],

                // Lista de días de libre disposición
                if (diasLibreMes.isNotEmpty) ...[
                  _buildLibreDisposicionMonthSection(diasLibreMes),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Construye un widget para mostrar una estadística individual del mes.
  Widget _buildMonthStat(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// Construye una sección visual para listar los festivos de un tipo concreto.
  Widget _buildMonthFestivosSection(
    String titulo,
    List<MapEntry<DateTime, String>> festivos,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                '$titulo (${festivos.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...festivos.map((entry) {
            final fecha = entry.key;
            final nombre = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withOpacity(0.2), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '${fecha.day}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        Text(
                          _getDayNameFromWeekday(fecha.weekday),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showDayConfigModal(fecha),
                    icon: Icon(Icons.more_vert,
                        size: 16, color: Colors.grey[500]),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// Construye la sección que lista los días de libre disposición del mes.
  Widget _buildLibreDisposicionMonthSection(List<DateTime> diasLibreMes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_calendar, size: 16, color: Colors.purple[700]),
              const SizedBox(width: 6),
              Text(
                'Días de Libre Disposición (${diasLibreMes.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: diasLibreMes.map((fecha) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purple[300]!, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${fecha.day}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getDayNameFromWeekday(fecha.weekday),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.purple[600],
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _toggleLibreDisposicion(fecha),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.purple[600],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Muestra un diálogo para gestionar los días especiales del mes.
  void _showMonthManagementDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.calendar_month, color: widget.monthInfo.color),
              const SizedBox(width: 8),
              Text('Gestión de ${widget.monthInfo.name}'),
            ],
          ),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.add_circle, color: Colors.purple[600]),
                  title: const Text('Añadir Libre Disposición'),
                  subtitle: const Text('Marcar días como no lectivos'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showDayPickerDialog();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.celebration, color: Colors.orange[600]),
                  title: const Text('Añadir Festivo Regional'),
                  subtitle: const Text('Crear festivo específico del mes'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showDayPickerForFestivoDialog();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  /// Muestra un diálogo con un Grid para seleccionar múltiples días de libre disposición.
  void _showDayPickerDialog() {
    final daysInMonth = AcademicCalendar.getMonthDays(
        widget.monthInfo.month, widget.monthInfo.year);
    Set<DateTime> selectedDays = {};

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Seleccionar días - ${widget.monthInfo.name}'),
              content: SizedBox(
                width: 350,
                height: 400,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: daysInMonth.length,
                  itemBuilder: (context, index) {
                    final day = daysInMonth[index];
                    final isSelected = selectedDays.contains(day);
                    final isLibreDisposicion =
                        _getDayType(day) == 'libreDisposicion';

                    return InkWell(
                      onTap: () {
                        setDialogState(() {
                          if (isSelected) {
                            selectedDays.remove(day);
                          } else {
                            selectedDays.add(day);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.purple[600]
                              : isLibreDisposicion
                                  ? Colors.purple[100]
                                  : Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isSelected
                                ? Colors.purple[800]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : isLibreDisposicion
                                      ? Colors.purple[800]
                                      : Colors.black87,
                              fontWeight: isSelected || isLibreDisposicion
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: selectedDays.isEmpty
                      ? null
                      : () {
                          for (final day in selectedDays) {
                            _toggleLibreDisposicion(day);
                          }
                          // Forzar actualización inmediata de la UI
                          setState(() {});

                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${selectedDays.length} día${selectedDays.length > 1 ? 's' : ''} actualizado${selectedDays.length > 1 ? 's' : ''}',
                              ),
                              backgroundColor: Colors.purple[600],
                            ),
                          );
                        },
                  child: Text('Aplicar (${selectedDays.length})'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Muestra un diálogo para seleccionar un único día para marcarlo como festivo.
  void _showDayPickerForFestivoDialog() {
    final daysInMonth = AcademicCalendar.getMonthDays(
        widget.monthInfo.month, widget.monthInfo.year);
    DateTime? selectedDay;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                  'Seleccionar día para festivo - ${widget.monthInfo.name}'),
              content: SizedBox(
                width: 350,
                height: 300,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: daysInMonth.length,
                  itemBuilder: (context, index) {
                    final day = daysInMonth[index];
                    final isSelected = selectedDay == day;
                    final dayType = _getDayType(day);

                    return InkWell(
                      onTap: () {
                        setDialogState(() {
                          selectedDay = isSelected ? null : day;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.orange[600]
                              : dayType == 'festivoNacional'
                                  ? Colors.red[100]
                                  : dayType == 'festivoRegional'
                                      ? Colors.orange[100]
                                      : Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isSelected
                                ? Colors.orange[800]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: selectedDay == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _showAddCustomFestivoDialog(selectedDay!);
                        },
                  child: const Text('Continuar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Devuelve el nombre completo de un día de la semana a partir de su índice.
  String _getDayNameFromWeekday(int weekday) {
    const days = [
      '',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    return days[weekday];
  }

// ============================================================================
// 3.6. CONSTRUCCIÓN DE FILAS Y CELDAS DEL CALENDARIO
// ============================================================================

  /// Prepara las filas del calendario para su renderización.
  ///
  /// Calcula el padding inicial y final para que el mes comience en el día
  /// de la semana correcto y divide la lista de días en filas de 7.
  void _prepareCalendarRows(List<DateTime> days) {
    final firstDay = days.first;
    final startPadding = (firstDay.weekday - 1) % 7;
    final totalCells = startPadding + days.length;
    final endPadding = (7 - (totalCells % 7)) % 7;

    final allCells = <DateTime?>[]
      ..addAll(List.filled(startPadding, null))
      ..addAll(days)
      ..addAll(List.filled(endPadding, null));

    // Dividir en filas de 7 días
    _calendarRows = [];
    for (int i = 0; i < allCells.length; i += 7) {
      _calendarRows.add(allCells.sublist(i, (i + 7).clamp(0, allCells.length)));
    }
  }

  /// Construye un rango de filas del calendario.
  ///
  /// Utilizado para renderizar las filas por encima y por debajo de la semana
  /// que se expande.
  List<Widget> _buildCalendarRowsRange(
      List<SesionHorario> sesiones, int start, int end) {
    List<Widget> rows = [];
    for (int i = start; i < end; i++) {
      if (i < _calendarRows.length) {
        rows.add(_buildCalendarRowWidget(_calendarRows[i], i, sesiones));
      }
    }
    return rows;
  }

  /// Construye el widget para una fila individual del calendario.
  Widget _buildCalendarRowWidget(
      List<DateTime?> row, int rowIndex, List<SesionHorario> sesiones) {
    return Container(
      height: 55, // AUMENTADA ligeramente para mejor legibilidad
      margin: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: row.map((day) {
          if (day == null) {
            return const Expanded(child: SizedBox(height: 55));
          }

          return Expanded(
            child: _buildDayCell(day, sesiones),
          );
        }).toList(),
      ),
    );
  }

  /// Construye la celda individual para un día del calendario.
  ///
  /// Gestiona la apariencia de la celda basándose en si es festivo, fin de
  /// semana, día de libre disposición, si tiene contenido académico o si es hoy.
  Widget _buildDayCell(DateTime day, List<SesionHorario> sesiones) {
    final hasContent = _hasContentOnDay(sesiones, day);
    final isSelected = _selectedDay?.day == day.day;
    final isInExpandedWeek =
        _expandedWeekDays?.any((d) => d.day == day.day) ?? false;

    final dayType = _getDayType(day);
    final dayColor = _getDayColor(day);
    final festivoName = _getFestivoName(day);
    final isToday = _isToday(day);

    Widget cellContent = InkWell(
      onTap: () => _expandWeek(day),
      onLongPress: () =>
          _showDayConfigModal(day), // NUEVO: configuración con long press
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 55,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: isSelected
              ? widget.monthInfo.color
              : isInExpandedWeek
                  ? widget.monthInfo.color.withOpacity(0.4)
                  : dayType == 'libreDisposicion'
                      ? Colors
                          .white // Fondo blanco para que se vea el patrón cebrado
                      : dayColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isToday
                ? widget.monthInfo.color
                : dayType == 'festivoNacional'
                    ? Colors.red[300]!
                    : dayType == 'festivoRegional'
                        ? Colors.orange[300]!
                        : dayType == 'libreDisposicion'
                            ? Colors.purple[300]!
                            : Colors.grey[300]!,
            width: isToday ? 2.5 : 1,
          ),
          boxShadow:
              (dayType != 'laborable' && dayType != 'finDeSemana') || isToday
                  ? [
                      BoxShadow(
                        color: isToday
                            ? widget.monthInfo.color.withOpacity(0.3)
                            : dayType == 'festivoNacional'
                                ? Colors.red.withOpacity(0.2)
                                : dayType == 'festivoRegional'
                                    ? Colors.orange.withOpacity(0.2)
                                    : Colors.purple.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
        ),
        child: Stack(
          children: [
            // Patrón cebrado como fondo para libre disposición
            if (dayType == 'libreDisposicion' &&
                !isSelected &&
                !isInExpandedWeek)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CustomPaint(
                    painter: StripedPainter(
                      color: Colors.purple.withOpacity(0.3),
                      stripeWidth: 2.0,
                      spacing: 3.0,
                    ),
                  ),
                ),
              ),

            // Contenido principal del día
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Número del día
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontWeight: isSelected || isToday
                          ? FontWeight.bold
                          : FontWeight.w600,
                      fontSize: isToday ? 16 : 14,
                      color: isSelected
                          ? Colors.white
                          : isToday
                              ? widget.monthInfo.color
                              : dayType == 'festivoNacional'
                                  ? Colors.red[800]
                                  : dayType == 'festivoRegional'
                                      ? Colors.orange[800]
                                      : dayType == 'libreDisposicion'
                                          ? Colors.purple[800]
                                          : Colors.black87,
                    ),
                  ),
                  // NUEVO: Indicador de festivo (texto pequeño)
                  if (festivoName != null && !isSelected)
                    Container(
                      constraints: const BoxConstraints(maxWidth: 35),
                      child: Text(
                        festivoName.length > 8
                            ? '${festivoName.substring(0, 8)}...'
                            : festivoName,
                        style: TextStyle(
                          fontSize: 7,
                          color: dayType == 'festivoNacional'
                              ? Colors.red[700]
                              : Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),

            // MODIFICADO: Indicadores en las esquinas
            // Indicador de contenido (esquina superior derecha)
            if (hasContent && !isSelected)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),

            // NUEVO: Indicador de libre disposición (esquina superior izquierda)
            if (dayType == 'libreDisposicion')
              Positioned(
                top: 3,
                left: 3,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.purple[600],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),

            // NUEVO: Indicador de hoy (esquina inferior izquierda)
            if (isToday)
              Positioned(
                bottom: 3,
                left: 3,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.monthInfo.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

            // NUEVO: Indicador de festivo (esquina inferior derecha)
            if ((dayType == 'festivoNacional' ||
                    dayType == 'festivoRegional') &&
                !isSelected)
              Positioned(
                bottom: 3,
                right: 3,
                child: Icon(
                  Icons.celebration,
                  size: 10,
                  color: dayType == 'festivoNacional'
                      ? Colors.red[600]
                      : Colors.orange[600],
                ),
              ),
          ],
        ),
      ),
    );

    return cellContent;
  }

  /// Verifica si una fecha corresponde al día actual.
  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

// ============================================================================
// 3.7. VISTA SEMANAL INSERTADA
// ============================================================================

  /// Vista semanal que se inserta orgánicamente en el calendario
  Widget _buildInsertedWeeklyView() {
    if (_expandedWeekDays == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.monthInfo.color.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título de la semana expandida
            Row(
              children: [
                Icon(
                  Icons.view_week,
                  color: widget.monthInfo.color,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Semana del ${_expandedWeekDays!.first.day} al ${_expandedWeekDays!.last.day}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _collapseWeek,
                  icon: const Icon(Icons.keyboard_arrow_up, size: 14),
                  label: const Text('Cerrar', style: TextStyle(fontSize: 10)),
                  style: TextButton.styleFrom(
                    foregroundColor: widget.monthInfo.color,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Vista compacta del horario semanal
            Expanded(
              child: _buildCompactWeeklyView(),
            ),
          ],
        ),
      ),
    );
  }

  /// Vista compacta del horario semanal insertado con popover de solo lectura
  Widget _buildCompactWeeklyView() {
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
    final weekDays = ['L', 'M', 'X', 'J', 'V'];
    final userId = _getFirestoreService().currentUserId ?? 'local';

    return Column(
      children: [
        // Header compacto con días clickeables
        SizedBox(
          height: 20,
          child: Row(
            children: [
              const SizedBox(width: 35),
              ...weekDays
                  .map((day) => Expanded(
                        child: InkWell(
                          onTap: () => _expandDay(day),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: _selectedDayCode == day
                                  ? widget.monthInfo.color.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              day,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: _selectedDayCode == day
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 10,
                                color: _selectedDayCode == day
                                    ? widget.monthInfo.color
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                      ))
                  .toList(), // ✅ CORREGIDO: Añadido .toList()
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Horario compacto con celdas clickeables modificado
        Expanded(
          child: Column(
            children: timeSlots.map((time) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 35,
                        child: Text(
                          time,
                          style: const TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      ...weekDays.map((day) {
                        // Obtener la fecha correspondiente al día de la semana
                        final fechaDia = _expandedWeekDays?.firstWhere(
                          (date) => _getDayOfWeekCode(date.weekday) == day,
                          orElse: () => DateTime.now(),
                        );

                        // Generar ID único para la sesión - ✅ CORREGIDO: Manejo de nulos
                        final sesionIdBuscado = fechaDia != null
                            ? _generateSesionId(fechaDia, time, userId)
                            : '';

                        // ✅ CORRECCIÓN CRÍTICA: Validación de sesionIdBuscado
                        final sesion = sesiones.firstWhere(
                          (s) =>
                              s.sesionId == sesionIdBuscado &&
                              sesionIdBuscado
                                  .isNotEmpty, // ← Validación añadida
                          orElse: () => SesionHorario(
                            id: sesionIdBuscado.isNotEmpty
                                ? sesionIdBuscado.hashCode
                                : '${day}_$time'
                                    .hashCode, // ← ID alternativo seguro
                            dia: day,
                            hora: time,
                            sesionId: sesionIdBuscado.isNotEmpty
                                ? sesionIdBuscado
                                : '${day}_$time', // ← ID seguro
                            docenteId: 0,
                            userId: userId,
                          ),
                        );

                        // Verificar si la celda tiene contenido
                        final bool tieneContenido = sesion.materia != null ||
                            (sesion.actividad != null &&
                                sesion.actividad!.isNotEmpty) ||
                            (sesion.notas != null &&
                                sesion.notas!.isNotEmpty) ||
                            sesion.esExamen;

                        return Expanded(
                          child: Builder(
                            builder: (context) {
                              return InkWell(
                                // Comportamiento condicional según contenido
                                onTap: () {
                                  if (tieneContenido) {
                                    // Si tiene contenido → mostrar popover de solo lectura
                                    _showReadOnlySessionPopover(
                                        context, sesion);
                                  } else {
                                    // Si no tiene contenido → expandir día como antes
                                    _expandDay(day);
                                  }
                                },
                                borderRadius: BorderRadius.circular(3),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 0.5),
                                  decoration: BoxDecoration(
                                    color: sesion.materia?.color
                                            ?.withOpacity(0.8) ??
                                        Colors.grey[100],
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: tieneContenido
                                          ? Colors.blue[300]!
                                          : Colors.grey[300]!,
                                      width: tieneContenido ? 1.0 : 0.3,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(1),
                                    child: Stack(
                                      children: [
                                        // Contenido principal
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (sesion.materia != null)
                                              Text(
                                                sesion.materia!.nombre,
                                                style: const TextStyle(
                                                  fontSize: 6,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                            // NUEVO: Mostrar curso debajo de la materia
                                            if (sesion.curso != null &&
                                                sesion.curso!.isNotEmpty)
                                              Text(
                                                sesion.curso!,
                                                style: const TextStyle(
                                                  fontSize: 5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF6B7280),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                            if (sesion.actividad != null &&
                                                sesion.actividad!.isNotEmpty)
                                              Text(
                                                sesion.actividad!,
                                                style: const TextStyle(
                                                  fontSize: 5,
                                                  color: Color(0xFF6B7280),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                          ],
                                        ),

                                        // Indicadores visuales
                                        // Indicador de examen (esquina superior izquierda)
                                        if (sesion.esExamen)
                                          Positioned(
                                            top: 1,
                                            left: 1,
                                            child: Container(
                                              width: 6,
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),

                                        // Indicador de notas (esquina inferior izquierda)
                                        if (sesion.notas != null &&
                                            sesion.notas!.isNotEmpty)
                                          const Positioned(
                                            bottom: 1,
                                            left: 1,
                                            child: Icon(
                                              Icons.notes,
                                              size: 6,
                                              color: Colors.black54,
                                            ),
                                          ),

                                        // Indicador de que es clickeable para ver más (esquina superior derecha)
                                        if (tieneContenido)
                                          Positioned(
                                            top: 1,
                                            right: 1,
                                            child: Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: Colors.blue[600],
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(), // ✅ CORREGIDO: Añadido .toList()
                    ],
                  ),
                ),
              );
            }).toList(), // ✅ CORREGIDO: Añadido .toList()
          ),
        ),
      ],
    );
  }

// ============================================================================
// NUEVO MÉTODO AÑADIDO: POPOVER DE SOLO LECTURA
// ============================================================================

  void _showReadOnlySessionPopover(BuildContext context, SesionHorario sesion) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black26,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: _buildSessionPopoverContent(sesion),
        );
      },
    );
  }

  Widget _buildSessionPopoverContent(SesionHorario sesion) {
    String getDayNameFromCode(String dayCode) {
      const dayNames = {
        'L': 'Lunes',
        'M': 'Martes',
        'X': 'Miércoles',
        'J': 'Jueves',
        'V': 'Viernes',
      };
      return dayNames[dayCode] ?? dayCode;
    }

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 380,
        maxHeight: 600,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.3),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  sesion.materia?.color?.withOpacity(0.3) ?? Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header fijo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sesion.materia?.color?.withOpacity(0.1) ??
                      Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: sesion.materia?.color ?? Colors.grey[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${getDayNameFromCode(sesion.dia)} ${sesion.hora}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: sesion.materia?.color ?? Colors.grey[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (sesion.esExamen)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.alarm, size: 12, color: Colors.red[700]),
                            const SizedBox(width: 2),
                            Text(
                              'EXAMEN',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Contenido scrolleable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sesion.materia != null) ...[
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: sesion.materia!.color,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: sesion.materia!.color.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              sesion.materia!.nombre,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (sesion.curso != null && sesion.curso!.isNotEmpty) ...[
                        _buildPopoverInfoRow(
                          icon: Icons.school,
                          title: 'Curso',
                          content: sesion.curso!,
                          color: Colors.blue[600]!,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (sesion.actividad != null &&
                          sesion.actividad!.isNotEmpty) ...[
                        _buildPopoverInfoRow(
                          icon: Icons.assignment,
                          title: 'Actividad',
                          content: sesion.actividad!,
                          color: Colors.green[600]!,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (sesion.notas != null && sesion.notas!.isNotEmpty) ...[
                        _buildPopoverInfoRow(
                          icon: Icons.notes,
                          title: 'Notas',
                          content: sesion.notas!,
                          color: Colors.orange[600]!,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (sesion.materia == null &&
                          (sesion.actividad == null ||
                              sesion.actividad!.isEmpty) &&
                          (sesion.notas == null || sesion.notas!.isEmpty) &&
                          !sesion.esExamen) ...[
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.event_available,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Hora libre',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Footer fijo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text(
                      'Cerrar',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopoverInfoRow({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// ============================================================================
// 3.8. VISTA DIARIA EXPANDIDA (NUEVA)
// ============================================================================

  /// Vista diaria expandida que se inserta después de la vista semanal
  Widget _buildDailyExpandedView() {
    if (_selectedDayCode == null) return const SizedBox.shrink();

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

    // Obtener el nombre completo del día
    final dayNames = {
      'L': 'Lunes',
      'M': 'Martes',
      'X': 'Miércoles',
      'J': 'Jueves',
      'V': 'Viernes',
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[25],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.monthInfo.color.withOpacity(0.4),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título de la vista diaria
            Row(
              children: [
                Icon(
                  Icons.today,
                  color: widget.monthInfo.color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${dayNames[_selectedDayCode]} ${_selectedDayForExpansion?.day ?? ''} - Horario Completo',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _collapseDay,
                  icon: const Icon(Icons.keyboard_arrow_up, size: 16),
                  label:
                      const Text('Cerrar Día', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: widget.monthInfo.color,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Horario diario expandido
            Expanded(
              child: _buildDailyScheduleView(sesiones, timeSlots),
            ),
          ],
        ),
      ),
    );
  }

  /// Vista del horario diario con información detallada
  Widget _buildDailyScheduleView(
      List<SesionHorario> sesiones, List<String> timeSlots) {
    return ListView.builder(
      itemCount: timeSlots.length,
      itemBuilder: (context, index) {
        final time = timeSlots[index];
        final sesion = sesiones.firstWhere(
          (s) => s.dia == _selectedDayCode && s.hora == time,
          orElse: () => SesionHorario(
            id: 0,
            dia: _selectedDayCode!,
            hora: time,
            sesionId: '',
            docenteId: 0,
            userId: 'local',
          ),
        );

        final hasContent = sesion.materia != null ||
            sesion.actividad != null ||
            sesion.notas != null;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasContent
                  ? (sesion.materia?.color ?? Colors.blue[300]!)
                  : Colors.grey[300]!,
              width: hasContent ? 2 : 1,
            ),
            boxShadow: hasContent
                ? [
                    BoxShadow(
                      color: (sesion.materia?.color ?? Colors.blue)
                          .withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hora
                Container(
                  width: 60,
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: hasContent
                        ? (sesion.materia?.color?.withOpacity(0.2) ??
                            Colors.blue[100])
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: hasContent
                          ? (sesion.materia?.color ?? Colors.blue[800])
                          : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                // Contenido de la sesión
                Expanded(
                  child: hasContent
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Materia y curso - MODIFICADO
                            if (sesion.materia != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sesion.materia!.nombre,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  // NUEVO: Curso debajo de la materia
                                  if (sesion.curso != null &&
                                      sesion.curso!.isNotEmpty)
                                    Text(
                                      sesion.curso!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            const SizedBox(height: 6),
                            // Actividad
                            if (sesion.actividad != null &&
                                sesion.actividad!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.assignment,
                                      size: 14,
                                      color: Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        sesion.actividad!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF4B5563),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Notas
                            if (sesion.notas != null &&
                                sesion.notas!.isNotEmpty)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.notes,
                                    size: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      sesion.notas!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6B7280),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            // Indicador de examen - MOVIDO aquí
                            if (sesion.esExamen)
                              Row(
                                children: [
                                  Icon(
                                    Icons.alarm,
                                    size: 14,
                                    color: Colors.red[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Examen',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        )
                      : const Text(
                          'Hora libre',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

// ============================================================================
// 3.9. MÉTODOS AUXILIARES
// ============================================================================

  /// Obtiene el servicio de Firestore
  FirestoreService _getFirestoreService() {
    return FirestoreService();
  }

  /// Genera el ID de sesión igual que en el controlador
  String _generateSesionId(DateTime fecha, String hora, String userId) {
    final fechaKey = "${fecha.year.toString().padLeft(4, '0')}-"
        "${fecha.month.toString().padLeft(2, '0')}-"
        "${fecha.day.toString().padLeft(2, '0')}";
    return "${fechaKey}_${hora}_${userId}";
  }

  /// Verifica si hay contenido en un día específico
  bool _hasContentOnDay(List<SesionHorario> sesiones, DateTime day) {
    final fechaKey = "${day.year.toString().padLeft(4, '0')}-"
        "${day.month.toString().padLeft(2, '0')}-"
        "${day.day.toString().padLeft(2, '0')}";

    return sesiones.any((s) =>
        s.sesionId.startsWith(fechaKey) &&
        (s.materia != null || s.actividad != null || s.notas != null));
  }

  /// Widget que crea un patrón cebrado diagonal
  Widget _buildStripedPattern({
    required Color color,
    required Widget child,
    double stripeWidth = 3.0,
    double spacing = 3.0,
  }) {
    return CustomPaint(
      painter: StripedPainter(
        color: color.withOpacity(0.4),
        stripeWidth: stripeWidth,
        spacing: spacing,
      ),
      child: child,
    );
  }

// ============================================================================
// 3.10. CONFIGURACIÓN DE DÍAS
// ============================================================================

  /// Modal avanzado para configurar días especiales
  void _showAdvancedDayConfig(DateTime day) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dayType = _getDayType(day);
            final festivoName = _getFestivoName(day);
            final isLibreDisposicion = dayType == 'libreDisposicion';

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.calendar_today,
                      color: widget.monthInfo.color, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Configurar ${day.day}/${day.month}/${day.year}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Estado actual del día
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getDayColor(day),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estado actual:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getDayTypeColor(dayType),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getDayTypeDisplayName(dayType),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (festivoName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Festivo: $festivoName',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Opciones de configuración
                    Text(
                      'Acciones disponibles:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Toggle libre disposición
                    ListTile(
                      leading: Icon(
                        isLibreDisposicion
                            ? Icons.remove_circle_outline
                            : Icons.add_circle_outline,
                        color: Colors.purple[600],
                      ),
                      title: Text(
                        isLibreDisposicion
                            ? 'Quitar libre disposición'
                            : 'Marcar como libre disposición',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        isLibreDisposicion
                            ? 'Este día volverá a su estado original'
                            : 'Marcará este día como no lectivo por decisión del centro',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      onTap: () {
                        _toggleLibreDisposicion(day);
                        setDialogState(() {}); // Refresh dialog
                        setState(() {}); // Refresh main UI
                      },
                    ),

                    const Divider(),

                    // Gestión de festivos personalizados
                    if (dayType == 'laborable' || dayType == 'finDeSemana')
                      ListTile(
                        leading:
                            Icon(Icons.celebration, color: Colors.orange[600]),
                        title: const Text('Añadir festivo regional'),
                        subtitle: const Text(
                            'Crear un festivo regional para este día'),
                        onTap: () {
                          Navigator.of(context).pop();
                          _showAddCustomFestivoDialog(day);
                        },
                      ),

                    // Eliminar festivo personalizado (solo si es regional y personalizado)
                    if (_isCustomRegionalFestivo(day))
                      ListTile(
                        leading:
                            Icon(Icons.delete_outline, color: Colors.red[600]),
                        title: const Text('Eliminar festivo personalizado'),
                        subtitle:
                            const Text('Quitar este festivo regionalizado'),
                        onTap: () {
                          _removeCustomFestivo(day);
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
                if (dayType != 'laborable' && dayType != 'finDeSemana')
                  TextButton(
                    onPressed: () {
                      _showDayInfoDialog(day);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Ver Info'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Diálogo para añadir festivo regional personalizado
  void _showAddCustomFestivoDialog(DateTime day) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
              'Añadir Festivo Regional - ${day.day}/${day.month}/${day.year}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Solo se pueden crear festivos regionales personalizados.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del festivo regional',
                  hintText: 'Ej: Fiesta patronal del municipio',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  // Trigger rebuild to update button state
                  (context as Element).markNeedsBuild();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: nameController.text.trim().isEmpty
                  ? null
                  : () {
                      _addCustomFestivo(day, nameController.text.trim(), true);
                      Navigator.of(context).pop();
                    },
              child: const Text('Añadir'),
            ),
          ],
        );
      },
    );
  }

  /// Diálogo informativo sobre el día
  void _showDayInfoDialog(DateTime day) {
    final dayType = _getDayType(day);
    final festivoName = _getFestivoName(day);
    final sesiones = ref.watch(horarioProvider);
    final hasContent = _hasContentOnDay(sesiones, day);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: widget.monthInfo.color),
              const SizedBox(width: 8),
              Text('Info ${day.day}/${day.month}'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Tipo de día', _getDayTypeDisplayName(dayType)),
              if (festivoName != null) _buildInfoRow('Festivo', festivoName),
              _buildInfoRow('Fecha completa',
                  '${_getDayName(day.weekday)}, ${day.day} de ${_getMonthName(day.month)} de ${day.year}'),
              _buildInfoRow('Contenido académico',
                  hasContent ? 'Sí (tiene clases programadas)' : 'No'),
              if (_isToday(day)) _buildInfoRow('Especial', 'Es el día de hoy'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  /// Widget helper para mostrar información en filas
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  /// Añadir festivo personalizado
  void _addCustomFestivo(DateTime day, String name, bool isRegional) {
    final normalizedDay = DateTime(day.year, day.month, day.day);

    setState(() {
      if (isRegional) {
        _festivosRegionales[normalizedDay] = name;
      } else {
        _festivosNacionales[normalizedDay] = name;
      }
    });

    _saveFestivosToStorage();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Festivo "$name" añadido correctamente'),
        backgroundColor: Colors.green[600],
      ),
    );
  }

  /// Eliminar festivo personalizado
  void _removeCustomFestivo(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);

    setState(() {
      _festivosRegionales.remove(normalizedDay);
      _festivosNacionales.remove(normalizedDay);
    });

    _saveFestivosToStorage();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Festivo eliminado correctamente'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  /// Verificar si es un festivo regional personalizado (no por defecto)
  bool _isCustomRegionalFestivo(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);

    // Lista de festivos regionales por defecto (no personalizados)
    final defaultRegionalFestivos = {
      DateTime(day.year, 4, 23), // Sant Jordi
      DateTime(day.year, 6, 24), // Sant Joan
      DateTime(day.year, 9, 11), // Diada Nacional de Cataluña
      DateTime(day.year, 12, 26), // Sant Esteve
    };

    return _festivosRegionales.containsKey(normalizedDay) &&
        !defaultRegionalFestivos.contains(normalizedDay);
  }

  /// Obtener color según tipo de día
  Color _getDayTypeColor(String dayType) {
    const colors = {
      'laborable': Colors.white,
      'festivoNacional': Colors.red,
      'festivoRegional': Colors.orange,
      'libreDisposicion': Colors.purple,
      'finDeSemana': Colors.grey,
    };
    return colors[dayType] ?? Colors.grey;
  }

  /// Obtener nombre del día de la semana
  String _getDayName(int weekday) {
    const days = [
      '',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    return days[weekday];
  }

  /// Obtener nombre del mes
  String _getMonthName(int month) {
    const months = [
      '',
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    return months[month];
  }
}

// ============================================================================
// 4. PUNTO DE ENTRADA - REEMPLAZA LA PANTALLA MONTHLY ACTUAL
// ============================================================================

/// Pantalla principal que reemplaza completamente la monthly_planner_screen anterior
class MonthlyPlannerScreen extends StatelessWidget {
  const MonthlyPlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const YearViewScreen();
  }
}
