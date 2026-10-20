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
              } else if (val == 'toggle_underlay') {
                setState(() => _isUnderlayVisible = !_isUnderlayVisible);
              } else if (val == 'pick_underlay') {
                _pickNewUnderlay();
              }
            },
            itemBuilder: (ctx) => [
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
              onTapUp: _addPointAt,
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

  CanvasPainter({
    required this.points,
    required this.routes,
    this.roomGeometry,
    this.isHeatmap = false,
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

      // Label (compact display to avoid overlapping)
      final displayLabel = pt.label.contains('(') ? pt.label.split('(').first.trim() : pt.label;
      final textSpan = TextSpan(
        text: displayLabel,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          backgroundColor: Color(0xCC161922),
        ),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(pt.x - (textPainter.width / 2), pt.y + 14));
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
      case 'FAN':
        return Colors.tealAccent;
      default:
        return Colors.white;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
