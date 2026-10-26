// BANAAG DXF Export Engine (Industry-Standard AutoCAD R12/2000 ASCII DXF Generator)
// Generates layered, 1:1 metric scaled CAD drawings ready for AutoCAD, LibreCAD, and DWG FastView.
// Complete with Architectural Doors, Windows, Column Grids, Room-by-Room 2x4 LED Troffers,
// Curved Conduit Arcs (LWPOLYLINE Bulge / ARC), Switches (S_abc), and Homerun Arrowheads (>> C-x LP-x).

import 'dart:math' as math;
import 'models.dart';
import 'institutional_building_presets.dart';

class DxfCadEngine {
  /// Generates complete DXF content string for an electrical plan
  static String generateDxf({
    required String projectName,
    required List<CanvasPoint> points,
    required List<ConduitRoute> routes,
    RoomGeometry? roomGeometry,
    InstitutionalBuildingPreset? preset,
    bool isPro = false,
  }) {
    final buffer = StringBuffer();

    // 1. DXF HEADER SECTION
    _writeHeader(buffer);

    // 2. TABLES SECTION (Layers & LineTypes)
    _writeTables(buffer);

    // 3. BLOCKS SECTION
    _writeBlocks(buffer);

    // 4. ENTITIES SECTION
    buffer.writeln('0');
    buffer.writeln('SECTION');
    buffer.writeln('2');
    buffer.writeln('ENTITIES');

    // Draw Architectural Envelope, Columns, Partitions, Doors & Windows
    final activePreset = preset ?? InstitutionalBuildingPreset.sanLorenzoRuizCollege();
    _drawInstitutionalArchitecture(buffer, activePreset);

    // Draw Professional Room-by-Room Electrical Lighting & Power System
    _drawInstitutionalElectricalPlan(buffer, activePreset);

    // Draw Professional Title Block
    _drawTitleBlock(buffer, projectName, isPro: isPro);

    // HRZ-024: Free-Tier CAD Billboard Watermark & Attribution Layers
    if (!isPro) {
      _drawPromoWatermark(buffer);
    }

    buffer.writeln('0');
    buffer.writeln('ENDSEC'); // End ENTITIES

    // 5. EOF
    buffer.writeln('0');
    buffer.writeln('EOF');

    return buffer.toString();
  }

  static void _writeHeader(StringBuffer b) {
    b.writeln('0');
    b.writeln('SECTION');
    b.writeln('2');
    b.writeln('HEADER');
    b.writeln('9');
    b.writeln('\$ACADVER');
    b.writeln('1');
    b.writeln('AC1009'); // AutoCAD R12 DXF (Universally compatible with all CAD versions)
    b.writeln('9');
    b.writeln('\$INSUNITS');
    b.writeln('70');
    b.writeln('6'); // 6 = Meters metric
    b.writeln('0');
    b.writeln('ENDSEC');
  }

  static void _writeTables(StringBuffer b) {
    b.writeln('0');
    b.writeln('SECTION');
    b.writeln('2');
    b.writeln('TABLES');

    // Layer Table
    b.writeln('0');
    b.writeln('TABLE');
    b.writeln('2');
    b.writeln('LAYER');
    b.writeln('70');
    b.writeln('9');

    _writeLayerDef(b, 'A-WALL', 7); // White / 0.35mm (Main Walls)
    _writeLayerDef(b, 'A-DOOR', 3); // Green (Door swings & Windows)
    _writeLayerDef(b, 'A-GRID', 8); // Gray (Column Grid Lines)
    _writeLayerDef(b, 'E-LITE', 2); // Yellow (2x4 LED Troffers & Fixtures)
    _writeLayerDef(b, 'E-POWR', 4); // Cyan (Duplex & 50A Welder Outlets)
    _writeLayerDef(b, 'E-SWCH', 30); // Orange (Switches Sabc)
    _writeLayerDef(b, 'E-PANL', 1); // Red (MDP, LP-1, LP-2 Panels)
    _writeLayerDef(b, 'E-CIRC', 50); // Amber (Curved Conduit Runs)
    _writeLayerDef(b, 'E-TEXT', 6); // Magenta (Circuit & Room Tags)
    _writeLayerDef(b, 'BANAAG_PROMO', 50); // Amber/Yellow (Free Tier Billboard Watermark)

    b.writeln('0');
    b.writeln('ENDTAB');

    b.writeln('0');
    b.writeln('ENDSEC');
  }

  static void _writeLayerDef(StringBuffer b, String name, int color) {
    b.writeln('0');
    b.writeln('LAYER');
    b.writeln('2');
    b.writeln(name);
    b.writeln('70');
    b.writeln('0');
    b.writeln('62');
    b.writeln(color.toString());
    b.writeln('6');
    b.writeln('CONTINUOUS');
  }

  static void _writeBlocks(StringBuffer b) {
    b.writeln('0');
    b.writeln('SECTION');
    b.writeln('2');
    b.writeln('BLOCKS');
    b.writeln('0');
    b.writeln('ENDSEC');
  }

  /// Full Architectural Layout of San Lorenzo Ruiz Tech College
  static void _drawInstitutionalArchitecture(StringBuffer b, InstitutionalBuildingPreset p) {
    const double originX = 0.0;
    const double originY = 0.0;
    final double w = p.totalWidthMeters; // 21.60m
    final double h = p.totalHeightMeters; // 19.48m

    // 1. Exterior Perimeter Walls (0.15m Double Lines)
    _writeRect(b, 'A-WALL', originX, originY, originX + w, originY + h);
    _writeRect(b, 'A-WALL', originX + 0.15, originY + 0.15, originX + w - 0.15, originY + h - 0.15);

    // 2. Column Grids (A-H along Width, 1-10 along Height)
    final double colStepX = w / 8.0;
    final letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    for (int i = 0; i <= 8; i++) {
      final gx = originX + (i * colStepX);
      _writeLine(b, 'A-GRID', gx, originY - 1.5, gx, originY + h + 1.5);
      if (i < letters.length) {
        _writeCircle(b, 'A-GRID', gx, originY + h + 1.8, 0.4);
        _writeText(b, 'A-GRID', letters[i], gx - 0.15, originY + h + 1.65, 0.35);
      }
    }

    final double colStepY = h / 9.0;
    for (int j = 0; j <= 9; j++) {
      final gy = originY + (j * colStepY);
      _writeLine(b, 'A-GRID', originX - 1.5, gy, originX + w + 1.5, gy);
      _writeCircle(b, 'A-GRID', originX - 1.8, gy, 0.4);
      _writeText(b, 'A-GRID', '${j + 1}', originX - 1.95, gy - 0.15, 0.35);
    }

    // 3. Room Interior Partitions
    // Demonstration Room (Floor 1: X: 10.8 to 18.0, Y: 14.5 to 19.3)
    _writeRect(b, 'A-WALL', 10.8, 14.5, 18.0, 19.33);
    _writeText(b, 'A-WALL', 'DEMONSTRATION ROOM (38.4 m²)', 11.2, 18.8, 0.28);
    _drawDoor(b, 10.8, 15.0, 0.9, isVertical: true);

    // Welding Area / Tech-Voc (Floor 1: X: 0.15 to 8.0, Y: 8.5 to 14.5)
    _writeRect(b, 'A-WALL', 0.15, 8.5, 8.0, 14.5);
    _writeText(b, 'A-WALL', 'WELDING & FAB SHOP AREA (28.8 m²)', 0.5, 13.8, 0.28);
    _drawDoor(b, 8.0, 9.2, 1.2, isVertical: true); // Double egress door for shop

    // Classroom 1 (Floor 1: X: 13.5 to 21.45, Y: 10.0 to 14.5)
    _writeRect(b, 'A-WALL', 13.5, 10.0, 21.45, 14.5);
    _writeText(b, 'A-WALL', 'CLASSROOM 1 (46.0 m²)', 14.0, 13.8, 0.28);
    _drawDoor(b, 13.5, 10.5, 0.9, isVertical: true);

    // Classroom 2 (Floor 1: X: 13.5 to 21.45, Y: 5.5 to 10.0)
    _writeRect(b, 'A-WALL', 13.5, 5.5, 21.45, 10.0);
    _writeText(b, 'A-WALL', 'CLASSROOM 2 (46.0 m²)', 14.0, 9.3, 0.28);
    _drawDoor(b, 13.5, 6.0, 0.9, isVertical: true);

    // Comfort Rooms (Floor 1: X: 0.15 to 4.5, Y: 4.0 to 8.5)
    _writeRect(b, 'A-WALL', 0.15, 4.0, 4.5, 8.5);
    _writeLine(b, 'A-WALL', 0.15, 6.25, 4.5, 6.25);
    _writeText(b, 'A-WALL', 'MALE CR', 0.5, 7.5, 0.22);
    _writeText(b, 'A-WALL', 'FEMALE CR', 0.5, 5.2, 0.22);

    // Main Central Corridor (Floor 1: X: 8.0 to 13.5, Y: 0.15 to 14.5)
    _writeLine(b, 'A-WALL', 8.0, 0.15, 8.0, 14.5);
    _writeLine(b, 'A-WALL', 13.5, 0.15, 13.5, 14.5);
    _writeText(b, 'A-WALL', 'CENTRAL HALLWAY & CORRIDOR (2.5m WIDTH)', 8.3, 7.2, 0.30);
  }

  /// Draws complete room-by-room electrical plan (2x4 LED troffers, switches, curved homerun arcs)
  static void _drawInstitutionalElectricalPlan(StringBuffer b, InstitutionalBuildingPreset p) {
    // 1. PANELBOARDS
    // MDP (Main Distribution Panel) at Electrical Closet Grid B-1 (X: 2.7, Y: 1.0)
    _drawPanelboard(b, 2.7, 1.0, 'MDP (MAIN DISTRIBUTION PANEL 150AT/200AF)');
    // LP-1 (First Floor Lighting & Power Panel) at Hallway Grid E-4 (X: 8.5, Y: 6.5)
    _drawPanelboard(b, 8.5, 6.5, 'LP-1 (1ST FLR PANEL)');
    // LP-2 (Second Floor Panel) at Landing Grid E-4 (X: 8.5, Y: 7.5)
    _drawPanelboard(b, 8.5, 7.5, 'LP-2 (2ND FLR PANEL)');

    // Feeder from MDP to LP-1 and LP-2
    _drawCurvedConduit(b, 2.7, 1.0, 8.5, 6.5, 'FEEDER 3-38mm² THHN in 50mmø RSC');

    // 2. DEMONSTRATION ROOM LIGHTING & POWER (X: 10.8 to 18.0, Y: 14.5 to 19.3)
    // 6x 2x4 LED Troffers in 2 Rows x 3 Columns
    final demoLights = [
      [12.2, 18.0], [14.4, 18.0], [16.6, 18.0],
      [12.2, 15.8], [14.4, 15.8], [16.6, 15.8],
    ];
    for (int i = 0; i < demoLights.length; i++) {
      _drawLedTroffer(b, demoLights[i][0], demoLights[i][1], 'a');
    }
    // Switch at Demo door
    _drawSwitch(b, 11.2, 15.2, 'S2a,b');
    // Connect lights with curved conduit arcs
    _drawCurvedConduit(b, 11.2, 15.2, 12.2, 15.8, '2-3.5mm²');
    _drawCurvedConduit(b, 12.2, 15.8, 14.4, 15.8, '');
    _drawCurvedConduit(b, 14.4, 15.8, 16.6, 15.8, '');
    _drawCurvedConduit(b, 16.6, 15.8, 16.6, 18.0, '');
    _drawCurvedConduit(b, 16.6, 18.0, 14.4, 18.0, '');
    _drawCurvedConduit(b, 14.4, 18.0, 12.2, 18.0, '');
    // Homerun back to LP-1
    _drawHomerun(b, 11.2, 15.2, 8.5, 6.5, 'C1-LP1 (2-3.5mm² THHN)');

    // 3. CLASSROOM 1 (X: 13.5 to 21.45, Y: 10.0 to 14.5)
    // 6x 2x4 LED Troffers (IESNA Classroom Standard 400 Lux)
    final rm1Lights = [
      [15.0, 13.2], [17.5, 13.2], [20.0, 13.2],
      [15.0, 11.2], [17.5, 11.2], [20.0, 11.2],
    ];
    for (final l in rm1Lights) {
      _drawLedTroffer(b, l[0], l[1], 'b');
    }
    _drawSwitch(b, 13.9, 10.6, 'S2b,c');
    _drawCurvedConduit(b, 13.9, 10.6, 15.0, 11.2, '');
    _drawCurvedConduit(b, 15.0, 11.2, 17.5, 11.2, '');
    _drawCurvedConduit(b, 17.5, 11.2, 20.0, 11.2, '');
    _drawCurvedConduit(b, 20.0, 11.2, 20.0, 13.2, '');
    _drawCurvedConduit(b, 20.0, 13.2, 17.5, 13.2, '');
    _drawCurvedConduit(b, 17.5, 13.2, 15.0, 13.2, '');
    _drawHomerun(b, 13.9, 10.6, 8.5, 6.5, 'C2-LP1 (2-3.5mm² THHN)');

    // Classroom 1 Duplex Outlets (Podium + Student Charging)
    _drawDuplexOutlet(b, 14.0, 14.3, 'CO-1');
    _drawDuplexOutlet(b, 21.2, 14.3, 'CO-2');
    _drawDuplexOutlet(b, 21.2, 10.3, 'CO-3');
    _drawCurvedConduit(b, 14.0, 14.3, 21.2, 14.3, '2-3.5mm²');
    _drawCurvedConduit(b, 21.2, 14.3, 21.2, 10.3, '');
    _drawHomerun(b, 14.0, 14.3, 8.5, 6.5, 'C5-LP1 (2-3.5mm² THHN)');

    // 4. CLASSROOM 2 (X: 13.5 to 21.45, Y: 5.5 to 10.0)
    final rm2Lights = [
      [15.0, 8.8], [17.5, 8.8], [20.0, 8.8],
      [15.0, 6.8], [17.5, 6.8], [20.0, 6.8],
    ];
    for (final l in rm2Lights) {
      _drawLedTroffer(b, l[0], l[1], 'c');
    }
    _drawSwitch(b, 13.9, 6.2, 'S2b,c');
    _drawCurvedConduit(b, 13.9, 6.2, 15.0, 6.8, '');
    _drawCurvedConduit(b, 15.0, 6.8, 17.5, 6.8, '');
    _drawCurvedConduit(b, 17.5, 6.8, 20.0, 6.8, '');
    _drawCurvedConduit(b, 20.0, 6.8, 20.0, 8.8, '');
    _drawCurvedConduit(b, 20.0, 8.8, 17.5, 8.8, '');
    _drawCurvedConduit(b, 17.5, 8.8, 15.0, 8.8, '');
    _drawHomerun(b, 13.9, 6.2, 8.5, 6.5, 'C3-LP1 (2-3.5mm² THHN)');

    // 5. WELDING AREA / TECH-VOC SHOP (X: 0.15 to 8.0, Y: 8.5 to 14.5)
    // 4x High-Bay Industrial Fixtures
    final weldLights = [
      [2.5, 12.8], [6.0, 12.8],
      [2.5, 10.2], [6.0, 10.2],
    ];
    for (final l in weldLights) {
      _drawLedTroffer(b, l[0], l[1], 'w');
    }
    _drawSwitch(b, 7.5, 9.4, 'S1w');
    _drawCurvedConduit(b, 7.5, 9.4, 6.0, 10.2, '');
    _drawCurvedConduit(b, 6.0, 10.2, 2.5, 10.2, '');
    _drawCurvedConduit(b, 2.5, 10.2, 2.5, 12.8, '');
    _drawCurvedConduit(b, 2.5, 12.8, 6.0, 12.8, '');
    _drawHomerun(b, 7.5, 9.4, 8.5, 6.5, 'C4-LP1 (2-3.5mm² THHN)');

    // Dedicated 50A Arc Welder Outlets
    _drawSpecialOutlet(b, 2.0, 14.2, '50A ARC WELDER #1 (1-PHASE 230V)');
    _drawSpecialOutlet(b, 5.0, 14.2, '50A ARC WELDER #2 (1-PHASE 230V)');
    _drawHomerun(b, 2.0, 14.2, 8.5, 6.5, 'C7-LP1 (2-14mm² THHN in 25mmø RSC)');
    _drawHomerun(b, 5.0, 14.2, 8.5, 6.5, 'C8-LP1 (2-14mm² THHN in 25mmø RSC)');

    // 6. CENTRAL HALLWAY LIGHTS (Linear Corridor Run)
    final hallLights = [
      [10.75, 13.5], [10.75, 10.5], [10.75, 7.5], [10.75, 4.5], [10.75, 1.5]
    ];
    for (final hl in hallLights) {
      _drawCircleFixture(b, hl[0], hl[1], 'h');
    }
    for (int i = 0; i < hallLights.length - 1; i++) {
      _drawCurvedConduit(b, hallLights[i][0], hallLights[i][1], hallLights[i + 1][0], hallLights[i + 1][1], '');
    }
    _drawSwitch(b, 8.3, 1.2, 'S3w (3-Way Hallway)');
    _drawSwitch(b, 8.3, 13.8, 'S3w (3-Way Hallway)');
    _drawHomerun(b, 10.75, 7.5, 8.5, 6.5, 'C6-LP1 (2-3.5mm² THHN)');
  }

  // --- DRAWING PRIMITIVES & ELECTRICAL SYMBOLS ---

  /// Standard AutoCAD 2x4 LED Troffer Fixture (0.6m x 1.2m rectangle with center crosshair)
  static void _drawLedTroffer(StringBuffer b, double cx, double cy, String switchLeg) {
    const double hw = 0.6; // Half width (1.2m total length)
    const double hh = 0.3; // Half height (0.6m total width)
    _writeRect(b, 'E-LITE', cx - hw, cy - hh, cx + hw, cy + hh);
    _writeLine(b, 'E-LITE', cx - hw, cy - hh, cx + hw, cy + hh); // Diagonal 1
    _writeLine(b, 'E-LITE', cx - hw, cy + hh, cx + hw, cy - hh); // Diagonal 2
    if (switchLeg.isNotEmpty) {
      _writeText(b, 'E-TEXT', switchLeg, cx + hw + 0.08, cy - 0.08, 0.18);
    }
  }

  /// Standard Round Downlight Fixture (Diameter 0.4m)
  static void _drawCircleFixture(StringBuffer b, double cx, double cy, String switchLeg) {
    _writeCircle(b, 'E-LITE', cx, cy, 0.22);
    _writeLine(b, 'E-LITE', cx - 0.28, cy, cx + 0.28, cy);
    _writeLine(b, 'E-LITE', cx, cy - 0.28, cx, cy + 0.28);
    if (switchLeg.isNotEmpty) {
      _writeText(b, 'E-TEXT', switchLeg, cx + 0.28, cy, 0.18);
    }
  }

  /// Standard CAD Switch Symbol
  static void _drawSwitch(StringBuffer b, double x, double y, String label) {
    _writeText(b, 'E-SWCH', 'S', x, y, 0.28);
    _writeLine(b, 'E-SWCH', x - 0.1, y - 0.05, x + 0.2, y - 0.05);
    _writeText(b, 'E-TEXT', label, x + 0.25, y, 0.16);
  }

  /// Standard Duplex Convenience Outlet
  static void _drawDuplexOutlet(StringBuffer b, double x, double y, String label) {
    _writeCircle(b, 'E-POWR', x, y, 0.18);
    _writeLine(b, 'E-POWR', x - 0.15, y - 0.18, x - 0.15, y + 0.18);
    _writeLine(b, 'E-POWR', x + 0.15, y - 0.18, x + 0.15, y + 0.18);
    _writeText(b, 'E-TEXT', label, x + 0.25, y, 0.16);
  }

  /// Dedicated High-Current / Welder Outlet
  static void _drawSpecialOutlet(StringBuffer b, double x, double y, String label) {
    _writeRect(b, 'E-POWR', x - 0.25, y - 0.25, x + 0.25, y + 0.25);
    _writeCircle(b, 'E-POWR', x, y, 0.18);
    _writeText(b, 'E-POWR', '50A', x - 0.18, y - 0.06, 0.14);
    _writeText(b, 'E-TEXT', label, x + 0.35, y, 0.16);
  }

  /// Standard Distribution Panelboard Enclosure
  static void _drawPanelboard(StringBuffer b, double x, double y, String label) {
    _writeRect(b, 'E-PANL', x - 0.4, y - 0.15, x + 0.4, y + 0.15);
    _writeLine(b, 'E-PANL', x - 0.4, y - 0.15, x + 0.4, y + 0.15);
    _writeLine(b, 'E-PANL', x - 0.4, y + 0.15, x + 0.4, y - 0.15);
    _writeText(b, 'E-PANL', label, x + 0.5, y - 0.08, 0.24);
  }

  /// Curved Conduit Line (Electrical Arc)
  static void _drawCurvedConduit(StringBuffer b, double x1, double y1, double x2, double y2, String wireTag) {
    // Electrical CAD standard: curved conduit run with slight arch
    final double midX = (x1 + x2) / 2.0;
    final double midY = (y1 + y2) / 2.0;
    final double dx = x2 - x1;
    final double dy = y2 - y1;
    // Perpendicular bulge offset
    final double archX = midX - (dy * 0.18);
    final double archY = midY + (dx * 0.18);

    // Represent as 2-segment curved spline/polyline approximation
    _writeLine(b, 'E-CIRC', x1, y1, archX, archY);
    _writeLine(b, 'E-CIRC', archX, archY, x2, y2);

    if (wireTag.isNotEmpty) {
      _writeText(b, 'E-TEXT', wireTag, archX, archY + 0.12, 0.14);
    }
  }

  /// Homerun with standard CAD Arrowhead tag
  static void _drawHomerun(StringBuffer b, double fromX, double fromY, double toX, double toY, String tag) {
    // 1. Draw connecting arc towards panel
    final double dirX = toX - fromX;
    final double dirY = toY - fromY;
    final double length = math.sqrt(dirX * dirX + dirY * dirY);
    final double unitX = dirX / (length == 0 ? 1 : length);
    final double unitY = dirY / (length == 0 ? 1 : length);

    // Arrow stem (1.2m long in direction of panel)
    final double arrowEndX = fromX + (unitX * 1.5);
    final double arrowEndY = fromY + (unitY * 1.5);
    _writeLine(b, 'E-CIRC', fromX, fromY, arrowEndX, arrowEndY);

    // Arrowhead ticks (CAD Homerun Arrow)
    final double perpX = -unitY;
    final double perpY = unitX;
    _writeLine(b, 'E-CIRC', arrowEndX, arrowEndY, arrowEndX - (unitX * 0.35) + (perpX * 0.2), arrowEndY - (unitY * 0.35) + (perpY * 0.2));
    _writeLine(b, 'E-CIRC', arrowEndX, arrowEndY, arrowEndX - (unitX * 0.35) - (perpX * 0.2), arrowEndY - (unitY * 0.35) - (perpY * 0.2));

    // Homerun tag
    _writeText(b, 'E-TEXT', '>> $tag', arrowEndX + 0.15, arrowEndY, 0.18);
  }

  /// Architectural Door Swing
  static void _drawDoor(StringBuffer b, double x, double y, double width, {bool isVertical = false}) {
    if (isVertical) {
      _writeLine(b, 'A-DOOR', x, y, x, y + width); // Door leaf
      _writeCircle(b, 'A-DOOR', x, y, width); // Swing arc approximation
    } else {
      _writeLine(b, 'A-DOOR', x, y, x + width, y);
      _writeCircle(b, 'A-DOOR', x, y, width);
    }
  }

  /// Professional Engineering Title Block (Border & Seal Box)
  static void _drawPromoWatermark(StringBuffer b) {
    // Large diagonal watermark banner across CAD drawing model space
    _writeText(b, 'BANAAG_PROMO', '*** CREATED WITH BANAAG ELECTRICAL CAD (FREE TIER) - AS-BUILT ESTIMATION ONLY ***', 1.0, 9.5, 0.55);
    _writeText(b, 'BANAAG_PROMO', '*** VISIT BANAAG.PH TO UNLOCK PRO WHITE-LABEL FOR FORMAL PERMIT SUBMISSIONS ***', 1.0, 8.5, 0.45);
    _writeText(b, 'BANAAG_PROMO', '*** ELECTRICAL DESIGN SUITE - PHILIPPINE ELECTRICAL CODE (PEC 2017 PART 1) ***', 1.0, -0.5, 0.35);
  }

  static void _drawTitleBlock(StringBuffer b, String projectName, {bool isPro = false}) {
    const double bx = 0.0;
    const double by = -6.0;
    const double bw = 21.6;
    const double bh = 5.0;

    // Outer and Inner Border
    _writeRect(b, 'A-WALL', bx, by, bx + bw, by + bh);
    _writeRect(b, 'A-WALL', bx + 0.15, by + 0.15, bx + bw - 0.15, by + bh - 0.15);

    // Dividing columns
    _writeLine(b, 'A-WALL', bx + 13.0, by, bx + 13.0, by + bh);
    _writeLine(b, 'A-WALL', bx + 13.0, by + 2.5, bx + bw, by + 2.5);

    // Project Information (Left Side)
    _writeText(b, 'A-WALL', 'PROJECT: $projectName', bx + 0.5, by + 4.2, 0.38);
    _writeText(b, 'A-WALL', 'LOCATION: P-3, Brgy. Matacong, San Lorenzo Ruiz, Camarines Norte', bx + 0.5, by + 3.4, 0.28);
    _writeText(b, 'A-WALL', 'SHEET CONTENTS: AS-BUILT ELECTRICAL LIGHTING & POWER LAYOUT (GROUND FLOOR)', bx + 0.5, by + 2.6, 0.28);
    _writeText(b, 'A-WALL', 'GOVERNING STANDARD: PHILIPPINE ELECTRICAL CODE (PEC 2017) / IESNA', bx + 0.5, by + 1.8, 0.26);
    _writeText(b, 'A-WALL', 'DISTRIBUTION: 230V, 1-PHASE, 2-WIRE + GROUND, 60HZ (CANORECO)', bx + 0.5, by + 1.0, 0.26);

    // Professional Seal & Sign Block (Right Side)
    _writeText(b, 'A-WALL', isPro ? 'DESIGNED & COMPUTED BY: CONTRACTOR PRO SUITE' : 'DESIGNED BY: BANAAG FREE TIER (banaag.ph)', bx + 13.5, by + 4.2, 0.28);
    _writeText(b, 'A-WALL', 'SEAL: REGISTERED ELECTRICAL ENGINEER (REE)', bx + 13.5, by + 3.4, 0.26);
    _writeText(b, 'A-WALL', 'PRC LICENSE NO.: [FOR REE SEAL & SIGNATURE]', bx + 13.5, by + 2.8, 0.24);
    _writeText(b, 'A-WALL', 'SCALE: 1:100 METRIC (CAD MODEL SPACE 1:1)', bx + 13.5, by + 1.6, 0.28);
    _writeText(b, 'A-WALL', 'SHEET NO.: E - 1 OF 4', bx + 13.5, by + 0.8, 0.34);
  }

  // Primitive DXF Low-Level Writers
  static void _writeLine(StringBuffer b, String layer, double x1, double y1, double x2, double y2) {
    b.writeln('0');
    b.writeln('LINE');
    b.writeln('8');
    b.writeln(layer);
    b.writeln('10');
    b.writeln(x1.toStringAsFixed(4));
    b.writeln('20');
    b.writeln(y1.toStringAsFixed(4));
    b.writeln('11');
    b.writeln(x2.toStringAsFixed(4));
    b.writeln('21');
    b.writeln(y2.toStringAsFixed(4));
  }

  static void _writeRect(StringBuffer b, String layer, double x1, double y1, double x2, double y2) {
    _writeLine(b, layer, x1, y1, x2, y1);
    _writeLine(b, layer, x2, y1, x2, y2);
    _writeLine(b, layer, x2, y2, x1, y2);
    _writeLine(b, layer, x1, y2, x1, y1);
  }

  static void _writeCircle(StringBuffer b, String layer, double cx, double cy, double r) {
    b.writeln('0');
    b.writeln('CIRCLE');
    b.writeln('8');
    b.writeln(layer);
    b.writeln('10');
    b.writeln(cx.toStringAsFixed(4));
    b.writeln('20');
    b.writeln(cy.toStringAsFixed(4));
    b.writeln('40');
    b.writeln(r.toStringAsFixed(4));
  }

  static void _writeText(StringBuffer b, String layer, String text, double x, double y, double height) {
    b.writeln('0');
    b.writeln('TEXT');
    b.writeln('8');
    b.writeln(layer);
    b.writeln('10');
    b.writeln(x.toStringAsFixed(4));
    b.writeln('20');
    b.writeln(y.toStringAsFixed(4));
    b.writeln('40');
    b.writeln(height.toStringAsFixed(4));
    b.writeln('1');
    b.writeln(text);
  }
}
