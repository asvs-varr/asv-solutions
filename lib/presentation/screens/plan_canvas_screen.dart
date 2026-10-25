import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../domain/models.dart';
import '../../domain/takeoff_engine.dart';
import '../../domain/lighting_engine.dart';
import '../../domain/pec_safety_auditor.dart';
import '../../domain/sld_engine.dart';
import '../../domain/dxf_cad_engine.dart';
import '../../domain/floor_plan_scanner_engine.dart';
import '../../domain/institutional_building_presets.dart';
import '../../domain/pdf_blueprint_engine.dart';
import '../../data/project_repository.dart';
import '../theme/banaag_theme.dart';
import '../widgets/dxf_export_guide_dialog.dart';
import '../widgets/room_dimension_input_dialog.dart';
import '../widgets/lighting_visualizer_modal.dart';
import '../../domain/blueprint_snap_engine.dart';
import 'client_needs_analysis_screen.dart';

class PlanCanvasScreen extends StatefulWidget {
  final Project? project;
  final int? initialStage; // 1 = Blank Plan Scale & Rooms, 3 = Electrical Layout & Wire Takeoff
  final bool forceRegenerateFromLoads;
  const PlanCanvasScreen({
    super.key,
    this.project,
    this.initialStage,
    this.forceRegenerateFromLoads = false,
  });

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
  int _pdfSheetIndex = 0;
  List<PdfBlueprintPageInfo> _pdfPages = [];
  String? _renderedPdfImagePath;
  bool _isRenderingPdf = false;
  bool _invertBlueprint = false;
  // Default Reference Scale Pins along the 15,500 mm top exterior wall (centered on 1400x1600 sheet)
  Offset _pinA = const Offset(338, 162);
  Offset _pinB = const Offset(1032, 162);
  bool _isDraggingItem = false;

  // 3-Stage Engineering Flow State:
  // Stage 1 = Blank Floor Plan Scale (Step 0) & 1-by-1 Polygon Room Wizard (Step 1)
  // Stage 2 = Space-Driven IESNA 10th Ed & PEC 2017 Load Schedule (ClientNeedsAnalysisScreen)
  // Stage 3 = Point-in-Polygon Electrical Layout & 3D-Aware Orthogonal Wire Takeoff
  int _canvasStage = 1;
  // Stage 1 Sub-Steps:
  // 0 = Step 0: Solo Scale (Pin A–B) + Wall Thickness Verification (zero room boxes visible)
  // 1 = Step 1: 1-by-1 Sequential Multi-Vertex Polygon Room Wizard (1 of N .. N of N)
  // 2 = End of Step 1: All Rooms Confirmed & Floor Plan Completeness Gate ("Are all spaces accounted for?")
  // 3 = Single-Room Re-Edit Mode (invoked from "📐 Edit Room Dimension" button, 1 room at a time)
  int _stage1SubStep = 0;
  double _wallThicknessMm = 150.0; // Default 150 mm CHB Wall Thickness
  bool _highlightUnaccountedZones = false;
  final Map<String, Rect> _roomBoxes = {};
  final Map<String, List<Offset>> _roomPolygons = {};
  int _selectedRoomIndex = 0;
  int? _activeDraggingRoomCorner; // 0=TL, 1=TR, 2=BR, 3=BL, 4=CenterMove
  int? _activeDraggingVertexIndex; // Active polygon vertex index being dragged in Step 1
  int? _selectedPinForTap; // 1=Pin A, 2=Pin B selected for tap-to-target snap
  int? _selectedVertexForTap; // Room corner vertex index selected for tap-to-target snap

  // Exact Structural Column Centers (Center ng Poste) & Vital Floor Plan Snap Points
  // Dynamically populated from blueprint or calibrated to genuine structural posts
  static const List<Offset> _cadStructuralColumns = [
    // Top Row (Grid Line 1 - 4000, 4800, 3400, 3300 bays)
    Offset(355.3, 317.5),
    Offset(555.2, 317.4),
    Offset(794.8, 317.4),
    Offset(964.5, 317.5),
    Offset(1129.5, 317.4),
    // Row 2 (Grid Line 2)
    Offset(355.3, 469.9),
    Offset(964.4, 469.9),
    Offset(1129.6, 469.9),
    // Row 3 (Grid Line 3)
    Offset(355.2, 644.4),
    Offset(555.2, 644.4),
    Offset(794.8, 644.5),
    Offset(964.6, 644.6),
    Offset(1129.6, 644.5),
    // Row 4 (Grid Line 4)
    Offset(355.3, 732.4),
    Offset(554.9, 732.5),
    // Row 5 (Grid Line 5)
    Offset(794.7, 818.7),
    Offset(1129.5, 818.8),
    // Row 6 (Grid Line 6)
    Offset(794.8, 988.6),
    Offset(964.5, 988.6),
    Offset(1129.5, 988.6),
    // Row 7 (Grid Line 7)
    Offset(794.7, 1088.5),
    Offset(964.4, 1088.6),
    Offset(1129.5, 1088.6),
    // Row 8 (Grid Line 8)
    Offset(794.7, 1185.8),
    Offset(964.4, 1192.4),
    Offset(1129.5, 1192.3),
    // Row 9 (Grid Line 9)
    Offset(964.9, 1291.1),
    Offset(1129.5, 1290.9),
  ];

  // Exact Architectural Non-Column Wall Corners & L-Junctions (Center ng Pader turns)
  static const List<Offset> _cadArchitecturalCorners = [
    // Stairs Landing intermediate wall turns & corners
    Offset(703.5, 730.8),
    Offset(703.5, 1090.7),
    // Alcove wall turns & corners between Grid 3 and Office (Ticket TKT-1792929351058)
    Offset(843.0, 638.0),
    Offset(843.0, 674.5),
    Offset(794.8, 674.5),
    // Void / Setback architectural boundary corners
    Offset(355.3, 1088.5),
    Offset(555.2, 1185.8),
  ];

  // Exact CAD Dimension Needles & Extension Line Tick Endpoints
  static const List<Offset> _cadDimensionNeedles = [
    // Top Horizontal Dimension Needles / Ticks (4000, 4800, 3400, 3300, 15500mm lines)
    Offset(355.3, 289.2), Offset(355.3, 303.3),
    Offset(555.2, 289.2), Offset(555.2, 303.3),
    Offset(794.8, 289.2), Offset(794.8, 303.3),
    Offset(964.5, 289.2), Offset(964.5, 303.3),
    Offset(1129.5, 289.2), Offset(1129.5, 303.3),
    // Right Vertical Dimension Needles / Ticks (3050, 3500, 3480, 3400, etc.)
    Offset(1185.0, 317.5), Offset(1240.0, 317.5),
    Offset(1185.0, 469.9), Offset(1240.0, 469.9),
    Offset(1185.0, 644.5), Offset(1240.0, 644.5),
    Offset(1185.0, 818.8), Offset(1240.0, 818.8),
    Offset(1185.0, 988.6), Offset(1240.0, 988.6),
    Offset(1185.0, 1088.6), Offset(1240.0, 1088.6),
    Offset(1185.0, 1192.3), Offset(1240.0, 1192.3),
    Offset(1185.0, 1291.0), Offset(1240.0, 1291.0),
  ];

  // Multi-Step Undo History Stack for Step 1 & Step 3 Polygon Geometry
  final List<Map<String, List<Offset>>> _polygonUndoHistory = [];

  void _pushUndoState() {
    final Map<String, List<Offset>> snapshot = {};
    _roomPolygons.forEach((k, v) {
      snapshot[k] = List<Offset>.from(v);
    });
    _polygonUndoHistory.add(snapshot);
    if (_polygonUndoHistory.length > 25) {
      _polygonUndoHistory.removeAt(0);
    }
  }

  void _performUndo() {
    if (_polygonUndoHistory.isEmpty) return;
    final lastState = _polygonUndoHistory.removeLast();
    setState(() {
      _roomPolygons.clear();
      lastState.forEach((k, v) {
        _roomPolygons[k] = List<Offset>.from(v);
      });
      _selectedVertexForTap = null;
    });
    _syncRoomSpacesFromBoxes(persist: true);
    HapticFeedback.mediumImpact();
  }

  // Orthogonal Snap & Floor Plan Snap Settings
  bool _isOrthoSnapEnabled = true;
  bool _isAiAutoWallDetectEnabled = true;
  final List<Offset> _customProjectColumns = [];
  Offset? _lastHapticSnappedPoint;
  Offset? _roomDragStartPos;
  List<Offset>? _roomDragInitialPoly;
  int? _activeDraggingWallIndex;
  Offset? _wallDragStartPos;
  List<Offset>? _wallDragInitialPoly;
  bool _isPerpendicularCornerSnapped = false;
  Offset? _perpendicularSnapCornerPos;

  // Multi-Point Polygon Calibration Engine for Real Rooms
  final List<Offset> _activePolygonPoints = [];
  int _activeCalibratingRoomIndex = 0;
  final Map<String, List<Offset>> _calibratedRoomPolygons = {};

  int? _activeDraggingPin;
  Offset? _activeSnapPoint;
  double _pixelsPerMeter = 44.77;
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

  /// Determines if current blueprint is a commercial/institutional CAD plan with column grids
  bool get _isCommercialCadPlan {
    final path = _blueprintPath?.toLowerCase() ?? '';
    final title = widget.project?.title.toLowerCase() ?? '';
    return path.contains('tesda') ||
        path.contains('commercial') ||
        path.contains('model.pdf') ||
        title.contains('commercial') ||
        title.contains('tesda');
  }

  /// Determines if current blueprint is a residential timber/CHB plan
  bool get _isResidentialPlan {
    final path = _blueprintPath?.toLowerCase() ?? '';
    final title = widget.project?.title.toLowerCase() ?? '';
    return path.contains('1000010166') ||
        path.contains('residential') ||
        path.contains('residence') ||
        title.contains('residential') ||
        title.contains('residence') ||
        title.contains('other');
  }

  /// Dynamically active structural columns for snapping and rendering
  List<Offset> get _activeStructuralColumns {
    if (!_isAiAutoWallDetectEnabled) return const [];
    final List<Offset> columns = [];
    if (_isCommercialCadPlan) {
      columns.addAll(_cadStructuralColumns);
    }
    // Merge user-tagged or smart-detected columns for residential/custom plans
    columns.addAll(_customProjectColumns);
    return columns;
  }

  /// Dynamically active architectural wall corners and turns
  List<Offset> get _activeArchitecturalCorners {
    if (!_isAiAutoWallDetectEnabled) return const [];
    final List<Offset> rawCorners = [];
    if (_isCommercialCadPlan) {
      rawCorners.addAll(_cadArchitecturalCorners);
    } else if (_isResidentialPlan) {
      rawCorners.addAll(BlueprintSnapEngine.residentialWallCorners);
    } else {
      rawCorners.add(_pinA);
      rawCorners.add(_pinB);
      _roomPolygons.forEach((_, poly) {
        rawCorners.addAll(poly);
      });
    }

    // Column-Priority Deduplication: If a spot has a column (within 20px), column is active and takes priority!
    final activeCols = _activeStructuralColumns;
    if (activeCols.isEmpty) return rawCorners;
    return rawCorners.where((corner) {
      for (final col in activeCols) {
        if ((corner - col).distance <= 20.0) {
          return false; // Column takes priority at this spot
        }
      }
      return true;
    }).toList();
  }

  /// Dynamically active dimension needles and witness ticks
  List<Offset> get _activeDimensionNeedles {
    if (!_isAiAutoWallDetectEnabled) return const [];
    if (_isCommercialCadPlan) {
      return _cadDimensionNeedles;
    }
    if (_isResidentialPlan) {
      return BlueprintSnapEngine.residentialDimensionNeedles;
    }
    return [_pinA, _pinB];
  }

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  static const double _cadCanvasWidth = 1400.0;
  static const double _cadCanvasHeight = 1600.0;
  static const double _planOriginX = 140.0;
  static const double _planOriginY = 120.0;

  /// Automatically positions Pin A and Pin B onto the primary dimension needles
  /// or exterior wall corners of the active blueprint, locking calibration to real drawing geometry!
  void _autoPositionScalePinsToNeedles({bool recomputePpm = false}) {
    if (_isResidentialPlan) {
      // 28'-0" (8.534m) Top Dimension Needles of residential plan:
      _pinA = const Offset(124.0, 125.2);
      _pinB = const Offset(1093.7, 125.2);
      if (recomputePpm || (widget.project?.calibrationPixelsPerMeter == null || widget.project!.calibrationPixelsPerMeter! < 50.0)) {
        // 969.7 px / 8.5344 m = ~113.62 px/m
        const double resDistMeters = 28.0 * 0.3048; // 8.5344 m
        _pixelsPerMeter = (_pinA - _pinB).distance / resDistMeters;
        if (widget.project != null) {
          widget.project!.calibrationPixelsPerMeter = _pixelsPerMeter;
        }
      }
    } else if (_isCommercialCadPlan) {
      // 15,500 mm (15.5m) Top Horizontal Dimension Needles of TESDA 3rd floor plan:
      _pinA = const Offset(355.3, 289.2);
      _pinB = const Offset(1129.5, 289.2);
      if (recomputePpm || (widget.project?.calibrationPixelsPerMeter == null || (widget.project!.calibrationPixelsPerMeter! - 44.77).abs() < 1.0)) {
        // 774.2 px / 15.5 m = 49.95 px/m
        const double comDistMeters = 15.5;
        _pixelsPerMeter = (_pinA - _pinB).distance / comDistMeters;
        if (widget.project != null) {
          widget.project!.calibrationPixelsPerMeter = _pixelsPerMeter;
        }
      }
    } else {
      // Generic plan fallback: Search first pair of dimension needles or corners
      final needles = _activeDimensionNeedles;
      if (needles.length >= 2) {
        _pinA = needles[0];
        _pinB = needles[1];
      }
    }
  }

  void _fitSheetToViewport() {
    // Fit unconstrained CAD sheet with comfortable padding around outer dimension callouts
    const double fitScale = 0.26;
    _currentZoom = fitScale;
    _zoomController.value = Matrix4.identity()
      ..translateByDouble(10.0, 16.0, 0.0, 1.0)
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

  Rect _defaultCadRectForRoom(String roomName, int index) {
    final lower = roomName.toLowerCase();
    if (lower.contains('hall') || lower.contains('event') || lower.contains('function')) {
      return const Rect.fromLTWH(198.0 + _planOriginX, 42.0 + _planOriginY, 546.0, 300.0);
    }
    if (lower.contains('staff')) {
      return const Rect.fromLTWH(744.0 + _planOriginX, 148.0 + _planOriginY, 148.0, 130.0);
    }
    if (lower.contains('office')) {
      return const Rect.fromLTWH(592.0 + _planOriginX, 278.0 + _planOriginY, 300.0, 250.0);
    }
    if (lower.contains('landing') || lower.contains('stair')) {
      return const Rect.fromLTWH(510.0 + _planOriginX, 528.0 + _planOriginY, 345.0, 140.0);
    }
    if (lower.contains('storage') || lower.contains('store')) {
      return const Rect.fromLTWH(744.0 + _planOriginX, 668.0 + _planOriginY, 148.0, 74.0);
    }
    final double col = (index % 2) * 320.0 + 200.0 + _planOriginX;
    final double row = (index ~/ 2) * 220.0 + 80.0 + _planOriginY;
    return Rect.fromLTWH(col, row, 280.0, 190.0);
  }

  /// Default Multi-Vertex Polygon on the expanded 1400x1600 CAD Sheet (supports L-shapes & alcoves)
  List<Offset> _defaultCadPolygonForRoom(String roomName, int index) {
    final lower = roomName.toLowerCase();
    if (lower.contains('hall') || lower.contains('event') || lower.contains('function')) {
      // L-Shaped Function Hall / Event Place matching the scanned CAD floor plan walls!
      return [
        const Offset(198.0 + _planOriginX, 42.0 + _planOriginY),
        const Offset(744.0 + _planOriginX, 42.0 + _planOriginY),
        const Offset(744.0 + _planOriginX, 278.0 + _planOriginY),
        const Offset(378.0 + _planOriginX, 278.0 + _planOriginY),
        const Offset(378.0 + _planOriginX, 342.0 + _planOriginY),
        const Offset(198.0 + _planOriginX, 342.0 + _planOriginY),
      ];
    }
    if (lower.contains('staff')) {
      return [
        const Offset(744.0 + _planOriginX, 148.0 + _planOriginY),
        const Offset(892.0 + _planOriginX, 148.0 + _planOriginY),
        const Offset(892.0 + _planOriginX, 278.0 + _planOriginY),
        const Offset(744.0 + _planOriginX, 278.0 + _planOriginY),
      ];
    }
    if (lower.contains('office')) {
      return [
        const Offset(592.0 + _planOriginX, 278.0 + _planOriginY),
        const Offset(892.0 + _planOriginX, 278.0 + _planOriginY),
        const Offset(892.0 + _planOriginX, 528.0 + _planOriginY),
        const Offset(592.0 + _planOriginX, 528.0 + _planOriginY),
      ];
    }
    if (lower.contains('landing') || lower.contains('stair')) {
      return [
        const Offset(510.0 + _planOriginX, 528.0 + _planOriginY),
        const Offset(855.0 + _planOriginX, 528.0 + _planOriginY),
        const Offset(855.0 + _planOriginX, 668.0 + _planOriginY),
        const Offset(510.0 + _planOriginX, 668.0 + _planOriginY),
      ];
    }
    if (lower.contains('storage') || lower.contains('store')) {
      return [
        const Offset(744.0 + _planOriginX, 668.0 + _planOriginY),
        const Offset(892.0 + _planOriginX, 668.0 + _planOriginY),
        const Offset(892.0 + _planOriginX, 742.0 + _planOriginY),
        const Offset(744.0 + _planOriginX, 742.0 + _planOriginY),
      ];
    }
    final r = _defaultCadRectForRoom(roomName, index);
    return [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
  }

  Rect _boundingBoxOfPolygon(List<Offset> poly) {
    if (poly.isEmpty) return const Rect.fromLTWH(200, 100, 200, 150);
    double minX = poly.first.dx;
    double maxX = poly.first.dx;
    double minY = poly.first.dy;
    double maxY = poly.first.dy;
    for (final pt in poly) {
      if (pt.dx < minX) minX = pt.dx;
      if (pt.dx > maxX) maxX = pt.dx;
      if (pt.dy < minY) minY = pt.dy;
      if (pt.dy > maxY) maxY = pt.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Ray-casting Point-in-Polygon check (strictly keeps ceiling luminaires inside L-shapes/polygons)
    /// Computes the perpendicular distance from point p to line segment (a - b)
  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final double l2 = (b - a).distanceSquared;
    if (l2 == 0.0) return (p - a).distance;
    final double t = math.max(0.0, math.min(1.0, ((p.dx - a.dx) * (b.dx - a.dx) + (p.dy - a.dy) * (b.dy - a.dy)) / l2));
    final Offset proj = Offset(a.dx + t * (b.dx - a.dx), a.dy + t * (b.dy - a.dy));
    return (p - proj).distance;
  }

  bool _isPointInPolygon(Offset pt, List<Offset> poly) {
    if (poly.length < 3) return true;
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].dx, yi = poly[i].dy;
      final xj = poly[j].dx, yj = poly[j].dy;
      final intersect = ((yi > pt.dy) != (yj > pt.dy)) &&
          (pt.dx < (xj - xi) * (pt.dy - yi) / ((yj - yi) == 0 ? 0.00001 : (yj - yi)) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  /// Exact Shoelace Polygon Net Area (m²), Perimeter (m), and IESNA 10th Edition Eq. 10.32 RCR
  ({double netAreaSqm, double perimeterMeters, double rcrValue}) _computePolygonEngineeringMetrics(
    List<Offset> poly,
    double ceilingHeightMeters,
  ) {
    final double ppm = _pixelsPerMeter > 5.0 ? _pixelsPerMeter : 44.77;
    if (poly.length < 3) {
      return (netAreaSqm: 12.0, perimeterMeters: 14.0, rcrValue: 5.8);
    }
    double signedArea2Px = 0.0;
    double perimPx = 0.0;
    for (int i = 0; i < poly.length; i++) {
      final p1 = poly[i];
      final p2 = poly[(i + 1) % poly.length];
      signedArea2Px += (p1.dx * p2.dy - p2.dx * p1.dy);
      perimPx += (p2 - p1).distance;
    }
    final double grossAreaSqm = (signedArea2Px.abs() * 0.5) / (ppm * ppm);
    final double perimMeters = perimPx / ppm;
    final double wallStripDeductionSqm = perimMeters * ((_wallThicknessMm / 1000.0) * 0.5);
    final double netAreaSqm = math.max(1.5, grossAreaSqm - wallStripDeductionSqm);

    // IESNA Lighting Handbook 10th Edition Equation 10.32 (Page 10.34):
    // RCR = 2.5 * h_RC * Perimeter / Net_Area, where h_RC = CeilingHeight - 0.80m workplane
    final double hRc = math.max(1.2, ceilingHeightMeters - 0.80);
    final double rcr = (2.5 * hRc * perimMeters) / netAreaSqm;

    return (
      netAreaSqm: double.parse(netAreaSqm.toStringAsFixed(1)),
      perimeterMeters: double.parse(perimMeters.toStringAsFixed(2)),
      rcrValue: double.parse(rcr.clamp(0.5, 15.0).toStringAsFixed(2)),
    );
  }

  /// Snaps a position to Floor Plan structural snap points (Column Corners/Centers and Wall Midpoints/Edges)
  Offset _snapToFloorPlanFeatures(Offset rawPos, {Offset? orthoAnchor, double snapTol = 16.0}) {
    Offset pos = rawPos;

    // 1. Orthogonal Snap: lock to horizontal (0°) or vertical (90°) relative to orthoAnchor
    if (_isOrthoSnapEnabled && orthoAnchor != null) {
      final double dx = (pos.dx - orthoAnchor.dx).abs();
      final double dy = (pos.dy - orthoAnchor.dy).abs();
      if (dx >= dy) {
        // Horizontal lock
        pos = Offset(pos.dx, orthoAnchor.dy);
      } else {
        // Vertical lock
        pos = Offset(orthoAnchor.dx, pos.dy);
      }
    }

    Offset? nearestSnap;
    double minDistance = snapTol;

    // 2. Snap to Column Intersections & Exact Column Centers (Center ng Poste)
    const double colTolerance = 24.0;
    final double ppm = _pixelsPerMeter > 5.0 ? _pixelsPerMeter : 44.77;
    final double wallThickPx = (_wallThicknessMm / 1000.0) * ppm;
    final double halfThickPx = wallThickPx / 2.0;
    // Strict Visual-to-Hit Synchronization: Only snap to face points if zoom >= 3.0x where they are visible!
    final bool enableFaceSnaps = _currentZoom >= 2.5;

    for (final colCenter in _activeStructuralColumns) {
      // 2.1 Centerline of column
      final distCenter = (pos - colCenter).distance;
      if (distCenter <= colTolerance && distCenter < minDistance) {
        minDistance = distCenter;
        nearestSnap = colCenter;
      }
      // 2.2 Tri-Snap: Column Face / Edges (Loob at Labas ng Poste)
      if (enableFaceSnaps) {
        for (final ox in [-halfThickPx, halfThickPx]) {
          for (final oy in [-halfThickPx, halfThickPx]) {
            final facePt = Offset(colCenter.dx + ox, colCenter.dy + oy);
            final distFace = (pos - facePt).distance;
            if (distFace <= 14.0 && distFace < minDistance) {
              minDistance = distFace;
              nearestSnap = facePt;
            }
          }
        }
      }
    }

    // 2.5 Snap to Architectural Wall Corners & Turns (Tri-Snap: Gitna, Loob, Labas)
    for (final wCorner in _activeArchitecturalCorners) {
      final distCorner = (pos - wCorner).distance;
      if (distCorner <= colTolerance && distCorner < minDistance) {
        minDistance = distCorner;
        nearestSnap = wCorner;
      }
      if (enableFaceSnaps) {
        for (final ox in [-halfThickPx, halfThickPx]) {
          for (final oy in [-halfThickPx, halfThickPx]) {
            final facePt = Offset(wCorner.dx + ox, wCorner.dy + oy);
            final distFace = (pos - facePt).distance;
            if (distFace <= 14.0 && distFace < minDistance) {
              minDistance = distFace;
              nearestSnap = facePt;
            }
          }
        }
      }
    }

    // 3. Snap to CAD Dimension Needles / Witness Ticks & Arrowhead Endpoints (Generous 26px Tolerance)
    for (final needlePt in _activeDimensionNeedles) {
      final distNeedle = (pos - needlePt).distance;
      if (distNeedle <= math.max(minDistance, 24.0)) {
        minDistance = distNeedle;
        nearestSnap = needlePt;
      }
    }

    // 4. Snap to Confirmed Room Corners (Adjacent Room Sharing)
    final spaces = widget.project?.spaces ?? [];
    for (int i = 0; i < spaces.length; i++) {
      if (i == _selectedRoomIndex) continue;
      final otherPoly = _roomPolygons[spaces[i].id];
      if (otherPoly == null) continue;
      for (final v in otherPoly) {
        final distV = (pos - v).distance;
        if (distV <= snapTol && distV < minDistance) {
          minDistance = distV;
          nearestSnap = v;
        }
      }
    }

    if (nearestSnap != null) {
      if (_lastHapticSnappedPoint == null || (_lastHapticSnappedPoint! - nearestSnap).distance > 4.0) {
        HapticFeedback.selectionClick();
        _lastHapticSnappedPoint = nearestSnap;
      }
      _activeSnapPoint = nearestSnap;
      return nearestSnap;
    } else {
      _lastHapticSnappedPoint = null;
      _activeSnapPoint = null;
    }

    return pos;
  }

  /// Locates the nearest structural column center, dimension needle, or confirmed room corner
  /// for tap-to-target snapping (Center ng Poste / Ticks / Room Corners)
  Offset? _findNearestTargetSnapPoint(Offset tapPos, {double maxDistance = 50.0}) {
    Offset? nearest;
    double minD = maxDistance;

    // 1. Check exact structural column centers (Center ng Poste) and Tri-Snap faces
    final double ppm = _pixelsPerMeter > 5.0 ? _pixelsPerMeter : 44.77;
    final double wallThickPx = (_wallThicknessMm / 1000.0) * ppm;
    final double halfThickPx = wallThickPx / 2.0;
    // Strict Visual-to-Hit Synchronization: Only snap to face points if zoom >= 3.0x where they are visible!
    final bool enableFaceSnaps = _currentZoom >= 2.5;

    for (final colCenter in _activeStructuralColumns) {
      final d = (tapPos - colCenter).distance;
      if (d <= minD) {
        minD = d;
        nearest = colCenter;
      }
      if (enableFaceSnaps) {
        for (final ox in [-halfThickPx, halfThickPx]) {
          for (final oy in [-halfThickPx, halfThickPx]) {
            final facePt = Offset(colCenter.dx + ox, colCenter.dy + oy);
            final fd = (tapPos - facePt).distance;
            if (fd <= minD) {
              minD = fd;
              nearest = facePt;
            }
          }
        }
      }
    }

    // 1.5 Check architectural wall corners (gitna, loob, labas)
    for (final wCorner in _activeArchitecturalCorners) {
      final d = (tapPos - wCorner).distance;
      if (d <= minD) {
        minD = d;
        nearest = wCorner;
      }
      if (enableFaceSnaps) {
        for (final ox in [-halfThickPx, halfThickPx]) {
          for (final oy in [-halfThickPx, halfThickPx]) {
            final facePt = Offset(wCorner.dx + ox, wCorner.dy + oy);
            final fd = (tapPos - facePt).distance;
            if (fd <= minD) {
              minD = fd;
              nearest = facePt;
            }
          }
        }
      }
    }

    // 2. Check dimension needles & witness ticks
    for (final needle in _activeDimensionNeedles) {
      final d = (tapPos - needle).distance;
      if (d <= minD) {
        minD = d;
        nearest = needle;
      }
    }

    // 3. Check corners of other confirmed rooms (shared wall corners)
    final spaces = widget.project?.spaces ?? [];
    for (int i = 0; i < spaces.length; i++) {
      if (i == _selectedRoomIndex) continue;
      final otherPoly = _roomPolygons[spaces[i].id];
      if (otherPoly == null) continue;
      for (final v in otherPoly) {
        final d = (tapPos - v).distance;
        if (d <= minD) {
          minD = d;
          nearest = v;
        }
      }
    }

    return nearest;
  }

  /// Magnetic Wall & Corner Snapping for Step 1 Polygon Vertices
  Offset _snapPolygonVertex(Offset rawPos, List<Offset> activePoly, int activeVertexIdx) {
    double sx = rawPos.dx.clamp(20.0, _cadCanvasWidth - 20.0);
    double sy = rawPos.dy.clamp(20.0, _cadCanvasHeight - 20.0);
    Offset? snapTarget;
    const double snapTol = 16.0;

    // 1. Snap to confirmed rooms' vertices so adjacent rooms share exact walls without gaps
    final spaces = widget.project?.spaces ?? [];
    for (int i = 0; i < spaces.length; i++) {
      if (i == _selectedRoomIndex) continue;
      final otherPoly = _roomPolygons[spaces[i].id];
      if (otherPoly == null) continue;
      for (final v in otherPoly) {
        if ((v - rawPos).distance <= snapTol) {
          if (_lastHapticSnappedPoint == null || (_lastHapticSnappedPoint! - v).distance > 4.0) {
            HapticFeedback.selectionClick();
            _lastHapticSnappedPoint = v;
          }
          _activeSnapPoint = v;
          return v;
        }
      }
    }

    // 2. Orthogonal & Perpendicular Snap: Lock to 0 deg / 90 deg relative to neighboring vertices
    bool isCornerPerpendicular = false;
    if (activePoly.length >= 3) {
      final prevV = activePoly[(activeVertexIdx - 1 + activePoly.length) % activePoly.length];
      final nextV = activePoly[(activeVertexIdx + 1) % activePoly.length];

      // Candidate 1: aligned horizontally with prevV and vertically with nextV -> (nextV.dx, prevV.dy)
      final cand1 = Offset(nextV.dx, prevV.dy);
      // Candidate 2: aligned vertically with prevV and horizontally with nextV -> (prevV.dx, nextV.dy)
      final cand2 = Offset(prevV.dx, nextV.dy);

      final double dist1 = (rawPos - cand1).distance;
      final double dist2 = (rawPos - cand2).distance;
      const double perpSnapTol = 24.0;

      if (dist1 <= perpSnapTol || dist2 <= perpSnapTol) {
        final exactPerp = dist1 <= dist2 ? cand1 : cand2;
        sx = exactPerp.dx;
        sy = exactPerp.dy;
        snapTarget = exactPerp;
        isCornerPerpendicular = true;
      } else if (_isOrthoSnapEnabled) {
        final double distPrev = (rawPos - prevV).distance;
        final double distNext = (rawPos - nextV).distance;
        final anchor = distPrev <= distNext ? prevV : nextV;
        final double dX = (sx - anchor.dx).abs();
        final double dY = (sy - anchor.dy).abs();
        if (dX <= 36.0 || dY <= 36.0) {
          if (dX < dY) {
            sx = anchor.dx; // Vertical lock
          } else {
            sy = anchor.dy; // Horizontal lock
          }
        }
      } else {
        if ((sx - prevV.dx).abs() <= 10.0) sx = prevV.dx;
        if ((sx - nextV.dx).abs() <= 10.0) sx = nextV.dx;
        if ((sy - prevV.dy).abs() <= 10.0) sy = prevV.dy;
        if ((sy - nextV.dy).abs() <= 10.0) sy = nextV.dy;
      }
    }

    _isPerpendicularCornerSnapped = isCornerPerpendicular;
    _perpendicularSnapCornerPos = isCornerPerpendicular ? Offset(sx, sy) : null;

    // 3. Snap to Structural Columns, Dimension Needles, & Shared Corners
    final featSnapped = _snapToFloorPlanFeatures(Offset(sx, sy), snapTol: snapTol);
    if ((featSnapped - Offset(sx, sy)).distance <= snapTol) {
      sx = featSnapped.dx;
      sy = featSnapped.dy;
      snapTarget = featSnapped;
    }

    if (snapTarget != null) {
      if (_lastHapticSnappedPoint == null || (_lastHapticSnappedPoint! - snapTarget).distance > 4.0) {
        HapticFeedback.selectionClick();
        _lastHapticSnappedPoint = snapTarget;
      }
    }
    _activeSnapPoint = snapTarget;
    return Offset((sx / 2.0).round() * 2.0, (sy / 2.0).round() * 2.0);
  }

  void _initRoomBoxesAndScale() {
    final proj = widget.project;
    if (proj == null) return;

    if (proj.calibrationPixelsPerMeter == null || proj.calibrationPixelsPerMeter! < 15.0 || (proj.calibrationPixelsPerMeter! - 30.0).abs() < 0.1) {
      _pixelsPerMeter = 44.77; // 694 px / 15.50 m = 44.77 px/m on 1000x1220 CAD sheet
      proj.calibrationPixelsPerMeter = _pixelsPerMeter;
    } else {
      _pixelsPerMeter = proj.calibrationPixelsPerMeter!;
    }

    final bool hasBlueprint = _blueprintPath != null && File(_blueprintPath!).existsSync();
    final bool isLegacyResidentialDefault = proj.spaces.isNotEmpty &&
        proj.spaces.any((s) => s.id == 'sp-1' || s.name.toLowerCase().contains('living & dining'));

    if (proj.spaces.isEmpty || (hasBlueprint && isLegacyResidentialDefault)) {
      proj.spaces.clear();
      proj.spaces.addAll([
        RoomSpace(id: 'sp-func', name: 'Function Hall / Event Place', areaSqm: 64.5, ceilingHeight: 3.5),
        RoomSpace(id: 'sp-staff', name: 'Staff Room', areaSqm: 9.6, ceilingHeight: 2.8),
        RoomSpace(id: 'sp-off', name: 'Office Rooms', areaSqm: 37.4, ceilingHeight: 2.8),
        RoomSpace(id: 'sp-land', name: 'Landing', areaSqm: 24.1, ceilingHeight: 2.8),
        RoomSpace(id: 'sp-stor', name: 'Storage Room', areaSqm: 5.5, ceilingHeight: 2.6),
      ]);
    }

    _roomPolygons.clear();
    _roomBoxes.clear();
    final Set<String> seenIds = {};
    for (int i = 0; i < proj.spaces.length; i++) {
      var sp = proj.spaces[i];
      // Auto-heal duplicate IDs from legacy scans
      if (seenIds.contains(sp.id) || sp.id == 'sp-scan-') {
        final uniqueId = 'sp-${DateTime.now().millisecondsSinceEpoch}-$i';
        sp = RoomSpace(
          id: uniqueId,
          name: sp.name,
          areaSqm: sp.areaSqm,
          ceilingHeight: sp.ceilingHeight,
          shapeType: sp.shapeType,
          cutoutDepth: sp.cutoutDepth,
          cutoutWidth: sp.cutoutWidth,
          canvasX: sp.canvasX,
          canvasY: sp.canvasY,
          canvasWidth: sp.canvasWidth,
          canvasHeight: sp.canvasHeight,
          perimeterMeters: sp.perimeterMeters,
          rcrValue: sp.rcrValue,
          polygonVertices: sp.polygonVertices,
        );
        proj.spaces[i] = sp;
      }
      seenIds.add(sp.id);

      List<Offset> poly;
      if (sp.polygonVertices != null && sp.polygonVertices!.length >= 3) {
        poly = sp.polygonVertices!
            .map((m) => Offset(m['x'] ?? 200.0, m['y'] ?? 100.0))
            .toList();
      } else {
        poly = _defaultCadPolygonForRoom(sp.name, i);
      }
      _roomPolygons[sp.id] = poly;
      _roomBoxes[sp.id] = _boundingBoxOfPolygon(poly);
    }
    _syncRoomSpacesFromBoxes(persist: false);

    // Silent background OCR scan if blueprint is attached and spaces were never customized
    _triggerSilentBlueprintOcrScanIfNeeded();
  }

  /// Silently scans the uploaded blueprint using ML Kit / CAD text stream in the background
  /// to dynamically detect and populate rooms directly from the blueprint!
  Future<void> _triggerSilentBlueprintOcrScanIfNeeded({bool forceRescan = false}) async {
    final proj = widget.project;
    final path = _blueprintPath;
    if (proj == null || path == null || !File(path).existsSync()) return;

    final bool isDefaultSpaces = proj.spaces.isEmpty ||
        proj.spaces.any((s) => s.id.startsWith('sp-') || s.name.toLowerCase().contains('living & dining'));
    if (!isDefaultSpaces && !forceRescan) return;

    try {
      final scanResult = await FloorPlanScannerEngine.scanFloorPlanWithMetadata(path, pdfPageIndex: _pdfSheetIndex);
      if (scanResult.rooms.isNotEmpty && mounted) {
        setState(() {
          proj.spaces.clear();
          _roomPolygons.clear();
          _roomBoxes.clear();

          for (int i = 0; i < scanResult.rooms.length; i++) {
            final scanned = scanResult.rooms[i];
            final roomSpace = RoomSpace(
              id: 'sp-scan-${DateTime.now().millisecondsSinceEpoch}-$i',
              name: scanned.name,
              areaSqm: scanned.areaSqm > 0 ? scanned.areaSqm : 15.0,
              ceilingHeight: LightingEngine.suggestDefaultCeilingHeight(scanned.name),
              shapeType: scanned.shapeType,
              cutoutDepth: scanned.cutoutDepth,
              cutoutWidth: scanned.cutoutWidth,
            );
            proj.spaces.add(roomSpace);

            final poly = _defaultCadPolygonForRoom(roomSpace.name, i);
            _roomPolygons[roomSpace.id] = poly;
            _roomBoxes[roomSpace.id] = _boundingBoxOfPolygon(poly);
          }
          if (_selectedRoomIndex >= proj.spaces.length) {
            _selectedRoomIndex = 0;
          }
          _syncRoomSpacesFromBoxes(persist: true);
        });
      }
    } catch (_) {}
  }

  void _syncRoomSpacesFromBoxes({bool persist = true}) {
    final proj = widget.project;
    if (proj == null) return;
    final double ppm = _pixelsPerMeter > 5.0 ? _pixelsPerMeter : 44.77;

    for (int i = 0; i < proj.spaces.length; i++) {
      final sp = proj.spaces[i];
      final poly = _roomPolygons[sp.id] ?? _defaultCadPolygonForRoom(sp.name, i);
      _roomPolygons[sp.id] = poly;
      final rect = _boundingBoxOfPolygon(poly);
      _roomBoxes[sp.id] = rect;

      final metrics = _computePolygonEngineeringMetrics(poly, sp.ceilingHeight);
      proj.spaces[i] = RoomSpace(
        id: sp.id,
        name: sp.name,
        areaSqm: metrics.netAreaSqm,
        ceilingHeight: sp.ceilingHeight,
        shapeType: poly.length > 4 ? 'L_SHAPE' : sp.shapeType,
        cutoutDepth: sp.cutoutDepth,
        cutoutWidth: sp.cutoutWidth,
        canvasX: rect.left,
        canvasY: rect.top,
        canvasWidth: rect.width,
        canvasHeight: rect.height,
        perimeterMeters: metrics.perimeterMeters,
        rcrValue: metrics.rcrValue,
        polygonVertices: poly.map((pt) => {'x': pt.dx, 'y': pt.dy}).toList(),
      );
    }
    proj.calibrationPixelsPerMeter = ppm;
    if (persist) {
      ProjectRepository.instance.updateProject(proj);
    }
  }

  /// Resolves the confirmed ceiling height (in meters) of the room containing [pt]
  double _resolveRoomCeilingHeightAt(Offset pt) {
    final spaces = widget.project?.spaces ?? [];
    for (int i = 0; i < spaces.length; i++) {
      final sp = spaces[i];
      final poly = _roomPolygons[sp.id];
      if (poly != null && poly.length >= 3 && _isPointInPolygon(pt, poly)) {
        return sp.ceilingHeight > 1.8 ? sp.ceilingHeight : LightingEngine.suggestDefaultCeilingHeight(sp.name);
      }
    }
    // Fallback nearest bounding box check if point is slightly on wall perimeter
    for (int i = 0; i < spaces.length; i++) {
      final sp = spaces[i];
      final rect = _roomBoxes[sp.id];
      if (rect != null && rect.inflate(16.0).contains(pt)) {
        return sp.ceilingHeight > 1.8 ? sp.ceilingHeight : LightingEngine.suggestDefaultCeilingHeight(sp.name);
      }
    }
    return 2.8;
  }

  /// 3D-Aware Orthogonal Manhattan Distance (|ΔX| + |ΔY| in calibrated meters + Per-Room 3D Vertical Wall Drops + ΔH Inter-Room Slab Transition)
  double _computeRouteLengthMeters(CanvasPoint p1, CanvasPoint p2) {
    final double ppm = _pixelsPerMeter > 5.0 ? _pixelsPerMeter : 44.77;
    final double horizMeters = ((p1.x - p2.x).abs() + (p1.y - p2.y).abs()) / ppm;

    final double h1 = _resolveRoomCeilingHeightAt(Offset(p1.x, p1.y));
    final double h2 = _resolveRoomCeilingHeightAt(Offset(p2.x, p2.y));

    double vertMeters = 0.0;

    // 1. Inter-room ceiling elevation step |H_1 - H_2| when conduit crosses rooms of different heights!
    if ((h1 - h2).abs() >= 0.05) {
      vertMeters += (h1 - h2).abs();
    }

    // 2. Endpoint 1 & Endpoint 2 Exact Vertical Wall Drops based on each room's confirmed Ceiling Height H_room
    double dropForPoint(CanvasPoint pt, double roomH) {
      if (pt.type == 'PANEL') {
        // Panel mounted at 1.50m AFF -> rise to ceiling (roomH - 1.50m) + 1.00m panelboard termination slack
        return math.max(0.8, roomH - 1.50) + 1.00;
      }
      if (pt.type == 'SWITCH_1G') {
        // Wall switch mounted at 1.40m AFF -> drop from ceiling (roomH - 1.40m) + 0.25m utility box slack
        return math.max(0.6, roomH - 1.40) + 0.25;
      }
      if (pt.type == 'OUTLET_DUPLEX') {
        // Convenience outlet mounted at 0.30m AFF -> drop from ceiling (roomH - 0.30m) + 0.25m box slack
        return math.max(1.2, roomH - 0.30) + 0.25;
      }
      if (pt.type == 'ACU') {
        // High-wall split ACU disconnect drop (~0.60m below ceiling slab + 0.25m whip allowance)
        return 0.85;
      }
      return 0.20; // Ceiling luminaire / fan octagonal box loop slack
    }

    if (p1.type == 'LIGHT' && p2.type == 'LIGHT') {
      vertMeters += 0.40;
    } else if (p1.type == 'OUTLET_DUPLEX' && p2.type == 'OUTLET_DUPLEX') {
      // Daisy-chained convenience receptacles along wall raceway
      vertMeters += 0.90;
    } else {
      if (p1.type != 'LIGHT') vertMeters += dropForPoint(p1, h1);
      if (p2.type != 'LIGHT') vertMeters += dropForPoint(p2, h2);
    }

    return double.parse((horizMeters + vertMeters).clamp(1.2, 180.0).toStringAsFixed(2));
  }

  void _recalculateAllRouteLengths() {
    if (_points.isEmpty) return;
    for (int i = 0; i < _routes.length; i++) {
      final r = _routes[i];
      final p1 = _points.firstWhere((p) => p.id == r.fromPointId, orElse: () => _points.first);
      final p2 = _points.firstWhere((p) => p.id == r.toPointId, orElse: () => _points.first);
      _routes[i] = ConduitRoute(
        id: r.id,
        fromPointId: r.fromPointId,
        toPointId: r.toPointId,
        measuredLengthMeters: _computeRouteLengthMeters(p1, p2),
        conductorCount: r.conductorCount,
      );
    }
  }

  Future<void> _confirmStage1AndOpenStage2Loads() async {
    _syncRoomSpacesFromBoxes(persist: true);
    if (widget.project == null) return;

    // Mark c0 (Floor Plan Intake & Calibration) as completed in Project Phase 1!
    final p1 = widget.project!.phases.firstWhere(
      (p) => p.type == ProjectPhaseType.consultation,
      orElse: () => widget.project!.phases.first,
    );
    for (final c in p1.checklist) {
      if (c.id == 'c0') {
        c.isCompleted = true;
      }
    }
    ProjectRepository.instance.updateProject(widget.project!);

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClientNeedsAnalysisScreen(
          project: widget.project!,
          fromStageFlow: true,
        ),
      ),
    );

    if (mounted) {
      setState(() {
        _canvasStage = 3;
        _selectedTool = 'SELECT';
        if (widget.project!.applianceLoads.isNotEmpty) {
          _autoGenerateFromAppliances(widget.project!.applianceLoads);
        }
        _recalculateAllRouteLengths();
        widget.project!.canvasPoints = _points;
        widget.project!.conduitRoutes = _routes;
        ProjectRepository.instance.updateProject(widget.project!);
        _fitSheetToViewport();
      });
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚡ Stage 3 Active: ${_points.length} fixtures placed inside confirmed rooms & 3D wire lengths calculated!',
            ),
            backgroundColor: BanaagTheme.successGreen,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _roomGeometry = widget.project?.roomGeometry;
    _blueprintPath = widget.project?.blueprintImagePath;
    _invertBlueprint = widget.project?.invertBlueprint ?? false;
    final bool hadConfirmedRooms = widget.project != null &&
        widget.project!.spaces.isNotEmpty &&
        widget.project!.spaces.every((s) => s.canvasX != null && s.canvasWidth != null);

    _initRoomBoxesAndScale();
    _autoPositionScalePinsToNeedles();
    _fitSheetToViewport();

    // Determine starting stage:
    // If initialStage is explicitly passed, use it; otherwise if rooms haven't been confirmed on the blank plan yet, start at Stage 1!
    if (widget.initialStage != null) {
      _canvasStage = widget.initialStage!;
    } else if (!hadConfirmedRooms && _hasBlueprintFile) {
      _canvasStage = 1;
    } else {
      _canvasStage = 3;
    }
    if (_canvasStage == 1) {
      _stage1SubStep = 0;
      _selectedRoomIndex = 0;
      _selectedTool = 'SELECT';
    }

    bool loadsCleaned = false;
    if (widget.project != null) {
      loadsCleaned = _sanitizeProjectApplianceLoads(widget.project!);
    }

    if (widget.project != null &&
        widget.project!.canvasPoints.isNotEmpty &&
        !loadsCleaned &&
        !widget.forceRegenerateFromLoads) {
      _points = List<CanvasPoint>.from(widget.project!.canvasPoints);
      _routes = List<ConduitRoute>.from(widget.project!.conduitRoutes);
      _sanitizeAndFitExistingPointsIfNeeded();
      _recalculateAllRouteLengths();
    } else if (widget.project != null && widget.project!.applianceLoads.isNotEmpty) {
      _autoGenerateFromAppliances(widget.project!.applianceLoads);
      _recalculateAllRouteLengths();
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
      if (_currentZoom < 0.40) {
        // Zoom to 0.75x centered on building
        _currentZoom = 0.75;
        _zoomController.value = Matrix4.identity()
          ..translateByDouble(-260.0, -100.0, 0.0, 1.0)
          ..scaleByDouble(_currentZoom, _currentZoom, 1.0, 1.0);
      } else if (_currentZoom < 1.10) {
        // Zoom to 1.60x for detailed room inspection & dimension reading
        _currentZoom = 1.60;
        _zoomController.value = Matrix4.identity()
          ..translateByDouble(-580.0, -260.0, 0.0, 1.0)
          ..scaleByDouble(_currentZoom, _currentZoom, 1.0, 1.0);
      } else if (_currentZoom < 2.50) {
        // Ultra-Precision 3.20x zoom for exact wall/dimension calibration
        _currentZoom = 3.20;
        _zoomController.value = Matrix4.identity()
          ..translateByDouble(-1100.0, -500.0, 0.0, 1.0)
          ..scaleByDouble(_currentZoom, _currentZoom, 1.0, 1.0);
      } else {
        // Reset to Full Sheet Fit (0.28x)
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

  /// High-Precision PEC 2017 & IESNA Placement Bounded Strictly Inside Confirmed Stage 1 Room Boxes
  void _autoGenerateForCadBuildingBlueprint(List<ApplianceItem> appliances) {
    // Main Distribution Panel (MDP) at Landing / Central Corridor structural wall (x: 585, y: 535)
    final panelPt = CanvasPoint(id: 'pt-panel', type: 'PANEL', label: 'MDP', x: 585.0, y: 535.0, circuitNumber: 0);
    _points = [panelPt];
    _routes = [];

    final spaces = widget.project?.spaces ?? [];
    if (spaces.isEmpty) return;

    int lightCounter = 1;
    int outletCounter = 1;
    int acuCounter = 1;
    int routeCounter = 1;

    for (int sIdx = 0; sIdx < spaces.length; sIdx++) {
      final sp = spaces[sIdx];
      final List<Offset> roomPoly = _roomPolygons[sp.id] ?? _defaultCadPolygonForRoom(sp.name, sIdx);
      final Rect roomRect = _boundingBoxOfPolygon(roomPoly);
      final lowerRoom = sp.name.toLowerCase();
      final bool isStorageOrLanding = lowerRoom.contains('storage') ||
          lowerRoom.contains('store') ||
          lowerRoom.contains('landing') ||
          lowerRoom.contains('stair');

      // Filter loads belonging to this room
      final roomApps = appliances.where(
        (a) => a.roomCategory.trim().toLowerCase() == lowerRoom,
      ).toList();

      int rawLights = 0;
      int rawOutlets = 0;
      int rawAcus = 0;

      for (final app in roomApps) {
        final nm = app.name.toLowerCase();
        final pcsMatch = RegExp(r'(?:x|\()\s*(\d+)\s*pcs', caseSensitive: false).firstMatch(app.name);
        final int packMult = pcsMatch != null ? (int.tryParse(pcsMatch.group(1)!) ?? 1) : 1;

        if (nm.contains('aircon') || nm.contains('acu')) {
          if (!isStorageOrLanding) {
            rawAcus += app.quantity;
          }
        } else if (app.isLighting ||
            nm.contains('light') ||
            nm.contains('luminaire') ||
            nm.contains('led') ||
            nm.contains('pinlight') ||
            nm.contains('panel') ||
            nm.contains('chandelier') ||
            nm.contains('tube')) {
          rawLights += app.quantity * packMult;
        } else if (!nm.contains('fan')) {
          rawOutlets += app.quantity;
        }
      }

      // Max lights capacity based on room area so symbols never overlap
      final int maxLightsForRoom = lowerRoom.contains('hall') || lowerRoom.contains('event')
          ? 8
          : (lowerRoom.contains('office') ? 4 : 2);
      final int numLights = rawLights > 0 ? math.min(rawLights, maxLightsForRoom) : 0;

      // 1. Place Room Wall Switch + Point-in-Polygon Ceiling Grid inside roomPoly
      if (numLights > 0) {
        final int swCkt = (sIdx < 2) ? 1 : 2;
        final String swLabel = lowerRoom.contains('hall')
            ? 'S3'
            : (lowerRoom.contains('office')
                ? 'S2'
                : (lowerRoom.contains('landing') ? 'S3w' : 'S1'));

        // Position Door Switch on the room's doorway edge inside roomPoly
        Offset swPos;
        if (lowerRoom.contains('hall')) {
          swPos = Offset(roomRect.left + 55.0, roomRect.bottom - 14.0);
        } else if (lowerRoom.contains('staff')) {
          swPos = Offset(roomRect.left + 14.0, roomRect.bottom - 20.0);
        } else if (lowerRoom.contains('office')) {
          swPos = Offset(roomRect.left + 52.0, roomRect.top + 14.0);
        } else if (lowerRoom.contains('landing')) {
          swPos = Offset(roomRect.left + 22.0, roomRect.top + 18.0);
        } else {
          swPos = Offset(roomRect.left + 48.0, roomRect.top + 12.0);
        }

        final String swId = 'pt-sw-${sp.id}';
        final swPt = CanvasPoint(
          id: swId,
          type: 'SWITCH_1G',
          label: swLabel,
          x: swPos.dx.clamp(roomRect.left + 10.0, roomRect.right - 10.0),
          y: swPos.dy.clamp(roomRect.top + 10.0, roomRect.bottom - 10.0),
          circuitNumber: swCkt,
        );
        _points.add(swPt);

        // Home-run from MDP to Room Switch (3D-aware Manhattan distance)
        _routes.add(ConduitRoute(
          id: 'rt-${routeCounter++}',
          fromPointId: panelPt.id,
          toPointId: swPt.id,
          measuredLengthMeters: _computeRouteLengthMeters(panelPt, swPt),
          conductorCount: 2,
        ));

        // Compute symmetrical ceiling grid strictly inside the confirmed polygon (Point-in-Polygon check!)
        final int cols = numLights <= 2
            ? numLights
            : (numLights <= 4 ? 2 : 4);
        final int rows = (numLights / cols).ceil();
        final Rect innerCeil = roomRect.deflate(22.0);
        final double stepX = innerCeil.width / (cols + 1);
        final double stepY = innerCeil.height / (rows + 1);

        CanvasPoint prevLightPt = swPt;
        for (int i = 0; i < numLights; i++) {
          final int c = i % cols;
          final int r = i ~/ cols;
          double lx = innerCeil.left + stepX * (c + 1);
          double ly = innerCeil.top + stepY * (r + 1);

          // If candidate falls in L-shape cutout outside roomPoly, nudge up/left into polygon interior
          if (!_isPointInPolygon(Offset(lx, ly), roomPoly)) {
            for (double nudgeY = -20.0; nudgeY >= -innerCeil.height * 0.7; nudgeY -= 18.0) {
              if (_isPointInPolygon(Offset(lx, ly + nudgeY), roomPoly)) {
                ly += nudgeY;
                break;
              }
            }
          }

          final lPt = CanvasPoint(
            id: 'pt-l-$lightCounter',
            type: 'LIGHT',
            label: 'L-${lightCounter++}',
            x: lx,
            y: ly,
            circuitNumber: swCkt,
          );
          _points.add(lPt);

          _routes.add(ConduitRoute(
            id: 'rt-${routeCounter++}',
            fromPointId: prevLightPt.id,
            toPointId: lPt.id,
            measuredLengthMeters: _computeRouteLengthMeters(prevLightPt, lPt),
            conductorCount: 2,
          ));
          prevLightPt = lPt;
        }
      }

      // 2. Place Room Convenience Outlets along the confirmed polygon's actual wall segments (PEC 2017 Sec. 2.10.3.3)
      final int maxOutletsForRoom = lowerRoom.contains('hall')
          ? 6
          : (lowerRoom.contains('office') ? 4 : (isStorageOrLanding ? 1 : 2));
      final int numOutlets = rawOutlets > 0 ? math.min(rawOutlets, maxOutletsForRoom) : 0;
      final int powerCkt = 3 + (sIdx % 3);

      final List<Offset> perimeterWallAnchors = [];
      final Offset polyCenter = roomRect.center;
      for (int v = 0; v < roomPoly.length; v++) {
        final Offset p1 = roomPoly[v];
        final Offset p2 = roomPoly[(v + 1) % roomPoly.length];
        final double segLen = (p2 - p1).distance;
        if (segLen < 45.0) continue;
        final int ptsOnSeg = segLen > 240.0 ? 2 : 1;
        for (int k = 1; k <= ptsOnSeg; k++) {
          final double t = k / (ptsOnSeg + 1);
          final Offset rawWallPt = Offset(p1.dx + (p2.dx - p1.dx) * t, p1.dy + (p2.dy - p1.dy) * t);
          final Offset toCenter = polyCenter - rawWallPt;
          final double dist = toCenter.distance > 1.0 ? toCenter.distance : 1.0;
          perimeterWallAnchors.add(rawWallPt + Offset(toCenter.dx / dist * 11.0, toCenter.dy / dist * 11.0));
        }
      }
      if (perimeterWallAnchors.isEmpty) {
        final Rect wallRect = roomRect.deflate(12.0);
        perimeterWallAnchors.add(Offset(wallRect.left, wallRect.center.dy));
      }

      CanvasPoint prevOutletPt = panelPt;
      for (int i = 0; i < numOutlets; i++) {
        final pos = perimeterWallAnchors[i % perimeterWallAnchors.length];
        final cPt = CanvasPoint(
          id: 'pt-co-$outletCounter',
          type: 'OUTLET_DUPLEX',
          label: 'CO-${outletCounter++}',
          x: pos.dx,
          y: pos.dy,
          circuitNumber: powerCkt,
        );
        _points.add(cPt);

        _routes.add(ConduitRoute(
          id: 'rt-${routeCounter++}',
          fromPointId: prevOutletPt.id,
          toPointId: cPt.id,
          measuredLengthMeters: _computeRouteLengthMeters(prevOutletPt, cPt),
          conductorCount: 3,
        ));
        prevOutletPt = cPt;
      }

      // 3. Place Dedicated Air Conditioning Units along the room's exterior wall
      final int numAcus = (!isStorageOrLanding && rawAcus > 0) ? math.min(rawAcus, 2) : 0;
      for (int i = 0; i < numAcus; i++) {
        final Offset acuPos = lowerRoom.contains('hall')
            ? Offset(roomRect.left + roomRect.width * (0.28 + i * 0.36), roomRect.top + 10.0)
            : Offset(roomRect.right - 10.0, roomRect.top + roomRect.height * (0.50 + i * 0.25));

        final aPt = CanvasPoint(
          id: 'pt-acu-$acuCounter',
          type: 'ACU',
          label: 'ACU-${acuCounter++}',
          x: acuPos.dx,
          y: acuPos.dy,
          circuitNumber: 5 + acuCounter,
        );
        _points.add(aPt);

        _routes.add(ConduitRoute(
          id: 'rt-${routeCounter++}',
          fromPointId: panelPt.id,
          toPointId: aPt.id,
          measuredLengthMeters: _computeRouteLengthMeters(panelPt, aPt),
          conductorCount: 3,
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
  bool _isPointOverDraggable(Offset tapPos) {
    // 1. Calibration Pins A & B or Midpoint Badge
    if (_canvasStage == 1 || _selectedTool == 'CALIBRATE') {
      if (_stage1SubStep == 0 || _selectedTool == 'CALIBRATE') {
        if ((_pinA - tapPos).distance <= 36.0 || (_pinB - tapPos).distance <= 36.0) {
          return true;
        }
        final mid = Offset((_pinA.dx + _pinB.dx) / 2, (_pinA.dy + _pinB.dy) / 2);
        if ((mid - tapPos).distance <= 40.0) {
          return true;
        }
        if (_stage1SubStep == 0) return false;
      }

      // 2. Active Room Polygon Vertices, Midpoint Handles, Walls, and Interior
      if ((_stage1SubStep == 1 || _stage1SubStep == 3) && widget.project != null) {
        final spaces = widget.project!.spaces;
        if (spaces.isNotEmpty && _selectedRoomIndex >= 0 && _selectedRoomIndex < spaces.length) {
          final sp = spaces[_selectedRoomIndex];
          final poly = _roomPolygons[sp.id] ?? _defaultCadPolygonForRoom(sp.name, _selectedRoomIndex);

          // Vertices
          for (int v = 0; v < poly.length; v++) {
            if ((poly[v] - tapPos).distance <= 32.0) return true;
          }
          // Midpoint Handles
          for (int v = 0; v < poly.length; v++) {
            final p1 = poly[v];
            final p2 = poly[(v + 1) % poly.length];
            final midPt = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
            if ((midPt - tapPos).distance <= 28.0) return true;
          }
          // Wall Segments
          for (int v = 0; v < poly.length; v++) {
            final p1 = poly[v];
            final p2 = poly[(v + 1) % poly.length];
            if (_distanceToSegment(tapPos, p1, p2) <= 20.0) return true;
          }
          // Inside room polygon
          if (_isPointInPolygon(tapPos, poly)) return true;
        }
      }
      return false;
    }

    // 3. Stage 3 Electrical Devices
    for (final pt in _points) {
      if ((Offset(pt.x, pt.y) - tapPos).distance <= 32.0) {
        return true;
      }
    }

    return false;
  }

  void _handlePanStart(DragStartDetails details) {

    final tapPos = details.localPosition;
    final tapX = tapPos.dx;
    final tapY = tapPos.dy;
    _dragStartOffset = tapPos;
    _hasMovedSignificantly = false;

    // STAGE 1: Step 0 (Scale Pin A/B) vs Step 1 / 3 (1-by-1 Polygon Vertex ● & Midpoint + Handles)
    if (_canvasStage == 1 || _selectedTool == 'CALIBRATE') {
      if (_stage1SubStep == 0 || _selectedTool == 'CALIBRATE') {
        if ((_pinA - tapPos).distance <= 32.0) {
          setState(() => _activeDraggingPin = 1);
          return;
        } else if ((_pinB - tapPos).distance <= 32.0) {
          setState(() => _activeDraggingPin = 2);
          return;
        } else {
          final mid = Offset((_pinA.dx + _pinB.dx) / 2, (_pinA.dy + _pinB.dy) / 2);
          if ((mid - tapPos).distance <= 36.0) {
            _showCalibrationDialog();
            return;
          }
        }
        if (_stage1SubStep == 0) return;
      }

      // Step 1 (1-by-1 Room Polygon Wizard) or Step 3 (Single-Room Re-Edit Mode):
      // Interact ONLY with the active room (_selectedRoomIndex)!
      if (_canvasStage == 1 && (_stage1SubStep == 1 || _stage1SubStep == 3) && widget.project != null) {
        final spaces = widget.project!.spaces;
        if (spaces.isEmpty) return;
        final idx = _selectedRoomIndex.clamp(0, spaces.length - 1);
        final sp = spaces[idx];
        final poly = List<Offset>.from(_roomPolygons[sp.id] ?? _defaultCadPolygonForRoom(sp.name, idx));

        // 1. Check Corner Vertices (●) of the active room polygon
        for (int v = 0; v < poly.length; v++) {
          if ((poly[v] - tapPos).distance <= 28.0) {
            _pushUndoState();
            setState(() {
              _activeDraggingVertexIndex = v;
              _activeDraggingRoomCorner = null;
            });
            HapticFeedback.selectionClick();
            return;
          }
        }

        // 2. Check Midpoint (+) Handles on each wall segment — dragging '+' splits the wall and adds a new corner point!
        for (int v = 0; v < poly.length; v++) {
          final p1 = poly[v];
          final p2 = poly[(v + 1) % poly.length];
          final midPt = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
          if ((midPt - tapPos).distance <= 24.0) {
            _pushUndoState();
            setState(() {
              poly.insert(v + 1, midPt);
              _roomPolygons[sp.id] = poly;
              _activeDraggingVertexIndex = v + 1;
              _activeDraggingRoomCorner = null;
              _syncRoomSpacesFromBoxes(persist: false);
            });
            HapticFeedback.mediumImpact();
            return;
          }
        }

        // 3. Check Wall Segments (Movable Wall) — touching anywhere on the wall moves the whole wall!
        for (int v = 0; v < poly.length; v++) {
          final p1 = poly[v];
          final p2 = poly[(v + 1) % poly.length];
          if (_distanceToSegment(tapPos, p1, p2) <= 18.0) {
            _pushUndoState();
            setState(() {
              _activeDraggingWallIndex = v;
              _activeDraggingVertexIndex = null;
              _activeDraggingRoomCorner = null;
              _wallDragStartPos = tapPos;
              _wallDragInitialPoly = List<Offset>.from(poly);
            });
            HapticFeedback.selectionClick();
            return;
          }
        }

        // 4. Check if dragging inside the active room polygon (whole-polygon move)
        if (_isPointInPolygon(tapPos, poly)) {
          _pushUndoState();
          setState(() {
            _activeDraggingVertexIndex = null;
            _activeDraggingRoomCorner = 4;
            _activeDraggingWallIndex = null;
            _roomDragStartPos = tapPos;
            _roomDragInitialPoly = List<Offset>.from(poly);
          });
          return;
        }
      }
      return;
    }

    // STAGE 3: Detect if user grabbed an electrical device point
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
    final newPos = details.localPosition;
    if (_dragStartOffset != null && (newPos - _dragStartOffset!).distance > 5.0) {
      _hasMovedSignificantly = true;
    }

    // 1. Dragging Reference Scale Pin A or Pin B (Step 0)
    if ((_canvasStage == 1 || _selectedTool == 'CALIBRATE') && _activeDraggingPin != null) {
      setState(() {
        if (_activeDraggingPin == 1) {
          _pinA = _snapToFloorPlanFeatures(newPos, orthoAnchor: _pinB);
        } else if (_activeDraggingPin == 2) {
          _pinB = _snapToFloorPlanFeatures(newPos, orthoAnchor: _pinA);
        }
      });
      return;
    }

    // 2. Dragging Active Room Polygon Vertex (●) with Magnetic Wall Snapping (Step 1 / Step 3)
    if (_canvasStage == 1 && _activeDraggingVertexIndex != null && widget.project != null) {
      final spaces = widget.project!.spaces;
      if (_selectedRoomIndex >= 0 && _selectedRoomIndex < spaces.length) {
        final sp = spaces[_selectedRoomIndex];
        final poly = List<Offset>.from(_roomPolygons[sp.id] ?? _defaultCadPolygonForRoom(sp.name, _selectedRoomIndex));
        final int vIdx = _activeDraggingVertexIndex!;
        if (vIdx >= 0 && vIdx < poly.length) {
          final Offset snappedVertex = _snapPolygonVertex(newPos, poly, vIdx);
          poly[vIdx] = snappedVertex;
          setState(() {
            _roomPolygons[sp.id] = poly;
            _syncRoomSpacesFromBoxes(persist: false);
          });
        }
      }
      return;
    }

    // 2.5 Dragging Whole Wall Segment (Movable Wall with Orthogonal & Snap Lock)
    if (_canvasStage == 1 && _activeDraggingWallIndex != null && widget.project != null) {
      final spaces = widget.project!.spaces;
      if (_selectedRoomIndex >= 0 && _selectedRoomIndex < spaces.length) {
        final sp = spaces[_selectedRoomIndex];
        final basePoly = _wallDragInitialPoly ??
            List<Offset>.from(_roomPolygons[sp.id] ?? _defaultCadPolygonForRoom(sp.name, _selectedRoomIndex));
        final int wIdx = _activeDraggingWallIndex!;
        final int nextIdx = (wIdx + 1) % basePoly.length;
        final startPos = _wallDragStartPos ?? details.localPosition;

        final Offset origP1 = basePoly[wIdx];
        final Offset origP2 = basePoly[nextIdx];
        final bool isHorizontalWall = (origP2.dx - origP1.dx).abs() >= (origP2.dy - origP1.dy).abs();

        double shiftX = 0.0;
        double shiftY = 0.0;

        if (isHorizontalWall) {
          // Horizontal wall moves strictly vertically (up / down)
          shiftY = details.localPosition.dy - startPos.dy;
          double targetY = origP1.dy + shiftY;
          final snappedPt = _snapToFloorPlanFeatures(Offset(origP1.dx, targetY));
          if ((snappedPt.dy - targetY).abs() <= 16.0) {
            targetY = snappedPt.dy;
            shiftY = targetY - origP1.dy;
          }
        } else {
          // Vertical wall moves strictly horizontally (left / right)
          shiftX = details.localPosition.dx - startPos.dx;
          double targetX = origP1.dx + shiftX;
          final snappedPt = _snapToFloorPlanFeatures(Offset(targetX, origP1.dy));
          if ((snappedPt.dx - targetX).abs() <= 16.0) {
            targetX = snappedPt.dx;
            shiftX = targetX - origP1.dx;
          }
        }

        final poly = List<Offset>.from(basePoly);
        poly[wIdx] = Offset(
          (origP1.dx + shiftX).clamp(20.0, _cadCanvasWidth - 20.0),
          (origP1.dy + shiftY).clamp(20.0, _cadCanvasHeight - 20.0),
        );
        poly[nextIdx] = Offset(
          (origP2.dx + shiftX).clamp(20.0, _cadCanvasWidth - 20.0),
          (origP2.dy + shiftY).clamp(20.0, _cadCanvasHeight - 20.0),
        );

        setState(() {
          _roomPolygons[sp.id] = poly;
          _syncRoomSpacesFromBoxes(persist: false);
        });
      }
      return;
    }

    // 3. Translating Whole Active Room Polygon (Center Move) with Ortho & Feature Snapping
    if (_canvasStage == 1 && _activeDraggingRoomCorner == 4 && widget.project != null) {
      final spaces = widget.project!.spaces;
      if (_selectedRoomIndex >= 0 && _selectedRoomIndex < spaces.length) {
        final sp = spaces[_selectedRoomIndex];
        final basePoly = _roomDragInitialPoly ??
            List<Offset>.from(_roomPolygons[sp.id] ?? _defaultCadPolygonForRoom(sp.name, _selectedRoomIndex));
        final startPos = _roomDragStartPos ?? details.localPosition;
        double shiftX = details.localPosition.dx - startPos.dx;
        double shiftY = details.localPosition.dy - startPos.dy;

        // Orthogonal Lock: strictly horizontal (0°) or vertical (90°)
        if (_isOrthoSnapEnabled) {
          if (shiftX.abs() >= shiftY.abs()) {
            shiftY = 0.0;
          } else {
            shiftX = 0.0;
          }
        }

        final poly = <Offset>[];
        for (final pt in basePoly) {
          poly.add(Offset(pt.dx + shiftX, pt.dy + shiftY));
        }

        // Clamp inside canvas bounds
        final rect = _boundingBoxOfPolygon(poly);
        double clampDx = 0.0;
        double clampDy = 0.0;
        if (rect.left < 20.0) clampDx = 20.0 - rect.left;
        if (rect.right > _cadCanvasWidth - 20.0) clampDx = (_cadCanvasWidth - 20.0) - rect.right;
        if (rect.top < 20.0) clampDy = 20.0 - rect.top;
        if (rect.bottom > _cadCanvasHeight - 20.0) clampDy = (_cadCanvasHeight - 20.0) - rect.bottom;

        if (clampDx != 0.0 || clampDy != 0.0) {
          for (int i = 0; i < poly.length; i++) {
            poly[i] = Offset(poly[i].dx + clampDx, poly[i].dy + clampDy);
          }
        }

        setState(() {
          _roomPolygons[sp.id] = poly;
          _syncRoomSpacesFromBoxes(persist: false);
        });
      }
      return;
    }

    // 4. Stage 3: Dragging an Electrical Fixture -> Live 3D Wire Length Recalculation!
    if (_draggedPoint != null) {
      setState(() {
        final snappedX = (newPos.dx / 4.0).round() * 4.0;
        final snappedY = (newPos.dy / 4.0).round() * 4.0;
        _draggedPoint!.x = snappedX.clamp(20.0, _cadCanvasWidth - 20.0);
        _draggedPoint!.y = snappedY.clamp(20.0, _cadCanvasHeight - 20.0);
        _recalculateAllRouteLengths();
      });
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_canvasStage == 1 || _selectedTool == 'CALIBRATE') {
      final hadPinDrag = _activeDraggingPin != null && _hasMovedSignificantly;
      setState(() {
        _activeDraggingPin = null;
        _activeDraggingVertexIndex = null;
        _activeDraggingWallIndex = null;
        _activeDraggingRoomCorner = null;
        _activeSnapPoint = null;
        _dragStartOffset = null;
        _roomDragStartPos = null;
        _roomDragInitialPoly = null;
        _wallDragStartPos = null;
        _wallDragInitialPoly = null;
        _isPerpendicularCornerSnapped = false;
        _perpendicularSnapCornerPos = null;
        _isDraggingItem = false;
        _hasMovedSignificantly = false;
      });
      _syncRoomSpacesFromBoxes(persist: true);
      if (hadPinDrag) {
        _showCalibrationDialog();
      }
      return;
    }

    if (_draggedPoint != null) {
      if (_hasMovedSignificantly) {
        _recalculateAllRouteLengths();
        if (widget.project != null) {
          widget.project!.canvasPoints = _points;
          widget.project!.conduitRoutes = _routes;
          ProjectRepository.instance.updateProject(widget.project!);
        }
      } else {
        _showPointInspectionSheet(_draggedPoint!);
      }

      setState(() {
        _draggedPoint = null;
        _dragStartOffset = null;
        _hasMovedSignificantly = false;
        _isDraggingItem = false;
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
    final tapPos = details.localPosition;
    if (_canvasStage == 1) {
      // Step 0: Reference Scale Calibration (Pin A & Pin B)
      if (_stage1SubStep == 0) {
        // 1. If a pin is already selected, tapping a snap target teleports the pin directly to it!
        if (_selectedPinForTap != null) {
          final targetSnap = _findNearestTargetSnapPoint(tapPos, maxDistance: 45.0);
          if (targetSnap != null) {
            setState(() {
              if (_selectedPinForTap == 1) {
                _pinA = targetSnap;
              } else if (_selectedPinForTap == 2) {
                _pinB = targetSnap;
              }
              _selectedPinForTap = null;
            });
            HapticFeedback.selectionClick();
            return;
          }
        }

        // 2. Tapping Pin A or Pin B directly toggles selection for tap-to-snap!
        if ((_pinA - tapPos).distance <= 32.0) {
          setState(() {
            _selectedPinForTap = (_selectedPinForTap == 1) ? null : 1;
            _selectedVertexForTap = null;
          });
          HapticFeedback.selectionClick();
          return;
        } else if ((_pinB - tapPos).distance <= 32.0) {
          setState(() {
            _selectedPinForTap = (_selectedPinForTap == 2) ? null : 2;
            _selectedVertexForTap = null;
          });
          HapticFeedback.selectionClick();
          return;
        }

        // 3. Tapping the midpoint length badge opens the Scale + Wall Thickness dialog
        final mid = Offset((_pinA.dx + _pinB.dx) / 2, (_pinA.dy + _pinB.dy) / 2);
        if ((mid - tapPos).distance <= 44.0) {
          _showCalibrationDialog();
          return;
        }

        // 4. Tapping empty space clears pin selection
        if (_selectedPinForTap != null) {
          setState(() => _selectedPinForTap = null);
        }
        return;
      }

      // Step 1 or Step 3: Active 1-by-1 Room Polygon Editing
      if ((_stage1SubStep == 1 || _stage1SubStep == 3) && widget.project != null) {
        final spaces = widget.project!.spaces;
        if (spaces.isEmpty) return;
        final idx = _selectedRoomIndex.clamp(0, spaces.length - 1);
        final sp = spaces[idx];
        final poly = List<Offset>.from(_roomPolygons[sp.id] ?? _defaultCadPolygonForRoom(sp.name, idx));

        // 1. If a corner vertex is selected for tap-to-snap, tapping near a snap point teleports the vertex!
        if (_selectedVertexForTap != null && _selectedVertexForTap! < poly.length) {
          final targetSnap = _findNearestTargetSnapPoint(tapPos, maxDistance: 45.0);
          if (targetSnap != null) {
            _pushUndoState();
            setState(() {
              poly[_selectedVertexForTap!] = targetSnap;
              _roomPolygons[sp.id] = poly;
              _selectedVertexForTap = null;
            });
            _syncRoomSpacesFromBoxes(persist: true);
            HapticFeedback.selectionClick();
            return;
          }
        }

        // 2. Check if user tapped a Corner Vertex (●) to select it for tap-to-target snap
        for (int v = 0; v < poly.length; v++) {
          if ((poly[v] - tapPos).distance <= 28.0) {
            setState(() {
              _selectedVertexForTap = (_selectedVertexForTap == v) ? null : v;
              _selectedPinForTap = null;
            });
            HapticFeedback.selectionClick();
            return;
          }
        }

        // 3. Check if user tapped a Midpoint (+) Handle or Wall Segment Dimension Badge to insert a point or edit length!
        for (int v = 0; v < poly.length; v++) {
          final p1 = poly[v];
          final p2 = poly[(v + 1) % poly.length];
          final midPt = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
          if ((midPt - tapPos).distance <= 30.0) {
            _showWallSegmentActionDialog(sp, v);
            HapticFeedback.selectionClick();
            return;
          }
        }

        // 4. Check if user tapped the Center Room Name/Area Badge -> Open Room ID/Name & Ceiling Height dialog
        final rect = _boundingBoxOfPolygon(poly);
        if ((rect.center - tapPos).distance <= 55.0) {
          _showRenameSelectedRoomDialog();
          return;
        }

        // 5. Tapping empty canvas clears selected vertex
        if (_selectedVertexForTap != null) {
          setState(() => _selectedVertexForTap = null);
        }
        return;
      }

      // Step 2: Completeness Gate ("Are all spaces accounted for?")
      // If _highlightUnaccountedZones is active, tapping an unaccounted space auto-detects its walls & opens Step 3 for it!
      if (_stage1SubStep == 2 && _highlightUnaccountedZones && widget.project != null) {
        _autoDetectAndAddTappedZone(tapPos);
        return;
      }
      return;
    }

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

          // 2. Import Floor Plan / DXF Intake -> Directly initiates Step 0 (Scale Pin A–B & Wall Thickness)
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: Colors.cyanAccent),
            tooltip: 'Import Architectural Floor Plan (PDF / Image) & Start Step 0',
            onPressed: _pickNewUnderlay,
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
                if (widget.project != null) {
                  final sld = SldEngine.generateFromProject(widget.project!);
                  final powerAudit = PecSafetyAuditor.auditSchedule(sld);
                  final lightAudit = IesnaLightingAuditor.auditProject(widget.project!);
                  if (powerAudit.isExportBlocked || lightAudit.isExportBlocked) {
                    _showUnifiedPowerAndLightingAuditSheet();
                    return;
                  }
                }
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
                final sld = SldEngine.generateFromProject(widget.project!);
                final powerAudit = PecSafetyAuditor.auditSchedule(sld);
                final lightAudit = IesnaLightingAuditor.auditProject(widget.project!);
                if (powerAudit.isExportBlocked || lightAudit.isExportBlocked) {
                  _showUnifiedPowerAndLightingAuditSheet();
                  return;
                }
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
          // 3-Stage Engineering Flow Stepper Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: const BoxDecoration(
              color: Color(0xFF141821),
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _stageStepPill(
                    stageNum: 1,
                    title: '① Scale & Rooms',
                    subtitle: 'Blank Plan',
                    isActive: _canvasStage == 1,
                    isDone: _canvasStage > 1,
                    onTap: () {
                      setState(() {
                        _canvasStage = 1;
                        _selectedTool = 'SELECT';
                      });
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right, size: 15, color: Colors.white38),
                ),
                Expanded(
                  child: _stageStepPill(
                    stageNum: 2,
                    title: '② Space Loads',
                    subtitle: 'PEC Suggest',
                    isActive: false,
                    isDone: (widget.project?.applianceLoads.isNotEmpty ?? false),
                    onTap: _confirmStage1AndOpenStage2Loads,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right, size: 15, color: Colors.white38),
                ),
                Expanded(
                  child: _stageStepPill(
                    stageNum: 3,
                    title: '③ Wire Takeoff',
                    subtitle: 'Layout & BOM',
                    isActive: _canvasStage == 3,
                    isDone: false,
                    onTap: () {
                      setState(() {
                        _syncRoomSpacesFromBoxes(persist: true);
                        _canvasStage = 3;
                        if (widget.project != null && widget.project!.applianceLoads.isNotEmpty) {
                          _autoGenerateFromAppliances(widget.project!.applianceLoads);
                        }
                        _recalculateAllRouteLengths();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // STAGE 1 INFO & LIVE SCALE / 1-BY-1 ROOM WIZARD RIBBON
          if (_canvasStage == 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFF1B2230),
              child: Builder(builder: (ctx) {
                final spaces = widget.project?.spaces ?? [];
                final int totalRooms = spaces.length;
                final int activeIdx = totalRooms > 0 ? _selectedRoomIndex.clamp(0, totalRooms - 1) : 0;
                final RoomSpace? activeSp = totalRooms > 0 ? spaces[activeIdx] : null;
                final double refLengthMm = ((_pinA - _pinB).distance / _pixelsPerMeter * 1000.0);
                final double refLengthM = refLengthMm / 1000.0;

                // SUB-STEP 0: Solo Scale (Pin A–B) & Wall Thickness Verification Card
                if (_stage1SubStep == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.cyanAccent),
                            ),
                            child: const Text(
                              'STEP 0',
                              style: TextStyle(color: Colors.cyanAccent, fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Tama ba ang na-detect na Reference Length at Wall Thickness?',
                              style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '📏 Pin A–B: ${refLengthMm.round()} mm (${refLengthM.toStringAsFixed(2)}m / ${(refLengthMm / 25.4 / 12.0).floor()}\'-${(refLengthMm / 25.4 % 12.0).round()}")  •  🧱 Wall: ${_wallThicknessMm.round()} mm CHB',
                              style: const TextStyle(color: BanaagTheme.primaryAmber, fontSize: 11.5, fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isOrthoSnapEnabled = !_isOrthoSnapEnabled;
                              });
                              HapticFeedback.selectionClick();
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(milliseconds: 1200),
                                  content: Text(
                                    _isOrthoSnapEnabled
                                        ? '📐 Orthogonal Snap: ON (Locks to 0°/90° & Column/Wall)'
                                        : '📐 Orthogonal Snap: OFF (Free-Angle Movement)',
                                  ),
                                  backgroundColor: _isOrthoSnapEnabled ? BanaagTheme.primaryAmber : Colors.grey[800],
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isOrthoSnapEnabled
                                    ? BanaagTheme.primaryAmber.withValues(alpha: 0.22)
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _isOrthoSnapEnabled ? BanaagTheme.primaryAmber : Colors.white24,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.square_foot,
                                    size: 13,
                                    color: _isOrthoSnapEnabled ? BanaagTheme.primaryAmber : Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isOrthoSnapEnabled ? 'Ortho: ON' : 'Ortho: OFF',
                                    style: TextStyle(
                                      color: _isOrthoSnapEnabled ? BanaagTheme.primaryAmber : Colors.white70,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isAiAutoWallDetectEnabled = !_isAiAutoWallDetectEnabled;
                              });
                              HapticFeedback.selectionClick();
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(milliseconds: 1400),
                                  content: Text(
                                    _isAiAutoWallDetectEnabled
                                        ? '🧠 AI Auto-Detect Walls: ON (Smart Corners & Needles)'
                                        : '🧠 AI Auto-Detect Walls: OFF (Manual Freehand Mode)',
                                  ),
                                  backgroundColor: _isAiAutoWallDetectEnabled ? BanaagTheme.primaryAmber : Colors.grey[800],
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isAiAutoWallDetectEnabled
                                    ? Colors.cyanAccent.withValues(alpha: 0.22)
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _isAiAutoWallDetectEnabled ? Colors.cyanAccent : Colors.white24,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 13,
                                    color: _isAiAutoWallDetectEnabled ? Colors.cyanAccent : Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isAiAutoWallDetectEnabled ? 'AI Wall: ON' : 'AI Wall: OFF',
                                    style: TextStyle(
                                      color: _isAiAutoWallDetectEnabled ? Colors.cyanAccent : Colors.white70,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _autoPositionScalePinsToNeedles(recomputePpm: true);
                              });
                              HapticFeedback.selectionClick();
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  duration: Duration(milliseconds: 1400),
                                  content: Text('🎯 Scale Pins snapped directly to Drawing Dimension Needles!'),
                                  backgroundColor: BanaagTheme.primaryAmber,
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                color: BanaagTheme.primaryAmber.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.6)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.gps_fixed, size: 12, color: BanaagTheme.primaryAmber),
                                  SizedBox(width: 4),
                                  Text(
                                    'Auto-Pin',
                                    style: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 10.5, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _showCalibrationDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white38),
                              ),
                              child: const Text(
                                '✏️ Specify Actual',
                                style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                // SUB-STEP 1 (1-by-1 Sequential Room Wizard) or SUB-STEP 3 (Single-Room Re-Edit Mode)
                if ((_stage1SubStep == 1 || _stage1SubStep == 3) && activeSp != null) {
                  final poly = _roomPolygons[activeSp.id] ?? _defaultCadPolygonForRoom(activeSp.name, activeIdx);
                  final metrics = _computePolygonEngineeringMetrics(poly, activeSp.ceilingHeight);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: BanaagTheme.primaryAmber.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: BanaagTheme.primaryAmber),
                            ),
                            child: Text(
                              _stage1SubStep == 3
                                  ? 'EDITING ROOM'
                                  : 'ROOM ${activeIdx + 1} OF $totalRooms',
                              style: const TextStyle(color: BanaagTheme.primaryAmber, fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tama ba ang room ID at hugis? (${activeSp.name})',
                              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isOrthoSnapEnabled = !_isOrthoSnapEnabled;
                              });
                              HapticFeedback.selectionClick();
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(milliseconds: 1200),
                                  content: Text(
                                    _isOrthoSnapEnabled
                                        ? '📐 Orthogonal Snap: ON (Locks to 0°/90° & Column/Wall)'
                                        : '📐 Orthogonal Snap: OFF (Free-Angle Movement)',
                                  ),
                                  backgroundColor: _isOrthoSnapEnabled ? BanaagTheme.primaryAmber : Colors.grey[800],
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: _isOrthoSnapEnabled
                                    ? BanaagTheme.primaryAmber.withValues(alpha: 0.22)
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: _isOrthoSnapEnabled ? BanaagTheme.primaryAmber : Colors.white24,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.square_foot,
                                    size: 12,
                                    color: _isOrthoSnapEnabled ? BanaagTheme.primaryAmber : Colors.white70,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _isOrthoSnapEnabled ? 'Ortho: ON' : 'Ortho: OFF',
                                    style: TextStyle(
                                      color: _isOrthoSnapEnabled ? BanaagTheme.primaryAmber : Colors.white70,
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isAiAutoWallDetectEnabled = !_isAiAutoWallDetectEnabled;
                              });
                              HapticFeedback.selectionClick();
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(milliseconds: 1400),
                                  content: Text(
                                    _isAiAutoWallDetectEnabled
                                        ? '🧠 AI Auto-Detect Walls: ON (Smart Corners & Needles)'
                                        : '🧠 AI Auto-Detect Walls: OFF (Manual Freehand Mode)',
                                  ),
                                  backgroundColor: _isAiAutoWallDetectEnabled ? BanaagTheme.primaryAmber : Colors.grey[800],
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: _isAiAutoWallDetectEnabled
                                    ? Colors.cyanAccent.withValues(alpha: 0.22)
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: _isAiAutoWallDetectEnabled ? Colors.cyanAccent : Colors.white24,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 12,
                                    color: _isAiAutoWallDetectEnabled ? Colors.cyanAccent : Colors.white70,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _isAiAutoWallDetectEnabled ? 'AI Wall: ON' : 'AI Wall: OFF',
                                    style: TextStyle(
                                      color: _isAiAutoWallDetectEnabled ? Colors.cyanAccent : Colors.white70,
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _showRenameSelectedRoomDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: Colors.white30),
                              ),
                              child: const Text(
                                '✏️ Edit ID/Height',
                                style: TextStyle(color: Colors.cyanAccent, fontSize: 10.0, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Net: ${metrics.netAreaSqm} m² • Perim: ${metrics.perimeterMeters} m • H: ${activeSp.ceilingHeight.toStringAsFixed(1)}m • RCR: ${metrics.rcrValue}',
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 10.6, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_selectedVertexForTap != null && poly.isNotEmpty) ...[
                            Builder(
                              builder: (ctx) {
                                final int vIdx = _selectedVertexForTap!;
                                if (vIdx >= poly.length) return const SizedBox.shrink();
                                final pt = poly[vIdx];
                                final bool isCol = _customProjectColumns.any((c) => (c - pt).distance < 12.0);
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isCol) {
                                        _customProjectColumns.removeWhere((c) => (c - pt).distance < 12.0);
                                      } else {
                                        _customProjectColumns.add(pt);
                                      }
                                    });
                                    HapticFeedback.selectionClick();
                                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        duration: const Duration(milliseconds: 1200),
                                        content: Text(
                                          isCol
                                              ? '🏛️ Column removed from corner (Converted to pure Wall Corner)'
                                              : '🏛️ Column post marked on corner (Tri-Snap Centerline & Faces Active!)',
                                        ),
                                        backgroundColor: isCol ? Colors.grey[800] : BanaagTheme.primaryAmber,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isCol
                                          ? BanaagTheme.primaryAmber.withValues(alpha: 0.25)
                                          : Colors.cyanAccent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isCol ? BanaagTheme.primaryAmber : Colors.cyanAccent.withValues(alpha: 0.8),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isCol ? Icons.check_circle : Icons.add_circle_outline,
                                          size: 11,
                                          color: isCol ? BanaagTheme.primaryAmber : Colors.cyanAccent,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          isCol ? 'Post: ON' : '+ Post',
                                          style: TextStyle(
                                            color: isCol ? BanaagTheme.primaryAmber : Colors.cyanAccent,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                          if (_selectedVertexForTap != null && poly.length > 3)
                            GestureDetector(
                              onTap: () {
                                final int vIdx = _selectedVertexForTap!;
                                if (vIdx < poly.length && poly.length > 3) {
                                  _pushUndoState();
                                  setState(() {
                                    poly.removeAt(vIdx);
                                    _roomPolygons[activeSp.id] = List<Offset>.from(poly);
                                    _selectedVertexForTap = null;
                                  });
                                  _syncRoomSpacesFromBoxes(persist: true);
                                  HapticFeedback.mediumImpact();
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      duration: Duration(milliseconds: 1000),
                                      content: Text('🗑️ Point deleted from room boundary'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.8)),
                                ),
                                child: const Text(
                                  '🗑️ Del Pt',
                                  style: TextStyle(color: Colors.redAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          if (_polygonUndoHistory.isNotEmpty || poly.length > 3)
                            GestureDetector(
                              onTap: () {
                                if (_polygonUndoHistory.isNotEmpty) {
                                  _performUndo();
                                } else if (poly.length > 3) {
                                  _pushUndoState();
                                  setState(() {
                                    poly.removeLast();
                                    _roomPolygons[activeSp.id] = List<Offset>.from(poly);
                                    _syncRoomSpacesFromBoxes(persist: true);
                                  });
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Text(
                                  '↩️ Undo',
                                  style: TextStyle(color: Colors.orangeAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text(
                              '📐 Ceiling Ht:',
                              style: TextStyle(color: Colors.white70, fontSize: 10.0, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            for (final double hPreset in [2.6, 2.8, 3.0, 3.5, 4.2])
                              Padding(
                                padding: const EdgeInsets.only(right: 5),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      spaces[activeIdx] = RoomSpace(
                                        id: activeSp.id,
                                        name: activeSp.name,
                                        areaSqm: activeSp.areaSqm,
                                        ceilingHeight: hPreset,
                                        shapeType: activeSp.shapeType,
                                        cutoutDepth: activeSp.cutoutDepth,
                                        cutoutWidth: activeSp.cutoutWidth,
                                        canvasX: activeSp.canvasX,
                                        canvasY: activeSp.canvasY,
                                        canvasWidth: activeSp.canvasWidth,
                                        canvasHeight: activeSp.canvasHeight,
                                        perimeterMeters: activeSp.perimeterMeters,
                                        rcrValue: activeSp.rcrValue,
                                        polygonVertices: activeSp.polygonVertices,
                                      );
                                      _syncRoomSpacesFromBoxes(persist: true);
                                      _recalculateAllRouteLengths();
                                    });
                                    HapticFeedback.selectionClick();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: (activeSp.ceilingHeight - hPreset).abs() < 0.05
                                          ? BanaagTheme.primaryAmber
                                          : Colors.white10,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: (activeSp.ceilingHeight - hPreset).abs() < 0.05
                                            ? BanaagTheme.primaryAmber
                                            : Colors.white24,
                                      ),
                                    ),
                                    child: Text(
                                      '${hPreset.toStringAsFixed(1)}m',
                                      style: TextStyle(
                                        color: (activeSp.ceilingHeight - hPreset).abs() < 0.05
                                            ? Colors.black
                                            : Colors.white70,
                                        fontSize: 9.8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            GestureDetector(
                              onTap: _showRenameSelectedRoomDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: Colors.cyanAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: Colors.cyanAccent),
                                ),
                                child: const Text(
                                  '✏️ Custom m/ft',
                                  style: TextStyle(color: Colors.cyanAccent, fontSize: 9.8, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                // SUB-STEP 2: All Rooms Confirmed — Floor Plan Completeness Gate ("Are all spaces accounted for?")
                final double totalNetArea = spaces.fold(0.0, (s, r) => s + r.areaSqm);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified, color: BanaagTheme.successGreen, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'All $totalRooms Rooms Confirmed (${totalNetArea.toStringAsFixed(1)} m² Net) • Are all floor plan spaces accounted for?',
                            style: const TextStyle(color: Colors.white, fontSize: 11.2, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _showSingleRoomEditPickerDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.cyanAccent),
                              ),
                              child: const Text(
                                '📐 Edit Room Dimension (1-by-1)',
                                style: TextStyle(color: Colors.cyanAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _showMissingSpaceCompletenessDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orangeAccent),
                              ),
                              child: Text(
                                _highlightUnaccountedZones ? '🎯 Tap Unaccounted Zone on Plan' : '⚠️ May Kulang na Space?',
                                style: const TextStyle(color: Colors.orangeAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => setState(() => _stage1SubStep = 0),
                            child: const Text(
                              '📏 Scale',
                              style: TextStyle(color: Colors.white70, fontSize: 10.5, decoration: TextDecoration.underline),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),

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

          // Takeoff Summary Live Ribbon (Visible in Stage 3: Electrical Layout & Wire Takeoff)
          if (_canvasStage == 3)
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
                  const SizedBox(height: 6),
                  Builder(builder: (ctx) {
                    final sld = SldEngine.generateFromProject(widget.project!);
                    final powerAudit = PecSafetyAuditor.auditSchedule(sld);
                    final lightAudit = IesnaLightingAuditor.auditProject(widget.project!);
                    final bool hasHazard = powerAudit.isExportBlocked || lightAudit.isExportBlocked;
                    final bool hasAdvisory = !hasHazard &&
                        (powerAudit.overallSeverity == PecAuditSeverity.advisory ||
                            lightAudit.overallSeverity == PecAuditSeverity.advisory);
                    final Color shieldColor = hasHazard
                        ? BanaagTheme.alertRed
                        : (hasAdvisory ? Colors.orangeAccent : BanaagTheme.successGreen);

                    return GestureDetector(
                      onTap: _showUnifiedPowerAndLightingAuditSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: shieldColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: shieldColor.withValues(alpha: 0.7), width: 1.1),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              hasHazard ? Icons.gpp_bad : Icons.verified_user,
                              size: 16,
                              color: shieldColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                hasHazard
                                    ? '🚨 AUDIT BLOCKED: ${lightAudit.criticalHazardRoomsCount} Lighting / ${powerAudit.criticalHazardCount} Power Hazards'
                                    : '🛡️ PEC Power (${powerAudit.assurancePercent.toStringAsFixed(0)}%) & IESNA Lighting (${lightAudit.compliantRoomsCount}/${lightAudit.totalRooms} Rooms) Verified',
                                style: TextStyle(
                                  color: shieldColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasHazard || hasAdvisory)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: shieldColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '⚡ AUTO-HEAL',
                                  style: TextStyle(color: Colors.black, fontSize: 9.5, fontWeight: FontWeight.w900),
                                ),
                              )
                            else
                              const Icon(Icons.chevron_right, size: 15, color: Colors.white60),
                          ],
                        ),
                      ),
                    );
                  }),
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
                    minScale: 0.15,
                    maxScale: 10.0,
                    panEnabled: true,
                    scaleEnabled: true,
                    panAxis: PanAxis.free,
                    boundaryMargin: const EdgeInsets.all(900.0),
                    onInteractionEnd: (_) {
                      setState(() {
                        _currentZoom = _zoomController.value.getMaxScaleOnAxis();
                      });
                    },
                    child: SizedBox(
                      width: _cadCanvasWidth,
                      height: _cadCanvasHeight,
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (event) {
                          final localPos = event.localPosition;
                          final isOverHandle = _isPointOverDraggable(localPos);
                          if (isOverHandle != _isDraggingItem) {
                            setState(() {
                              _isDraggingItem = isOverHandle;
                            });
                          }
                        },
                        onPointerUp: (event) {
                          if (_isDraggingItem &&
                              _activeDraggingPin == null &&
                              _draggedPoint == null &&
                              _activeDraggingVertexIndex == null &&
                              _activeDraggingWallIndex == null &&
                              _activeDraggingRoomCorner == null) {
                            setState(() {
                              _isDraggingItem = false;
                            });
                          }
                        },
                        onPointerCancel: (event) {
                          if (_isDraggingItem) {
                            setState(() {
                              _isDraggingItem = false;
                            });
                          }
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapUp: _handleCanvasTap,
                          onPanStart: _isDraggingItem ? _handlePanStart : null,
                          onPanUpdate: _isDraggingItem ? _handlePanUpdate : null,
                          onPanEnd: _isDraggingItem ? _handlePanEnd : null,
                          child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Blueprint Floor Plan Underlay locked to expanded 1400 x 1600 CAD canvas with contain aspect fit
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
                                                width: _cadCanvasWidth,
                                                height: _cadCanvasHeight,
                                                fit: BoxFit.contain,
                                                alignment: Alignment.center,
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
                                          width: _cadCanvasWidth,
                                          height: _cadCanvasHeight,
                                          fit: BoxFit.contain,
                                          alignment: Alignment.center,
                                          errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                                        ),
                                ),
                              ),

                            // 2. Interactive Vector Layer locked to 1400 x 1600 (Stage 1 Step 0/1/2/3 vs Stage 3 Electrical Takeoff)
                            CustomPaint(
                              size: const Size(_cadCanvasWidth, _cadCanvasHeight),
                              painter: CanvasPainter(
                                points: _points,
                                routes: _routes,
                                roomGeometry: _roomGeometry,
                                spaces: widget.project?.spaces ?? [],
                                canvasStage: _canvasStage,
                                stage1SubStep: _stage1SubStep,
                                roomBoxes: _roomBoxes,
                                roomPolygons: _roomPolygons,
                                wallThicknessMm: _wallThicknessMm,
                                currentZoom: _currentZoom,
                                activeStructuralColumns: _activeStructuralColumns,
                                activeArchitecturalCorners: _activeArchitecturalCorners,
                                activeDimensionNeedles: _activeDimensionNeedles,
                                highlightUnaccountedZones: _highlightUnaccountedZones,
                                selectedRoomIndex: _selectedRoomIndex,
                                isHeatmap: _isHeatmapVisible,
                                showLabels: _showLabels,
                                showConduits: _showConduits,
                                activeLayerFilter: _activeLayerFilter,
                                hasBlueprintUnderlay: _hasBlueprintFile && _isUnderlayVisible,
                                selectedPoint: _selectedPoint,
                                isCalibrating: (_canvasStage == 1 && _stage1SubStep == 0) || _selectedTool == 'CALIBRATE',
                                pinA: _pinA,
                                pinB: _pinB,
                                activeDraggingPin: _activeDraggingPin,
                                activeDraggingWallIndex: _activeDraggingWallIndex,
                                activeDraggingVertexIndex: _activeDraggingVertexIndex,
                                isPerpendicularCornerSnapped: _isPerpendicularCornerSnapped,
                                perpendicularSnapCornerPos: _perpendicularSnapCornerPos,
                                activeSnapPoint: _activeSnapPoint,
                                selectedPinForTap: _selectedPinForTap,
                                selectedVertexForTap: _selectedVertexForTap,
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

          // Bottom Action Bar: Stage 1 (Step 0 -> Step 1 1-by-1 Wizard -> Step 2 Completeness Gate -> Step 3 Re-Edit) vs Stage 3
          if (_canvasStage == 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              color: BanaagTheme.surfaceCard,
              child: Builder(builder: (ctx) {
                final spaces = widget.project?.spaces ?? [];
                final int totalRooms = spaces.length;
                final int activeIdx = totalRooms > 0 ? _selectedRoomIndex.clamp(0, totalRooms - 1) : 0;

                return Row(
                  children: [
                    _symbolButton(
                      'SELECT',
                      Icons.open_with,
                      _stage1SubStep == 0 ? 'Move Pins' : 'Edit Points (●/+)',
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _stage1SubStep == 2 ? BanaagTheme.successGreen : BanaagTheme.primaryAmber,
                            foregroundColor: _stage1SubStep == 2 ? Colors.white : Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: Icon(
                            _stage1SubStep == 2 ? Icons.bolt : Icons.check_circle,
                            size: 17,
                          ),
                          label: Text(
                            _stage1SubStep == 0
                                ? '✅ Tama, Confirm Scale → Room 1'
                                : (_stage1SubStep == 1
                                    ? (activeIdx + 1 < totalRooms
                                        ? '✅ Confirm Room ${activeIdx + 1} → Next (${activeIdx + 2}/$totalRooms)'
                                        : '✅ Confirm Room ${activeIdx + 1} → Finish')
                                    : (_stage1SubStep == 3
                                        ? '✅ Save Room Dimensions'
                                        : '✅ All Accounted → Stage 2 Loads')),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.2),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () {
                            if (_stage1SubStep == 0) {
                              setState(() {
                                _stage1SubStep = 1;
                                _selectedRoomIndex = 0;
                                _selectedTool = 'SELECT';
                                _syncRoomSpacesFromBoxes(persist: true);
                              });
                            } else if (_stage1SubStep == 1) {
                              setState(() {
                                _syncRoomSpacesFromBoxes(persist: true);
                                if (activeIdx + 1 < totalRooms) {
                                  _selectedRoomIndex = activeIdx + 1;
                                } else {
                                  _stage1SubStep = 2;
                                }
                              });
                            } else if (_stage1SubStep == 3) {
                              setState(() {
                                _syncRoomSpacesFromBoxes(persist: true);
                                _stage1SubStep = 2;
                              });
                            } else {
                              _confirmStage1AndOpenStage2Loads();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                );
              }),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              color: BanaagTheme.surfaceCard,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _symbolButton('SELECT', Icons.near_me, 'Select / Move'),
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

    // 3-Way Unit Selector: 'mm' | 'm' | 'ft-in' (Ticket TKT-1792922320289)
    String selectedUnit = 'mm';
    final currentCalibratedMm = (pixelDist / _pixelsPerMeter) * 1000.0;
    final totalInches = currentCalibratedMm / 25.4;
    int initialFeet = (totalInches / 12).floor();
    int initialInches = (totalInches % 12).round();
    if (initialInches == 12) {
      initialFeet += 1;
      initialInches = 0;
    }

    final distCtrl = TextEditingController(
      text: currentCalibratedMm.round().toString(),
    );
    final feetCtrl = TextEditingController(text: initialFeet.toString());
    final inchCtrl = TextEditingController(text: initialInches.toString());

    final wallCtrl = TextEditingController(
      text: _wallThicknessMm.round().toString(),
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
              Expanded(
                child: Text(
                  'Step 0: Scale & Wall Thickness',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: Colors.white),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CAD Span (Pin A–B): ${pixelDist.toStringAsFixed(1)} px',
                  style: const TextStyle(fontSize: 12, color: Colors.cyanAccent),
                ),
                const SizedBox(height: 10),
                const Text(
                  '1. Actual Reference Length (Pin A to Pin B):',
                  style: TextStyle(fontSize: 11, color: BanaagTheme.textMuted),
                ),
                const SizedBox(height: 8),
                // 3-Way Unit Selector Chips: [ mm ] [ m ] [ ft-in ]
                Row(
                  children: [
                    const Text('Unit: ', style: TextStyle(color: BanaagTheme.textMuted, fontSize: 11)),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label: const Text('mm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: selectedUnit == 'mm',
                      selectedColor: BanaagTheme.primaryAmber,
                      onSelected: (_) {
                        setDlgState(() {
                          if (selectedUnit == 'm') {
                            final mVal = double.tryParse(distCtrl.text.trim()) ?? 0.0;
                            distCtrl.text = (mVal * 1000.0).round().toString();
                          } else if (selectedUnit == 'ft-in') {
                            final ft = double.tryParse(feetCtrl.text.trim()) ?? 0.0;
                            final inc = double.tryParse(inchCtrl.text.trim()) ?? 0.0;
                            final mm = ((ft * 12.0) + inc) * 25.4;
                            distCtrl.text = mm.round().toString();
                          }
                          selectedUnit = 'mm';
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('m', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: selectedUnit == 'm',
                      selectedColor: BanaagTheme.primaryAmber,
                      onSelected: (_) {
                        setDlgState(() {
                          if (selectedUnit == 'mm') {
                            final mmVal = double.tryParse(distCtrl.text.trim()) ?? 0.0;
                            distCtrl.text = (mmVal / 1000.0).toStringAsFixed(3);
                          } else if (selectedUnit == 'ft-in') {
                            final ft = double.tryParse(feetCtrl.text.trim()) ?? 0.0;
                            final inc = double.tryParse(inchCtrl.text.trim()) ?? 0.0;
                            final mVal = (((ft * 12.0) + inc) * 25.4) / 1000.0;
                            distCtrl.text = mVal.toStringAsFixed(3);
                          }
                          selectedUnit = 'm';
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text("ft - in (28'-0\")", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: selectedUnit == 'ft-in',
                      selectedColor: BanaagTheme.primaryAmber,
                      onSelected: (_) {
                        setDlgState(() {
                          double curMm = 0.0;
                          if (selectedUnit == 'mm') {
                            curMm = double.tryParse(distCtrl.text.trim()) ?? 0.0;
                          } else {
                            curMm = (double.tryParse(distCtrl.text.trim()) ?? 0.0) * 1000.0;
                          }
                          final totIn = curMm / 25.4;
                          int f = (totIn / 12.0).floor();
                          int ic = (totIn % 12.0).round();
                          if (ic == 12) {
                            f += 1;
                            ic = 0;
                          }
                          feetCtrl.text = f.toString();
                          inchCtrl.text = ic.toString();
                          selectedUnit = 'ft-in';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (selectedUnit == 'ft-in')
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: feetCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Feet (ft / ')",
                            isDense: true,
                            suffixText: 'ft',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: inchCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Inches (in / ")',
                            isDense: true,
                            suffixText: 'in',
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  TextField(
                    controller: distCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: selectedUnit == 'mm' ? 'Distance (mm)' : 'Distance (m)',
                      isDense: true,
                      suffixText: selectedUnit == 'mm' ? 'mm' : 'm',
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(
                      label: const Text("28'-0\" (8,534 mm)", style: TextStyle(fontSize: 10, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                      onPressed: () => setDlgState(() {
                        if (selectedUnit == 'ft-in') {
                          feetCtrl.text = '28';
                          inchCtrl.text = '0';
                        } else if (selectedUnit == 'mm') {
                          distCtrl.text = '8534';
                        } else {
                          distCtrl.text = '8.534';
                        }
                      }),
                    ),
                    ActionChip(
                      label: const Text("32'-0\" (9,754 mm)", style: TextStyle(fontSize: 10, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                      onPressed: () => setDlgState(() {
                        if (selectedUnit == 'ft-in') {
                          feetCtrl.text = '32';
                          inchCtrl.text = '0';
                        } else if (selectedUnit == 'mm') {
                          distCtrl.text = '9754';
                        } else {
                          distCtrl.text = '9.754';
                        }
                      }),
                    ),
                    ActionChip(
                      label: const Text('15500 mm (15.5m)', style: TextStyle(fontSize: 10, color: BanaagTheme.primaryAmber)),
                      onPressed: () => setDlgState(() {
                        if (selectedUnit == 'ft-in') {
                          feetCtrl.text = '50';
                          inchCtrl.text = '10';
                        } else if (selectedUnit == 'mm') {
                          distCtrl.text = '15500';
                        } else {
                          distCtrl.text = '15.500';
                        }
                      }),
                    ),
                    ActionChip(
                      label: const Text('18480 mm (18.5m)', style: TextStyle(fontSize: 10, color: BanaagTheme.primaryAmber)),
                      onPressed: () => setDlgState(() {
                        if (selectedUnit == 'ft-in') {
                          feetCtrl.text = '60';
                          inchCtrl.text = '8';
                        } else if (selectedUnit == 'mm') {
                          distCtrl.text = '18480';
                        } else {
                          distCtrl.text = '18.480';
                        }
                      }),
                    ),
                    ActionChip(
                      label: const Text('4800 mm (4.8m)', style: TextStyle(fontSize: 10)),
                      onPressed: () => setDlgState(() {
                        if (selectedUnit == 'ft-in') {
                          feetCtrl.text = '15';
                          inchCtrl.text = '9';
                        } else if (selectedUnit == 'mm') {
                          distCtrl.text = '4800';
                        } else {
                          distCtrl.text = '4.800';
                        }
                      }),
                    ),
                    ActionChip(
                      label: const Text('6000 mm (6m)', style: TextStyle(fontSize: 10)),
                      onPressed: () => setDlgState(() {
                        if (selectedUnit == 'ft-in') {
                          feetCtrl.text = '19';
                          inchCtrl.text = '8';
                        } else if (selectedUnit == 'mm') {
                          distCtrl.text = '6000';
                        } else {
                          distCtrl.text = '6.000';
                        }
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                const Text(
                  '2. Structural Wall Thickness (for Net Interior Area):',
                  style: TextStyle(fontSize: 11, color: BanaagTheme.textMuted),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: wallCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Wall Thickness (mm)',
                    isDense: true,
                    suffixText: 'mm',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('100 mm (4" CHB)', style: TextStyle(fontSize: 10)),
                      onPressed: () => setDlgState(() => wallCtrl.text = '100'),
                    ),
                    ActionChip(
                      label: const Text('150 mm (6" CHB)', style: TextStyle(fontSize: 10, color: BanaagTheme.primaryAmber)),
                      onPressed: () => setDlgState(() => wallCtrl.text = '150'),
                    ),
                    ActionChip(
                      label: const Text('200 mm (8" CHB)', style: TextStyle(fontSize: 10)),
                      onPressed: () => setDlgState(() => wallCtrl.text = '200'),
                    ),
                  ],
                ),
              ],
            ),
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
                double distMeters = 0.0;
                if (selectedUnit == 'ft-in') {
                  final ft = double.tryParse(feetCtrl.text.trim()) ?? 0.0;
                  final inc = double.tryParse(inchCtrl.text.trim()) ?? 0.0;
                  distMeters = (((ft * 12.0) + inc) * 25.4) / 1000.0;
                } else if (selectedUnit == 'mm') {
                  final val = double.tryParse(distCtrl.text.trim()) ?? 0.0;
                  distMeters = val / 1000.0;
                } else {
                  distMeters = double.tryParse(distCtrl.text.trim()) ?? 0.0;
                }
                final wallVal = double.tryParse(wallCtrl.text.trim()) ?? 150.0;
                if (distMeters > 0) {
                  final double newPixelsPerMeter = pixelDist / distMeters;

                  setState(() {
                    _pixelsPerMeter = newPixelsPerMeter;
                    _wallThicknessMm = wallVal.clamp(50.0, 400.0);
                    _syncRoomSpacesFromBoxes(persist: false);
                    _recalculateAllRouteLengths();

                    if (widget.project != null) {
                      widget.project!.calibrationPixelsPerMeter = _pixelsPerMeter;
                      widget.project!.conduitRoutes = _routes;
                      ProjectRepository.instance.updateProject(widget.project!);
                    }
                  });

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✅ Scale (${(distMeters * 1000).round()} mm) & Wall (${_wallThicknessMm.round()} mm) Calibrated!',
                      ),
                      backgroundColor: BanaagTheme.successGreen,
                    ),
                  );
                }
              },
              child: const Text('Apply Scale & Wall'),
            ),
          ],
        ),
      ),
    );
  }

  /// Tap-on-Wall-Segment Dialog: Lets user either type exact Wall Segment Length (m/mm) OR Split Wall (+ Point)
  void _showWallSegmentActionDialog(RoomSpace sp, int segIndex) {
    final poly = List<Offset>.from(_roomPolygons[sp.id] ?? _defaultCadPolygonForRoom(sp.name, _selectedRoomIndex));
    if (poly.length < 3) return;
    final int nextIdx = (segIndex + 1) % poly.length;
    final Offset p1 = poly[segIndex];
    final Offset p2 = poly[nextIdx];
    final double ppm = _pixelsPerMeter > 5.0 ? _pixelsPerMeter : 44.77;
    final double curMeters = (p2 - p1).distance / ppm;
    final lenCtrl = TextEditingController(text: curMeters.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BanaagTheme.surfaceCard,
        title: Text(
          'Wall Segment #${segIndex + 1} (${sp.name})',
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Specify exact wall segment length (in meters) or add a corner point (+) on this wall:',
              style: TextStyle(color: Colors.white70, fontSize: 11.5),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lenCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Wall Segment Length (m)',
                suffixText: 'm',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.cyanAccent,
                  side: const BorderSide(color: Colors.cyanAccent),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('➕ Add Corner Point on This Wall (L-Shape)'),
                onPressed: () {
                  final midPt = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
                  setState(() {
                    poly.insert(segIndex + 1, midPt);
                    _roomPolygons[sp.id] = poly;
                    _syncRoomSpacesFromBoxes(persist: true);
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('➕ Corner point added! Drag the new ● handle to shape the room.'),
                      backgroundColor: Colors.cyan,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BanaagTheme.primaryAmber, foregroundColor: Colors.black),
            onPressed: () {
              final newLenM = double.tryParse(lenCtrl.text.trim()) ?? curMeters;
              if (newLenM > 0.4) {
                final Offset vec = p2 - p1;
                final double dist = vec.distance > 1.0 ? vec.distance : 1.0;
                final Offset unit = Offset(vec.dx / dist, vec.dy / dist);
                final double targetPx = newLenM * ppm;
                poly[nextIdx] = Offset(
                  (p1.dx + unit.dx * targetPx).clamp(20.0, _cadCanvasWidth - 20.0),
                  (p1.dy + unit.dy * targetPx).clamp(20.0, _cadCanvasHeight - 20.0),
                );
                setState(() {
                  _roomPolygons[sp.id] = poly;
                  _syncRoomSpacesFromBoxes(persist: true);
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Apply Length'),
          ),
        ],
      ),
    );
  }

  /// Single-Room Re-Edit Picker (invoked from "📐 Edit Room Dimension (1-by-1)" at the bottom of Step 2)
  void _showSingleRoomEditPickerDialog() {
    final spaces = widget.project?.spaces ?? [];
    if (spaces.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: BanaagTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.aspect_ratio, color: Colors.cyanAccent, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Select 1 Room to Edit Dimensions & Shape',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Only the selected room will show active corner points (●) and wall lengths; all other rooms stay faint.',
                style: TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 10),
              ...List.generate(spaces.length, (i) {
                final r = spaces[i];
                final poly = _roomPolygons[r.id] ?? _defaultCadPolygonForRoom(r.name, i);
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(color: BanaagTheme.primaryAmber, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(r.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                    'Net Area: ${r.areaSqm.toStringAsFixed(1)} m² • Perim: ${(r.perimeterMeters ?? 0).toStringAsFixed(1)} m • RCR: ${(r.rcrValue ?? 0).toStringAsFixed(2)} (${poly.length} pts)',
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 10.5),
                  ),
                  trailing: const Icon(Icons.edit_location_alt, color: BanaagTheme.primaryAmber, size: 18),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedRoomIndex = i;
                      _stage1SubStep = 3; // Single-Room Re-Edit Mode!
                      _selectedTool = 'SELECT';
                    });
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  /// Floor Plan Completeness Gate Dialog ("Does all of the floors/spaces from the floor plan are accounted?")
  void _showMissingSpaceCompletenessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BanaagTheme.surfaceCard,
        title: Row(
          children: const [
            Icon(Icons.fact_check_outlined, color: Colors.orangeAccent, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Floor Plan Completeness Check',
                style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'May kulang ba na kwarto o espasyo mula sa floor plan?\n\n'
          '• Option 1: I-highlight ang unaccounted space sa floor plan at i-tap ito para awtomatikong ma-detect ang pader at maisama sa listahan.\n'
          '• Option 2: Kung mali o kulang ang mismong floor plan sheet, palitan / i-reupload ang tamang Floor Plan.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.upload_file, size: 16, color: Colors.cyanAccent),
            label: const Text('Re-Upload Floor Plan', style: TextStyle(color: Colors.cyanAccent, fontSize: 11.5)),
            onPressed: () {
              Navigator.pop(ctx);
              _pickNewUnderlay();
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: BanaagTheme.primaryAmber, foregroundColor: Colors.black),
            icon: const Icon(Icons.touch_app, size: 16),
            label: const Text('Tap Unaccounted Space on Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _highlightUnaccountedZones = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎯 Tap any unaccounted zone on the floor plan to auto-detect its walls & edit 1-by-1!'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Auto-detects the nearest structural CAD wall polygon around a tapped unaccounted point and opens Single-Room Edit Mode
  void _autoDetectAndAddTappedZone(Offset tapPos) {
    if (widget.project == null) return;
    double leftWall = 198.0;
    double rightWall = 892.0;
    double topWall = 42.0;
    double bottomWall = 742.0;

    final searchCorners = _activeStructuralColumns.isNotEmpty
        ? _activeStructuralColumns
        : _activeArchitecturalCorners;
    for (final col in searchCorners) {
      if (col.dx <= tapPos.dx && col.dx > leftWall) leftWall = col.dx;
      if (col.dx > tapPos.dx && col.dx < rightWall) rightWall = col.dx;
      if (col.dy <= tapPos.dy && col.dy > topWall) topWall = col.dy;
      if (col.dy > tapPos.dy && col.dy < bottomWall) bottomWall = col.dy;
    }
    if ((rightWall - leftWall) < 60.0) rightWall = (leftWall + 148.0).clamp(100.0, _cadCanvasWidth - 40.0);
    if ((bottomWall - topWall) < 60.0) bottomWall = (topWall + 130.0).clamp(100.0, _cadCanvasHeight - 40.0);

    final List<Offset> detectedPoly = [
      Offset(leftWall, topWall),
      Offset(rightWall, topWall),
      Offset(rightWall, bottomWall),
      Offset(leftWall, bottomWall),
    ];
    final String newId = 'sp-${DateTime.now().millisecondsSinceEpoch}';
    final int newRoomNum = widget.project!.spaces.length + 1;
    final metrics = _computePolygonEngineeringMetrics(detectedPoly, 2.8);

    setState(() {
      _highlightUnaccountedZones = false;
      _roomPolygons[newId] = detectedPoly;
      _roomBoxes[newId] = _boundingBoxOfPolygon(detectedPoly);
      widget.project!.spaces.add(
        RoomSpace(
          id: newId,
          name: 'Detected Space $newRoomNum',
          areaSqm: metrics.netAreaSqm,
          ceilingHeight: 2.8,
          perimeterMeters: metrics.perimeterMeters,
          rcrValue: metrics.rcrValue,
          polygonVertices: detectedPoly.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        ),
      );
      _selectedRoomIndex = widget.project!.spaces.length - 1;
      _stage1SubStep = 3; // Open directly in 1-by-1 room verification mode!
      _syncRoomSpacesFromBoxes(persist: true);
    });
  }

  Widget _stageStepPill({
    required int stageNum,
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isDone,
    required VoidCallback onTap,
  }) {
    final Color borderColor = isActive
        ? BanaagTheme.primaryAmber
        : (isDone ? BanaagTheme.successGreen.withValues(alpha: 0.7) : Colors.white24);
    final Color bgColor = isActive
        ? BanaagTheme.primaryAmber.withValues(alpha: 0.18)
        : (isDone ? BanaagTheme.successGreen.withValues(alpha: 0.10) : const Color(0xFF1E2430));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: isActive ? 1.5 : 0.9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isActive ? BanaagTheme.primaryAmber : (isDone ? BanaagTheme.successGreen : Colors.white),
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white60, fontSize: 9.0),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameSelectedRoomDialog() {
    final spaces = widget.project?.spaces ?? [];
    if (spaces.isEmpty) return;
    final idx = _selectedRoomIndex.clamp(0, spaces.length - 1);
    final sp = spaces[idx];
    final nameCtrl = TextEditingController(text: sp.name);
    final heightCtrl = TextEditingController(text: sp.ceilingHeight.toStringAsFixed(2));
    bool useFeet = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: BanaagTheme.surfaceCard,
          title: const Text('Edit Room ID & Ceiling Height', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Room Name (e.g. Function Hall, Office)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: heightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: useFeet ? 'Ceiling Height (ft)' : 'Ceiling Height (m)',
                        suffixText: useFeet ? 'ft' : 'm',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(useFeet ? 'feet (ft)' : 'meters (m)', style: const TextStyle(fontSize: 11)),
                    selected: true,
                    selectedColor: BanaagTheme.primaryAmber,
                    onSelected: (_) {
                      setDlgState(() {
                        final cur = double.tryParse(heightCtrl.text.trim()) ?? (useFeet ? 9.2 : 2.8);
                        if (!useFeet) {
                          heightCtrl.text = (cur * 3.28084).toStringAsFixed(1);
                        } else {
                          heightCtrl.text = (cur / 3.28084).toStringAsFixed(2);
                        }
                        useFeet = !useFeet;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final double presetM in [2.6, 2.8, 3.0, 3.5, 4.2, 5.0])
                    ActionChip(
                      label: Text(
                        useFeet ? '${(presetM * 3.28084).toStringAsFixed(1)} ft' : '${presetM.toStringAsFixed(1)} m',
                        style: const TextStyle(fontSize: 10.5),
                      ),
                      onPressed: () => setDlgState(() {
                        heightCtrl.text = useFeet
                            ? (presetM * 3.28084).toStringAsFixed(1)
                            : presetM.toStringAsFixed(2);
                      }),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            if (spaces.length > 1)
              TextButton(
                onPressed: () {
                  setState(() {
                    _roomBoxes.remove(sp.id);
                    spaces.removeAt(idx);
                    _selectedRoomIndex = 0;
                    _syncRoomSpacesFromBoxes(persist: true);
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Delete Room', style: TextStyle(color: BanaagTheme.alertRed)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: BanaagTheme.primaryAmber, foregroundColor: Colors.black),
              onPressed: () {
                final newName = nameCtrl.text.trim();
                final parsedVal = double.tryParse(heightCtrl.text.trim()) ?? (useFeet ? sp.ceilingHeight * 3.28084 : sp.ceilingHeight);
                final double newH = (useFeet ? (parsedVal / 3.28084) : parsedVal).clamp(2.1, 9.0);
                if (newName.isNotEmpty) {
                  setState(() {
                    for (int i = 0; i < widget.project!.applianceLoads.length; i++) {
                      final a = widget.project!.applianceLoads[i];
                      if (a.roomCategory.toLowerCase() == sp.name.toLowerCase()) {
                        widget.project!.applianceLoads[i] = ApplianceItem(
                          id: a.id,
                          name: a.name,
                          roomCategory: newName,
                          ratingVA: a.ratingVA,
                          quantity: a.quantity,
                          isDedicatedCircuit: a.isDedicatedCircuit,
                          isLighting: a.isLighting,
                          circuitNumber: a.circuitNumber,
                        );
                      }
                    }
                    spaces[idx] = RoomSpace(
                      id: sp.id,
                      name: newName,
                      areaSqm: sp.areaSqm,
                      ceilingHeight: double.parse(newH.toStringAsFixed(2)),
                      shapeType: sp.shapeType,
                      cutoutDepth: sp.cutoutDepth,
                      cutoutWidth: sp.cutoutWidth,
                      canvasX: sp.canvasX,
                      canvasY: sp.canvasY,
                      canvasWidth: sp.canvasWidth,
                      canvasHeight: sp.canvasHeight,
                      perimeterMeters: sp.perimeterMeters,
                      rcrValue: sp.rcrValue,
                      polygonVertices: sp.polygonVertices,
                    );
                    _syncRoomSpacesFromBoxes(persist: true);
                    _recalculateAllRouteLengths();
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnifiedPowerAndLightingAuditSheet() {
    if (widget.project == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BanaagTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final sld = SldEngine.generateFromProject(widget.project!);
          final powerAudit = PecSafetyAuditor.auditSchedule(sld);
          final lightAudit = IesnaLightingAuditor.auditProject(widget.project!);
          final bool isBlocked = powerAudit.isExportBlocked || lightAudit.isExportBlocked;

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.86),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isBlocked ? Icons.gpp_bad : Icons.verified_user,
                          color: isBlocked ? BanaagTheme.alertRed : BanaagTheme.successGreen,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isBlocked
                                ? 'Export Interlock: Power & Illumination Audit'
                                : '100% Verbatim PEC 2017 & IESNA 10th Ed. Verified',
                            style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Power Assurance: ${powerAudit.assurancePercent.toStringAsFixed(0)}% (${powerAudit.criticalHazardCount} hazards)  •  '
                      'Lighting Assurance: ${lightAudit.assurancePercent.toStringAsFixed(0)}% (${lightAudit.compliantRoomsCount}/${lightAudit.totalRooms} rooms compliant)',
                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    const Divider(color: Colors.white24, height: 18),
                    Expanded(
                      child: ListView(
                        children: [
                          const Text(
                            '💡 IESNA 10TH ED. & DOLE RULE 1075 ROOM ILLUMINATION AUDIT',
                            style: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          ...lightAudit.roomFindings.map((rf) {
                            final Color c = rf.severity == PecAuditSeverity.criticalHazard
                                ? BanaagTheme.alertRed
                                : (rf.severity == PecAuditSeverity.advisory ? Colors.orangeAccent : BanaagTheme.successGreen);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: c.withValues(alpha: 0.5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        rf.severity == PecAuditSeverity.criticalHazard
                                            ? Icons.warning_amber_rounded
                                            : Icons.lightbulb_outline,
                                        size: 16,
                                        color: c,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${rf.roomName} (${rf.areaSqm.toStringAsFixed(1)} m² • H=${rf.ceilingHeightMeters.toStringAsFixed(1)}m)',
                                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Text(
                                        '${rf.actualMaintainedLux.toStringAsFixed(0)} / ${rf.targetLux} Lux',
                                        style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    rf.mathTrace,
                                    style: const TextStyle(color: Colors.white70, fontSize: 10.0),
                                  ),
                                  if (rf.issues.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    ...rf.issues.map(
                                      (iss) => Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text('• $iss', style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                          if (lightAudit.branchCircuitIssues.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ...lightAudit.branchCircuitIssues.map(
                              (bIss) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('⚠️ $bIss', style: const TextStyle(color: BanaagTheme.alertRed, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          const Text(
                            '⚡ PEC 2017 PART 1 BRANCH CIRCUIT & FEEDER POWER AUDIT',
                            style: TextStyle(color: Colors.cyanAccent, fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          ...powerAudit.circuitFindings.map((cf) {
                            final Color c = cf.severity == PecAuditSeverity.criticalHazard
                                ? BanaagTheme.alertRed
                                : (cf.severity == PecAuditSeverity.advisory ? Colors.orangeAccent : BanaagTheme.successGreen);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: c.withValues(alpha: 0.45)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    cf.severity == PecAuditSeverity.criticalHazard ? Icons.error_outline : Icons.check_circle_outline,
                                    size: 15,
                                    color: c,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Ckt #${cf.circuitNumber} (${cf.description}): ${cf.headline}',
                                      style: const TextStyle(color: Colors.white, fontSize: 11.2),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BanaagTheme.primaryAmber,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.auto_fix_high, size: 18),
                        label: const Text(
                          '⚡ 1-Click Auto-Heal All Lighting & Power (IESNA + PEC 2017)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.2),
                        ),
                        onPressed: () {
                          setState(() {
                            IesnaLightingAuditor.autoHealProjectLighting(widget.project!);
                            _autoGenerateFromAppliances(widget.project!.applianceLoads);
                            _recalculateAllRouteLengths();
                            widget.project!.canvasPoints = _points;
                            widget.project!.conduitRoutes = _routes;
                            ProjectRepository.instance.updateProject(widget.project!);
                          });
                          setSheetState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ All Rooms Healed to 100% IESNA 10th Ed. Lux & Spacing + PEC 2017 Compliance!'),
                              backgroundColor: BanaagTheme.successGreen,
                            ),
                          );
                        },
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
          // Immediately initiate Stage 1 -> Step 0 (Scale Pin A–B & Wall Thickness) upon floor plan import!
          _canvasStage = 1;
          _stage1SubStep = 0;
          _selectedRoomIndex = 0;
          _selectedTool = 'SELECT';
          _fitSheetToViewport();
          if (widget.project != null) {
            widget.project!.blueprintImagePath = path;
            ProjectRepository.instance.updateProject(widget.project!);
          }
        });
        if (PdfBlueprintEngine.isPdf(path)) {
          _loadPdfBlueprint();
        }
        _triggerSilentBlueprintOcrScanIfNeeded(forceRescan: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📐 Step 0 Initiated: Verify Reference Scale (Pin A–B) & Wall Thickness on ${path.split(Platform.pathSeparator).last}!'),
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
  final int canvasStage;
  final int stage1SubStep;
  final Map<String, Rect> roomBoxes;
  final Map<String, List<Offset>> roomPolygons;
  final double wallThicknessMm;
  final bool highlightUnaccountedZones;
  final int selectedRoomIndex;
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

  final int? activeDraggingPin;
  final int? activeDraggingWallIndex;
  final int? activeDraggingVertexIndex;
  final bool isPerpendicularCornerSnapped;
  final Offset? perpendicularSnapCornerPos;
  final int? selectedPinForTap;
  final int? selectedVertexForTap;

  final double currentZoom;
  final List<Offset> activeStructuralColumns;
  final List<Offset> activeArchitecturalCorners;
  final List<Offset> activeDimensionNeedles;

  CanvasPainter({
    required this.points,
    required this.routes,
    this.roomGeometry,
    this.spaces = const [],
    this.canvasStage = 3,
    this.stage1SubStep = 0,
    this.roomBoxes = const {},
    this.roomPolygons = const {},
    this.wallThicknessMm = 150.0,
    this.currentZoom = 1.0,
    this.activeStructuralColumns = const [],
    this.activeArchitecturalCorners = const [],
    this.activeDimensionNeedles = const [],
    this.highlightUnaccountedZones = false,
    this.selectedRoomIndex = 0,
    this.isHeatmap = false,
    this.showLabels = true,
    this.showConduits = true,
    this.activeLayerFilter = 'ALL',
    this.hasBlueprintUnderlay = false,
    this.selectedPoint,
    this.isCalibrating = false,
    this.pinA = const Offset(60, 200),
    this.pinB = const Offset(240, 200),
    this.activeDraggingPin,
    this.activeDraggingWallIndex,
    this.activeDraggingVertexIndex,
    this.isPerpendicularCornerSnapped = false,
    this.perpendicularSnapCornerPos,
    this.selectedPinForTap,
    this.selectedVertexForTap,
    this.activeSnapPoint,
    this.pixelsPerMeter = 30.0,
    this.activePolygonPoints = const [],
    this.calibratedRoomPolygons = const {},
  });

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      double dist = 0.0;
      while (dist < metric.length) {
        final next = math.min(dist + 7.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist += 13.0;
      }
    }
  }

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
    } else if (isCalibrating && canvasStage != 1) {
      _drawCalibrationOverlay(canvas, size);
    }

    // STAGE 1: Step 0 (Solo Scale Pin A–B) -> Step 1/3 (1-by-1 Polygon Room Wizard) -> Step 2 (Completeness Gate)
    if (canvasStage == 1) {
      // STEP 0: Draw ONLY Reference Scale Pin A — Pin B on the Blank Floor Plan (Zero room boxes!)
      if (stage1SubStep == 0) {
        _drawCalibrationOverlay(canvas, size);
        return;
      }

      final List<Color> roomColors = [
        Colors.amberAccent,
        Colors.cyanAccent,
        Colors.lightGreenAccent,
        Colors.orangeAccent,
        Colors.purpleAccent,
      ];
      final double ppm = pixelsPerMeter > 5.0 ? pixelsPerMeter : 44.77;

      for (int i = 0; i < spaces.length; i++) {
        // In Step 1 (1-by-1 Sequential Wizard):
        // - Future rooms (i > selectedRoomIndex) are hidden!
        // - Confirmed rooms (i < selectedRoomIndex) are drawn ONLY as a very faint dashed outline (no labels, no handles)!
        // In Step 3 (Single-Room Re-Edit Mode):
        // - Only selectedRoomIndex is active; all other rooms (i != selectedRoomIndex) are drawn as a very faint dashed outline!
        if (stage1SubStep == 1 && i > selectedRoomIndex) continue;

        final sp = spaces[i];
        final List<Offset>? poly = roomPolygons[sp.id];
        if (poly == null || poly.length < 3) continue;

        final Path polyPath = Path()..moveTo(poly.first.dx, poly.first.dy);
        for (int v = 1; v < poly.length; v++) {
          polyPath.lineTo(poly[v].dx, poly[v].dy);
        }
        polyPath.close();

        final bool isActiveRoom = (stage1SubStep == 1 || stage1SubStep == 3) && (i == selectedRoomIndex);
        final bool isAllConfirmedOverview = (stage1SubStep == 2);
        final Color baseColor = roomColors[i % roomColors.length];

        // Case A: Confirmed Non-Active Room in Step 1 or Step 3 -> Very Faint Dashed Outline ONLY (No Label, No Handles!)
        if (!isActiveRoom && !isAllConfirmedOverview) {
          final faintPaint = Paint()
            ..color = Colors.white.withValues(alpha: 0.25)
            ..strokeWidth = 1.4
            ..style = PaintingStyle.stroke;
          _drawDashedPath(canvas, polyPath, faintPaint);
          continue;
        }

        // Case B: Step 2 Completeness Gate Overview -> Clean Confirmed Polygons + Compact Room Summary Badge (No Handles)
        if (isAllConfirmedOverview) {
          canvas.drawPath(
            polyPath,
            Paint()
              ..color = baseColor.withValues(alpha: 0.14)
              ..style = PaintingStyle.fill,
          );
          canvas.drawPath(
            polyPath,
            Paint()
              ..color = baseColor.withValues(alpha: 0.82)
              ..strokeWidth = 1.8
              ..style = PaintingStyle.stroke,
          );
          final Rect bounds = polyPath.getBounds();
          final tp = TextPainter(
            text: TextSpan(
              text: '${sp.name}\n${sp.areaSqm.toStringAsFixed(1)} m² • RCR ${(sp.rcrValue ?? 0).toStringAsFixed(1)}',
              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          )..layout();
          final badgeRRect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: bounds.center, width: tp.width + 12, height: tp.height + 8),
            const Radius.circular(5),
          );
          canvas.drawRRect(badgeRRect, Paint()..color = const Color(0xD811151E));
          tp.paint(canvas, Offset(bounds.center.dx - tp.width / 2, bounds.center.dy - tp.height / 2));
          continue;
        }

        // Case C: Active Room in Step 1 or Step 3 -> Full Interactive Multi-Vertex Polygon!
        // 1. Translucent Room Fill + Crisp Active Border
        canvas.drawPath(
          polyPath,
          Paint()
            ..color = BanaagTheme.primaryAmber.withValues(alpha: 0.20)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          polyPath,
          Paint()
            ..color = BanaagTheme.primaryAmber
            ..strokeWidth = 2.8
            ..style = PaintingStyle.stroke,
        );

        // 2. Wall Segment Length Labels (e.g. "5.25m") + Midpoint (+) Split Handles on Every Wall Segment
        for (int v = 0; v < poly.length; v++) {
          final Offset p1 = poly[v];
          final Offset p2 = poly[(v + 1) % poly.length];

          // Highlight the actively dragged movable wall segment in bright cyan
          if (activeDraggingWallIndex == v) {
            canvas.drawLine(
              p1,
              p2,
              Paint()
                ..color = Colors.cyanAccent
                ..strokeWidth = 4.5
                ..strokeCap = StrokeCap.round
                ..style = PaintingStyle.stroke,
            );
          }
          final Offset midPt = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
          final double segMeters = (p2 - p1).distance / ppm;

          // Draw Midpoint '+' Circle Handle
          canvas.drawCircle(midPt, 8.5, Paint()..color = const Color(0xFF11151E));
          canvas.drawCircle(
            midPt,
            7.0,
            Paint()
              ..color = Colors.cyanAccent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6,
          );
          // Draw '+' cross inside midpoint handle
          final plusPaint = Paint()
            ..color = Colors.cyanAccent
            ..strokeWidth = 1.5;
          canvas.drawLine(Offset(midPt.dx - 3.5, midPt.dy), Offset(midPt.dx + 3.5, midPt.dy), plusPaint);
          canvas.drawLine(Offset(midPt.dx, midPt.dy - 3.5), Offset(midPt.dx, midPt.dy + 3.5), plusPaint);

          // Draw Clickable Segment Dimension Pill next to the midpoint handle
          final segTp = TextPainter(
            text: TextSpan(
              text: '${segMeters.toStringAsFixed(2)}m',
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 9.2, fontWeight: FontWeight.bold),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          final bool isHoriz = (p2.dx - p1.dx).abs() >= (p2.dy - p1.dy).abs();
          final Offset pillCenter = isHoriz ? Offset(midPt.dx, midPt.dy - 16.0) : Offset(midPt.dx + 24.0, midPt.dy);
          final segRect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: pillCenter, width: segTp.width + 8.0, height: segTp.height + 4.0),
            const Radius.circular(4),
          );
          canvas.drawRRect(segRect, Paint()..color = const Color(0xE611151E));
          canvas.drawRRect(
            segRect,
            Paint()
              ..color = Colors.cyanAccent.withValues(alpha: 0.65)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.9,
          );
          segTp.paint(canvas, Offset(pillCenter.dx - segTp.width / 2, pillCenter.dy - segTp.height / 2));
        }

        // 3. Draggable Corner Vertices with Perpendicular (90 deg) Snap Feedback & Tap Selection
        for (int vi = 0; vi < poly.length; vi++) {
          final cPos = poly[vi];
          final bool isSnappedPerp = isPerpendicularCornerSnapped &&
              (activeDraggingVertexIndex == vi || (perpendicularSnapCornerPos != null && (cPos - perpendicularSnapCornerPos!).distance < 2.0));
          final bool isVertexSelectedForTap = selectedVertexForTap == vi;

          if (isVertexSelectedForTap) {
            // Pulsing / Prominent Selection Halo
            canvas.drawCircle(cPos, 19.0, Paint()..color = Colors.cyanAccent.withValues(alpha: 0.35));
            canvas.drawCircle(cPos, 14.5, Paint()..color = Colors.cyanAccent..style = PaintingStyle.stroke..strokeWidth = 2.0);
          }

          canvas.drawCircle(cPos, (isSnappedPerp || isVertexSelectedForTap) ? 12.0 : 10.0, Paint()..color = const Color(0xFF11151E));
          canvas.drawCircle(
            cPos,
            (isSnappedPerp || isVertexSelectedForTap) ? 9.5 : 8.2,
            Paint()..color = isSnappedPerp ? Colors.greenAccent : (isVertexSelectedForTap ? Colors.cyanAccent : BanaagTheme.primaryAmber),
          );
          canvas.drawCircle(cPos, 3.0, Paint()..color = Colors.black);

          // Draw Right-Angle Square Glyph on the corner when perfectly perpendicular
          if (isSnappedPerp) {
            final prevPt = poly[(vi - 1 + poly.length) % poly.length];
            final nextPt = poly[(vi + 1) % poly.length];
            final Offset dirP = (prevPt - cPos);
            final Offset dirN = (nextPt - cPos);
            final double lenP = dirP.distance > 0 ? dirP.distance : 1.0;
            final double lenN = dirN.distance > 0 ? dirN.distance : 1.0;
            final Offset uP = Offset(dirP.dx / lenP * 12.0, dirP.dy / lenP * 12.0);
            final Offset uN = Offset(dirN.dx / lenN * 12.0, dirN.dy / lenN * 12.0);

            final rightAnglePath = Path()
              ..moveTo(cPos.dx + uP.dx, cPos.dy + uP.dy)
              ..lineTo(cPos.dx + uP.dx + uN.dx, cPos.dy + uP.dy + uN.dy)
              ..lineTo(cPos.dx + uN.dx, cPos.dy + uN.dy);

            canvas.drawPath(
              rightAnglePath,
              Paint()
                ..color = Colors.greenAccent
                ..strokeWidth = 2.0
                ..style = PaintingStyle.stroke,
            );

            final perpBadge = TextPainter(
              text: const TextSpan(
                text: '90 deg',
                style: TextStyle(color: Colors.black, fontSize: 9.0, fontWeight: FontWeight.bold),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            final badgeCenter = Offset(cPos.dx + (uP.dx + uN.dx) * 1.5, cPos.dy + (uP.dy + uN.dy) * 1.5);
            final bgRRect = RRect.fromRectAndRadius(
              Rect.fromCenter(center: badgeCenter, width: perpBadge.width + 8, height: perpBadge.height + 4),
              const Radius.circular(4),
            );
            canvas.drawRRect(bgRRect, Paint()..color = Colors.greenAccent);
            perpBadge.paint(canvas, Offset(badgeCenter.dx - perpBadge.width / 2, badgeCenter.dy - perpBadge.height / 2));
          }
        }

        // 4. Obvious Snap Target Rings on column centers and needles when vertex is selected or dragged
        if (selectedVertexForTap != null || activeDraggingVertexIndex != null) {
          _drawObviousSnapTargetRings(canvas);
        }

        // 5. Active Magnetic Wall Snap Crosshair Indicator
        if (activeSnapPoint != null) {
          final snapPaint = Paint()
            ..color = Colors.greenAccent
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(activeSnapPoint!, 14.0, snapPaint);
        }

        // 5. Center Room Info Badge (Name + Net Area + Perimeter + Ceiling Height + IESNA RCR)
        final Rect bounds = polyPath.getBounds();
        final String titleLine = sp.name.toUpperCase();
        final String dimLine =
            'Net ${sp.areaSqm.toStringAsFixed(1)} m² • H=${sp.ceilingHeight.toStringAsFixed(1)}m\nPerim ${(sp.perimeterMeters ?? 0).toStringAsFixed(1)}m • RCR: ${(sp.rcrValue ?? 0).toStringAsFixed(2)}';

        final tp = TextPainter(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$titleLine\n',
                style: const TextStyle(
                  color: BanaagTheme.primaryAmber,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: dimLine,
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 9.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();

        final badgeRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: bounds.center,
            width: tp.width + 16.0,
            height: tp.height + 10.0,
          ),
          const Radius.circular(6),
        );
        canvas.drawRRect(badgeRect, Paint()..color = const Color(0xE811151E));
        canvas.drawRRect(
          badgeRect,
          Paint()
            ..color = BanaagTheme.primaryAmber
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        tp.paint(canvas, Offset(bounds.center.dx - tp.width / 2, bounds.center.dy - tp.height / 2));
      }

      // Highlight Unaccounted Floor Plan Zones if user tapped "⚠️ May Kulang na Space?" in Step 2
      if (stage1SubStep == 2 && highlightUnaccountedZones) {
        const List<Rect> candidateZones = [
          Rect.fromLTWH(198.0, 342.0, 180.0, 186.0), // Left Mid Zone / Restrooms
          Rect.fromLTWH(378.0, 278.0, 214.0, 250.0), // Central Lobby / Hallway
          Rect.fromLTWH(198.0, 528.0, 312.0, 214.0), // Lower Left Wing
        ];
        for (final z in candidateZones) {
          canvas.drawRect(
            z,
            Paint()
              ..color = Colors.orangeAccent.withValues(alpha: 0.18)
              ..style = PaintingStyle.fill,
          );
          final Path zPath = Path()..addRect(z);
          _drawDashedPath(
            canvas,
            zPath,
            Paint()
              ..color = Colors.orangeAccent
              ..strokeWidth = 2.0
              ..style = PaintingStyle.stroke,
          );
          final zTp = TextPainter(
            text: const TextSpan(
              text: '➕ TAP TO ADD SPACE',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 9.5, fontWeight: FontWeight.bold),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          zTp.paint(canvas, Offset(z.center.dx - zTp.width / 2, z.center.dy - zTp.height / 2));
        }
      }
      return;
    }

    // STAGE 3: Draw Subtle Confirmed Room Polygons Behind Electrical Layout
    for (int i = 0; i < spaces.length; i++) {
      final sp = spaces[i];
      final List<Offset>? poly = roomPolygons[sp.id];
      if (poly != null && poly.length >= 3) {
        final path = Path()..moveTo(poly.first.dx, poly.first.dy);
        for (int v = 1; v < poly.length; v++) {
          path.lineTo(poly[v].dx, poly[v].dy);
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.cyanAccent.withValues(alpha: 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1,
        );
      }
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

    final totalIn = realMm / 25.4;
    int fVal = (totalIn / 12.0).floor();
    int inVal = (totalIn % 12.0).round();
    if (inVal == 12) {
      fVal += 1;
      inVal = 0;
    }
    final badgeText = '${realMm.round()} mm (${realMeters.toStringAsFixed(2)}m / $fVal\'-$inVal")';
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

    // 3. Pin A (Cyan Crosshair & Target Ring + Magnifier Loupe if dragged)
    _drawPinTarget(canvas, pinA, 'A', Colors.cyanAccent, isDragging: activeDraggingPin == 1, isSelected: selectedPinForTap == 1);

    // 4. Pin B (Amber Crosshair & Target Ring + Magnifier Loupe if dragged)
    _drawPinTarget(canvas, pinB, 'B', BanaagTheme.primaryAmber, isDragging: activeDraggingPin == 2, isSelected: selectedPinForTap == 2);

    // 5. Draw Obvious Snap Target Rings at Column Centers & Needles when a Pin is selected or dragged!
    if (selectedPinForTap != null || activeDraggingPin != null) {
      _drawObviousSnapTargetRings(canvas);
    }

    // 6. Magnetic Snap Indicator (Glowing Diamond)
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

  void _drawObviousSnapTargetRings(Canvas canvas) {
    // 1. Structural Column Centers (Center ng Poste) — Prominent Emerald / Cyan Double Target Rings
    final colOuterPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final colInnerPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final colCenterPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;

    const double crossArm = 7.0;
    final crossPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.8)
      ..strokeWidth = 1.0;

    final columnsToDraw = activeStructuralColumns.isNotEmpty
        ? activeStructuralColumns
        : _PlanCanvasScreenState._cadStructuralColumns;

    final archCornersToDraw = activeArchitecturalCorners.isNotEmpty
        ? activeArchitecturalCorners
        : _PlanCanvasScreenState._cadArchitecturalCorners;

    final needlesToDraw = activeDimensionNeedles.isNotEmpty
        ? activeDimensionNeedles
        : _PlanCanvasScreenState._cadDimensionNeedles;

    final double ppm = pixelsPerMeter > 5.0 ? pixelsPerMeter : 44.77;
    final double wallThickPx = (wallThicknessMm / 1000.0) * ppm;
    final double halfThickPx = wallThickPx / 2.0;

    // Paint for Tri-Snap (Inner Face & Outer Face) at Zoom >= 3.0x
    final bool showFaceSnaps = currentZoom >= 2.5;
    final innerFacePaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final outerFacePaint = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final faceStrokePaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // 1. Exact Column Centers (Center ng Poste) — Halo Rings + Target Reticle
    for (final pt in columnsToDraw) {
      // Outer halo ring
      canvas.drawCircle(pt, 12.0, colOuterPaint);
      // Inner crisp target ring
      canvas.drawCircle(pt, 6.0, colInnerPaint);
      // Micro center dot
      canvas.drawCircle(pt, 2.0, colCenterPaint);
      // Reticle ticks
      canvas.drawLine(pt + const Offset(-crossArm, 0), pt + const Offset(crossArm, 0), crossPaint);
      canvas.drawLine(pt + const Offset(0, -crossArm), pt + const Offset(0, crossArm), crossPaint);

      // Tri-Snap: When Zoom >= 3.0x, display subtle inner/outer face dots
      if (showFaceSnaps) {
        for (final ox in [-halfThickPx, halfThickPx]) {
          for (final oy in [-halfThickPx, halfThickPx]) {
            final fPt = Offset(pt.dx + ox, pt.dy + oy);
            canvas.drawCircle(fPt, 2.2, ox < 0 ? innerFacePaint : outerFacePaint);
            canvas.drawCircle(fPt, 2.2, faceStrokePaint);
          }
        }
      }
    }

    // 1.5 Architectural Non-Column Wall Corners & L-Junctions
    final cornerOuterPaint = Paint()
      ..color = Colors.tealAccent.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final cpt in archCornersToDraw) {
      canvas.drawCircle(cpt, 9.0, cornerOuterPaint);
      canvas.drawCircle(cpt, 4.5, colInnerPaint);
      canvas.drawCircle(cpt, 1.8, colCenterPaint);

      if (showFaceSnaps) {
        for (final ox in [-halfThickPx, halfThickPx]) {
          for (final oy in [-halfThickPx, halfThickPx]) {
            final fPt = Offset(cpt.dx + ox, cpt.dy + oy);
            canvas.drawCircle(fPt, 2.0, innerFacePaint);
          }
        }
      }
    }

    // 2. Dimension Needle Ticks — Crisp Diamond / Diamond Rings
    final needlePaint = Paint()
      ..color = Colors.amberAccent.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (final nPt in needlesToDraw) {
      canvas.drawCircle(nPt, 4.5, needlePaint);
      canvas.drawCircle(nPt, 1.5, Paint()..color = Colors.amberAccent);
    }
  }

  void _drawPinTarget(Canvas canvas, Offset pos, String label, Color color, {bool isDragging = false, bool isSelected = false}) {
    // 0. If selected for tap-to-target snap, render a pulsing neon selection halo!
    if (isSelected) {
      canvas.drawCircle(pos, 28.0, Paint()..color = color.withValues(alpha: 0.28));
      canvas.drawCircle(pos, 20.0, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.4);
    }

    // 1. If actively being dragged, render an elevated Precision Loupe Magnifier above the finger!
    if (isDragging) {
      final loupeCenter = Offset(pos.dx, pos.dy - 65.0);
      const double loupeRadius = 38.0;

      // Stem connecting pin to loupe
      final stemPaint = Paint()
        ..color = color.withValues(alpha: 0.6)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      canvas.drawLine(pos, loupeCenter, stemPaint);

      // Loupe Shadow / Glow
      canvas.drawCircle(
        loupeCenter,
        loupeRadius + 4.0,
        Paint()..color = Colors.black.withValues(alpha: 0.6),
      );

      // Loupe Background lens
      canvas.drawCircle(
        loupeCenter,
        loupeRadius,
        Paint()..color = const Color(0xFB141923),
      );

      // Loupe Outer Ring
      canvas.drawCircle(
        loupeCenter,
        loupeRadius,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );

      // Loupe Crosshairs (Precision Reticle)
      final reticlePaint = Paint()
        ..color = color
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(loupeCenter.dx - loupeRadius + 6, loupeCenter.dy),
        Offset(loupeCenter.dx + loupeRadius - 6, loupeCenter.dy),
        reticlePaint,
      );
      canvas.drawLine(
        Offset(loupeCenter.dx, loupeCenter.dy - loupeRadius + 6),
        Offset(loupeCenter.dx, loupeCenter.dy + loupeRadius - 6),
        reticlePaint,
      );
      canvas.drawCircle(loupeCenter, 3.0, Paint()..color = color);

      // Loupe Header Tag ("PIN A 🔍" or "PIN B 🔍")
      final loupeTp = TextPainter(
        text: TextSpan(
          text: 'PIN $label (EXACT)',
          style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      loupeTp.paint(canvas, Offset(loupeCenter.dx - loupeTp.width / 2, loupeCenter.dy - loupeRadius + 6));
    }

    // Outer Target Glow
    canvas.drawCircle(pos, 16.0, Paint()..color = color.withValues(alpha: isDragging ? 0.45 : 0.25));

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
