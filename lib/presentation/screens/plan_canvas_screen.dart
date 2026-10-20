import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../domain/models.dart';
import '../../domain/takeoff_engine.dart';
import '../../domain/dxf_cad_engine.dart';
import '../../domain/institutional_building_presets.dart';
import '../../data/project_repository.dart';
import '../theme/banaag_theme.dart';
import '../widgets/dxf_export_guide_dialog.dart';
import '../widgets/room_dimension_input_dialog.dart';
import '../widgets/lighting_visualizer_modal.dart';
import '../widgets/raw_plan_calibration_modal.dart';

class PlanCanvasScreen extends StatefulWidget {
  final Project? project;
  const PlanCanvasScreen({super.key, this.project});

  @override
  State<PlanCanvasScreen> createState() => _PlanCanvasScreenState();
}

class _PlanCanvasScreenState extends State<PlanCanvasScreen> {
  late List<CanvasPoint> _points;
  late List<ConduitRoute> _routes;
  RoomGeometry? _roomGeometry;
  bool _isHeatmapVisible = false;
  String _selectedTool = 'SELECT';
  bool _isUnderlayVisible = true;
  final double _underlayOpacity = 0.78;
  String? _blueprintPath;
  bool _showLabels = true;
  bool _showConduits = true;
  CanvasPoint? _selectedPoint;
  CanvasPoint? _draggedPoint;
  Offset? _dragStartOffset;
  bool _hasMovedSignificantly = false;
  final TransformationController _zoomController = TransformationController();
  double _currentZoom = 1.0;

  // Room-Zone Ceiling Centers (strictly inside house walls [x: 68..230, y: 168..358])
  static const List<Offset> _roomCeilingAnchors = [
    Offset(74, 172),  // Bath ceiling
    Offset(105, 172), // Bath/Hall ceiling
    Offset(178, 172), // Bedroom 3 ceiling left
    Offset(222, 172), // Bedroom 3 ceiling right
    Offset(222, 206), // Bedroom 3 ceiling lower-right
    Offset(178, 206), // Bedroom 3 ceiling lower-left
    Offset(74, 212),  // Closet ceiling
    Offset(82, 262),  // Kitchen ceiling left
    Offset(118, 262), // Kitchen ceiling right
    Offset(178, 258), // Mid-hall/Stairs ceiling left
    Offset(222, 258), // Mid-hall/Stairs ceiling right
    Offset(222, 312), // Living Room ceiling upper-right
    Offset(178, 312), // Living Room ceiling upper-left
    Offset(118, 318), // Dining/Entry ceiling upper
    Offset(78, 318),  // Dining/Entry ceiling left
    Offset(78, 356),  // Entry ceiling lower-left
    Offset(118, 356), // Entry ceiling lower-right
    Offset(178, 356), // Living Room ceiling lower-left
    Offset(222, 356), // Living Room ceiling lower-right
  ];

  // Perimeter & Partition Wall Anchors ordered clockwise around the house ([x: 48..258, y: 156..386])
  static const List<Offset> _wallPerimeterAnchors = [
    Offset(52, 248),  // Kitchen left wall upper
    Offset(52, 212),  // Closet left wall
    Offset(52, 160),  // Bathroom top-left wall
    Offset(96, 156),  // Bathroom top wall
    Offset(124, 185), // Bathroom partition wall
    Offset(160, 156), // Bedroom 3 top-left wall
    Offset(208, 156), // Bedroom 3 top-mid wall
    Offset(256, 162), // Bedroom 3 top-right exterior wall (ACU/Outlet)
    Offset(256, 196), // Bedroom 3 right exterior wall
    Offset(256, 226), // Bedroom 3 lower-right wall
    Offset(256, 256), // Mid-right exterior wall
    Offset(256, 286), // Living/Stairs right exterior wall
    Offset(256, 318), // Living Room right exterior wall upper
    Offset(256, 350), // Living Room right exterior wall lower
    Offset(256, 382), // Living Room bottom-right corner wall
    Offset(212, 386), // Living Room bottom exterior wall
    Offset(165, 386), // Living Room bottom-mid wall
    Offset(124, 386), // Entry bottom wall right
    Offset(82, 386),  // Entry bottom wall left
    Offset(52, 376),  // Entry bottom-left corner wall
    Offset(52, 338),  // Dining/Kitchen lower-left wall
    Offset(132, 342), // Interior partition lower
    Offset(132, 292), // Kitchen counter partition lower
    Offset(132, 245), // Kitchen counter partition upper
  ];

  bool get _hasBlueprintFile =>
      _blueprintPath != null && _blueprintPath!.isNotEmpty && File(_blueprintPath!).existsSync();

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _roomGeometry = widget.project?.roomGeometry;
    _blueprintPath = widget.project?.blueprintImagePath;
    if (widget.project != null && widget.project!.canvasPoints.isNotEmpty) {
      _points = List<CanvasPoint>.from(widget.project!.canvasPoints);
      _routes = List<ConduitRoute>.from(widget.project!.conduitRoutes);
      _sanitizeAndFitExistingPointsIfNeeded();
    } else if (widget.project != null && widget.project!.applianceLoads.isNotEmpty) {
      _autoGenerateFromAppliances(widget.project!.applianceLoads);
    } else {
      _points = [
        CanvasPoint(id: 'pt-1', type: 'PANEL', label: 'MDP', x: 42, y: 285),
        CanvasPoint(id: 'pt-2', type: 'SWITCH_1G', label: 'S1-1', x: 110, y: 225),
        CanvasPoint(id: 'pt-3', type: 'LIGHT', label: 'L-1', x: 190, y: 225),
        CanvasPoint(id: 'pt-4', type: 'OUTLET_DUPLEX', label: 'CO-1', x: 140, y: 335),
        CanvasPoint(id: 'pt-5', type: 'ACU', label: 'ACU-1', x: 254, y: 170),
      ];
      _routes = [
        ConduitRoute(id: 'rt-1', fromPointId: 'pt-1', toPointId: 'pt-2', measuredLengthMeters: 4.5),
        ConduitRoute(id: 'rt-2', fromPointId: 'pt-2', toPointId: 'pt-3', measuredLengthMeters: 3.2),
        ConduitRoute(id: 'rt-3', fromPointId: 'pt-1', toPointId: 'pt-4', measuredLengthMeters: 5.0),
        ConduitRoute(id: 'rt-4', fromPointId: 'pt-4', toPointId: 'pt-5', measuredLengthMeters: 4.8),
      ];
    }
  }

  /// Automatically cleans up duplicate MDP panels or out-of-bounds coordinates
  /// (e.g. x > 266 outside the right exterior wall) so all items sit strictly inside the rooms.
  void _sanitizeAndFitExistingPointsIfNeeded() {
    final panelCount = _points.where((p) => p.type == 'PANEL').length;
    final hasOutOfBounds = _points.any((p) => p.x > 266.0 || p.y < 150.0 || p.y > 395.0);

    if (panelCount > 1 || hasOutOfBounds) {
      if (widget.project != null && widget.project!.applianceLoads.isNotEmpty) {
        _autoGenerateFromAppliances(widget.project!.applianceLoads);
      } else {
        bool keptFirstPanel = false;
        final List<CanvasPoint> cleaned = [];
        for (final pt in _points) {
          if (pt.type == 'PANEL') {
            if (keptFirstPanel) continue;
            keptFirstPanel = true;
            cleaned.add(CanvasPoint(
              id: pt.id,
              type: pt.type,
              label: 'MDP',
              x: 42.0,
              y: 280.0,
              circuitNumber: pt.circuitNumber,
            ));
            continue;
          }
          cleaned.add(pt);
        }

        int lightIdx = 0;
        int wallIdx = 0;
        for (final pt in cleaned) {
          if (pt.type == 'PANEL') continue;
          if (pt.type == 'LIGHT' || pt.type == 'FAN') {
            final anchor = _roomCeilingAnchors[lightIdx % _roomCeilingAnchors.length];
            final int cycle = lightIdx ~/ _roomCeilingAnchors.length;
            pt.x = (anchor.dx + (cycle * 12.0)).clamp(52.0, 248.0);
            pt.y = (anchor.dy + (cycle * 10.0)).clamp(160.0, 380.0);
            lightIdx++;
          } else {
            final anchor = _wallPerimeterAnchors[wallIdx % _wallPerimeterAnchors.length];
            final int cycle = wallIdx ~/ _wallPerimeterAnchors.length;
            pt.x = (anchor.dx - (cycle * 10.0)).clamp(48.0, 258.0);
            pt.y = (anchor.dy + (cycle * 8.0)).clamp(156.0, 386.0);
            wallIdx++;
          }
        }
        _points = cleaned;
        final validIds = _points.map((p) => p.id).toSet();
        _routes.removeWhere((r) => !validIds.contains(r.fromPointId) || !validIds.contains(r.toPointId));
      }

      if (widget.project != null) {
        widget.project!.canvasPoints = _points;
        widget.project!.conduitRoutes = _routes;
        ProjectRepository.instance.updateProject(widget.project!);
      }
    }
  }

  void _cycleZoomLevel() {
    setState(() {
      if (_currentZoom < 1.4) {
        _currentZoom = 1.75;
      } else if (_currentZoom < 2.2) {
        _currentZoom = 2.4;
      } else {
        _currentZoom = 1.0;
      }

      if (_currentZoom == 1.0) {
        _zoomController.value = Matrix4.identity();
      } else {
        // Zoom toward the center of the floor plan (approx x: 160, y: 275)
        const double centerX = 160.0;
        const double centerY = 275.0;
        final double dx = -centerX * (_currentZoom - 1.0);
        final double dy = -centerY * (_currentZoom - 1.0);
        _zoomController.value = Matrix4.identity()
          ..translateByDouble(dx, dy, 0.0, 1.0)
          ..scaleByDouble(_currentZoom, _currentZoom, 1.0, 1.0);
      }
    });
  }

  String _getShorthandLabel(String pointType, String originalName, int index) {
    if (pointType == 'PANEL') return 'MDP';
    if (pointType == 'ACU') return 'ACU-$index';
    if (pointType == 'LIGHT') return 'L-$index';
    if (pointType == 'SWITCH_1G') return 'S1-$index';
    if (pointType == 'OUTLET_DUPLEX') {
      final lower = originalName.toLowerCase();
      if (lower.contains('gfci') || lower.contains('shaver') || lower.contains('bath')) return 'GFCI-$index';
      if (lower.contains('ref') || lower.contains('refrigerator')) return 'REF-$index';
      if (lower.contains('wash') || lower.contains('laundry')) return 'WM-$index';
      if (lower.contains('range') || lower.contains('cook') || lower.contains('induction')) return 'RO-$index';
      return 'CO-$index';
    }
    return 'D-$index';
  }

  void _autoGenerateFromAppliances(List<ApplianceItem> appliances) {
    // Place MDP on the left entrance/kitchen wall inside the floor plan
    final panelPt = CanvasPoint(id: 'pt-panel', type: 'PANEL', label: 'MDP', x: 42.0, y: 280.0);
    _points = [panelPt];
    _routes = [];

    final List<Map<String, dynamic>> ceilingDevices = [];
    final List<Map<String, dynamic>> wallDevices = [];
    int devCounter = 1;

    for (final app in appliances) {
      for (int i = 0; i < app.quantity; i++) {
        String pointType = 'OUTLET_DUPLEX';
        if (app.name.toLowerCase().contains('aircon') || app.name.toLowerCase().contains('acu')) {
          pointType = 'ACU';
        } else if (app.name.toLowerCase().contains('light') ||
            app.name.toLowerCase().contains('fan') ||
            app.name.toLowerCase().contains('luminaire') ||
            app.name.toLowerCase().contains('led')) {
          pointType = 'LIGHT';
        } else if (app.name.toLowerCase().contains('switch')) {
          pointType = 'SWITCH_1G';
        }

        final devMap = {
          'id': 'pt-$devCounter',
          'type': pointType,
          'name': app.name,
          'isDedicated': app.isDedicatedCircuit,
          'circuitNumber': app.circuitNumber,
          'index': devCounter,
        };

        if (pointType == 'LIGHT' || pointType == 'FAN') {
          ceilingDevices.add(devMap);
        } else {
          wallDevices.add(devMap);
        }
        devCounter++;
      }
    }

    String lastLightingPointId = 'pt-panel';
    String lastOutletPointId = 'pt-panel';
    int routeCounter = 1;

    // 1. Place Ceiling Luminaires in Room Centers & Daisy-Chain Room-to-Room
    for (int i = 0; i < ceilingDevices.length; i++) {
      final dev = ceilingDevices[i];
      final String pId = dev['id'];
      final String pType = dev['type'];
      final String pName = dev['name'];
      final int idx = dev['index'];

      final anchor = _roomCeilingAnchors[i % _roomCeilingAnchors.length];
      final int cycle = i ~/ _roomCeilingAnchors.length;
      final double curX = (anchor.dx + (cycle * 14.0)).clamp(58.0, 244.0);
      final double curY = (anchor.dy + (cycle * 12.0)).clamp(162.0, 376.0);

      final compactLabel = _getShorthandLabel(pType, pName, idx);

      _points.add(CanvasPoint(
        id: pId,
        type: pType,
        label: compactLabel,
        x: curX,
        y: curY,
        circuitNumber: 1,
      ));

      _routes.add(ConduitRoute(
        id: 'rt-${routeCounter++}',
        fromPointId: lastLightingPointId,
        toPointId: pId,
        measuredLengthMeters: 3.5,
      ));
      lastLightingPointId = pId;
    }

    // 2. Place Outlets, Switches & ACUs Along Perimeter/Interior Walls Clockwise
    for (int i = 0; i < wallDevices.length; i++) {
      final dev = wallDevices[i];
      final String pId = dev['id'];
      final String pType = dev['type'];
      final String pName = dev['name'];
      final bool isDedicated = dev['isDedicated'];
      final int idx = dev['index'];

      final anchor = _wallPerimeterAnchors[i % _wallPerimeterAnchors.length];
      final int cycle = i ~/ _wallPerimeterAnchors.length;
      final double curX = (anchor.dx - (cycle * 12.0)).clamp(48.0, 258.0);
      final double curY = (anchor.dy + (cycle * 10.0)).clamp(156.0, 386.0);

      final compactLabel = _getShorthandLabel(pType, pName, idx);

      _points.add(CanvasPoint(
        id: pId,
        type: pType,
        label: compactLabel,
        x: curX,
        y: curY,
        circuitNumber: isDedicated ? (idx + 2) : 2,
      ));

      if (isDedicated) {
        // Dedicated equipment: Home-run conduit back to MDP (rendered as CAD Home-Run Arrowhead!)
        _routes.add(ConduitRoute(
          id: 'rt-${routeCounter++}',
          fromPointId: 'pt-panel',
          toPointId: pId,
          measuredLengthMeters: 7.5,
        ));
      } else {
        // Convenience outlet branch circuit daisy-chain along perimeter walls
        _routes.add(ConduitRoute(
          id: 'rt-${routeCounter++}',
          fromPointId: lastOutletPointId,
          toPointId: pId,
          measuredLengthMeters: 3.8,
        ));
        lastOutletPointId = pId;
      }
    }
  }

  void _handlePanStart(DragStartDetails details) {
    final tapX = details.localPosition.dx;
    final tapY = details.localPosition.dy;
    _dragStartOffset = details.localPosition;
    _hasMovedSignificantly = false;

    // Detect if user grabbed a device point
    CanvasPoint? hitPt;
    for (final pt in _points.reversed) {
      final dist = (Offset(pt.x, pt.y) - Offset(tapX, tapY)).distance;
      if (dist <= 28.0) {
        hitPt = pt;
        break;
      }
    }

    if (hitPt != null) {
      setState(() {
        _draggedPoint = hitPt;
        _selectedPoint = hitPt;
      });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_draggedPoint != null) {
      final newPos = details.localPosition;
      if (_dragStartOffset != null && (newPos - _dragStartOffset!).distance > 6.0) {
        _hasMovedSignificantly = true;
      }

      setState(() {
        // Snap gently to 5px CAD grid for precision
        final snappedX = (newPos.dx / 5.0).round() * 5.0;
        final snappedY = (newPos.dy / 5.0).round() * 5.0;
        _draggedPoint!.x = snappedX.clamp(20.0, 1200.0);
        _draggedPoint!.y = snappedY.clamp(20.0, 1200.0);
      });
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_draggedPoint != null) {
      if (_hasMovedSignificantly) {
        // Persist updated point coordinates
        if (widget.project != null) {
          widget.project!.canvasPoints = _points;
          ProjectRepository.instance.updateProject(widget.project!);
        }
      } else {
        // Short tap without drag: open inspection sheet
        _showPointInspectionSheet(_draggedPoint!);
      }

      setState(() {
        _draggedPoint = null;
        _dragStartOffset = null;
        _hasMovedSignificantly = false;
      });
    }
  }

  void _handleCanvasTap(TapUpDetails details) {
    // If not dragging, check if tapping an existing point (within 24px radius)
    final tapX = details.localPosition.dx;
    final tapY = details.localPosition.dy;

    CanvasPoint? tappedPt;
    for (final pt in _points.reversed) {
      final dist = (Offset(pt.x, pt.y) - Offset(tapX, tapY)).distance;
      if (dist <= 24.0) {
        tappedPt = pt;
        break;
      }
    }

    if (tappedPt != null) {
      setState(() {
        _selectedPoint = tappedPt;
      });
      _showPointInspectionSheet(tappedPt);
      return;
    }

    // Otherwise add new device if empty space tapped
    _addPointAt(details);
  }

  void _showPointInspectionSheet(CanvasPoint pt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BanaagTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: CanvasPainter.getColorForType(pt.type).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: CanvasPainter.getColorForType(pt.type), width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        pt.label,
                        style: TextStyle(
                          color: CanvasPainter.getColorForType(pt.type),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
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
                          '${pt.type.replaceAll('_', ' ')} (${pt.label})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                        Text(
                          'Coordinates: X: ${pt.x.toStringAsFixed(0)}px, Y: ${pt.y.toStringAsFixed(0)}px • Branch Ckt #${pt.circuitNumber}',
                          style: const TextStyle(fontSize: 11, color: BanaagTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: BanaagTheme.alertRed),
                    tooltip: 'Remove Point',
                    onPressed: () {
                      setState(() {
                        _points.removeWhere((p) => p.id == pt.id);
                        _routes.removeWhere((r) => r.fromPointId == pt.id || r.toPointId == pt.id);
                        _selectedPoint = null;
                        if (widget.project != null) {
                          widget.project!.canvasPoints = _points;
                          widget.project!.conduitRoutes = _routes;
                          ProjectRepository.instance.updateProject(widget.project!);
                        }
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Colors.white12),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PEC Wiring Method: 20 mm Ø PVC • 2 - 3.5 mm² THHN',
                    style: const TextStyle(fontSize: 11, color: BanaagTheme.primaryAmber),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addPointAt(TapUpDetails details) {
    if (_selectedTool == 'SELECT') {
      // In Select/Move mode, tapping empty space just deselects
      setState(() => _selectedPoint = null);
      return;
    }

    if (_selectedTool == 'PANEL') {
      final hasPanel = _points.any((p) => p.type == 'PANEL');
      if (hasPanel) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Main Distribution Panel (MDP) already placed. Only 1 main panel allowed per dwelling unit.'),
            backgroundColor: BanaagTheme.warningOrange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    setState(() {
      final newId = 'pt-${_points.length + 1}';
      final compactLabel = _getShorthandLabel(_selectedTool, _selectedTool, _points.length + 1);
      final newPt = CanvasPoint(
        id: newId,
        type: _selectedTool,
        label: compactLabel,
        x: details.localPosition.dx,
        y: details.localPosition.dy,
      );
      _points.add(newPt);
      _selectedPoint = newPt;

      // Auto-route from last point of compatible type
      if (_points.length > 1) {
        _routes.add(ConduitRoute(
          id: 'rt-${_routes.length + 1}',
          fromPointId: _points[_points.length - 2].id,
          toPointId: newId,
          measuredLengthMeters: 3.5, // Standard estimated run
        ));
      }

      if (widget.project != null) {
        widget.project!.canvasPoints = _points;
        widget.project!.conduitRoutes = _routes;
        ProjectRepository.instance.updateProject(widget.project!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final takeoff = TakeoffEngine.calculate(points: _points, routes: _routes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📐 Plan Canvas & Takeoff'),
        actions: [
          // 1. Quick Room Dimensions Generator
          IconButton(
            icon: const Icon(Icons.aspect_ratio, color: BanaagTheme.primaryAmber),
            tooltip: 'Room Dimensions & Wall Calibration',
            onPressed: () {
              RoomDimensionInputDialog.show(
                context,
                initialGeometry: _roomGeometry,
                onGenerated: (geom, pts, rts) {
                  setState(() {
                    _roomGeometry = geom;
                    _points = pts;
                    _routes = rts;
                    if (widget.project != null) {
                      widget.project!.roomGeometry = geom;
                      widget.project!.canvasPoints = pts;
                      widget.project!.conduitRoutes = rts;
                      ProjectRepository.instance.updateProject(widget.project!);
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('📐 Auto-drawn ${geom.roomType == 'L_SHAPE' ? 'L-Shape' : 'Room'} (${geom.computedAreaSqm.toStringAsFixed(1)} m²)! ${pts.length} devices routed.'),
                      backgroundColor: BanaagTheme.successGreen,
                    ),
                  );
                },
              );
            },
          ),

          // 2. Import Floor Plan / DXF Intake
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: Colors.cyanAccent),
            tooltip: 'Import Architectural Floor Plan / DXF',
            onPressed: () {
              RawPlanCalibrationModal.show(
                context,
                project: widget.project,
                onApplied: (pts, rts, geom) {
                  setState(() {
                    _points = pts;
                    _routes = rts;
                    _roomGeometry = geom;

                    if (widget.project != null) {
                      widget.project!.canvasPoints = pts;
                      widget.project!.conduitRoutes = rts;
                      widget.project!.roomGeometry = geom;

                      // Mark Takeoff & Intake checklist item complete if applicable
                      for (final phase in widget.project!.phases) {
                        for (final item in phase.checklist) {
                          if (item.id == 'c_dxf' || item.id == 'c_takeoff' || item.id == 'p_takeoff') {
                            item.isCompleted = true;
                            item.notes = 'Completed via Takeoff Plan Engine (${pts.length} devices auto-placed)';
                          }
                        }
                        if (phase.checklist.every((c) => c.isCompleted)) {
                          phase.isCompleted = true;
                        }
                      }
                      ProjectRepository.instance.updateProject(widget.project!);
                    }
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('⚡ PEC Smart Placement Applied: ${pts.length} devices in ${geom.totalWidthMeters.toStringAsFixed(1)}m × ${geom.leftWallMeters.toStringAsFixed(1)}m area!'),
                      backgroundColor: BanaagTheme.successGreen,
                    ),
                  );
                },
              );
            },
          ),

          // 3. Overflow Menu for Lighting Calculator, Heatmap, and DXF Export
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'More Engineering Tools',
            color: const Color(0xFF1E2430),
            onSelected: (val) async {
              if (val == 'heatmap') {
                setState(() {
                  _isHeatmapVisible = !_isHeatmapVisible;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isHeatmapVisible ? '🔥 In-Canvas Lux Heatmap Activated (IESNA)' : '❄️ Lux Heatmap Hidden (CAD Mode)'),
                    backgroundColor: _isHeatmapVisible ? BanaagTheme.primaryAmber : const Color(0xFF262C38),
                    duration: const Duration(seconds: 2),
                  ),
                );
              } else if (val == 'lighting') {
                LightingVisualizerModal.show(
                  context,
                  initialLength: _roomGeometry?.leftWallMeters ?? 7.0,
                  initialWidth: _roomGeometry?.totalWidthMeters ?? 6.0,
                  onApplyToCanvas: (result) {
                    setState(() {
                      for (int i = 0; i < result.fixtures.length; i++) {
                        final f = result.fixtures[i];
                        _points.add(CanvasPoint(
                          id: 'pt-lux-${_points.length + 1}',
                          type: 'LIGHT',
                          label: f.label,
                          x: 80.0 + (f.xMeters * 20.0),
                          y: 80.0 + (f.yMeters * 20.0),
                        ));
                      }
                      if (widget.project != null) {
                        widget.project!.canvasPoints = _points;
                        ProjectRepository.instance.updateProject(widget.project!);
                      }
                    });
                  },
                );
              } else if (val == 'dxf_export') {
                try {
                  final preset = InstitutionalBuildingPreset.sanLorenzoRuizCollege();
                  final dxfString = DxfCadEngine.generateDxf(
                    projectName: widget.project?.title ?? 'Takeoff Electrical Plan',
                    points: _points,
                    routes: _routes,
                    roomGeometry: _roomGeometry,
                    preset: preset,
                  );

                  final tempDir = await getTemporaryDirectory();
                  final file = File('${tempDir.path}/${widget.project?.title.replaceAll(" ", "_") ?? "Takeoff"}_Plan.dxf');
                  await file.writeAsString(dxfString);

                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(file.path)],
                      text: '📐 BANAAG AutoCAD DXF Export: ${widget.project?.title ?? "Electrical Plan"}\n100% Editable in AutoCAD / DWG FastView.',
                      subject: 'AutoCAD DXF Electrical Plan Export',
                    ),
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('DXF Export Error: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              } else if (val == 'dxf_guide') {
                DxfExportGuideDialog.show(context);
              } else if (val == 'auto_fit_reset') {
                setState(() {
                  if (widget.project != null && widget.project!.applianceLoads.isNotEmpty) {
                    _autoGenerateFromAppliances(widget.project!.applianceLoads);
                    widget.project!.canvasPoints = _points;
                    widget.project!.conduitRoutes = _routes;
                    ProjectRepository.instance.updateProject(widget.project!);
                  } else {
                    // Default baseline clean layout strictly inside floor plan bounds
                    _points = [
                      CanvasPoint(id: 'pt-panel', type: 'PANEL', label: 'MDP', x: 40, y: 285),
                      CanvasPoint(id: 'pt-1', type: 'SWITCH_1G', label: 'S1-1', x: 110, y: 225),
                      CanvasPoint(id: 'pt-2', type: 'LIGHT', label: 'L-1', x: 190, y: 225),
                      CanvasPoint(id: 'pt-3', type: 'OUTLET_DUPLEX', label: 'CO-1', x: 140, y: 335),
                      CanvasPoint(id: 'pt-4', type: 'ACU', label: 'ACU-1', x: 285, y: 235),
                    ];
                    _routes = [
                      ConduitRoute(id: 'rt-1', fromPointId: 'pt-panel', toPointId: 'pt-1', measuredLengthMeters: 4.0),
                      ConduitRoute(id: 'rt-2', fromPointId: 'pt-1', toPointId: 'pt-2', measuredLengthMeters: 3.0),
                      ConduitRoute(id: 'rt-3', fromPointId: 'pt-panel', toPointId: 'pt-3', measuredLengthMeters: 3.5),
                      ConduitRoute(id: 'rt-4', fromPointId: 'pt-panel', toPointId: 'pt-4', measuredLengthMeters: 7.5),
                    ];
                  }
                  _selectedPoint = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚡ Auto-Fitted to Floor Plan! Duplicate MDPs removed & items aligned inside rooms.'),
                    backgroundColor: BanaagTheme.successGreen,
                  ),
                );
              } else if (val == 'toggle_conduits') {
                setState(() => _showConduits = !_showConduits);
              } else if (val == 'toggle_underlay') {
                setState(() => _isUnderlayVisible = !_isUnderlayVisible);
              } else if (val == 'toggle_labels') {
                setState(() => _showLabels = !_showLabels);
              } else if (val == 'pick_underlay') {
                _pickNewUnderlay();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'auto_fit_reset',
                child: Row(
                  children: const [
                    Icon(Icons.auto_fix_high, color: BanaagTheme.primaryAmber, size: 18),
                    SizedBox(width: 10),
                    Text('Auto-Clean & Fit to Plan', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_conduits',
                child: Row(
                  children: [
                    Icon(_showConduits ? Icons.alt_route : Icons.route_outlined, color: Colors.orangeAccent, size: 18),
                    const SizedBox(width: 10),
                    Text(_showConduits ? 'Hide Conduit Lines' : 'Show Conduit Lines', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_labels',
                child: Row(
                  children: [
                    Icon(_showLabels ? Icons.label_off_outlined : Icons.label_outlined, color: BanaagTheme.primaryAmber, size: 18),
                    const SizedBox(width: 10),
                    Text(_showLabels ? 'Hide Device Badges' : 'Show Device Badges', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              if (_hasBlueprintFile)
                PopupMenuItem(
                  value: 'toggle_underlay',
                  child: Row(
                    children: [
                      Icon(_isUnderlayVisible ? Icons.layers_clear : Icons.layers, color: Colors.cyanAccent, size: 18),
                      const SizedBox(width: 10),
                      Text(_isUnderlayVisible ? 'Hide Floor Plan Underlay' : 'Show Floor Plan Underlay', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'pick_underlay',
                child: Row(
                  children: const [
                    Icon(Icons.add_photo_alternate_outlined, color: Colors.amberAccent, size: 18),
                    SizedBox(width: 10),
                    Text('Attach/Change Floor Plan', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'heatmap',
                child: Row(
                  children: [
                    Icon(_isHeatmapVisible ? Icons.blur_on : Icons.blur_off_outlined, color: Colors.amberAccent, size: 18),
                    const SizedBox(width: 10),
                    Text(_isHeatmapVisible ? 'Hide Lux Heatmap' : 'Show Lux Heatmap', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'lighting',
                child: Row(
                  children: const [
                    Icon(Icons.wb_incandescent_outlined, color: Colors.amberAccent, size: 18),
                    SizedBox(width: 10),
                    Text('Illuminance Calculator (IESNA)', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'dxf_export',
                child: Row(
                  children: const [
                    Icon(Icons.download_for_offline_outlined, color: Colors.cyanAccent, size: 18),
                    SizedBox(width: 10),
                    Text('Export AutoCAD (.DXF)', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'dxf_guide',
                child: Row(
                  children: const [
                    Icon(Icons.help_outline, color: BanaagTheme.primaryAmber, size: 18),
                    SizedBox(width: 10),
                    Text('AutoCAD Export Guide', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ],
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

          // Interactive 2D Grid Canvas with Blueprint Floor Plan Underlay + Zoom & Fit Controls
          Expanded(
            child: Container(
              color: const Color(0xFF16191F),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Zoomable Interactive Canvas (Floor Plan + Electrical Vector Layer move/scale together)
                  InteractiveViewer(
                    transformationController: _zoomController,
                    minScale: 1.0,
                    maxScale: 3.2,
                    panEnabled: false,
                    scaleEnabled: true,
                    onInteractionEnd: (_) {
                      setState(() {
                        _currentZoom = _zoomController.value.getMaxScaleOnAxis();
                      });
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: _handleCanvasTap,
                      onPanStart: _handlePanStart,
                      onPanUpdate: _handlePanUpdate,
                      onPanEnd: _handlePanEnd,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. Blueprint Floor Plan Underlay
                          if (_hasBlueprintFile && _isUnderlayVisible)
                            Positioned.fill(
                              child: Opacity(
                                opacity: _underlayOpacity,
                                child: _blueprintPath!.toLowerCase().endsWith('.pdf')
                                    ? _buildPdfUnderlayPlaceholder()
                                    : Image.file(
                                        File(_blueprintPath!),
                                        fit: BoxFit.contain,
                                        errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                                      ),
                              ),
                            ),

                          // 2. Interactive Vector Electrical Layer
                          CustomPaint(
                            painter: CanvasPainter(
                              points: _points,
                              routes: _routes,
                              roomGeometry: _roomGeometry,
                              isHeatmap: _isHeatmapVisible,
                              showLabels: _showLabels,
                              showConduits: _showConduits,
                              hasBlueprintUnderlay: _hasBlueprintFile && _isUnderlayVisible,
                              selectedPoint: _selectedPoint,
                            ),
                            child: Container(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Floating Blueprint Layer Pill Indicator (Top-Left)
                  if (_hasBlueprintFile)
                    Positioned(
                      top: 10,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xDD11151E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _blueprintPath!.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image,
                              size: 14,
                              color: BanaagTheme.primaryAmber,
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 115),
                              child: Text(
                                _blueprintPath!.split(Platform.pathSeparator).last,
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => setState(() => _isUnderlayVisible = !_isUnderlayVisible),
                              child: Icon(
                                _isUnderlayVisible ? Icons.visibility : Icons.visibility_off,
                                size: 15,
                                color: _isUnderlayVisible ? BanaagTheme.primaryAmber : Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 4. Floating Quick Zoom & Auto-Fit Controls (Top-Right)
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1-Tap Auto-Fit Items to Plan Button
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (widget.project != null && widget.project!.applianceLoads.isNotEmpty) {
                                _autoGenerateFromAppliances(widget.project!.applianceLoads);
                                widget.project!.canvasPoints = _points;
                                widget.project!.conduitRoutes = _routes;
                                ProjectRepository.instance.updateProject(widget.project!);
                              } else {
                                _sanitizeAndFitExistingPointsIfNeeded();
                              }
                              _selectedPoint = null;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🎯 Items fitted strictly inside Floor Plan bounds!'),
                                backgroundColor: BanaagTheme.successGreen,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xDD11151E),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.7)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.fit_screen, size: 14, color: Colors.cyanAccent),
                                SizedBox(width: 4),
                                Text(
                                  'Fit Items',
                                  style: TextStyle(color: Colors.cyanAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 1-Tap Zoom Floor Plan Button (1.0x -> 1.8x -> 2.4x)
                        GestureDetector(
                          onTap: _cycleZoomLevel,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: _currentZoom > 1.05 ? BanaagTheme.primaryAmber : const Color(0xDD11151E),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: BanaagTheme.primaryAmber),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.zoom_in,
                                  size: 14,
                                  color: _currentZoom > 1.05 ? Colors.black : BanaagTheme.primaryAmber,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${_currentZoom.toStringAsFixed(1)}x',
                                  style: TextStyle(
                                    color: _currentZoom > 1.05 ? Colors.black : Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                  _symbolButton('SELECT', Icons.near_me, 'Select / Move'),
                  _symbolButton('PANEL', Icons.dashboard, 'Panel'),
                  _symbolButton('SWITCH_1G', Icons.toggle_on, '1G Switch'),
                  _symbolButton('LIGHT', Icons.lightbulb, 'Light'),
                  _symbolButton('OUTLET_DUPLEX', Icons.power, 'Duplex CO'),
                  _symbolButton('ACU', Icons.ac_unit, 'Aircon'),
                  _symbolButton('FAN', Icons.toys_outlined, 'Electric Fan'),
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

  Future<void> _pickNewUnderlay() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );
      if (file != null && file.path != null) {
        final path = file.path!;
        setState(() {
          _blueprintPath = path;
          _isUnderlayVisible = true;
          if (widget.project != null) {
            widget.project!.blueprintImagePath = path;
            ProjectRepository.instance.updateProject(widget.project!);
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📐 Floor plan attached: ${path.split(Platform.pathSeparator).last}!'),
              backgroundColor: BanaagTheme.successGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking plan: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildPdfUnderlayPlaceholder() {
    return Container(
      color: const Color(0xFF1B2332),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, size: 64, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              'PDF Blueprint: ${_blueprintPath!.split(Platform.pathSeparator).last}',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Floor Plan Reference Calibrated • Grid Overlay Active',
              style: TextStyle(color: BanaagTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class CanvasPainter extends CustomPainter {
  final List<CanvasPoint> points;
  final List<ConduitRoute> routes;
  final RoomGeometry? roomGeometry;
  final bool isHeatmap;
  final bool showLabels;
  final bool showConduits;
  final bool hasBlueprintUnderlay;
  final CanvasPoint? selectedPoint;

  CanvasPainter({
    required this.points,
    required this.routes,
    this.roomGeometry,
    this.isHeatmap = false,
    this.showLabels = true,
    this.showConduits = true,
    this.hasBlueprintUnderlay = false,
    this.selectedPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw Subtle CAD Grid Lines
    final gridPaint = Paint()
      ..color = const Color(0xFF1E232E)
      ..strokeWidth = 0.8;

    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw Synthetic Room Walls ONLY if no actual blueprint image/PDF is underlaid
    if (roomGeometry != null && !hasBlueprintUnderlay) {
      _drawRoomWalls(canvas, size, roomGeometry!);
    }

    // In-Canvas Optical Lux Heatmap Layer
    if (isHeatmap) {
      for (final pt in points.where((p) => p.type == 'LIGHT')) {
        const radius = 38.0;
        final gradPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              BanaagTheme.primaryAmber.withValues(alpha: 0.50),
              BanaagTheme.primaryAmber.withValues(alpha: 0.15),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(pt.x, pt.y), radius: radius))
          ..blendMode = BlendMode.screen;

        canvas.drawCircle(Offset(pt.x, pt.y), radius, gradPaint);
      }
    }

    // Draw Conduit Routes (Sleek Orthogonal 90-degree CAD Routing + AutoCAD Home-Run Arrowheads)
    if (showConduits) {
      final routePaint = Paint()
        ..color = BanaagTheme.primaryAmber.withValues(alpha: 0.62)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final homerunStubPaint = Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.85)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (final r in routes) {
        final p1 = points.firstWhere((p) => p.id == r.fromPointId, orElse: () => points.first);
        final p2 = points.firstWhere((p) => p.id == r.toPointId, orElse: () => points.first);

        if (p1.id == p2.id) continue;

        final bool isDedicatedHomerun =
            p1.type == 'PANEL' && (p2.type == 'ACU' || p2.circuitNumber > 2);

        if (isDedicatedHomerun) {
          // AutoCAD Standard: Draw a short Home-Run Arrowhead stub pointing toward MDP
          // instead of cluttering the floor plan with long crossing lines
          final angle = math.atan2(p1.y - p2.y, p1.x - p2.x);
          const double startDist = 7.5;
          const double endDist = 18.0;
          final stubStart = Offset(
            p2.x + math.cos(angle) * startDist,
            p2.y + math.sin(angle) * startDist,
          );
          final stubTip = Offset(
            p2.x + math.cos(angle) * endDist,
            p2.y + math.sin(angle) * endDist,
          );

          canvas.drawLine(stubStart, stubTip, homerunStubPaint);

          // Arrowhead wings at stubTip
          const double wingLen = 4.5;
          const double wingAngle = 0.55;
          final wing1 = Offset(
            stubTip.dx - math.cos(angle - wingAngle) * wingLen,
            stubTip.dy - math.sin(angle - wingAngle) * wingLen,
          );
          final wing2 = Offset(
            stubTip.dx - math.cos(angle + wingAngle) * wingLen,
            stubTip.dy - math.sin(angle + wingAngle) * wingLen,
          );
          canvas.drawLine(stubTip, wing1, homerunStubPaint);
          canvas.drawLine(stubTip, wing2, homerunStubPaint);

          // Tiny conductor slash tick across the midpoint of the homerun stub
          final midStub = Offset(
            (stubStart.dx + stubTip.dx) / 2,
            (stubStart.dy + stubTip.dy) / 2,
          );
          final perpAngle = angle + (math.pi / 4);
          canvas.drawLine(
            Offset(midStub.dx - math.cos(perpAngle) * 3.0, midStub.dy - math.sin(perpAngle) * 3.0),
            Offset(midStub.dx + math.cos(perpAngle) * 3.0, midStub.dy + math.sin(perpAngle) * 3.0),
            homerunStubPaint,
          );
          continue;
        }

        final path = Path();
        path.moveTo(p1.x, p1.y);

        final dx = (p2.x - p1.x).abs();
        final dy = (p2.y - p1.y).abs();

        if (dx >= dy) {
          path.lineTo(p2.x, p1.y);
          path.lineTo(p2.x, p2.y);
        } else {
          path.lineTo(p1.x, p2.y);
          path.lineTo(p2.x, p2.y);
        }

        canvas.drawPath(path, routePaint);
      }
    }

    // Draw Micro-CAD Points (6.5px radius so rooms & walls remain clearly visible)
    for (final pt in points) {
      final isSel = selectedPoint?.id == pt.id;
      final bool isPanel = pt.type == 'PANEL';
      final double radius = isSel ? 9.0 : (isPanel ? 7.5 : 6.2);
      final pointPaint = Paint()..color = getColorForType(pt.type);

      // Selection halo
      if (isSel) {
        canvas.drawCircle(
          Offset(pt.x, pt.y),
          13.0,
          Paint()
            ..color = BanaagTheme.primaryAmber.withValues(alpha: 0.35)
            ..style = PaintingStyle.fill,
        );
      }

      canvas.drawCircle(Offset(pt.x, pt.y), radius, pointPaint);

      // Crisp CAD Symbol Border
      canvas.drawCircle(
        Offset(pt.x, pt.y),
        radius,
        Paint()
          ..color = isSel ? BanaagTheme.primaryAmber : const Color(0xFF11151E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSel ? 2.0 : 1.2,
      );

      // Inner CAD center dot for precision visual anchor
      canvas.drawCircle(
        Offset(pt.x, pt.y),
        1.8,
        Paint()..color = const Color(0xFF11151E),
      );

      // Micro-Badge Label
      if (showLabels) {
        final displayLabel = pt.label.length > 7 ? pt.label.substring(0, 7) : pt.label;
        final textSpan = TextSpan(
          text: displayLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 6.4,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        );
        final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
        textPainter.layout();

        final bgRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            pt.x - (textPainter.width / 2) - 2.5,
            pt.y + radius + 1.5,
            textPainter.width + 5.0,
            textPainter.height + 1.8,
          ),
          const Radius.circular(3),
        );

        final bgPaint = Paint()..color = const Color(0xD811151E);
        final borderPaint = Paint()
          ..color = isSel ? BanaagTheme.primaryAmber : Colors.white24
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6;

        canvas.drawRRect(bgRect, bgPaint);
        canvas.drawRRect(bgRect, borderPaint);
        textPainter.paint(canvas, Offset(pt.x - (textPainter.width / 2), pt.y + radius + 2.4));
      }
    }
  }

  void _drawRoomWalls(Canvas canvas, Size size, RoomGeometry geom) {
    const originX = 60.0;
    const originY = 60.0;
    final maxDim = geom.totalWidthMeters > geom.leftWallMeters ? geom.totalWidthMeters : geom.leftWallMeters;
    final scale = (300.0 / (maxDim <= 0 ? 6.0 : maxDim)).clamp(20.0, 50.0);

    final wallPaint = Paint()
      ..color = const Color(0xFF5A6882)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0xFF1B2230).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    final path = Path();
    if (geom.roomType == 'RECTANGULAR') {
      final rect = Rect.fromLTWH(
        originX,
        originY,
        geom.totalWidthMeters * scale,
        geom.leftWallMeters * scale,
      );
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, wallPaint);
    } else {
      // L-Shaped Room / Cutout based on user sketch:
      // P1: (originX, originY) -> Top Left
      // P2: (originX + (geom.totalWidthMeters - geom.cutoutWidthMeters) * scale, originY)
      // P3: Turn Down along Cutout: (..., originY + geom.cutoutDepthMeters * scale)
      // P4: Turn Right: (originX + geom.totalWidthMeters * scale, originY + geom.cutoutDepthMeters * scale)
      // P5: Down to Bottom Right: (originX + geom.totalWidthMeters * scale, originY + geom.leftWallMeters * scale)
      // P6: Left along Bottom: (originX, originY + geom.leftWallMeters * scale)
      // Close to P1
      final wMain = (geom.totalWidthMeters - geom.cutoutWidthMeters) * scale;
      final wTotal = geom.totalWidthMeters * scale;
      final hLeft = geom.leftWallMeters * scale;
      final hCutout = geom.cutoutDepthMeters * scale;

      path.moveTo(originX, originY);
      path.lineTo(originX + wMain, originY);
      path.lineTo(originX + wMain, originY + hCutout);
      path.lineTo(originX + wTotal, originY + hCutout);
      path.lineTo(originX + wTotal, originY + hLeft);
      path.lineTo(originX, originY + hLeft);
      path.close();

      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, wallPaint);

      // Dimension labels
      _drawDimensionText(canvas, '${geom.leftWallMeters.toStringAsFixed(1)}m', originX - 35, originY + (hLeft / 2));
      _drawDimensionText(canvas, '${geom.totalWidthMeters.toStringAsFixed(1)}m', originX + (wTotal / 2) - 15, originY + hLeft + 12);
      _drawDimensionText(canvas, '${geom.cutoutWidthMeters.toStringAsFixed(1)}m', originX + wMain + 5, originY + hCutout - 15);
    }

    // Floor Area badge inside room
    final areaText = 'AREA: ${geom.computedAreaSqm.toStringAsFixed(1)} m²';
    _drawDimensionText(canvas, areaText, originX + 25, originY + 25, color: BanaagTheme.primaryAmber, isBold: true);
  }

  void _drawDimensionText(Canvas canvas, String text, double x, double y, {Color color = const Color(0xFF8C9BAE), bool isBold = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(x, y));
  }

  static Color getColorForType(String type) {
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
      case 'FAN':
        return Colors.tealAccent;
      default:
        return Colors.white;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
