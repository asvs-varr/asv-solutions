// BANAAG Raw Floor Plan & DXF Calibration Modal
// Supports uploading/selecting raw images/PDFs and messy DXFs with 2-point calibration and 1-tap PEC Auto-Placement.

import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../domain/dxf_intake_engine.dart';
import '../../domain/pec_auto_placement_engine.dart';
import '../../domain/lighting_engine.dart';
import '../theme/banaag_theme.dart';

class RawPlanCalibrationModal extends StatefulWidget {
  final Project? project;
  final Function(List<CanvasPoint> points, List<ConduitRoute> routes, RoomGeometry geometry) onApplied;

  const RawPlanCalibrationModal({
    super.key,
    this.project,
    required this.onApplied,
  });

  static Future<void> show(
    BuildContext context, {
    Project? project,
    required Function(List<CanvasPoint> points, List<ConduitRoute> routes, RoomGeometry geometry) onApplied,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RawPlanCalibrationModal(
        project: project,
        onApplied: onApplied,
      ),
    );
  }

  @override
  State<RawPlanCalibrationModal> createState() => _RawPlanCalibrationModalState();
}

class _RawPlanCalibrationModalState extends State<RawPlanCalibrationModal> {
  int _activeTab = 0; // 0: Raw Floor Plan (Image/PDF), 1: Messy / Student DXF

  // Calibration parameters
  double _calibratedLengthMeters = 8.0;
  double _calibratedWidthMeters = 6.0;
  double _ceilingHeightMeters = 2.7;
  RoomType _selectedRoomType = RoomType.livingDining;

  // DXF Simulation choices
  String _selectedDxfPreset = 'messy_student'; // 'messy_student', 'semi_compliant', 'fully_compliant'

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF141922),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.architecture, color: BanaagTheme.primaryAmber, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Floor Plan Intake & Smart Auto-Placement',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                      Text(
                        'Raw Images, PDFs, at Messy CAD Layer 0 Filter',
                        style: TextStyle(color: BanaagTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2530),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(0, 'Raw Plan (Image/PDF)', Icons.image_outlined),
                  ),
                  Expanded(
                    child: _buildTabButton(1, 'AutoCAD .DXF Filter', Icons.layers_outlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _activeTab == 0 ? _buildRawPlanTab() : _buildDxfTab(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final bool isSelected = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? BanaagTheme.primaryAmber : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.black : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.black : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawPlanTab() {
    final blueprintPath = widget.project?.blueprintImagePath;
    final bool hasFile = blueprintPath != null && blueprintPath.isNotEmpty && File(blueprintPath).existsSync();
    final fileName = hasFile ? blueprintPath.split(Platform.pathSeparator).last : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Underlay Simulation Box
        Container(
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(
            color: const Color(0xFF1B212D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasFile ? BanaagTheme.primaryAmber : Colors.white24,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasFile ? Icons.check_circle_outline : Icons.cloud_upload_outlined,
                size: 36,
                color: hasFile ? BanaagTheme.successGreen : BanaagTheme.primaryAmber.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 8),
              Text(
                hasFile ? 'Naka-Link na Floor Plan:' : 'I-upload ang Blueprint Photo, Scan, o PDF',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                hasFile ? (fileName ?? '') : 'Kahit walang electrical layout (architectural walls lang)',
                style: const TextStyle(fontSize: 11, color: BanaagTheme.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BanaagTheme.successGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hasFile ? 'ACTIVE IN CANVAS BACKGROUND' : 'SAMPLE PLAN LOADED: 8.0m x 6.0m House Plan',
                  style: const TextStyle(fontSize: 10, color: BanaagTheme.successGreen, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2-Point Calibration Section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BanaagTheme.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: BanaagTheme.surfaceCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.straighten, color: BanaagTheme.primaryAmber, size: 18),
                  SizedBox(width: 8),
                  Text('2-Point Metric Calibration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'I-set ang totoong sukat ng kwarto mula sa dalawang kilalang pader upang ma-scale nang eksakto ang wiring runs.',
                style: TextStyle(fontSize: 11, color: BanaagTheme.textMuted, height: 1.3),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _dimensionField('Haba / Length (Meters)', _calibratedLengthMeters.toString(), (val) {
                      setState(() => _calibratedLengthMeters = double.tryParse(val) ?? 8.0);
                    }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dimensionField('Lapad / Width (Meters)', _calibratedWidthMeters.toString(), (val) {
                      setState(() => _calibratedWidthMeters = double.tryParse(val) ?? 6.0);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _dimensionField('Taas ng Kisame (Meters)', _ceilingHeightMeters.toString(), (val) {
                      setState(() => _ceilingHeightMeters = double.tryParse(val) ?? 2.7);
                    }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Uri ng Kwarto (PEC)', style: TextStyle(color: BanaagTheme.textMuted, fontSize: 11)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141922),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<RoomType>(
                              value: _selectedRoomType,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1E2530),
                              items: const [
                                DropdownMenuItem(value: RoomType.livingDining, child: Text('Living & Dining', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: RoomType.bedroom, child: Text('Bedroom', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: RoomType.kitchen, child: Text('Kitchen (SABC)', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: RoomType.homeOffice, child: Text('Home Office', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedRoomType = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Live Preview of PEC Placement Plan
        Builder(
          builder: (_) {
            final preview = PecAutoPlacementEngine.generateLayout(
              lengthMeters: _calibratedLengthMeters,
              widthMeters: _calibratedWidthMeters,
              ceilingHeightMeters: _ceilingHeightMeters,
              roomType: _selectedRoomType,
            );

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BanaagTheme.primaryAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: BanaagTheme.primaryAmber, size: 18),
                      SizedBox(width: 8),
                      Text('PEC Smart Auto-Placement Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BanaagTheme.primaryAmber)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preview.complianceSummary,
                    style: const TextStyle(fontSize: 11, color: Colors.white, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _previewStat('Lights', '${preview.totalLights} pcs'),
                      _previewStat('Duplex CO', '${preview.totalOutlets} pcs'),
                      _previewStat('Switch', '${preview.totalSwitches} unit'),
                      _previewStat('Wire Run', '${preview.estimatedWireMeters.toStringAsFixed(1)}m'),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        // Apply Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: BanaagTheme.primaryAmber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.flash_on, size: 20),
            label: const Text('ILAGAY ANG PEC ELECTRICAL LAYOUT SA CANVAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: () {
              final result = PecAutoPlacementEngine.generateLayout(
                lengthMeters: _calibratedLengthMeters,
                widthMeters: _calibratedWidthMeters,
                ceilingHeightMeters: _ceilingHeightMeters,
                roomType: _selectedRoomType,
              );

              final geom = RoomGeometry(
                leftWallMeters: _calibratedWidthMeters,
                totalWidthMeters: _calibratedLengthMeters,
                roomType: 'RECTANGULAR',
              );

              widget.onApplied(result.points, result.routes, geom);
              Navigator.pop(context);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDxfTab() {
    final simulatedDxfContent = _getSimulatedDxfContent(_selectedDxfPreset);
    final parseResult = DxfIntakeEngine.parseDxfContent(simulatedDxfContent, fileName: 'uploaded_plan.dxf');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // DXF Mode Selector
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BanaagTheme.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: BanaagTheme.surfaceCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Subukan ang CAD Ingestion Scenario:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 8),
              _radioChoice('messy_student', 'Messy / Student File (Lahat sa "Layer 0", walang electrical layers)', Icons.warning_amber),
              _radioChoice('semi_compliant', 'Semi-Compliant (May ACU/CO text tags pero hindi standard ang layer)', Icons.rule),
              _radioChoice('fully_compliant', '100% Industry Standard (May E-LITE, E-POWR, A-WALL layers)', Icons.verified),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Hybrid Smart Filter Analysis Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B2230),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: parseResult.grade == DxfComplianceGrade.fullyLayeredCompliant
                  ? BanaagTheme.successGreen
                  : (parseResult.grade == DxfComplianceGrade.semiCompliantWithText
                      ? BanaagTheme.warningOrange
                      : BanaagTheme.primaryAmber),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    parseResult.grade == DxfComplianceGrade.fullyLayeredCompliant
                        ? Icons.verified
                        : Icons.filter_alt,
                    color: BanaagTheme.primaryAmber,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text('Hybrid Smart Filter Diagnostics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                parseResult.diagnosticMessage,
                style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
              ),
              const Divider(color: Colors.white12, height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _previewStat('Total Entities', '${parseResult.totalEntities}'),
                  _previewStat('Layers Found', '${parseResult.detectedLayers.length}'),
                  _previewStat('Points Extracted', '${parseResult.extractedElectricalPoints.length}'),
                  _previewStat('Plan Size', '${parseResult.boundingWidthMeters.toStringAsFixed(1)}m × ${parseResult.boundingHeightMeters.toStringAsFixed(1)}m'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Apply DXF Layout Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: BanaagTheme.primaryAmber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.input_rounded, size: 20),
            label: const Text('ILAGAY ANG NA-FILTER NA CAD PLAN SA CANVAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: () {
              final geom = RoomGeometry(
                leftWallMeters: parseResult.boundingHeightMeters.clamp(4.0, 25.0),
                totalWidthMeters: parseResult.boundingWidthMeters.clamp(5.0, 30.0),
                roomType: 'RECTANGULAR',
              );

              widget.onApplied(
                parseResult.extractedElectricalPoints,
                parseResult.extractedConduitRoutes,
                geom,
              );
              Navigator.pop(context);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _radioChoice(String value, String label, IconData icon) {
    final bool isSelected = _selectedDxfPreset == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedDxfPreset = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? BanaagTheme.primaryAmber.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? BanaagTheme.primaryAmber : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? BanaagTheme.primaryAmber : BanaagTheme.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dimensionField(String label, String value, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: value,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: const Color(0xFF141922),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _previewStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: BanaagTheme.textMuted)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BanaagTheme.primaryAmber)),
      ],
    );
  }

  String _getSimulatedDxfContent(String preset) {
    if (preset == 'fully_compliant') {
      return '''0
SECTION
2
ENTITIES
0
LINE
8
A-WALL
10
0.0
20
0.0
11
8.0
21
0.0
0
INSERT
8
E-LITE
2
LIGHT
10
4.0
20
3.0
0
INSERT
8
E-POWR
2
OUTLET
10
0.2
20
3.0
0
ENDSEC
0
EOF''';
    } else if (preset == 'semi_compliant') {
      return '''0
SECTION
2
ENTITIES
0
LINE
8
WALLS
10
0.0
20
0.0
11
9.0
21
0.0
0
TEXT
8
TEXT_LAYER
1
ACU 2.0HP
10
7.5
20
5.0
0
TEXT
8
TEXT_LAYER
1
CO DUPLEX
10
1.0
20
4.0
0
ENDSEC
0
EOF''';
    } else {
      // Student file: everything on layer 0, lines only
      return '''0
SECTION
2
ENTITIES
0
LINE
8
0
10
0.0
20
0.0
11
8.0
21
0.0
0
LINE
8
0
10
8.0
20
0.0
11
8.0
21
6.0
0
LINE
8
0
10
8.0
20
6.0
11
0.0
21
6.0
0
LINE
8
0
10
0.0
20
6.0
11
0.0
21
0.0
0
ENDSEC
0
EOF''';
    }
  }
}
