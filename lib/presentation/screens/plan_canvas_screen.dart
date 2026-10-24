import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../domain/models.dart';
import '../../domain/takeoff_engine.dart';
import '../../domain/dxf_cad_engine.dart';
import '../../domain/institutional_building_presets.dart';
import '../../domain/pdf_blueprint_engine.dart';
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
  String _selectedTool = 'PAN';
  bool _isUnderlayVisible = true;
  final double _underlayOpacity = 0.78;
  String? _blueprintPath;
  int _pdfSheetIndex = 0;
  List<PdfBlueprintPageInfo> _pdfPages = [];
  String? _renderedPdfImagePath;
  bool _isRenderingPdf = false;
  bool _invertBlueprint = false;
  Offset _pinA = const Offset(145, 95);
  Offset _pinB = const Offset(500, 95);

  // Multi-Point Polygon Calibration Engine for Real Rooms
  final List<Offset> _activePolygonPoints = [];
  int _activeCalibratingRoomIndex = 0;
  final Map<String, List<Offset>> _calibratedRoomPolygons = {};

  int? _activeDraggingPin;
  Offset? _activeSnapPoint;
  double _pixelsPerMeter = 30.0;
  bool _showLabels = true;
  bool _showConduits = true;
  String _activeLayerFilter = 'ALL'; // 'ALL', 'LIGHTING', 'POWER'
  CanvasPoint? _selectedPoint;
  CanvasPoint? _draggedPoint;
  Offset? _dragStartOffset;
  bool _hasMovedSignificantly = false;
  final TransformationController _zoomController = TransformationController();
  double _currentZoom = 0.39;

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

  void _fitSheetToViewport() {
    // 1000 x 1220 unconstrained CAD sheet fitted to ~393px mobile screen width
    const double fitScale = 0.39;
    _currentZoom = fitScale;
    _zoomController.value = Matrix4.identity()
      ..translateByDouble(2.0, 6.0, 0.0, 1.0)
      ..scaleByDouble(fitScale, fitScale, 1.0, 1.0);
  }

  /// Purges orphaned residential loads and fixes legacy misclassified room appliances
  bool _sanitizeProjectApplianceLoads(Project proj) {
    if (proj.spaces.isEmpty) return false;
    bool modified = false;
    final validRoomNames = proj.spaces.map((s) => s.name.trim().toLowerCase()).toSet();

    final int beforeLen = proj.applianceLoads.length;
    proj.applianceLoads.removeWhere((app) {
      final cat = app.roomCategory.trim().toLowerCase();
      if (cat.isEmpty) return false;
      return !validRoomNames.contains(cat);
    });
    if (proj.applianceLoads.length != beforeLen) {
      modified = true;
    }

    // Remove accidental residential loads (TV, Dining, Fan, ACU, WM, REF, RO, GFCI) from Storage & Landing
    final int beforeSpecialClean = proj.applianceLoads.length;
    proj.applianceLoads.removeWhere((app) {
      final cat = app.roomCategory.toLowerCase();
      final nm = app.name.toLowerCase();
      if (cat.contains('storage') || cat.contains('store') || cat.contains('landing') || cat.contains('stair')) {
        if (nm.contains('tv') ||
            nm.contains('dining') ||
            nm.contains('aircon') ||
            nm.contains('acu') ||
            nm.contains('fan') ||
            nm.contains('refrigerator') ||
            nm.contains('washing') ||
            nm.contains('range') ||
            nm.contains('heater') ||
            nm.contains('shaver')) {
          return true;
        }
      }
      return false;
    });
    if (proj.applianceLoads.length != beforeSpecialClean) {
      modified = true;
    }

    // Rename legacy Living Room TV / Dining Table in commercial rooms to Convenience Outlet
    for (int i = 0; i < proj.applianceLoads.length; i++) {
      final app = proj.applianceLoads[i];
      final cat = app.roomCategory.toLowerCase();
      final nm = app.name.toLowerCase();
      if (cat.contains('hall') || cat.contains('event') || cat.contains('office') || cat.contains('staff')) {
        if (nm.contains('living room tv') || nm.contains('dining table')) {
          proj.applianceLoads[i] = ApplianceItem(
            id: app.id,
            name: 'Convenience Outlet (Duplex)',
            roomCategory: app.roomCategory,
            ratingVA: 180.0,
            quantity: 2,
            isDedicatedCircuit: false,
            isLighting: false,
            circuitNumber: app.circuitNumber,
          );
          modified = true;
        }
      }
    }

    // Ensure Storage and Landing have sensible PEC loads if emptied
    for (final sp in proj.spaces) {
      final lower = sp.name.toLowerCase();
      final hasLoads = proj.applianceLoads.any((a) => a.roomCategory.toLowerCase() == lower);
      if (!hasLoads) {
        if (lower.contains('storage') || lower.contains('store')) {
          proj.applianceLoads.addAll([
            ApplianceItem(
              id: 'auto-stor-l-${sp.id}',
              name: 'Utility LED Tube Luminaire (18W x 2 pcs)',
              roomCategory: sp.name,
              ratingVA: 36.0,
              isLighting: true,
              quantity: 1,
              circuitNumber: 1,
            ),
            ApplianceItem(
              id: 'auto-stor-c-${sp.id}',
              name: 'Utility Convenience Outlet (Duplex)',
              roomCategory: sp.name,
              ratingVA: 180.0,
              isLighting: false,
              quantity: 1,
              circuitNumber: 2,
            ),
          ]);
          modified = true;
        } else if (lower.contains('landing') || lower.contains('stair')) {
          proj.applianceLoads.addAll([
            ApplianceItem(
              id: 'auto-land-l-${sp.id}',
              name: 'Stairwell / Landing LED Light (18W x 2 pcs)',
              roomCategory: sp.name,
              ratingVA: 36.0,
              isLighting: true,
              quantity: 1,
              circuitNumber: 1,
            ),
            ApplianceItem(
              id: 'auto-land-c-${sp.id}',
              name: 'Emergency Light / Corridor Receptacle',
              roomCategory: sp.name,
              ratingVA: 180.0,
              isLighting: false,
              quantity: 1,
              circuitNumber: 2,
            ),
          ]);
          modified = true;
        }
      }
    }

    return modified;
  }

  @override
  void initState() {
    super.initState();
    _roomGeometry = widget.project?.roomGeometry;
    _blueprintPath = widget.project?.blueprintImagePath;
    _invertBlueprint = widget.project?.invertBlueprint ?? false;
    _pixelsPerMeter = widget.project?.calibrationPixelsPerMeter ?? 30.0;
    _fitSheetToViewport();

    bool loadsCleaned = false;
    if (widget.project != null) {
      loadsCleaned = _sanitizeProjectApplianceLoads(widget.project!);
    }

    if (widget.project != null && widget.project!.canvasPoints.isNotEmpty && !loadsCleaned) {
      _points = List<CanvasPoint>.from(widget.project!.canvasPoints);
      _routes = List<ConduitRoute>.from(widget.project!.conduitRoutes);
      _sanitizeAndFitExistingPointsIfNeeded();
    } else if (widget.project != null && widget.project!.applianceLoads.isNotEmpty) {
      _autoGenerateFromAppliances(widget.project!.applianceLoads);
      widget.project!.canvasPoints = _points;
      widget.project!.conduitRoutes = _routes;
      ProjectRepository.instance.updateProject(widget.project!);
    } else {
      _points = [
        CanvasPoint(id: 'pt-1', type: 'PANEL', label: 'MDP', x: 585, y: 535),
        CanvasPoint(id: 'pt-2', type: 'SWITCH_1G', label: 'S1-1', x: 645, y: 290),
        CanvasPoint(id: 'pt-3', type: 'LIGHT', label: 'L-1', x: 675, y: 345),
        CanvasPoint(id: 'pt-4', type: 'OUTLET_DUPLEX', label: 'CO-1', x: 604, y: 355),
        CanvasPoint(id: 'pt-5', type: 'ACU', label: 'ACU-1', x: 882, y: 435),
      ];
      _routes = [
        ConduitRoute(id: 'rt-1', fromPointId: 'pt-1', toPointId: 'pt-2', measuredLengthMeters: 4.5),
        ConduitRoute(id: 'rt-2', fromPointId: 'pt-2', toPointId: 'pt-3', measuredLengthMeters: 3.2),
        ConduitRoute(id: 'rt-3', fromPointId: 'pt-1', toPointId: 'pt-4', measuredLengthMeters: 5.0),
        ConduitRoute(id: 'rt-4', fromPointId: 'pt-1', toPointId: 'pt-5', measuredLengthMeters: 6.5),
      ];
    }
    if (_blueprintPath != null && PdfBlueprintEngine.isPdf(_blueprintPath)) {
      _loadPdfBlueprint();
    }
  }

  Future<void> _loadPdfBlueprint() async {
    final path = _blueprintPath;
    if (path == null || !PdfBlueprintEngine.isPdf(path)) return;
    if (!File(path).existsSync()) return;

    setState(() => _isRenderingPdf = true);

    try {
      final pages = await PdfBlueprintEngine.getPdfPages(path);
      final rendered = await PdfBlueprintEngine.renderPdfPageToImage(
        path,
        pageIndex: _pdfSheetIndex,
        dpi: 150.0,
      );
      if (mounted) {
        setState(() {
          _pdfPages = pages;
          _renderedPdfImagePath = rendered;
          _isRenderingPdf = false;
        });
      }
    } catch (e) {
      debugPrint('Error rasterizing PDF blueprint: $e');
      if (mounted) setState(() => _isRenderingPdf = false);
    }
  }

  /// Automatically cleans up duplicate MDP panels, legacy residential artifacts, or misaligned coordinates
  void _sanitizeAndFitExistingPointsIfNeeded() {
    final panelCount = _points.where((p) => p.type == 'PANEL').length;
    final bool hasCadBlueprint = _hasBlueprintFile &&
        _blueprintPath != null &&
        PdfBlueprintEngine.isPdf(_blueprintPath!);

    // Detect if points were generated under old coordinate map (e.g. MDP at 480,690 or 155,285, or missing room switches, or containing orphaned WM/REF/RO)
    final bool hasLegacyCadCoords = hasCadBlueprint && (
        _points.any((p) => p.type == 'PANEL' && ((p.x - 585.0).abs() > 5.0 || (p.y - 535.0).abs() > 5.0)) ||
        !_points.any((p) => p.type == 'SWITCH_1G') ||
        _points.any((p) => p.label.startsWith('WM-') || p.label.startsWith('REF-') || p.label.startsWith('RO-'))
    );

    if (panelCount > 1 || hasLegacyCadCoords) {
      if (widget.project != null && widget.project!.applianceLoads.isNotEmpty) {
        _sanitizeProjectApplianceLoads(widget.project!);
        _autoGenerateFromAppliances(widget.project!.applianceLoads);
        widget.project!.canvasPoints = _points;
        widget.project!.conduitRoutes = _routes;
        ProjectRepository.instance.updateProject(widget.project!);
      }
    }
  }

  void _cycleZoomLevel() {
    setState(() {
      if (_currentZoom < 0.55) {
        // Zoom to 0.85x centered on building
        _currentZoom = 0.85;
        _zoomController.value = Matrix4.identity()
          ..translateByDouble(-240.0, -80.0, 0.0, 1.0)
          ..scaleByDouble(_currentZoom, _currentZoom, 1.0, 1.0);
      } else if (_currentZoom < 1.25) {
        // Zoom to 1.45x for detailed room inspection
        _currentZoom = 1.45;
        _zoomController.value = Matrix4.identity()
          ..translateByDouble(-540.0, -220.0, 0.0, 1.0)
          ..scaleByDouble(_currentZoom, _currentZoom, 1.0, 1.0);
      } else {
        // Reset to Full Sheet Fit (0.39x)
        _fitSheetToViewport();
      }
    });
  }

  String _getShorthandLabel(String pointType, String originalName, int index) {
    if (pointType == 'PANEL') return 'MDP';
    if (pointType == 'ACU') return 'ACU-$index';
    if (pointType == 'LIGHT') return 'L-$index';
    if (pointType == 'SWITCH_1G') {
      if (originalName.startsWith('S')) return originalName;
      return 'S-$index';
    }
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
    if (widget.project != null) {
      _sanitizeProjectApplianceLoads(widget.project!);
      appliances = widget.project!.applianceLoads;
    }
    final bool hasCadBlueprint = _hasBlueprintFile &&
        _blueprintPath != null &&
        PdfBlueprintEngine.isPdf(_blueprintPath!);

    if (hasCadBlueprint) {
      _autoGenerateForCadBuildingBlueprint(appliances);
      return;
    }

    _autoGenerateForStandardDwelling(appliances);
  }

  /// High-Precision PEC 2017 & IESNA Placement for 1000 x 1220 Cropped CAD Building Blueprint
  void _autoGenerateForCadBuildingBlueprint(List<ApplianceItem> appliances) {
    // Main Distribution Panel (MDP) at Landing / Central Corridor structural wall (x: 585, y: 535)
    final panelPt = CanvasPoint(id: 'pt-panel', type: 'PANEL', label: 'MDP', x: 585.0, y: 535.0, circuitNumber: 0);
    _points = [panelPt];
    _routes = [];

    // Visually Verified Room Ceiling Luminaire Grids on 1000 x 1220 Cropped CAD Sheet
    final Map<String, List<Offset>> roomCeilingMap = {
      'function': [
        // 2x4 Symmetrical Ceiling Grid inside Function Hall (Grids 1-7, Bays A-C: x=210..730, y=55..265)
        const Offset(270.0, 105.0),
        const Offset(400.0, 105.0),
        const Offset(530.0, 105.0),
        const Offset(660.0, 105.0),
        const Offset(270.0, 210.0),
        const Offset(400.0, 210.0),
        const Offset(530.0, 210.0),
        const Offset(660.0, 210.0),
      ],
      'staff': [
        // Staff Room Ceiling (Grids 7-10, Bays B-C: x=755..880, y=160..265)
        const Offset(790.0, 210.0),
        const Offset(850.0, 210.0),
      ],
      'office': [
        // 2x2 Symmetrical Ceiling Grid inside Office Rooms (Grids 5-10, Bays C-E: x=600..880, y=290..515)
        const Offset(675.0, 345.0),
        const Offset(810.0, 345.0),
        const Offset(675.0, 455.0),
        const Offset(810.0, 455.0),
      ],
      'landing': [
        // Stairs & Landing Ceiling (Grids 5-9, Bays E-G: x=515..850, y=535..655)
        const Offset(555.0, 585.0),
        const Offset(795.0, 595.0),
      ],
      'storage': [
        // Storage Room Ceiling (Grids 7-10, Bays G-H: x=755..880, y=675..735)
        const Offset(790.0, 706.0),
        const Offset(850.0, 706.0),
      ],
    };

    // Visually Verified Door Switch Positions per Room
    final Map<String, Map<String, dynamic>> roomSwitchMap = {
      'function': {'pos': const Offset(255.0, 262.0), 'label': 'S3', 'ckt': 1},
      'staff':    {'pos': const Offset(755.0, 255.0), 'label': 'S1', 'ckt': 1},
      'office':   {'pos': const Offset(645.0, 290.0), 'label': 'S2', 'ckt': 2},
      'landing':  {'pos': const Offset(530.0, 545.0), 'label': 'S3w', 'ckt': 2},
      'storage':  {'pos': const Offset(795.0, 676.0), 'label': 'S1', 'ckt': 2},
    };

    // Visually Verified Wall Convenience Outlet Anchors per Room
    final Map<String, List<Offset>> roomOutletMap = {
      'function': [
        const Offset(208.0, 105.0), // West exterior wall upper
        const Offset(208.0, 210.0), // West exterior wall lower
        const Offset(335.0, 52.0),  // North exterior wall left
        const Offset(595.0, 52.0),  // North exterior wall right
        const Offset(732.0, 155.0), // East partition wall
        const Offset(465.0, 268.0), // South partition wall
      ],
      'staff': [
        const Offset(755.0, 180.0), // West partition wall
        const Offset(820.0, 158.0), // North wall
      ],
      'office': [
        const Offset(604.0, 355.0), // West corridor partition upper
        const Offset(604.0, 455.0), // West corridor partition lower
        const Offset(740.0, 515.0), // South partition wall
        const Offset(880.0, 345.0), // East exterior wall upper
      ],
      'landing': [
        const Offset(650.0, 536.0), // Landing corridor wall
      ],
      'storage': [
        const Offset(755.0, 706.0), // Storage west wall
      ],
    };

    // Visually Verified Exterior Window/Wall ACU Anchors per Room
    final Map<String, List<Offset>> roomAcuMap = {
      'function': [
        const Offset(270.0, 52.0),  // North exterior wall Bay 1-3
        const Offset(475.0, 52.0),  // North exterior wall Bay 3-5
      ],
      'staff': [
        const Offset(882.0, 210.0), // East exterior wall
      ],
      'office': [
        const Offset(882.0, 435.0), // East exterior wall W5
      ],
    };

    String getRoomKey(String roomCategory) {
      final lower = roomCategory.toLowerCase();
      if (lower.contains('hall') || lower.contains('event') || lower.contains('function')) return 'function';
      if (lower.contains('staff')) return 'staff';
      if (lower.contains('office')) return 'office';
      if (lower.contains('storage') || lower.contains('store')) return 'storage';
      if (lower.contains('landing') || lower.contains('stair')) return 'landing';
      return 'function';
    }

    // Group expanded fixture counts per room
    final Map<String, int> roomLightCounts = {};
    final Map<String, int> roomOutletCounts = {};
    final Map<String, int> roomAcuCounts = {};

    for (final app in appliances) {
      final rKey = getRoomKey(app.roomCategory);
      final lowerName = app.name.toLowerCase();
      final pcsMatch = RegExp(r'(?:x|\()\s*(\d+)\s*pcs', caseSensitive: false).firstMatch(app.name);
      final int packMult = pcsMatch != null ? (int.tryParse(pcsMatch.group(1)!) ?? 1) : 1;

      if (lowerName.contains('aircon') || lowerName.contains('acu')) {
        // Storage and Landing never get ACUs
        if (rKey != 'storage' && rKey != 'landing') {
          roomAcuCounts[rKey] = (roomAcuCounts[rKey] ?? 0) + app.quantity;
        }
      } else if (lowerName.contains('light') ||
          lowerName.contains('luminaire') ||
          lowerName.contains('led') ||
          lowerName.contains('pinlight') ||
          lowerName.contains('panel') ||
          lowerName.contains('chandelier') ||
          lowerName.contains('tube')) {
        roomLightCounts[rKey] = (roomLightCounts[rKey] ?? 0) + (app.quantity * packMult);
      } else if (!lowerName.contains('fan')) {
        roomOutletCounts[rKey] = (roomOutletCounts[rKey] ?? 0) + app.quantity;
      }
    }

    int lightCounter = 1;
    int outletCounter = 1;
    int acuCounter = 1;
    int routeCounter = 1;

    final orderedRooms = ['function', 'staff', 'office', 'landing', 'storage'];

    for (final rKey in orderedRooms) {
      final ceilAnchors = roomCeilingMap[rKey]!;
      final rawLights = roomLightCounts[rKey] ?? 0;
      // Cap ceiling lights to room's architectural grid capacity so icons never overlap
      final int numLights = rawLights > 0 ? math.min(rawLights, ceilAnchors.length) : 0;

      // 1. Place Room Wall Switch + Symmetrical Ceiling Lights (Lighting Layer E-1)
      if (numLights > 0) {
        final swInfo = roomSwitchMap[rKey]!;
        final Offset swPos = swInfo['pos'] as Offset;
        final String swLabel = swInfo['label'] as String;
        final int swCkt = swInfo['ckt'] as int;
        final String swId = 'pt-sw-$rKey';

        _points.add(CanvasPoint(
          id: swId,
          type: 'SWITCH_1G',
          label: swLabel,
          x: swPos.dx,
          y: swPos.dy,
          circuitNumber: swCkt,
        ));

        // Home-run from MDP to Room Switch (renders as crisp CAD Home-Run Arrowhead)
        _routes.add(ConduitRoute(
          id: 'rt-${routeCounter++}',
          fromPointId: 'pt-panel',
          toPointId: swId,
          measuredLengthMeters: 5.5,
        ));

        String prevLightId = swId;
        for (int i = 0; i < numLights; i++) {
          final pos = ceilAnchors[i];
          final String lId = 'pt-l-$lightCounter';
          _points.add(CanvasPoint(
            id: lId,
            type: 'LIGHT',
            label: 'L-${lightCounter++}',
            x: pos.dx,
            y: pos.dy,
            circuitNumber: swCkt,
          ));

          // Intra-room conduit from Switch -> Light 1 -> Light 2...
          _routes.add(ConduitRoute(
            id: 'rt-${routeCounter++}',
            fromPointId: prevLightId,
            toPointId: lId,
            measuredLengthMeters: 2.6,
          ));
          prevLightId = lId;
        }
      }

      // 2. Place Room Convenience Outlets (Power Layer E-2)
      final outAnchors = roomOutletMap[rKey]!;
      final rawOutlets = roomOutletCounts[rKey] ?? 0;
      final int numOutlets = rawOutlets > 0 ? math.min(rawOutlets, outAnchors.length) : 0;
      final int powerCkt = rKey == 'function' ? 3 : (rKey == 'office' ? 4 : 5);

      String prevOutletId = 'pt-panel';
      for (int i = 0; i < numOutlets; i++) {
        final pos = outAnchors[i];
        final String cId = 'pt-co-$outletCounter';
        _points.add(CanvasPoint(
          id: cId,
          type: 'OUTLET_DUPLEX',
          label: 'CO-${outletCounter++}',
          x: pos.dx,
          y: pos.dy,
          circuitNumber: powerCkt,
        ));

        _routes.add(ConduitRoute(
          id: 'rt-${routeCounter++}',
          fromPointId: prevOutletId,
          toPointId: cId,
          measuredLengthMeters: prevOutletId == 'pt-panel' ? 6.0 : 3.2,
        ));
        prevOutletId = cId;
      }

      // 3. Place Dedicated Air Conditioning Units (Power Layer E-2)
      final acuAnchors = roomAcuMap[rKey] ?? const [];
      final rawAcus = roomAcuCounts[rKey] ?? 0;
      final int numAcus = rawAcus > 0 ? math.min(rawAcus, acuAnchors.length) : 0;

      for (int i = 0; i < numAcus; i++) {
        final pos = acuAnchors[i];
        final String aId = 'pt-acu-$acuCounter';
        final int acuCkt = 5 + acuCounter;
        _points.add(CanvasPoint(
          id: aId,
          type: 'ACU',
          label: 'ACU-${acuCounter++}',
          x: pos.dx,
          y: pos.dy,
          circuitNumber: acuCkt,
        ));

        // Dedicated Home-run from MDP (renders as crisp CAD Home-Run Arrowhead)
        _routes.add(ConduitRoute(
          id: 'rt-${routeCounter++}',
          fromPointId: 'pt-panel',
          toPointId: aId,
          measuredLengthMeters: 7.5,
        ));
      }
    }
  }
  /// Standard Residential 4-Room Fallback Auto-Placement
  void _autoGenerateForStandardDwelling(List<ApplianceItem> appliances) {
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
        _routes.add(ConduitRoute(
          id: 'rt-${routeCounter++}',
          fromPointId: 'pt-panel',
          toPointId: pId,
          measuredLengthMeters: 7.5,
        ));
      } else {
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
    if (_selectedTool == 'PAN') return;

    final tapX = details.localPosition.dx;
    final tapY = details.localPosition.dy;
    _dragStartOffset = details.localPosition;
    _hasMovedSignificantly = false;

    if (_selectedTool == 'CALIBRATE') {
      final tapPos = details.localPosition;
      if ((_pinA - tapPos).distance <= 28.0) {
        setState(() => _activeDraggingPin = 1);
        return;
      } else if ((_pinB - tapPos).distance <= 28.0) {
        setState(() => _activeDraggingPin = 2);
        return;
      } else {
        final mid = Offset((_pinA.dx + _pinB.dx) / 2, (_pinA.dy + _pinB.dy) / 2);
        if ((mid - tapPos).distance <= 32.0) {
          _showCalibrationDialog();
          return;
        }
      }
    }

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
    if (_selectedTool == 'CALIBRATE' && _activeDraggingPin != null) {
      final newPos = details.localPosition;
      if (_dragStartOffset != null && (newPos - _dragStartOffset!).distance > 6.0) {
        _hasMovedSignificantly = true;
      }

      // Magnetic snapping candidate anchors (all points, corners, and grid lines)
      final List<Offset> snapAnchors = [];
      for (final p in _points) {
        snapAnchors.add(Offset(p.x, p.y));
      }
      snapAnchors.addAll([
        const Offset(45, 145),
        const Offset(275, 145),
        const Offset(275, 395),
        const Offset(45, 395),
        const Offset(132, 145),
        const Offset(132, 395),
      ]);

      Offset targetPos = newPos;
      Offset? foundSnap;
      for (final a in snapAnchors) {
        if ((a - newPos).distance <= 16.0) {
          targetPos = a;
          foundSnap = a;
          break;
        }
      }

      if (foundSnap != null && foundSnap != _activeSnapPoint) {
        HapticFeedback.selectionClick();
      }

      setState(() {
        _activeSnapPoint = foundSnap;
        if (_activeDraggingPin == 1) {
          _pinA = targetPos;
        } else if (_activeDraggingPin == 2) {
          _pinB = targetPos;
        }
      });
      return;
    }

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
    if (_selectedTool == 'CALIBRATE') {
      final hadDrag = _hasMovedSignificantly;
      setState(() {
        _activeDraggingPin = null;
        _activeSnapPoint = null;
        _dragStartOffset = null;
        _hasMovedSignificantly = false;
      });
      if (!hadDrag) {
        _showCalibrationDialog();
      }
      return;
    }

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


  void _populateDevicesInsidePolygon(String roomName, List<Offset> polygon) {
    if (polygon.length < 3 || widget.project == null) return;

    // Filter loads corresponding to this room
    final lowerRoom = roomName.toLowerCase();
    final List<ApplianceItem> roomLoads = widget.project!.applianceLoads.where((a) {
      final cat = (a.roomCategory).toLowerCase();
      if (lowerRoom.contains('hall') || lowerRoom.contains('event')) {
        return cat.contains('hall') || cat.contains('event');
      }
      if (lowerRoom.contains('staff')) return cat.contains('staff');
      if (lowerRoom.contains('office')) return cat.contains('office');
      if (lowerRoom.contains('storage') || lowerRoom.contains('store')) {
        return cat.contains('storage') || cat.contains('store');
      }
      if (lowerRoom.contains('landing') || lowerRoom.contains('stair')) {
        return cat.contains('landing') || cat.contains('stair');
      }
      return cat == lowerRoom;
    }).toList();

    if (roomLoads.isEmpty) return;

    // Compute bounding box and centroid
    double minX = polygon.map((p) => p.dx).reduce(math.min);
    double maxX = polygon.map((p) => p.dx).reduce(math.max);
    double minY = polygon.map((p) => p.dy).reduce(math.min);
    double maxY = polygon.map((p) => p.dy).reduce(math.max);

    final double width = maxX - minX;
    final double height = maxY - minY;
    final Offset center = Offset(minX + width / 2, minY + height / 2);

    // Remove old points for this room
    final oldPointsToRemove = _points.where((p) {
      return p.x >= minX - 10 && p.x <= maxX + 10 && p.y >= minY - 10 && p.y <= maxY + 10;
    }).map((p) => p.id).toSet();
    _points.removeWhere((p) => oldPointsToRemove.contains(p.id));
    _routes.removeWhere((r) => oldPointsToRemove.contains(r.fromPointId) || oldPointsToRemove.contains(r.toPointId));

    int devCount = _points.length + 1;
    int routeCount = _routes.length + 1;
    String lastLightId = 'pt-panel';
    String lastOutletId = 'pt-panel';

    // Separate into ceiling and wall appliances
    final List<Map<String, dynamic>> ceilingItems = [];
    final List<Map<String, dynamic>> wallItems = [];

    for (final app in roomLoads) {
      for (int i = 0; i < app.quantity; i++) {
        String pType = 'OUTLET_DUPLEX';
        if (app.name.toLowerCase().contains('aircon') || app.name.toLowerCase().contains('acu')) {
          pType = 'ACU';
        } else if (app.name.toLowerCase().contains('light') ||
            app.name.toLowerCase().contains('fan') ||
            app.name.toLowerCase().contains('luminaire') ||
            app.name.toLowerCase().contains('led') ||
            app.name.toLowerCase().contains('pinlight') ||
            app.name.toLowerCase().contains('panel')) {
          pType = 'LIGHT';
        } else if (app.name.toLowerCase().contains('switch')) {
          pType = 'SWITCH_1G';
        }

        final item = {
          'id': 'pt-${devCount++}',
          'type': pType,
          'name': app.name,
          'circuit': app.circuitNumber,
          'isDedicated': app.isDedicatedCircuit,
        };

        if (pType == 'LIGHT' || pType == 'FAN') {
          ceilingItems.add(item);
        } else {
          wallItems.add(item);
        }
      }
    }

    // 1. Symmetrical Ceiling Grid inside room polygon
    if (ceilingItems.length == 1) {
      final item = ceilingItems.first;
      _points.add(CanvasPoint(
        id: item['id'],
        type: item['type'],
        label: _getShorthandLabel(item['type'], item['name'], _points.length + 1),
        x: center.dx,
        y: center.dy,
        circuitNumber: item['circuit'],
      ));
      _routes.add(ConduitRoute(id: 'rt-${routeCount++}', fromPointId: 'pt-panel', toPointId: item['id'], measuredLengthMeters: 4.5));
    } else if (ceilingItems.isNotEmpty) {
      final int cols = math.max(1, math.sqrt(ceilingItems.length).ceil());
      final int rows = (ceilingItems.length / cols).ceil();
      final double stepX = width / (cols + 1);
      final double stepY = height / (rows + 1);

      for (int i = 0; i < ceilingItems.length; i++) {
        final item = ceilingItems[i];
        final int c = i % cols;
        final int r = i ~/ cols;
        final double px = minX + stepX * (c + 1);
        final double py = minY + stepY * (r + 1);

        final pId = item['id'];
        _points.add(CanvasPoint(
          id: pId,
          type: item['type'],
          label: _getShorthandLabel(item['type'], item['name'], _points.length + 1),
          x: px,
          y: py,
          circuitNumber: item['circuit'],
        ));

        _routes.add(ConduitRoute(
          id: 'rt-${routeCount++}',
          fromPointId: lastLightId,
          toPointId: pId,
          measuredLengthMeters: lastLightId == 'pt-panel' ? 5.0 : 2.8,
        ));
        lastLightId = pId;
      }
    }

    // 2. Perimeter Wall Placement (Outlets, ACUs, Switches)
    // Sample points along the polygon segments
    final List<Offset> wallAnchors = [];
    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];
      wallAnchors.add(Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2));
      wallAnchors.add(Offset((p1.dx * 0.75 + p2.dx * 0.25), (p1.dy * 0.75 + p2.dy * 0.25)));
      wallAnchors.add(Offset((p1.dx * 0.25 + p2.dx * 0.75), (p1.dy * 0.25 + p2.dy * 0.75)));
    }

    for (int i = 0; i < wallItems.length; i++) {
      final item = wallItems[i];
      final anchor = wallAnchors[i % wallAnchors.length];
      final pId = item['id'];
      final bool isDedicated = item['isDedicated'] || item['type'] == 'ACU';

      _points.add(CanvasPoint(
        id: pId,
        type: item['type'],
        label: _getShorthandLabel(item['type'], item['name'], _points.length + 1),
        x: anchor.dx,
        y: anchor.dy,
        circuitNumber: item['circuit'],
      ));

      if (isDedicated) {
        _routes.add(ConduitRoute(
          id: 'rt-${routeCount++}',
          fromPointId: 'pt-panel',
          toPointId: pId,
          measuredLengthMeters: 6.5,
        ));
      } else {
        _routes.add(ConduitRoute(
          id: 'rt-${routeCount++}',
          fromPointId: lastOutletId,
          toPointId: pId,
          measuredLengthMeters: lastOutletId == 'pt-panel' ? 4.5 : 3.0,
        ));
        lastOutletId = pId;
      }
    }

    // Persist to project
    widget.project!.canvasPoints = _points;
    widget.project!.conduitRoutes = _routes;
    ProjectRepository.instance.updateProject(widget.project!);
  }

  void _handleCanvasTap(TapUpDetails details) {
    if (_selectedTool == 'CALIBRATE_ROOM') {
      setState(() {
        _activePolygonPoints.add(details.localPosition);
      });
      HapticFeedback.selectionClick();
      return;
    }

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
          
          // Room Calibration Active Banner
          if (_selectedTool == 'CALIBRATE_ROOM')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFF1F2937),
              child: Row(
                children: [
                  const Icon(Icons.touch_app, color: BanaagTheme.primaryAmber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Builder(builder: (ctx) {
                      final roomList = widget.project?.spaces.map((s) => s.name).toList() ??
                          ['Function Hall / Event Place', 'Staff Room', 'Office Rooms', 'Storage Room', 'Landing'];
                      final currentRoom = roomList[_activeCalibratingRoomIndex % roomList.length];
                      return Text(
                        'Tap corners of: $currentRoom (${_activePolygonPoints.length} pts)',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      );
                    }),
                  ),
                  if (_activePolygonPoints.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.undo, color: Colors.orangeAccent, size: 20),
                      tooltip: 'Undo Last Corner',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _activePolygonPoints.removeLast();
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BanaagTheme.primaryAmber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(50, 30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _activePolygonPoints.length < 3
                          ? null
                          : () {
                              final roomList = widget.project?.spaces.map((s) => s.name).toList() ??
                                  ['Function Hall / Event Place', 'Staff Room', 'Office Rooms', 'Storage Room', 'Landing'];
                              final currentRoom = roomList[_activeCalibratingRoomIndex % roomList.length];

                              setState(() {
                                final pts = List<Offset>.from(_activePolygonPoints);
                                _calibratedRoomPolygons[currentRoom] = pts;
                                _populateDevicesInsidePolygon(currentRoom, pts);
                                _activePolygonPoints.clear();
                                _activeCalibratingRoomIndex++;

                                if (_activeCalibratingRoomIndex >= roomList.length) {
                                  _selectedTool = 'SELECT';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('🎉 All rooms calibrated and populated according to PEC 2017 & IESNA!'),
                                      backgroundColor: BanaagTheme.successGreen,
                                    ),
                                  );
                                } else {
                                  final nextRoom = roomList[_activeCalibratingRoomIndex % roomList.length];
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✅ $currentRoom locked! Next: Tap corners of $nextRoom.'),
                                      backgroundColor: BanaagTheme.primaryAmber,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              });
                            },
                      child: const Text('Lock & Populate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ),

          // Takeoff Summary Live Ribbon with 1-Tap Load Schedule Populate Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFF1B2028),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _metricMini('Total Wire', '${takeoff.totalThhnWireMeters.toStringAsFixed(0)} m', '(${takeoff.wireRollsCount.toStringAsFixed(1)} rolls)'),
                    _metricMini('Conduit', '${takeoff.totalConduitMeters.toStringAsFixed(0)} m', '(${takeoff.totalPvcPipesPcs} pipes)'),
                    _metricMini('Boxes', '${takeoff.utilityBoxesCount + takeoff.octagonalBoxesCount} pcs', '(${takeoff.conduitClampsCount} clamps)'),
                    _metricMini('Estimated', '₱${takeoff.grandTotalEstimatedCost.toStringAsFixed(0)}', 'Mat+Labor', color: BanaagTheme.primaryAmber),
                  ],
                ),
                if (widget.project != null && widget.project!.applianceLoads.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 30,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BanaagTheme.primaryAmber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: const Icon(Icons.flash_on, size: 15),
                            label: Text(
                              '⚡ Populate Plan (${_points.length} pts)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () {
                              setState(() {
                                _autoGenerateFromAppliances(widget.project!.applianceLoads);
                                widget.project!.canvasPoints = _points;
                                widget.project!.conduitRoutes = _routes;
                                ProjectRepository.instance.updateProject(widget.project!);
                                _selectedPoint = null;
                                _fitSheetToViewport();
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('⚡ ${_points.length} devices auto-populated across rooms according to PEC 2017 & IESNA!'),
                                  backgroundColor: BanaagTheme.successGreen,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _layerFilterChip('ALL', 'All'),
                      const SizedBox(width: 4),
                      _layerFilterChip('LIGHTING', '💡 E-1'),
                      const SizedBox(width: 4),
                      _layerFilterChip('POWER', '🔌 E-2'),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Interactive 2D Grid Canvas with Unconstrained 1000x1220 CAD Sheet
          Expanded(
            child: Container(
              color: const Color(0xFF16191F),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Unconstrained 1000x1220 CAD World Sheet: Floor Plan + Electrical Symbols locked 1:1
                  InteractiveViewer(
                    transformationController: _zoomController,
                    constrained: false,
                    minScale: 0.25,
                    maxScale: 4.5,
                    panEnabled: _selectedTool == 'PAN' || _draggedPoint == null,
                    scaleEnabled: true,
                    panAxis: PanAxis.free,
                    boundaryMargin: const EdgeInsets.all(600.0),
                    onInteractionEnd: (_) {
                      setState(() {
                        _currentZoom = _zoomController.value.getMaxScaleOnAxis();
                      });
                    },
                    child: SizedBox(
                      width: 1000.0,
                      height: 1220.0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: _handleCanvasTap,
                        onPanStart: _selectedTool == 'PAN' ? null : _handlePanStart,
                        onPanUpdate: _selectedTool == 'PAN' ? null : _handlePanUpdate,
                        onPanEnd: _selectedTool == 'PAN' ? null : _handlePanEnd,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Blueprint Floor Plan Underlay locked to 1000 x 1220
                            if (_hasBlueprintFile && _isUnderlayVisible)
                              Positioned.fill(
                                child: Opacity(
                                  opacity: _underlayOpacity,
                                  child: _blueprintPath!.toLowerCase().endsWith('.pdf')
                                      ? (_renderedPdfImagePath != null && File(_renderedPdfImagePath!).existsSync()
                                          ? ColorFiltered(
                                              colorFilter: _invertBlueprint
                                                  ? const ColorFilter.matrix([
                                                      -1.0,  0.0,  0.0, 0.0, 255.0,
                                                       0.0, -1.0,  0.0, 0.0, 255.0,
                                                       0.0,  0.0, -1.0, 0.0, 255.0,
                                                       0.0,  0.0,  0.0, 1.0,   0.0,
                                                    ])
                                                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                                              child: Image.file(
                                                File(_renderedPdfImagePath!),
                                                width: 1000.0,
                                                height: 1220.0,
                                                fit: BoxFit.fill,
                                                errorBuilder: (ctx, err, stack) => _buildPdfUnderlayPlaceholder(),
                                              ),
                                            )
                                          : (_isRenderingPdf
                                              ? const Center(
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      CircularProgressIndicator(color: BanaagTheme.primaryAmber),
                                                      SizedBox(height: 12),
                                                      Text(
                                                        'Rendering Architectural Blueprint...',
                                                        style: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : _buildPdfUnderlayPlaceholder()))
                                      : Image.file(
                                          File(_blueprintPath!),
                                          width: 1000.0,
                                          height: 1220.0,
                                          fit: BoxFit.fill,
                                          errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                                        ),
                                ),
                              ),

                            // 2. Interactive Vector Electrical Layer locked to 1000 x 1220
                            CustomPaint(
                              size: const Size(1000.0, 1220.0),
                              painter: CanvasPainter(
                                points: _points,
                                routes: _routes,
                                roomGeometry: _roomGeometry,
                                spaces: widget.project?.spaces ?? [],
                                isHeatmap: _isHeatmapVisible,
                                showLabels: _showLabels,
                                showConduits: _showConduits,
                                activeLayerFilter: _activeLayerFilter,
                                hasBlueprintUnderlay: _hasBlueprintFile && _isUnderlayVisible,
                                selectedPoint: _selectedPoint,
                                isCalibrating: _selectedTool == 'CALIBRATE',
                                pinA: _pinA,
                                pinB: _pinB,
                                activeSnapPoint: _activeSnapPoint,
                                pixelsPerMeter: _pixelsPerMeter,
                                activePolygonPoints: _activePolygonPoints,
                                calibratedRoomPolygons: _calibratedRoomPolygons,
                              ),
                            ),
                          ],
                        ),
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
                              constraints: const BoxConstraints(maxWidth: 100),
                              child: Text(
                                _blueprintPath!.split(Platform.pathSeparator).last,
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_blueprintPath!.toLowerCase().endsWith('.pdf') && _pdfPages.length > 1) ...[
                              const SizedBox(width: 4),
                              PopupMenuButton<int>(
                                tooltip: 'Switch Blueprint Sheet',
                                color: BanaagTheme.surfaceCard,
                                padding: EdgeInsets.zero,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Sheet ${_pdfSheetIndex + 1}',
                                        style: const TextStyle(
                                          color: BanaagTheme.primaryAmber,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down, size: 14, color: BanaagTheme.primaryAmber),
                                    ],
                                  ),
                                ),
                                onSelected: (idx) {
                                  if (idx != _pdfSheetIndex) {
                                    setState(() {
                                      _pdfSheetIndex = idx;
                                    });
                                    _loadPdfBlueprint();
                                  }
                                },
                                itemBuilder: (context) => _pdfPages.map((p) {
                                  final isCurrent = p.pageIndex == _pdfSheetIndex;
                                  return PopupMenuItem<int>(
                                    value: p.pageIndex,
                                    child: Row(
                                      children: [
                                        Icon(
                                          isCurrent ? Icons.check_circle : Icons.layers_outlined,
                                          size: 16,
                                          color: isCurrent ? BanaagTheme.primaryAmber : Colors.white70,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          p.label,
                                          style: TextStyle(
                                            color: isCurrent ? BanaagTheme.primaryAmber : Colors.white,
                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _invertBlueprint = !_invertBlueprint;
                                  if (widget.project != null) {
                                    widget.project!.invertBlueprint = _invertBlueprint;
                                    ProjectRepository.instance.updateProject(widget.project!);
                                  }
                                });
                              },
                              child: Tooltip(
                                message: 'Invert Blueprint Contrast',
                                child: Icon(
                                  Icons.contrast,
                                  size: 15,
                                  color: _invertBlueprint ? BanaagTheme.primaryAmber : Colors.white54,
                                ),
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
                        // 1-Tap Auto-Fit Items & Sheet to Plan Button
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
                              _fitSheetToViewport();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🎯 Sheet & Devices fitted strictly inside Floor Plan rooms!'),
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
                  _symbolButton('PAN', Icons.pan_tool, 'Pan / Zoom'),
                  _symbolButton('SELECT', Icons.near_me, 'Select / Move'),
                  _symbolButton('CALIBRATE_ROOM', Icons.polyline, 'Calibrate Room'),
                  _symbolButton('CALIBRATE', Icons.straighten, 'Scale (mm)'),
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

  void _showCalibrationDialog() {
    final pixelDist = (_pinA - _pinB).distance;
    if (pixelDist < 5.0) return;

    bool isMm = true;
    final currentCalibratedMm = (pixelDist / _pixelsPerMeter) * 1000.0;
    final distCtrl = TextEditingController(
      text: currentCalibratedMm.round().toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: BanaagTheme.surfaceCard,
          title: Row(
            children: const [
              Icon(Icons.straighten, color: BanaagTheme.primaryAmber, size: 20),
              SizedBox(width: 8),
              Text(
                '2-Point Scale Calibration',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CAD Pixel Distance: ${pixelDist.toStringAsFixed(1)} px',
                style: const TextStyle(fontSize: 12, color: Colors.cyanAccent),
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter the known physical length between Pin A and Pin B:',
                style: TextStyle(fontSize: 11, color: BanaagTheme.textMuted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: distCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: isMm ? 'Distance (mm)' : 'Distance (m)',
                        isDense: true,
                        suffixText: isMm ? 'mm' : 'm',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(isMm ? 'mm' : 'meters', style: const TextStyle(fontSize: 11)),
                    selected: true,
                    selectedColor: BanaagTheme.primaryAmber,
                    onSelected: (_) {
                      setDlgState(() {
                        final currentVal = double.tryParse(distCtrl.text.trim()) ?? 0.0;
                        if (isMm) {
                          distCtrl.text = (currentVal / 1000.0).toStringAsFixed(3);
                        } else {
                          distCtrl.text = (currentVal * 1000.0).round().toString();
                        }
                        isMm = !isMm;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Quick Presets:', style: TextStyle(fontSize: 10, color: Colors.white60)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  ActionChip(
                    label: const Text('15500 mm (15.5m)', style: TextStyle(fontSize: 10, color: BanaagTheme.primaryAmber)),
                    onPressed: () => setDlgState(() {
                      distCtrl.text = isMm ? '15500' : '15.500';
                    }),
                  ),
                  ActionChip(
                    label: const Text('18480 mm (18.5m)', style: TextStyle(fontSize: 10, color: BanaagTheme.primaryAmber)),
                    onPressed: () => setDlgState(() {
                      distCtrl.text = isMm ? '18480' : '18.480';
                    }),
                  ),
                  ActionChip(
                    label: const Text('3400 mm (3.4m)', style: TextStyle(fontSize: 10)),
                    onPressed: () => setDlgState(() {
                      distCtrl.text = isMm ? '3400' : '3.400';
                    }),
                  ),
                  ActionChip(
                    label: const Text('4800 mm (4.8m)', style: TextStyle(fontSize: 10)),
                    onPressed: () => setDlgState(() {
                      distCtrl.text = isMm ? '4800' : '4.800';
                    }),
                  ),
                  ActionChip(
                    label: const Text('3000 mm (3m)', style: TextStyle(fontSize: 10)),
                    onPressed: () => setDlgState(() {
                      distCtrl.text = isMm ? '3000' : '3.000';
                    }),
                  ),
                  ActionChip(
                    label: const Text('4000 mm (4m)', style: TextStyle(fontSize: 10)),
                    onPressed: () => setDlgState(() {
                      distCtrl.text = isMm ? '4000' : '4.000';
                    }),
                  ),
                  ActionChip(
                    label: const Text('6000 mm (6m)', style: TextStyle(fontSize: 10)),
                    onPressed: () => setDlgState(() {
                      distCtrl.text = isMm ? '6000' : '6.000';
                    }),
                  ),
                  ActionChip(
                    label: const Text('8000 mm (8m)', style: TextStyle(fontSize: 10)),
                    onPressed: () => setDlgState(() {
                      distCtrl.text = isMm ? '8000' : '8.000';
                    }),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: BanaagTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: BanaagTheme.primaryAmber,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final val = double.tryParse(distCtrl.text.trim()) ?? 0.0;
                if (val > 0) {
                  final double distMeters = isMm ? (val / 1000.0) : val;
                  final double newPixelsPerMeter = pixelDist / distMeters;

                  setState(() {
                    _pixelsPerMeter = newPixelsPerMeter;

                    // Recalculate all conduit routes
                    for (int i = 0; i < _routes.length; i++) {
                      final r = _routes[i];
                      final p1 = _points.firstWhere((p) => p.id == r.fromPointId, orElse: () => _points.first);
                      final p2 = _points.firstWhere((p) => p.id == r.toPointId, orElse: () => _points.first);
                      final px = (Offset(p1.x, p1.y) - Offset(p2.x, p2.y)).distance;
                      final realMeters = px / _pixelsPerMeter;
                      _routes[i] = ConduitRoute(
                        id: r.id,
                        fromPointId: r.fromPointId,
                        toPointId: r.toPointId,
                        measuredLengthMeters: double.parse(realMeters.clamp(1.0, 99.0).toStringAsFixed(2)),
                        conductorCount: r.conductorCount,
                      );
                    }

                    if (widget.project != null) {
                      widget.project!.calibrationPixelsPerMeter = _pixelsPerMeter;
                      widget.project!.conduitRoutes = _routes;
                      ProjectRepository.instance.updateProject(widget.project!);
                    }
                  });

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Scale Calibrated! (${(distMeters * 1000).round()} mm) - All conduit takeoffs updated.'),
                      backgroundColor: BanaagTheme.successGreen,
                    ),
                  );
                }
              },
              child: const Text('Apply Calibration'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _layerFilterChip(String mode, String label) {
    final bool isSel = _activeLayerFilter == mode;
    return GestureDetector(
      onTap: () => setState(() => _activeLayerFilter = mode),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSel ? Colors.cyanAccent.withValues(alpha: 0.22) : const Color(0xFF262C38),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSel ? Colors.cyanAccent : Colors.white24,
            width: isSel ? 1.3 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSel ? Colors.cyanAccent : Colors.white70,
            fontSize: 10.5,
            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
          ),
        ),
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
          _pdfSheetIndex = 0;
          _renderedPdfImagePath = null;
          if (widget.project != null) {
            widget.project!.blueprintImagePath = path;
            ProjectRepository.instance.updateProject(widget.project!);
          }
        });
        if (PdfBlueprintEngine.isPdf(path)) {
          _loadPdfBlueprint();
        }
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
  final List<RoomSpace> spaces;
  final bool isHeatmap;
  final bool showLabels;
  final bool showConduits;
  final String activeLayerFilter;
  final bool hasBlueprintUnderlay;
  final CanvasPoint? selectedPoint;
  final bool isCalibrating;
  final Offset pinA;
  final Offset pinB;
  final Offset? activeSnapPoint;
  final double pixelsPerMeter;
  final List<Offset> activePolygonPoints;
  final Map<String, List<Offset>> calibratedRoomPolygons;

  CanvasPainter({
    required this.points,
    required this.routes,
    this.roomGeometry,
    this.spaces = const [],
    this.isHeatmap = false,
    this.showLabels = true,
    this.showConduits = true,
    this.activeLayerFilter = 'ALL',
    this.hasBlueprintUnderlay = false,
    this.selectedPoint,
    this.isCalibrating = false,
    this.pinA = const Offset(60, 200),
    this.pinB = const Offset(240, 200),
    this.activeSnapPoint,
    this.pixelsPerMeter = 30.0,
    this.activePolygonPoints = const [],
    this.calibratedRoomPolygons = const {},
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

    // Draw Auto-Recreated CAD Floor Plan Walls only when no real blueprint underlay exists
    if (!hasBlueprintUnderlay) {
      if (roomGeometry != null) {
        _drawRoomWalls(canvas, size, roomGeometry!);
      } else {
        _drawArchitecturalFloorPlan(canvas, size);
      }
    } else if (isCalibrating) {
      _drawCalibrationOverlay(canvas, size);
    }

    // Paint Locked Room Polygons with Soft Translucent Fill & Clean Border
    for (final entry in calibratedRoomPolygons.entries) {
      final poly = entry.value;
      if (poly.length >= 3) {
        final path = Path()..moveTo(poly.first.dx, poly.first.dy);
        for (int i = 1; i < poly.length; i++) {
          path.lineTo(poly[i].dx, poly[i].dy);
        }
        path.close();

        final fillPaint = Paint()
          ..color = BanaagTheme.primaryAmber.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, fillPaint);

        final strokePaint = Paint()
          ..color = BanaagTheme.primaryAmber.withValues(alpha: 0.6)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawPath(path, strokePaint);
      }
    }

    // Paint Active Calibration Polygon (dashed cyan line + corner target rings)
    if (activePolygonPoints.isNotEmpty) {
      final polyPaint = Paint()
        ..color = Colors.cyanAccent
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      if (activePolygonPoints.length > 1) {
        final path = Path()..moveTo(activePolygonPoints.first.dx, activePolygonPoints.first.dy);
        for (int i = 1; i < activePolygonPoints.length; i++) {
          path.lineTo(activePolygonPoints[i].dx, activePolygonPoints[i].dy);
        }
        canvas.drawPath(path, polyPaint);
      }

      for (int i = 0; i < activePolygonPoints.length; i++) {
        final pt = activePolygonPoints[i];
        canvas.drawCircle(pt, 5.0, Paint()..color = Colors.cyanAccent);
        canvas.drawCircle(pt, 8.0, Paint()..color = Colors.cyanAccent.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 1.5);
      }
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

    bool isPointVisibleInLayer(CanvasPoint pt) {
      if (pt.type == 'PANEL') return true;
      if (activeLayerFilter == 'LIGHTING') {
        return pt.type == 'LIGHT' || pt.type == 'FAN' || pt.type == 'SWITCH_1G';
      }
      if (activeLayerFilter == 'POWER') {
        return pt.type == 'OUTLET_DUPLEX' || pt.type == 'ACU';
      }
      return true;
    }

    // Draw Conduit Routes (Intra-Room Orthogonal CAD Conduits + Short Home-Run Arrowheads)
    if (showConduits) {
      final lightingRoutePaint = Paint()
        ..color = BanaagTheme.primaryAmber.withValues(alpha: 0.78)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final powerRoutePaint = Paint()
        ..color = Colors.lightBlueAccent.withValues(alpha: 0.78)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final homerunStubPaint = Paint()
        ..color = Colors.cyanAccent
        ..strokeWidth = 1.7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (final r in routes) {
        final p1 = points.firstWhere((p) => p.id == r.fromPointId, orElse: () => points.first);
        final p2 = points.firstWhere((p) => p.id == r.toPointId, orElse: () => points.first);

        if (p1.id == p2.id) continue;
        if (!isPointVisibleInLayer(p1) || !isPointVisibleInLayer(p2)) continue;

        // Every home-run from MDP (PANEL) is drawn as a crisp CAD Home-Run Arrowhead (───► Ckt)
        // at the room's entry point (Switch, First Outlet, or ACU) so cross-building lines never clutter the plan!
        if (p1.type == 'PANEL') {
          final angle = math.atan2(p1.y - p2.y, p1.x - p2.x);
          const double startDist = 9.0;
          const double endDist = 23.0;
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
          const double wingLen = 5.5;
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

          // Conductor slash ticks + Circuit Tag (e.g. C1, C2)
          final midStub = Offset(
            (stubStart.dx + stubTip.dx) / 2,
            (stubStart.dy + stubTip.dy) / 2,
          );
          final perpAngle = angle + (math.pi / 4);
          canvas.drawLine(
            Offset(midStub.dx - math.cos(perpAngle) * 3.5, midStub.dy - math.sin(perpAngle) * 3.5),
            Offset(midStub.dx + math.cos(perpAngle) * 3.5, midStub.dy + math.sin(perpAngle) * 3.5),
            homerunStubPaint,
          );

          if (showLabels && p2.circuitNumber > 0) {
            final cktSpan = TextSpan(
              text: 'C${p2.circuitNumber}',
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 7.5,
                fontWeight: FontWeight.bold,
              ),
            );
            final cktTp = TextPainter(text: cktSpan, textDirection: TextDirection.ltr)..layout();
            final tagOffset = Offset(
              stubTip.dx + math.cos(angle) * 6.0 - cktTp.width / 2,
              stubTip.dy + math.sin(angle) * 6.0 - cktTp.height / 2,
            );
            cktTp.paint(canvas, tagOffset);
          }
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

        final bool isPowerRun = p2.type == 'OUTLET_DUPLEX' || p2.type == 'ACU';
        canvas.drawPath(path, isPowerRun ? powerRoutePaint : lightingRoutePaint);
      }
    }

    // Draw Crisp CAD Points (scaled cleanly for the 1000 x 1220 CAD sheet)
    for (final pt in points) {
      if (!isPointVisibleInLayer(pt)) continue;
      final isSel = selectedPoint?.id == pt.id;
      final bool isPanel = pt.type == 'PANEL';
      final double radius = isSel ? 11.0 : (isPanel ? 9.5 : 7.5);
      final pointPaint = Paint()..color = getColorForType(pt.type);

      // Selection halo
      if (isSel) {
        canvas.drawCircle(
          Offset(pt.x, pt.y),
          10.0,
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
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
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

  void _drawArchitecturalFloorPlan(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Calculate dynamic bounding envelope encompassing all electrical fixtures
    double minX = points.map((p) => p.x).reduce(math.min);
    double maxX = points.map((p) => p.x).reduce(math.max);
    double minY = points.map((p) => p.y).reduce(math.min);
    double maxY = points.map((p) => p.y).reduce(math.max);

    // Add architectural clearance around perimeter fixtures
    minX = (minX - 22.0).clamp(25.0, 1200.0);
    maxX = (maxX + 22.0).clamp(minX + 200.0, 1600.0);
    minY = (minY - 22.0).clamp(120.0, 1200.0);
    maxY = (maxY + 22.0).clamp(minY + 220.0, 1600.0);

    final outerRect = Rect.fromLTRB(minX, minY, maxX, maxY);

    // Subtle CAD floor tint
    final floorFill = Paint()
      ..color = const Color(0xFF131A26).withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    canvas.drawRect(outerRect, floorFill);

    // Exterior Architectural Building Walls (Double Line CAD Wall with Corner Pillars)
    final outerWallPaint = Paint()
      ..color = const Color(0xFF48658A)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final innerCasingPaint = Paint()
      ..color = const Color(0xFF2C3E55)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(outerRect, outerWallPaint);
    canvas.drawRect(outerRect.deflate(4.0), innerCasingPaint);

    // Corner Structural Columns (Reinforced Concrete CAD Columns)
    final columnPaint = Paint()
      ..color = const Color(0xFF64B5F6).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    const colSize = 7.0;
    canvas.drawRect(Rect.fromCenter(center: outerRect.topLeft, width: colSize, height: colSize), columnPaint);
    canvas.drawRect(Rect.fromCenter(center: outerRect.topRight, width: colSize, height: colSize), columnPaint);
    canvas.drawRect(Rect.fromCenter(center: outerRect.bottomLeft, width: colSize, height: colSize), columnPaint);
    canvas.drawRect(Rect.fromCenter(center: outerRect.bottomRight, width: colSize, height: colSize), columnPaint);

    // Interior Room Partitions (Divide into Left and Right Wings & Zones)
    final partitionPaint = Paint()
      ..color = const Color(0xFF3B4E6B)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final midX = minX + (maxX - minX) * 0.48;
    final midY = minY + (maxY - minY) * 0.52;

    // Vertical Divider with Door Opening Gap
    canvas.drawLine(Offset(midX, minY), Offset(midX, minY + 35), partitionPaint);
    canvas.drawLine(Offset(midX, minY + 65), Offset(midX, maxY), partitionPaint);

    // Horizontal Divider in Left Wing
    canvas.drawLine(Offset(minX, midY), Offset(midX - 30, midY), partitionPaint);

    // Horizontal Divider in Right Wing
    canvas.drawLine(Offset(midX, midY), Offset(maxX, midY), partitionPaint);

    // Stylized CAD Room Labels with Area Badges
    final List<Map<String, dynamic>> roomTags = [];
    if (spaces.isNotEmpty) {
      final s1 = spaces[0];
      roomTags.add({'name': s1.name.toUpperCase(), 'sqm': s1.areaSqm, 'center': Offset(minX + (midX - minX) / 2, minY + 40)});
      if (spaces.length > 1) {
        final s2 = spaces[1];
        roomTags.add({'name': s2.name.toUpperCase(), 'sqm': s2.areaSqm, 'center': Offset(minX + (midX - minX) / 2, midY + 45)});
      }
      if (spaces.length > 2) {
        final s3 = spaces[2];
        roomTags.add({'name': s3.name.toUpperCase(), 'sqm': s3.areaSqm, 'center': Offset(midX + (maxX - midX) / 2, minY + 40)});
      }
      if (spaces.length > 3) {
        final s4 = spaces[3];
        roomTags.add({'name': s4.name.toUpperCase(), 'sqm': s4.areaSqm, 'center': Offset(midX + (maxX - midX) / 2, midY + 45)});
      }
    } else {
      roomTags.add({'name': 'MAIN LIVING & WORKSPACE', 'sqm': 28.5, 'center': Offset(minX + (midX - minX) / 2, minY + 40)});
      roomTags.add({'name': 'KITCHEN & UTILITY', 'sqm': 16.0, 'center': Offset(minX + (midX - minX) / 2, midY + 45)});
      roomTags.add({'name': 'BEDROOM 1', 'sqm': 18.0, 'center': Offset(midX + (maxX - midX) / 2, minY + 40)});
      roomTags.add({'name': 'BEDROOM 2 & BATH', 'sqm': 14.5, 'center': Offset(midX + (maxX - midX) / 2, midY + 45)});
    }

    for (final tag in roomTags) {
      final Offset c = tag['center'];
      final String name = tag['name'];
      final double sqm = tag['sqm'];

      final textSpan = TextSpan(
        text: '$name • ${sqm.toStringAsFixed(1)} m²',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.38),
          fontSize: 8.0,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(c.dx - (tp.width / 2), c.dy));
    }

    // If 2-Point Calibration Mode is Active, draw overlay
    if (isCalibrating) {
      _drawCalibrationOverlay(canvas, size);
    }
  }

  void _drawCalibrationOverlay(Canvas canvas, Size size) {
    // 1. Dynamic Dimension Line connecting Pin A and Pin B
    final dimPaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(pinA, pinB, dimPaint);

    // Architectural 45-degree CAD dimension ticks on Pin A & Pin B
    final tickPaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const tickLen = 6.0;
    canvas.drawLine(pinA + const Offset(-tickLen, -tickLen), pinA + const Offset(tickLen, tickLen), tickPaint);
    canvas.drawLine(pinB + const Offset(-tickLen, -tickLen), pinB + const Offset(tickLen, tickLen), tickPaint);

    // 2. Interactive Distance Badge at Center of Line
    final center = Offset((pinA.dx + pinB.dx) / 2, (pinA.dy + pinB.dy) / 2);
    final pixelDist = (pinA - pinB).distance;
    final realMm = (pixelDist / pixelsPerMeter) * 1000.0;
    final realMeters = realMm / 1000.0;

    final badgeText = '${realMm.round()} mm (${realMeters.toStringAsFixed(2)}m)';
    final textSpan = TextSpan(
      text: badgeText,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 10.0,
        fontWeight: FontWeight.bold,
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: tp.width + 12, height: tp.height + 6),
      const Radius.circular(5),
    );
    canvas.drawRRect(badgeRect, Paint()..color = BanaagTheme.primaryAmber);
    tp.paint(canvas, Offset(center.dx - (tp.width / 2), center.dy - (tp.height / 2)));

    // 3. Pin A (Cyan Crosshair & Target Ring)
    _drawPinTarget(canvas, pinA, 'A', Colors.cyanAccent);

    // 4. Pin B (Amber Crosshair & Target Ring)
    _drawPinTarget(canvas, pinB, 'B', BanaagTheme.primaryAmber);

    // 5. Magnetic Snap Indicator (Glowing Diamond)
    if (activeSnapPoint != null) {
      final snapP = Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      const sz = 7.0;
      final path = Path()
        ..moveTo(activeSnapPoint!.dx, activeSnapPoint!.dy - sz)
        ..lineTo(activeSnapPoint!.dx + sz, activeSnapPoint!.dy)
        ..lineTo(activeSnapPoint!.dx, activeSnapPoint!.dy + sz)
        ..lineTo(activeSnapPoint!.dx - sz, activeSnapPoint!.dy)
        ..close();
      canvas.drawPath(path, snapP);
      canvas.drawCircle(activeSnapPoint!, sz * 1.6, Paint()..color = Colors.cyanAccent.withValues(alpha: 0.25)..style = PaintingStyle.stroke);
    }
  }

  void _drawPinTarget(Canvas canvas, Offset pos, String label, Color color) {
    // Outer Target Glow
    canvas.drawCircle(pos, 16.0, Paint()..color = color.withValues(alpha: 0.25));

    // Crisp Target Ring
    canvas.drawCircle(pos, 11.0, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.0);

    // Crosshairs
    const arm = 15.0;
    final crossPaint = Paint()..color = color..strokeWidth = 1.2;
    canvas.drawLine(pos + const Offset(-arm, 0), pos + const Offset(arm, 0), crossPaint);
    canvas.drawLine(pos + const Offset(0, -arm), pos + const Offset(0, arm), crossPaint);

    // Center Solid Core
    canvas.drawCircle(pos, 8.0, Paint()..color = const Color(0xFF11151E));
    canvas.drawCircle(pos, 8.0, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // Letter Label
    final tp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - (tp.width / 2), pos.dy - (tp.height / 2)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
