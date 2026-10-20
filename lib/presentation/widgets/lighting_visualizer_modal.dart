// BANAAG Lighting Visualizer & Illuminance Layout Modal
// Displays Dual-View (CAD Schematic Layout vs. Lux Contour Heatmap)
// with live spacing dimensions and 'Apply to Plan Canvas' export.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/lighting_engine.dart';
import '../../domain/illuminance_grid_engine.dart';
import '../theme/banaag_theme.dart';

class LightingVisualizerModal extends StatefulWidget {
  final RoomType initialRoomType;
  final double initialLength;
  final double initialWidth;
  final double initialHeight;
  final Function(IlluminanceLayoutResult result)? onApplyToCanvas;

  const LightingVisualizerModal({
    super.key,
    this.initialRoomType = RoomType.bedroom,
    this.initialLength = 4.0,
    this.initialWidth = 3.5,
    this.initialHeight = 2.7,
    this.onApplyToCanvas,
  });

  static Future<void> show(
    BuildContext context, {
    RoomType initialRoomType = RoomType.bedroom,
    double initialLength = 4.0,
    double initialWidth = 3.5,
    double initialHeight = 2.7,
    Function(IlluminanceLayoutResult result)? onApplyToCanvas,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LightingVisualizerModal(
        initialRoomType: initialRoomType,
        initialLength: initialLength,
        initialWidth: initialWidth,
        initialHeight: initialHeight,
        onApplyToCanvas: onApplyToCanvas,
      ),
    );
  }

  @override
  State<LightingVisualizerModal> createState() => _LightingVisualizerModalState();
}

class _LightingVisualizerModalState extends State<LightingVisualizerModal> {
  late RoomType _roomType;
  late double _length;
  late double _width;
  late double _height;
  bool _isHeatmapView = false;
  late IlluminanceLayoutResult _result;

  late TextEditingController _lenCtrl;
  late TextEditingController _widCtrl;
  late TextEditingController _heightCtrl;

  @override
  void initState() {
    super.initState();
    _roomType = widget.initialRoomType;
    _length = widget.initialLength;
    _width = widget.initialWidth;
    _height = widget.initialHeight;

    _lenCtrl = TextEditingController(text: _length.toStringAsFixed(1));
    _widCtrl = TextEditingController(text: _width.toStringAsFixed(1));
    _heightCtrl = TextEditingController(text: _height.toStringAsFixed(1));

    _recalculate();
  }

  @override
  void dispose() {
    _lenCtrl.dispose;
    _widCtrl.dispose;
    _heightCtrl.dispose;
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _result = IlluminanceGridEngine.computeLayout(
        lengthMeters: _length,
        widthMeters: _width,
        ceilingHeightMeters: _height,
        roomType: _roomType,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Dialog(
      backgroundColor: BanaagTheme.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: screenH * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.grid_view_rounded, color: BanaagTheme.primaryAmber, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Illuminance & Fixture Placement Sizer',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                        Text(
                          'IESNA d/2 Symmetrical Spacing • Lux Point-by-Point',
                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
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

            // Controls Ribbon: Dimensions & Mode Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF161B22),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Room Type Selector
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<RoomType>(
                          initialValue: _roomType,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            labelText: 'Room Type',
                            border: OutlineInputBorder(),
                          ),
                          dropdownColor: const Color(0xFF212836),
                          items: RoomType.values.map((r) {
                            return DropdownMenuItem(
                              value: r,
                              child: Text(r.label, style: const TextStyle(fontSize: 12, color: Colors.white)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _roomType = val;
                              _recalculate();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // View Toggle
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('CAD', style: TextStyle(fontSize: 11)), icon: Icon(Icons.architecture, size: 14)),
                          ButtonSegment(value: true, label: Text('Heatmap', style: TextStyle(fontSize: 11)), icon: Icon(Icons.gradient, size: 14)),
                        ],
                        selected: {_isHeatmapView},
                        onSelectionChanged: (set) {
                          setState(() => _isHeatmapView = set.first);
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDimInput('Length (m)', _lenCtrl, (v) {
                        _length = double.tryParse(v) ?? _length;
                        _recalculate();
                      }),
                      const SizedBox(width: 6),
                      _buildDimInput('Width (m)', _widCtrl, (v) {
                        _width = double.tryParse(v) ?? _width;
                        _recalculate();
                      }),
                      const SizedBox(width: 6),
                      _buildDimInput('Height (m)', _heightCtrl, (v) {
                        _height = double.tryParse(v) ?? _height;
                        _recalculate();
                      }),
                    ],
                  ),
                ],
              ),
            ),

            // Canvas Visualization
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1218),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: _RoomGridPainter(
                          layout: _result,
                          isHeatmap: _isHeatmapView,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Calculation Telemetry Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_result.totalFixtures}x ${_result.fixtureModelName}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: BanaagTheme.primaryAmber),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Array: ${_result.rows}R × ${_result.columns}C • Spacing: ${_result.spacingXMeters.toStringAsFixed(2)}m × ${_result.spacingYMeters.toStringAsFixed(2)}m',
                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 28, width: 1, color: Colors.white24),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Avg: ${_result.maintainedAverageLux.toStringAsFixed(0)} Lux (Target: ${_result.targetLux})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Uniformity U₀: ${_result.uniformityRatio.toStringAsFixed(2)} ${_result.uniformityRatio >= 0.6 ? "✅ (Pass)" : "⚠️ (Marginal)"}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _result.uniformityRatio >= 0.6 ? BanaagTheme.successGreen : Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Footer Action Buttons
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Text(
                    'IESNA Standard: Wall = d/2',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BanaagTheme.primaryAmber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.brush, size: 16),
                    label: const Text('Apply to Plan Canvas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      Navigator.pop(context);
                      if (widget.onApplyToCanvas != null) {
                        widget.onApplyToCanvas!(_result);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDimInput(String label, TextEditingController ctrl, Function(String) onChanged) {
    return Expanded(
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 12, color: Colors.white),
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          labelStyle: const TextStyle(fontSize: 10, color: BanaagTheme.textMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _RoomGridPainter extends CustomPainter {
  final IlluminanceLayoutResult layout;
  final bool isHeatmap;

  _RoomGridPainter({required this.layout, required this.isHeatmap});

  @override
  void paint(Canvas canvas, Size size) {
    if (layout.lengthMeters <= 0 || layout.widthMeters <= 0) return;

    // Margins for dimension markers
    const double margin = 46.0;
    final double availW = size.width - (margin * 2);
    final double availH = size.height - (margin * 2);

    final double scaleX = availW / layout.lengthMeters;
    final double scaleY = availH / layout.widthMeters;
    final double scale = math.min(scaleX, scaleY);

    final double roomPxW = layout.lengthMeters * scale;
    final double roomPxH = layout.widthMeters * scale;
    final double originX = (size.width - roomPxW) / 2.0;
    final double originY = (size.height - roomPxH) / 2.0;
    final Rect roomRect = Rect.fromLTWH(originX, originY, roomPxW, roomPxH);

    // 1. Room Background
    final bgPaint = Paint()..color = const Color(0xFF131720);
    canvas.drawRect(roomRect, bgPaint);

    // 2. Heatmap Layer (if selected)
    if (isHeatmap) {
      for (final fix in layout.fixtures) {
        final double fx = originX + (fix.xMeters * scale);
        final double fy = originY + (fix.yMeters * scale);
        final double radius = math.max(scale * 1.6, 60.0);

        final gradPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              BanaagTheme.primaryAmber.withValues(alpha: 0.55),
              BanaagTheme.primaryAmber.withValues(alpha: 0.20),
              const Color(0xFF131720).withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(fx, fy), radius: radius))
          ..blendMode = BlendMode.screen;

        canvas.save();
        canvas.clipRect(roomRect);
        canvas.drawCircle(Offset(fx, fy), radius, gradPaint);
        canvas.restore();
      }
    }

    // 3. Wall Outline
    final wallPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(roomRect, wallPaint);

    // 4. Fixtures & Crosshairs
    final fixBorder = Paint()
      ..color = BanaagTheme.primaryAmber
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final fixFill = Paint()..color = const Color(0xFF1F2633);

    final crossPaint = Paint()
      ..color = BanaagTheme.primaryAmber
      ..strokeWidth = 1.2;

    for (final fix in layout.fixtures) {
      final double fx = originX + (fix.xMeters * scale);
      final double fy = originY + (fix.yMeters * scale);
      final center = Offset(fx, fy);
      final double r = 12.0;

      canvas.drawCircle(center, r, fixFill);
      canvas.drawCircle(center, r, fixBorder);

      // Electrical Fixture Crosshair (Symbol)
      canvas.drawLine(Offset(fx - r, fy), Offset(fx + r, fy), crossPaint);
      canvas.drawLine(Offset(fx, fy - r), Offset(fx, fy + r), crossPaint);

      // Label (L1, L2, etc)
      _drawText(
        canvas,
        fix.label,
        fx + 14,
        fy - 14,
        const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      );
    }

    // 5. Dimension Markers (Top & Left)
    _drawDimensions(canvas, roomRect, scale);
  }

  void _drawDimensions(Canvas canvas, Rect r, double scale) {
    final dimPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1.0;
    const textStyle = TextStyle(color: Colors.white70, fontSize: 9);

    // Top Dimension Line (Total Length)
    final double topY = r.top - 20;
    canvas.drawLine(Offset(r.left, topY), Offset(r.right, topY), dimPaint);
    canvas.drawLine(Offset(r.left, topY - 4), Offset(r.left, topY + 4), dimPaint);
    canvas.drawLine(Offset(r.right, topY - 4), Offset(r.right, topY + 4), dimPaint);
    _drawText(canvas, '${layout.lengthMeters.toStringAsFixed(2)}m', r.center.dx - 14, topY - 14, textStyle);

    // Left Dimension Line (Total Width)
    final double leftX = r.left - 20;
    canvas.drawLine(Offset(leftX, r.top), Offset(leftX, r.bottom), dimPaint);
    canvas.drawLine(Offset(leftX - 4, r.top), Offset(leftX + 4, r.top), dimPaint);
    canvas.drawLine(Offset(leftX - 4, r.bottom), Offset(leftX + 4, r.bottom), dimPaint);
    _drawText(canvas, '${layout.widthMeters.toStringAsFixed(2)}m', leftX - 28, r.center.dy - 6, textStyle);

    // Spacing Annotations (d/2 and d)
    if (layout.columns > 1) {
      final double subY = r.bottom + 12;
      final double dWall = layout.wallDistanceXMeters * scale;
      final double dSpacing = layout.spacingXMeters * scale;

      // Wall to 1st light
      _drawDimTick(canvas, r.left, r.left + dWall, subY, '${layout.wallDistanceXMeters.toStringAsFixed(2)}m (d/2)');
      // 1st light to 2nd light
      _drawDimTick(canvas, r.left + dWall, r.left + dWall + dSpacing, subY, '${layout.spacingXMeters.toStringAsFixed(2)}m (d)');
    }
  }

  void _drawDimTick(Canvas canvas, double x1, double x2, double y, String label) {
    final p = Paint()..color = BanaagTheme.primaryAmber.withValues(alpha: 0.5)..strokeWidth = 1;
    canvas.drawLine(Offset(x1, y), Offset(x2, y), p);
    canvas.drawLine(Offset(x1, y - 3), Offset(x1, y + 3), p);
    canvas.drawLine(Offset(x2, y - 3), Offset(x2, y + 3), p);
    _drawText(canvas, label, ((x1 + x2) / 2) - 18, y + 3, const TextStyle(color: BanaagTheme.primaryAmber, fontSize: 8));
  }

  void _drawText(Canvas canvas, String text, double x, double y, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant _RoomGridPainter oldDelegate) {
    return oldDelegate.layout != layout || oldDelegate.isHeatmap != isHeatmap;
  }
}
