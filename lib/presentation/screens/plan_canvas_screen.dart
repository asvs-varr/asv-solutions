import 'dart:io';
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
  String _selectedTool = 'PANEL';
  bool _isUnderlayVisible = true;
  final double _underlayOpacity = 0.65;
  String? _blueprintPath;
  bool _showLabels = true;
  bool _showConduits = true;
  CanvasPoint? _selectedPoint;
  CanvasPoint? _draggedPoint;
  Offset? _dragStartOffset;
  bool _hasMovedSignificantly = false;

  bool get _hasBlueprintFile =>
      _blueprintPath != null && _blueprintPath!.isNotEmpty && File(_blueprintPath!).existsSync();

  @override
  void initState() {
    super.initState();
    _roomGeometry = widget.project?.roomGeometry;
    _blueprintPath = widget.project?.blueprintImagePath;
    if (widget.project != null && widget.project!.canvasPoints.isNotEmpty) {
      _points = widget.project!.canvasPoints;
      _routes = widget.project!.conduitRoutes;
    } else if (widget.project != null && widget.project!.applianceLoads.isNotEmpty) {
      _autoGenerateFromAppliances(widget.project!.applianceLoads);
    } else {
      _points = [
        CanvasPoint(id: 'pt-1', type: 'PANEL', label: 'MDP', x: 60, y: 150),
        CanvasPoint(id: 'pt-2', type: 'SWITCH_1G', label: 'SW-1', x: 160, y: 150),
        CanvasPoint(id: 'pt-3', type: 'LIGHT', label: 'L-1', x: 260, y: 150),
        CanvasPoint(id: 'pt-4', type: 'OUTLET_DUPLEX', label: 'CO-1', x: 160, y: 260),
        CanvasPoint(id: 'pt-5', type: 'ACU', label: 'ACU-1', x: 280, y: 260),
      ];
      _routes = [
        ConduitRoute(id: 'rt-1', fromPointId: 'pt-1', toPointId: 'pt-2', measuredLengthMeters: 4.5),
        ConduitRoute(id: 'rt-2', fromPointId: 'pt-2', toPointId: 'pt-3', measuredLengthMeters: 3.2),
        ConduitRoute(id: 'rt-3', fromPointId: 'pt-1', toPointId: 'pt-4', measuredLengthMeters: 5.0),
        ConduitRoute(id: 'rt-4', fromPointId: 'pt-4', toPointId: 'pt-5', measuredLengthMeters: 4.8),
      ];
    }
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
    final panelPt = CanvasPoint(id: 'pt-panel', type: 'PANEL', label: 'MDP', x: 80, y: 140);
    _points = [panelPt];
    _routes = [];

    // Separate into Circuit Types:
    // 1. Lighting (Circuit 1)
    // 2. Convenience Outlets (Circuit 2)
    // 3. Dedicated Equipment (Circuit 3+)
    final List<Map<String, dynamic>> flatDevices = [];
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

        flatDevices.add({
          'id': 'pt-$devCounter',
          'type': pointType,
          'name': app.name,
          'isDedicated': app.isDedicatedCircuit,
          'circuitNumber': app.circuitNumber,
          'index': devCounter,
        });
        devCounter++;
      }
    }

    // Grid placement parameters
    double curX = 180.0;
    double curY = 140.0;

    // Track the last point in each circuit branch for clean daisy-chaining
    String lastLightingPointId = 'pt-panel';
    String lastOutletPointId = 'pt-panel';
    int routeCounter = 1;

    for (final dev in flatDevices) {
      final String pId = dev['id'];
      final String pType = dev['type'];
      final String pName = dev['name'];
      final bool isDedicated = dev['isDedicated'];
      final int idx = dev['index'];

      final compactLabel = _getShorthandLabel(pType, pName, idx);

      _points.add(CanvasPoint(
        id: pId,
        type: pType,
        label: compactLabel,
        x: curX,
        y: curY,
        circuitNumber: isDedicated ? (idx + 2) : (pType == 'LIGHT' ? 1 : 2),
      ));

      // SMART ROUTING:
      if (isDedicated) {
        // Dedicated equipment: Single direct home-run conduit back to MDP
        _routes.add(ConduitRoute(
          id: 'rt-${routeCounter++}',
          fromPointId: 'pt-panel',
          toPointId: pId,
          measuredLengthMeters: 7.5,
        ));
      } else if (pType == 'LIGHT' || pType == 'SWITCH_1G') {
        // Lighting branch circuit daisy-chain (Panel -> Light 1 -> Light 2 -> ...)
        _routes.add(ConduitRoute(
          id: 'rt-${routeCounter++}',
          fromPointId: lastLightingPointId,
          toPointId: pId,
          measuredLengthMeters: 3.5,
        ));
        lastLightingPointId = pId;
      } else {
        // Convenience outlet branch circuit daisy-chain (Panel -> CO 1 -> CO 2 -> ...)
        _routes.add(ConduitRoute(
          id: 'rt-${routeCounter++}',
          fromPointId: lastOutletPointId,
          toPointId: pId,
          measuredLengthMeters: 3.8,
        ));
        lastOutletPointId = pId;
      }

      curX += 95.0;
      if (curX > 400.0) {
        curX = 180.0;
        curY += 85.0;
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
    setState(() {
      final newId = 'pt-${_points.length + 1}';
      final compactLabel = _getShorthandLabel(_selectedTool, _selectedTool, _points.length + 1);
      _points.add(CanvasPoint(
        id: newId,
        type: _selectedTool,
        label: compactLabel,
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

          // Interactive 2D Grid Canvas with Blueprint Floor Plan Underlay
          Expanded(
            child: GestureDetector(
              onTapUp: _handleCanvasTap,
              onPanStart: _handlePanStart,
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              child: Container(
                color: const Color(0xFF16191F),
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
                        selectedPoint: _selectedPoint,
                      ),
                      child: Container(),
                    ),

                    // 3. Floating Blueprint Layer Pill Indicator
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
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: Text(
                                  _blueprintPath!.split(Platform.pathSeparator).last,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(() => _isUnderlayVisible = !_isUnderlayVisible),
                                child: Icon(
                                  _isUnderlayVisible ? Icons.visibility : Icons.visibility_off,
                                  size: 16,
                                  color: _isUnderlayVisible ? BanaagTheme.primaryAmber : Colors.white38,
                                ),
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
  final CanvasPoint? selectedPoint;

  CanvasPainter({
    required this.points,
    required this.routes,
    this.roomGeometry,
    this.isHeatmap = false,
    this.showLabels = true,
    this.showConduits = true,
    this.selectedPoint,
  });

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

    // Draw Room Walls if RoomGeometry is specified
    if (roomGeometry != null) {
      _drawRoomWalls(canvas, size, roomGeometry!);
    }

    // In-Canvas Optical Lux Heatmap Layer
    if (isHeatmap) {
      for (final pt in points.where((p) => p.type == 'LIGHT')) {
        final radius = 55.0;
        final gradPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              BanaagTheme.primaryAmber.withValues(alpha: 0.55),
              BanaagTheme.primaryAmber.withValues(alpha: 0.18),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(pt.x, pt.y), radius: radius))
          ..blendMode = BlendMode.screen;

        canvas.drawCircle(Offset(pt.x, pt.y), radius, gradPaint);
      }
    }

    // Draw Conduit Routes (Orthogonal 90-degree CAD Routing)
    if (showConduits) {
      final routePaint = Paint()
        ..color = BanaagTheme.primaryAmber.withValues(alpha: 0.85)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      for (final r in routes) {
        final p1 = points.firstWhere((p) => p.id == r.fromPointId, orElse: () => points.first);
        final p2 = points.firstWhere((p) => p.id == r.toPointId, orElse: () => points.first);

        if (p1.id == p2.id) continue;

        // Clean Orthogonal CAD Conduit Path (Right-Angle Manhattan routing)
        final path = Path();
        path.moveTo(p1.x, p1.y);

        // Break routing through an intermediate elbow point:
        // Horizontal-first if dx > dy, otherwise Vertical-first
        final dx = (p2.x - p1.x).abs();
        final dy = (p2.y - p1.y).abs();

        if (dx >= dy) {
          // Horizontal then Vertical
          path.lineTo(p2.x, p1.y);
          path.lineTo(p2.x, p2.y);
        } else {
          // Vertical then Horizontal
          path.lineTo(p1.x, p2.y);
          path.lineTo(p2.x, p2.y);
        }

        canvas.drawPath(path, routePaint);
      }
    }

    // Draw Points
    for (final pt in points) {
      final isSel = selectedPoint?.id == pt.id;
      final pointPaint = Paint()..color = getColorForType(pt.type);

      // Selection halo
      if (isSel) {
        canvas.drawCircle(
          Offset(pt.x, pt.y),
          17,
          Paint()
            ..color = BanaagTheme.primaryAmber.withValues(alpha: 0.35)
            ..style = PaintingStyle.fill,
        );
      }

      canvas.drawCircle(Offset(pt.x, pt.y), isSel ? 13 : 11, pointPaint);

      // Border
      canvas.drawCircle(
        Offset(pt.x, pt.y),
        isSel ? 13 : 11,
        Paint()
          ..color = isSel ? BanaagTheme.primaryAmber : Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSel ? 2.5 : 1.5,
      );

      // Compact Badge Label
      if (showLabels) {
        final displayLabel = pt.label.length > 8 ? pt.label.substring(0, 8) : pt.label;
        final textSpan = TextSpan(
          text: displayLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        );
        final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
        textPainter.layout();

        final bgRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            pt.x - (textPainter.width / 2) - 4,
            pt.y + 13,
            textPainter.width + 8,
            textPainter.height + 3,
          ),
          const Radius.circular(4),
        );

        final bgPaint = Paint()..color = const Color(0xEE11151E);
        final borderPaint = Paint()
          ..color = isSel ? BanaagTheme.primaryAmber : Colors.white24
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;

        canvas.drawRRect(bgRect, bgPaint);
        canvas.drawRRect(bgRect, borderPaint);
        textPainter.paint(canvas, Offset(pt.x - (textPainter.width / 2), pt.y + 14.5));
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
