import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../theme/banaag_theme.dart';

class RoomBayConfig {
  String name;
  double widthMeters;
  double depthMeters;
  double cutoutWidthMeters;
  double cutoutDepthMeters;

  RoomBayConfig({
    required this.name,
    required this.widthMeters,
    required this.depthMeters,
    this.cutoutWidthMeters = 0.0,
    this.cutoutDepthMeters = 0.0,
  });
}

class MultiRoomSketchBuilderModal extends StatefulWidget {
  final double referenceWidthMeters;
  final Offset pinA;
  final Offset pinB;
  final double pixelsPerMeter;
  final Function(List<RoomSpace> spaces, Map<String, List<Offset>> polygons) onApply;

  const MultiRoomSketchBuilderModal({
    super.key,
    required this.referenceWidthMeters,
    required this.pinA,
    required this.pinB,
    required this.pixelsPerMeter,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required double referenceWidthMeters,
    required Offset pinA,
    required Offset pinB,
    required double pixelsPerMeter,
    required Function(List<RoomSpace> spaces, Map<String, List<Offset>> polygons) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MultiRoomSketchBuilderModal(
        referenceWidthMeters: referenceWidthMeters,
        pinA: pinA,
        pinB: pinB,
        pixelsPerMeter: pixelsPerMeter,
        onApply: onApply,
      ),
    );
  }

  @override
  State<MultiRoomSketchBuilderModal> createState() => _MultiRoomSketchBuilderModalState();
}

class _MultiRoomSketchBuilderModalState extends State<MultiRoomSketchBuilderModal> {
  late List<RoomBayConfig> _bays;

  @override
  void initState() {
    super.initState();
    // Default 3 bays matching typical hand-drawn electrical sketch
    // Bay 1: Room 1 (2.0m x 3.5m with 1m x 1m cutout)
    // Bay 2: Hallway / Utility (1.0m x 2.5m)
    // Bay 3: Room 2 / Bedroom (2.0m x 4.5m)
    _bays = [
      RoomBayConfig(name: 'Room 1 (Master)', widthMeters: 2.0, depthMeters: 3.5, cutoutWidthMeters: 1.0, cutoutDepthMeters: 1.0),
      RoomBayConfig(name: 'Hallway / Utility', widthMeters: 1.0, depthMeters: 2.5),
      RoomBayConfig(name: 'Room 2 (Bedroom)', widthMeters: 2.0, depthMeters: 4.5),
    ];
  }

  double get _totalConfiguredWidth => _bays.fold(0.0, (sum, b) => sum + b.widthMeters);

  void _addBay() {
    setState(() {
      _bays.add(RoomBayConfig(
        name: 'Room ${_bays.length + 1}',
        widthMeters: 2.5,
        depthMeters: 3.5,
      ));
    });
  }

  void _removeBay(int index) {
    if (_bays.length <= 1) return;
    setState(() {
      _bays.removeAt(index);
    });
  }

  void _applyReconstruction() {
    final double ppm = widget.pixelsPerMeter > 5.0 ? widget.pixelsPerMeter : 44.77;

    // Pin A to Pin B baseline vector
    final Offset pA = widget.pinA;
    final Offset pB = widget.pinB;
    final Offset baselineVec = pB - pA;
    final double baselineDistPx = baselineVec.distance;

    // Unit vectors
    final Offset unitX = baselineDistPx > 0.001 ? baselineVec / baselineDistPx : const Offset(1, 0);
    // Orthogonal 90° down vector (CW perpendicular: (dx, dy) -> (-dy, dx))
    final Offset unitY = Offset(-unitX.dy, unitX.dx);

    final List<RoomSpace> generatedSpaces = [];
    final Map<String, List<Offset>> generatedPolygons = {};

    double currentOffsetMeters = 0.0;

    for (int i = 0; i < _bays.length; i++) {
      final bay = _bays[i];
      final String spaceId = 'sp-bay-${DateTime.now().millisecondsSinceEpoch}-$i';

      // Top-Left corner of this bay along the baseline
      final Offset bayTL = pA + (unitX * (currentOffsetMeters * ppm));
      final Offset bayTR = bayTL + (unitX * (bay.widthMeters * ppm));

      List<Offset> polyVertices;

      if (bay.cutoutWidthMeters > 0.1 && bay.cutoutDepthMeters > 0.1 && bay.cutoutWidthMeters < bay.widthMeters) {
        // L-Shape polygon:
        // P1: Top-Left
        // P2: Top Cutout start (bayTL + unitX * (width - cutoutWidth))
        // P3: Cutout turn down (P2 + unitY * cutoutDepth)
        // P4: Cutout turn right to TR line (P3 + unitX * cutoutWidth)
        // P5: Bottom Right corner (bayTR + unitY * depth)
        // P6: Bottom Left corner (bayTL + unitY * depth)
        final Offset p1 = bayTL;
        final Offset p2 = bayTL + (unitX * ((bay.widthMeters - bay.cutoutWidthMeters) * ppm));
        final Offset p3 = p2 + (unitY * (bay.cutoutDepthMeters * ppm));
        final Offset p4 = p3 + (unitX * (bay.cutoutWidthMeters * ppm));
        final Offset p5 = bayTL + (unitX * (bay.widthMeters * ppm)) + (unitY * (bay.depthMeters * ppm));
        final Offset p6 = bayTL + (unitY * (bay.depthMeters * ppm));

        polyVertices = [p1, p2, p3, p4, p5, p6];
      } else {
        // Rectangular 4-point bay
        final Offset p1 = bayTL;
        final Offset p2 = bayTR;
        final Offset p3 = bayTR + (unitY * (bay.depthMeters * ppm));
        final Offset p4 = bayTL + (unitY * (bay.depthMeters * ppm));

        polyVertices = [p1, p2, p3, p4];
      }

      // Compute Net Area (sqm)
      double areaSqm = bay.widthMeters * bay.depthMeters;
      if (bay.cutoutWidthMeters > 0 && bay.cutoutDepthMeters > 0) {
        areaSqm -= (bay.cutoutWidthMeters * bay.cutoutDepthMeters);
      }
      areaSqm = math.max(1.0, areaSqm);

      final double perimeterM = (bay.widthMeters + bay.depthMeters) * 2;

      final roomSpace = RoomSpace(
        id: spaceId,
        name: bay.name,
        areaSqm: double.parse(areaSqm.toStringAsFixed(2)),
        ceilingHeight: 2.8,
        shapeType: polyVertices.length > 4 ? 'L_SHAPE' : 'RECTANGULAR',
        cutoutDepth: bay.cutoutDepthMeters,
        cutoutWidth: bay.cutoutWidthMeters,
        canvasX: bayTL.dx,
        canvasY: bayTL.dy,
        canvasWidth: bay.widthMeters * ppm,
        canvasHeight: bay.depthMeters * ppm,
        perimeterMeters: double.parse(perimeterM.toStringAsFixed(2)),
        polygonVertices: polyVertices.map((pt) => {'x': pt.dx, 'y': pt.dy}).toList(),
      );

      generatedSpaces.add(roomSpace);
      generatedPolygons[spaceId] = polyVertices;

      currentOffsetMeters += bay.widthMeters;
    }

    widget.onApply(generatedSpaces, generatedPolygons);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final double totalW = _totalConfiguredWidth;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161922),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 18,
        right: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.architecture, color: BanaagTheme.primaryAmber, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Auto-Redraw Sketch to CAD Walls',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Aligns true 90° CAD walls to Pin A–B baseline ($totalW m total bay width)',
                        style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 11),
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
            const SizedBox(height: 16),

            // Dimension Summary Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2430),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.straighten, color: Colors.cyanAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pin A–B Reference: ${widget.referenceWidthMeters.toStringAsFixed(2)} m\n'
                      'Configured Bay Sum: ${totalW.toStringAsFixed(2)} m (${_bays.length} Rooms)',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: BanaagTheme.primaryAmber,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Bay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    onPressed: _addBay,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Bay List Editor
            ...List.generate(_bays.length, (idx) {
              final bay = _bays[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2230),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: BanaagTheme.primaryAmber.withValues(alpha: 0.25),
                          child: Text('${idx + 1}', style: const TextStyle(color: BanaagTheme.primaryAmber, fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: bay.name,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                              border: InputBorder.none,
                              hintText: 'Room Name',
                            ),
                            onChanged: (v) => bay.name = v.trim(),
                          ),
                        ),
                        if (_bays.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _removeBay(idx),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Bay Width
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Lapad (m)', style: TextStyle(color: Colors.white60, fontSize: 10)),
                              const SizedBox(height: 3),
                              TextFormField(
                                initialValue: bay.widthMeters.toStringAsFixed(1),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.black26,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                ),
                                onChanged: (v) {
                                  final val = double.tryParse(v);
                                  if (val != null && val > 0.2) {
                                    setState(() => bay.widthMeters = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Bay Depth
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Lalim (m)', style: TextStyle(color: Colors.white60, fontSize: 10)),
                              const SizedBox(height: 3),
                              TextFormField(
                                initialValue: bay.depthMeters.toStringAsFixed(1),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.black26,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                ),
                                onChanged: (v) {
                                  final val = double.tryParse(v);
                                  if (val != null && val > 0.2) {
                                    setState(() => bay.depthMeters = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Cutout row (optional for L-shape)
                    if (bay.cutoutWidthMeters > 0 || bay.cutoutDepthMeters > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.call_split, size: 13, color: Colors.white38),
                          const SizedBox(width: 4),
                          const Text('L-Cutout: ', style: TextStyle(color: Colors.white38, fontSize: 10)),
                          Text(
                            '${bay.cutoutWidthMeters}m x ${bay.cutoutDepthMeters}m',
                            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          TextButton(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                            onPressed: () {
                              setState(() {
                                bay.cutoutWidthMeters = 0.0;
                                bay.cutoutDepthMeters = 0.0;
                              });
                            },
                            child: const Text('Make Rectangle', style: TextStyle(color: Colors.cyanAccent, fontSize: 10)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BanaagTheme.primaryAmber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: Text(
                  '⚡ Reconstruct ${_bays.length} CAD Rooms over Sketch',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: _applyReconstruction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
