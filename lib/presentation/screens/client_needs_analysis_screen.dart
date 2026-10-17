// BANAAG Client Needs Analysis Screen: Modular List View, Custom Spaces, Custom Appliances & Smart Lighting Sizer

import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../domain/lighting_engine.dart';
import '../../data/project_repository.dart';
import '../theme/banaag_theme.dart';
import 'plan_canvas_screen.dart';

class ClientNeedsAnalysisScreen extends StatefulWidget {
  final Project project;
  const ClientNeedsAnalysisScreen({super.key, required this.project});

  @override
  State<ClientNeedsAnalysisScreen> createState() => _ClientNeedsAnalysisScreenState();
}

class _ClientNeedsAnalysisScreenState extends State<ClientNeedsAnalysisScreen> {
  final List<RoomSpace> _spaces = [
    RoomSpace(id: 'sp-1', name: 'Living & Dining', areaSqm: 24.0, ceilingHeight: 2.7),
    RoomSpace(id: 'sp-2', name: 'Kitchen', areaSqm: 14.0, ceilingHeight: 2.7),
    RoomSpace(id: 'sp-3', name: 'Master Bedroom', areaSqm: 18.0, ceilingHeight: 2.7),
    RoomSpace(id: 'sp-4', name: 'Bath & Laundry', areaSqm: 8.0, ceilingHeight: 2.6),
  ];

  late String _activeSpaceName;

  // Standard Philippine Quick-Pick Preset Catalog
  final List<Map<String, dynamic>> _quickPresets = [
    {'name': '2.5HP Inverter Split ACU', 'va': 2600.0, 'dedicated': true, 'icon': Icons.ac_unit},
    {'name': '1.5HP Inverter Split ACU', 'va': 1650.0, 'dedicated': true, 'icon': Icons.ac_unit},
    {'name': 'Two-Door Inverter Refrigerator', 'va': 800.0, 'dedicated': true, 'icon': Icons.kitchen},
    {'name': 'Induction Cooktop (Double Burner)', 'va': 3500.0, 'dedicated': true, 'icon': Icons.soup_kitchen},
    {'name': 'Multipoint Water Heater (3.5kW)', 'va': 3500.0, 'dedicated': true, 'icon': Icons.hot_tub},
    {'name': 'Single-point Shower Heater', 'va': 2500.0, 'dedicated': true, 'icon': Icons.shower},
    {'name': 'Front-load Washing Machine', 'va': 1800.0, 'dedicated': true, 'icon': Icons.local_laundry_service},
    {'name': 'Microwave & Oven Toaster', 'va': 1800.0, 'dedicated': false, 'icon': Icons.microwave},
    {'name': '65" Smart 4K TV & Audio Rack', 'va': 350.0, 'dedicated': false, 'icon': Icons.tv},
    {'name': 'General Convenience Outlet (Duplex)', 'va': 180.0, 'dedicated': false, 'icon': Icons.power},
    {'name': 'Workstation PC / Desktop', 'va': 450.0, 'dedicated': false, 'icon': Icons.computer},
    {'name': 'Ceiling Fan with Drop Light', 'va': 120.0, 'dedicated': false, 'icon': Icons.mode_fan_off_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _activeSpaceName = _spaces.first.name;
    // Strictly Zero-Default: Keep clean canvas, do NOT inject unwanted items
  }

  RoomSpace get _currentSpace => _spaces.firstWhere(
        (s) => s.name == _activeSpaceName,
        orElse: () => _spaces.first,
      );

  RoomType _mapSpaceToRoomType(String spaceName) {
    final lower = spaceName.toLowerCase();
    if (lower.contains('kitchen')) return RoomType.kitchen;
    if (lower.contains('bed')) return RoomType.bedroom;
    if (lower.contains('bath') || lower.contains('laundry')) return RoomType.bathroom;
    if (lower.contains('office') || lower.contains('study')) return RoomType.homeOffice;
    if (lower.contains('garage') || lower.contains('outdoor') || lower.contains('deck')) return RoomType.garageStorage;
    return RoomType.livingDining;
  }

  void _addOrIncrementAppliance({
    required String name,
    required double ratingVA,
    required bool isDedicated,
  }) {
    setState(() {
      final existingIndex = widget.project.applianceLoads.indexWhere(
        (a) => a.name == name && a.roomCategory == _activeSpaceName,
      );

      if (existingIndex != -1) {
        widget.project.applianceLoads[existingIndex].quantity++;
      } else {
        widget.project.applianceLoads.add(ApplianceItem(
          id: 'app-${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          roomCategory: _activeSpaceName,
          ratingVA: ratingVA,
          quantity: 1,
          isDedicatedCircuit: isDedicated,
        ));
      }
      ProjectRepository.instance.updateProject(widget.project);
    });
  }

  void _decrementAppliance(ApplianceItem item) {
    setState(() {
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        widget.project.applianceLoads.remove(item);
      }
      ProjectRepository.instance.updateProject(widget.project);
    });
  }

  void _deleteAppliance(ApplianceItem item) {
    setState(() {
      widget.project.applianceLoads.remove(item);
      ProjectRepository.instance.updateProject(widget.project);
    });
  }

  void _promptAddCustomAppliance() {
    final nameController = TextEditingController();
    final vaController = TextEditingController(text: '300');
    bool isDedicated = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: BanaagTheme.surfaceCard,
          title: Row(
            children: [
              const Icon(Icons.add_circle_outline, color: BanaagTheme.primaryAmber),
              const SizedBox(width: 8),
              Text('Add Appliance: $_activeSpaceName', style: const TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Appliance Name',
                  hintText: 'e.g. Espresso Machine / Air Fryer',
                  labelStyle: TextStyle(color: BanaagTheme.textMuted),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: vaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Rating (VA or Watts)',
                  hintText: 'e.g. 1500',
                  suffixText: 'VA',
                  labelStyle: TextStyle(color: BanaagTheme.textMuted),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: BanaagTheme.primaryAmber,
                title: const Text('Dedicated Circuit Line', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Direct homerun wire & dedicated breaker (PEC required for >1.5kW / motors)', style: TextStyle(fontSize: 10, color: BanaagTheme.textMuted)),
                value: isDedicated,
                onChanged: (val) => setDialogState(() => isDedicated = val ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: BanaagTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final double va = double.tryParse(vaController.text.trim()) ?? 200.0;
                if (name.isNotEmpty) {
                  _addOrIncrementAppliance(name: name, ratingVA: va, isDedicated: isDedicated);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add to Room'),
            ),
          ],
        ),
      ),
    );
  }

  void _promptAddCustomSpace() {
    final nameController = TextEditingController();
    final areaController = TextEditingController(text: '16.0');
    final heightController = TextEditingController(text: '2.7');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BanaagTheme.surfaceCard,
        title: const Row(
          children: [
            Icon(Icons.meeting_room_outlined, color: BanaagTheme.primaryAmber),
            SizedBox(width: 8),
            Text('Create Custom Space / Room', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Room Name',
                hintText: 'e.g. Dirty Kitchen / Home Office / Balcony',
                labelStyle: TextStyle(color: BanaagTheme.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: areaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Floor Area',
                      suffixText: 'm²',
                      labelStyle: TextStyle(color: BanaagTheme.textMuted),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ceiling Ht',
                      suffixText: 'm',
                      labelStyle: TextStyle(color: BanaagTheme.textMuted),
                    ),
                  ),
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
            onPressed: () {
              final name = nameController.text.trim();
              final area = double.tryParse(areaController.text.trim()) ?? 16.0;
              final height = double.tryParse(heightController.text.trim()) ?? 2.7;
              if (name.isNotEmpty) {
                setState(() {
                  _spaces.add(RoomSpace(
                    id: 'sp-${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    areaSqm: area,
                    ceilingHeight: height,
                  ));
                  _activeSpaceName = name;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create Space'),
          ),
        ],
      ),
    );
  }

  void _showQuickPresetPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BanaagTheme.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quick Preset Library: $_activeSpaceName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Text('Pumili ng appliance para ma-add sa active room nang mabilis:', style: TextStyle(color: BanaagTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _quickPresets.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                itemBuilder: (context, index) {
                  final preset = _quickPresets[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                      foregroundColor: BanaagTheme.primaryAmber,
                      child: Icon(preset['icon'], size: 20),
                    ),
                    title: Text(preset['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text('${preset['va']} VA (${(preset['va'] / 230.0).toStringAsFixed(1)}A) ${preset['dedicated'] ? '• [DEDICATED]' : ''}',
                        style: TextStyle(color: preset['dedicated'] ? Colors.redAccent : BanaagTheme.textMuted, fontSize: 11)),
                    trailing: const Icon(Icons.add_circle, color: BanaagTheme.primaryAmber),
                    onTap: () {
                      _addOrIncrementAppliance(
                        name: preset['name'],
                        ratingVA: preset['va'],
                        isDedicated: preset['dedicated'],
                      );
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double totalConnectedVA = widget.project.totalConnectedLoadVA;
    final double totalCurrentAmps = totalConnectedVA / 230.0;
    final int dedicatedLinesCount = widget.project.applianceLoads.where((a) => a.isDedicatedCircuit).length;
    final int totalApplianceUnits = widget.project.applianceLoads.fold(0, (sum, a) => sum + a.quantity);

    final currentSpaceItems = widget.project.applianceLoads.where((a) => a.roomCategory == _activeSpaceName).toList();
    final lightingRec = LightingEngine.calculate(
      roomType: _mapSpaceToRoomType(_activeSpaceName),
      areaSqm: _currentSpace.areaSqm,
      ceilingHeightMeters: _currentSpace.ceilingHeight,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📋 Modular Client Needs Analysis', style: TextStyle(fontSize: 16)),
            Text(widget.project.title, style: const TextStyle(fontSize: 11, color: BanaagTheme.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_home_work_outlined, color: BanaagTheme.primaryAmber),
            tooltip: 'Add Custom Space / Room',
            onPressed: _promptAddCustomSpace,
          ),
        ],
      ),
      body: Column(
        children: [
          // Telemetry Summary Ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF1B2028),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _metricColumn('Connected Load', '${(totalConnectedVA / 1000.0).toStringAsFixed(1)} kVA', 'Total Rating'),
                _metricColumn('Total Amps', '${totalCurrentAmps.toStringAsFixed(1)} A', '230V 1-Phase'),
                _metricColumn('Dedicated Lines', '$dedicatedLinesCount Lines', 'Heaters/ACU/Ref', color: BanaagTheme.primaryAmber),
                _metricColumn('Total Units', '$totalApplianceUnits pcs', 'Tallied Items'),
              ],
            ),
          ),

          // Horizontal Space Selector Ribbon
          Container(
            height: 48,
            color: const Color(0xFF14171E),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              itemCount: _spaces.length + 1,
              itemBuilder: (context, index) {
                if (index == _spaces.length) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.add, size: 14, color: BanaagTheme.primaryAmber),
                      label: const Text('Add Space', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      onPressed: _promptAddCustomSpace,
                    ),
                  );
                }

                final space = _spaces[index];
                final bool isSelected = space.name == _activeSpaceName;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('${space.name} (${space.areaSqm.toStringAsFixed(0)}m²)'),
                    selected: isSelected,
                    selectedColor: BanaagTheme.primaryAmber,
                    backgroundColor: BanaagTheme.surfaceCard,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.black : Colors.white70,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _activeSpaceName = space.name);
                    },
                  ),
                );
              },
            ),
          ),

          // Smart Lighting Sizer Suggestion Ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFF1E2430),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: BanaagTheme.primaryAmber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Lighting: ${lightingRec.fixtureCount} pcs ${lightingRec.recommendedWattagePerFixture}W LED Downlight (${lightingRec.lumensPerFixture} lm)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                      ),
                      Text(
                        'Target: ${lightingRec.targetLumens.toStringAsFixed(0)} lm (${lightingRec.roomType.recommendedLux} Lux standard para sa $_activeSpaceName)',
                        style: const TextStyle(fontSize: 10, color: BanaagTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    backgroundColor: BanaagTheme.primaryAmber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    _addOrIncrementAppliance(
                      name: '${lightingRec.recommendedWattagePerFixture}W LED Downlight ($_activeSpaceName)',
                      ratingVA: 15.0,
                      isDedicated: false,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('💡 Added recommended LED lighting fixture to $_activeSpaceName!')),
                    );
                  },
                  child: const Text('+ Add Light', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // High-Density Vertical List View for Active Room
          Expanded(
            child: currentSpaceItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox_outlined, size: 48, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text('Walang nakalistang appliance sa $_activeSpaceName.', style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 13)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.flash_on, size: 16),
                              label: const Text('Quick Preset'),
                              onPressed: _showQuickPresetPicker,
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: BanaagTheme.primaryAmber),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Custom Appliance'),
                              onPressed: _promptAddCustomAppliance,
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: currentSpaceItems.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = currentSpaceItems[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: BanaagTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: item.isDedicatedCircuit ? Colors.redAccent.withValues(alpha: 0.5) : BanaagTheme.surfaceCardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: item.isDedicatedCircuit ? Colors.redAccent.withValues(alpha: 0.15) : BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                              foregroundColor: item.isDedicatedCircuit ? Colors.redAccent : BanaagTheme.primaryAmber,
                              child: Icon(item.isDedicatedCircuit ? Icons.electrical_services : Icons.power, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (item.isDedicatedCircuit)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('DEDICATED', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.ratingVA.toStringAsFixed(0)} VA (${(item.ratingVA / 230.0).toStringAsFixed(1)}A) • Subtotal: ${(item.totalVA / 1000.0).toStringAsFixed(2)} kVA',
                                    style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 20),
                                  onPressed: () => _decrementAppliance(item),
                                ),
                                Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: BanaagTheme.primaryAmber, size: 20),
                                  onPressed: () => _addOrIncrementAppliance(
                                    name: item.name,
                                    ratingVA: item.ratingVA,
                                    isDedicated: item.isDedicatedCircuit,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
                                  onPressed: () => _deleteAppliance(item),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Quick Actions Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFF14171E),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: BanaagTheme.primaryAmber),
                    icon: const Icon(Icons.library_add_outlined, size: 16),
                    label: const Text('Quick Presets'),
                    onPressed: _showQuickPresetPicker,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Appliance'),
                    onPressed: _promptAddCustomAppliance,
                  ),
                ),
              ],
            ),
          ),

          // Complete & Proceed to Stage 2 Plan Canvas Bridge
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: BanaagTheme.surfaceCard,
              border: Border(top: BorderSide(color: BanaagTheme.surfaceCardBorder)),
            ),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Complete & Proceed to Stage 2 Plan Canvas'),
              onPressed: () {
                final consultationPhase = widget.project.phases[0];
                final needsItem = consultationPhase.checklist.firstWhere(
                  (c) => c.id == 'c1',
                  orElse: () => consultationPhase.checklist.first,
                );
                needsItem.isCompleted = true;
                ProjectRepository.instance.updateProject(widget.project);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Client Needs Analysis complete! Generating auto-layout on Plan Canvas...')),
                );

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlanCanvasScreen(project: widget.project),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricColumn(String label, String value, String subtext, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color ?? Colors.white)),
        Text(label, style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 10)),
        Text(subtext, style: const TextStyle(color: Colors.white24, fontSize: 8)),
      ],
    );
  }
}
