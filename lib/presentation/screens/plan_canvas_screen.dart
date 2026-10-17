// BANAAG Plan Canvas & Takeoff Screen (Interactive 2D Canvas with live 3D Drop Takeoff)

import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../domain/takeoff_engine.dart';
import '../../data/project_repository.dart';
import '../theme/banaag_theme.dart';

class PlanCanvasScreen extends StatefulWidget {
  final Project? project;
  const PlanCanvasScreen({super.key, this.project});

  @override
  State<PlanCanvasScreen> createState() => _PlanCanvasScreenState();
}

class _PlanCanvasScreenState extends State<PlanCanvasScreen> {
  late List<CanvasPoint> _points;
  late List<ConduitRoute> _routes;

  @override
  void initState() {
    super.initState();
    if (widget.project != null && widget.project!.canvasPoints.isNotEmpty) {
      _points = widget.project!.canvasPoints;
      _routes = widget.project!.conduitRoutes;
    } else if (widget.project != null && widget.project!.applianceLoads.isNotEmpty) {
      _autoGenerateFromAppliances(widget.project!.applianceLoads);
    } else {
      _points = [
        CanvasPoint(id: 'pt-1', type: 'PANEL', label: 'Main Panel (LP-1)', x: 60, y: 150),
        CanvasPoint(id: 'pt-2', type: 'SWITCH_1G', label: '1G Switch Living', x: 160, y: 150),
        CanvasPoint(id: 'pt-3', type: 'LIGHT', label: 'LED Drop Light', x: 260, y: 150),
        CanvasPoint(id: 'pt-4', type: 'OUTLET_DUPLEX', label: 'Duplex CO Master', x: 160, y: 260),
        CanvasPoint(id: 'pt-5', type: 'ACU', label: '2.0HP Inverter ACU', x: 280, y: 260),
      ];
      _routes = [
        ConduitRoute(id: 'rt-1', fromPointId: 'pt-1', toPointId: 'pt-2', measuredLengthMeters: 4.5),
        ConduitRoute(id: 'rt-2', fromPointId: 'pt-2', toPointId: 'pt-3', measuredLengthMeters: 3.2),
        ConduitRoute(id: 'rt-3', fromPointId: 'pt-1', toPointId: 'pt-4', measuredLengthMeters: 5.0),
        ConduitRoute(id: 'rt-4', fromPointId: 'pt-4', toPointId: 'pt-5', measuredLengthMeters: 4.8),
      ];
    }
  }

  void _autoGenerateFromAppliances(List<ApplianceItem> appliances) {
    _points = [
      CanvasPoint(id: 'pt-panel', type: 'PANEL', label: 'Main Panel (LP-1)', x: 60, y: 150),
    ];
    _routes = [];

    double curX = 160.0;
    double curY = 100.0;
    int index = 1;

    for (final app in appliances) {
      for (int i = 0; i < app.quantity; i++) {
        final id = 'pt-$index';
        String pointType = 'OUTLET_DUPLEX';
        if (app.name.toLowerCase().contains('aircon')) {
          pointType = 'ACU';
        } else if (app.name.toLowerCase().contains('light') || app.name.toLowerCase().contains('fan')) {
          pointType = 'LIGHT';
        } else if (app.name.toLowerCase().contains('switch')) {
          pointType = 'SWITCH_1G';
        }

        _points.add(CanvasPoint(
          id: id,
          type: pointType,
          label: '${app.name} #${i + 1}',
          x: curX,
          y: curY,
          circuitNumber: app.isDedicatedCircuit ? index : 1,
        ));

        // Route from Panel or previous point
        final fromId = app.isDedicatedCircuit ? 'pt-panel' : (_points.length > 2 ? _points[_points.length - 2].id : 'pt-panel');
        _routes.add(ConduitRoute(
          id: 'rt-$index',
          fromPointId: fromId,
          toPointId: id,
          measuredLengthMeters: app.isDedicatedCircuit ? 8.5 : 4.0,
        ));

        curX += 90.0;
        if (curX > 320.0) {
          curX = 140.0;
          curY += 75.0;
        }
        index++;
      }
    }
  }

  String _selectedTool = 'OUTLET_DUPLEX';

  void _addPointAt(TapUpDetails details) {
    setState(() {
      final newId = 'pt-${_points.length + 1}';
      _points.add(CanvasPoint(
        id: newId,
        type: _selectedTool,
        label: 'Device ${_points.length + 1}',
        x: details.localPosition.dx,
        y: details.localPosition.dy,
      ));

      // Auto-route from last point
      if (_points.length > 1) {
        _routes.add(ConduitRoute(
          id: 'rt-${_routes.length + 1}',
          fromPointId: _points[_points.length - 2].id,
          toPointId: newId,
          measuredLengthMeters: 3.5, // Standard estimated run
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final takeoff = TakeoffEngine.calculate(points: _points, routes: _routes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📐 Plan Canvas & Auto-Takeoff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: BanaagTheme.primaryAmber),
            tooltip: 'Import AutoCAD .DXF / Blueprint Image',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('⚡ Dual-Engine: Ready to parse AutoCAD .DXF / PDF Plan!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: BanaagTheme.successGreen),
            tooltip: 'Lock Contract Amount from Takeoff',
            onPressed: () {
              if (widget.project != null) {
                setState(() {
                  widget.project!.contractAmount = takeoff.grandTotalEstimatedCost;
                  widget.project!.canvasPoints = _points;
                  widget.project!.conduitRoutes = _routes;
                  // Advance to Permitting (Stage 2)
                  if (widget.project!.currentPhaseNumber < 2) {
                    widget.project!.currentPhaseNumber = 2;
                  }
                  ProjectRepository.instance.updateProject(widget.project!);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('⚡ Contract Amount officially locked at ₱${takeoff.grandTotalEstimatedCost.toStringAsFixed(0)}!')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('⚡ Takeoff Total: ₱${takeoff.grandTotalEstimatedCost.toStringAsFixed(0)}')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Takeoff Summary Live Ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF1B2028),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _metricMini('Total Wire', '${takeoff.totalThhnWireMeters.toStringAsFixed(0)} m', '(${takeoff.wireRollsCount.toStringAsFixed(1)} rolls)'),
                _metricMini('Conduit', '${takeoff.totalConduitMeters.toStringAsFixed(0)} m', '(${takeoff.totalPvcPipesPcs} pipes)'),
                _metricMini('Boxes', '${takeoff.utilityBoxesCount + takeoff.octagonalBoxesCount} pcs', '(${takeoff.conduitClampsCount} clamps)'),
                _metricMini('Estimated', '₱${takeoff.grandTotalEstimatedCost.toStringAsFixed(0)}', 'Mat+Labor', color: BanaagTheme.primaryAmber),
              ],
            ),
          ),

          // Interactive 2D Grid Canvas
          Expanded(
            child: GestureDetector(
              onTapUp: _addPointAt,
              child: Container(
                color: const Color(0xFF16191F),
                child: CustomPaint(
                  painter: CanvasPainter(points: _points, routes: _routes),
                  child: Container(),
                ),
              ),
            ),
          ),

          // Symbol Toolbar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            color: BanaagTheme.surfaceCard,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _symbolButton('PANEL', Icons.dashboard, 'Panel'),
                  _symbolButton('SWITCH_1G', Icons.toggle_on, '1G Switch'),
                  _symbolButton('LIGHT', Icons.lightbulb, 'Light'),
                  _symbolButton('OUTLET_DUPLEX', Icons.power, 'Duplex CO'),
                  _symbolButton('ACU', Icons.ac_unit, 'Aircon'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricMini(String label, String value, String sub, {Color color = BanaagTheme.textHighEmphasis}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 10)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(sub, style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 9)),
      ],
    );
  }

  Widget _symbolButton(String type, IconData icon, String label) {
    final bool isSelected = _selectedTool == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        selectedColor: BanaagTheme.primaryAmber,
        backgroundColor: const Color(0xFF262C38),
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.black : BanaagTheme.primaryAmber),
        label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12)),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedTool = type),
      ),
    );
  }
}

class CanvasPainter extends CustomPainter {
  final List<CanvasPoint> points;
  final List<ConduitRoute> routes;

  CanvasPainter({required this.points, required this.routes});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw Grid Lines
    final gridPaint = Paint()
      ..color = const Color(0xFF222733)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw Conduit Routes
    final routePaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (final r in routes) {
      final p1 = points.firstWhere((p) => p.id == r.fromPointId, orElse: () => points.first);
      final p2 = points.firstWhere((p) => p.id == r.toPointId, orElse: () => points.first);
      canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), routePaint);
    }

    // Draw Points
    for (final pt in points) {
      final pointPaint = Paint()..color = _getColorForType(pt.type);
      canvas.drawCircle(Offset(pt.x, pt.y), 12, pointPaint);

      // Border
      canvas.drawCircle(
        Offset(pt.x, pt.y),
        12,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Label
      final textSpan = TextSpan(
        text: pt.label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(pt.x - (textPainter.width / 2), pt.y + 14));
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'PANEL':
        return Colors.redAccent;
      case 'SWITCH_1G':
        return Colors.orangeAccent;
      case 'LIGHT':
        return Colors.yellowAccent;
      case 'OUTLET_DUPLEX':
        return Colors.lightBlueAccent;
      case 'ACU':
        return Colors.purpleAccent;
      default:
        return Colors.white;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
