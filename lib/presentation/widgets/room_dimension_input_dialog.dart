import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../domain/lighting_engine.dart';
import '../../domain/illuminance_grid_engine.dart';
import '../../domain/room_illuminance_placement_service.dart';
import '../theme/banaag_theme.dart';

class RoomDimensionInputDialog extends StatefulWidget {
  final RoomGeometry? initialGeometry;
  final Function(RoomGeometry geometry, List<CanvasPoint> points, List<ConduitRoute> routes) onGenerated;

  const RoomDimensionInputDialog({
    super.key,
    this.initialGeometry,
    required this.onGenerated,
  });

  static Future<void> show(
    BuildContext context, {
    RoomGeometry? initialGeometry,
    required Function(RoomGeometry geometry, List<CanvasPoint> points, List<ConduitRoute> routes) onGenerated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoomDimensionInputDialog(
        initialGeometry: initialGeometry,
        onGenerated: onGenerated,
      ),
    );
  }

  @override
  State<RoomDimensionInputDialog> createState() => _RoomDimensionInputDialogState();
}

class _RoomDimensionInputDialogState extends State<RoomDimensionInputDialog> {
  late TextEditingController _lengthCtrl;
  late TextEditingController _widthCtrl;
  late TextEditingController _heightCtrl;
  RoomType _selectedRoomType = RoomType.classroom;

  @override
  void initState() {
    super.initState();
    final geom = widget.initialGeometry ?? const RoomGeometry();
    _lengthCtrl = TextEditingController(text: geom.totalWidthMeters > 0 ? geom.totalWidthMeters.toStringAsFixed(1) : '7.0');
    _widthCtrl = TextEditingController(text: geom.leftWallMeters > 0 ? geom.leftWallMeters.toStringAsFixed(1) : '6.0');
    _heightCtrl = TextEditingController(text: '2.8');
  }

  @override
  void dispose() {
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  void _generate() {
    final double length = double.tryParse(_lengthCtrl.text) ?? 7.0;
    final double width = double.tryParse(_widthCtrl.text) ?? 6.0;
    final double height = double.tryParse(_heightCtrl.text) ?? 2.8;

    final result = RoomIlluminancePlacementService.generate(
      lengthMeters: length,
      widthMeters: width,
      ceilingHeightMeters: height,
      roomType: _selectedRoomType,
    );

    widget.onGenerated(result.geometry, result.points, result.routes);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final double length = double.tryParse(_lengthCtrl.text) ?? 7.0;
    final double width = double.tryParse(_widthCtrl.text) ?? 6.0;
    final double height = double.tryParse(_heightCtrl.text) ?? 2.8;
    final double areaSqm = length * width;

    final illumCalc = IlluminanceGridEngine.computeLayout(
      lengthMeters: length,
      widthMeters: width,
      ceilingHeightMeters: height,
      roomType: _selectedRoomType,
    );

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161922),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.wb_incandescent, color: BanaagTheme.primaryAmber, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dimension & Auto-Illuminance Sizer',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      Text(
                        'PEC Table 2.20.2.3 & DOLE Rule 1075 / IESNA (${_selectedRoomType.recommendedLux} Lux)',
                        style: const TextStyle(fontSize: 11, color: BanaagTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Dimension Inputs (Length, Width, Height)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lengthCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Haba (Length)',
                      suffixText: 'm',
                      filled: true,
                      fillColor: BanaagTheme.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _widthCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Lapad (Width)',
                      suffixText: 'm',
                      filled: true,
                      fillColor: BanaagTheme.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _heightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Taas (Height)',
                      suffixText: 'm',
                      filled: true,
                      fillColor: BanaagTheme.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Room Occupancy Function Selector
            const Text('Room Function / Occupancy Type:', style: TextStyle(color: BanaagTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: BanaagTheme.surfaceCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BanaagTheme.surfaceCardBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<RoomType>(
                  value: _selectedRoomType,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E2430),
                  items: RoomType.values.map((type) {
                    final category = type.index <= 5 ? '🏡 Res' : (type.index <= 9 ? '🏛️ Inst' : '🏢 Comm');
                    return DropdownMenuItem<RoomType>(
                      value: type,
                      child: Text(
                        '[$category] ${type.label} (${type.recommendedLux} Lux)',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRoomType = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Live Room Calculation & Photometric Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2430),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BanaagTheme.surfaceCardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Computed Floor Area', style: TextStyle(fontSize: 10, color: BanaagTheme.textMuted)),
                          Text('${areaSqm.toStringAsFixed(1)} m²', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: BanaagTheme.primaryAmber)),
                          Text('IESNA Wall: ${(illumCalc.wallDistanceXMeters).toStringAsFixed(2)}m (d/2)', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('IESNA / DOLE Lux Target', style: TextStyle(fontSize: 10, color: BanaagTheme.textMuted)),
                          Text(
                            '${illumCalc.maintainedAverageLux.toStringAsFixed(0)} Lux (Target: ${illumCalc.targetLux})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BanaagTheme.successGreen),
                          ),
                          Text(
                            'U₀ = ${illumCalc.uniformityRatio.toStringAsFixed(2)} (${illumCalc.uniformityRatio >= 0.60 ? "Good" : "Marginal"})',
                            style: TextStyle(
                              fontSize: 10,
                              color: illumCalc.uniformityRatio >= 0.60 ? BanaagTheme.successGreen : BanaagTheme.warningOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 16),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: BanaagTheme.successGreen, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Kusang maglalagay ng ${illumCalc.totalFixtures}x ${illumCalc.fixtureModelName} (${illumCalc.rows}R × ${illumCalc.columns}C), Switch Leg, at Homerun papuntang Panelboard.',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BanaagTheme.primaryAmber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.flash_on, size: 18),
                label: const Text('Auto-Place Fixtures & Conduits on Canvas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: _generate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
