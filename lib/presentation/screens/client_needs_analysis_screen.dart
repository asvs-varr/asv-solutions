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
    final wattsController = TextEditingController(text: '1000');
    final vaController = TextEditingController(text: '1000');
    double powerFactor = 1.0;
    String activeLoadType = 'Resistive';
    bool isDedicated = false;
    bool isUpdatingFromWatts = false;
    bool isUpdatingFromVA = false;

    // Quick common wattage buttons
    final List<int> quickWattages = [150, 350, 800, 1500, 2500, 3500];

    // Power factor preset definitions
    final Map<String, double> pfPresets = {
      'Resistive (1.0)': 1.0,
      'Inverter (0.85)': 0.85,
      'Motor/ACU (0.80)': 0.80,
      'LED Light (0.75)': 0.75,
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          void updateDedicatedStatus(double calculatedVA, String loadType) {
            if (calculatedVA >= 1500.0 || loadType.contains('Motor') || loadType.contains('ACU')) {
              isDedicated = true;
            }
          }

          void syncFromWatts(String val) {
            if (isUpdatingFromVA) return;
            isUpdatingFromWatts = true;
            final double? w = double.tryParse(val);
            if (w != null && powerFactor > 0) {
              final double calculatedVA = w / powerFactor;
              vaController.text = calculatedVA.toStringAsFixed(0);
              updateDedicatedStatus(calculatedVA, activeLoadType);
            }
            isUpdatingFromWatts = false;
            setDialogState(() {});
          }

          void syncFromVA(String val) {
            if (isUpdatingFromWatts) return;
            isUpdatingFromVA = true;
            final double? v = double.tryParse(val);
            if (v != null) {
              final double calculatedW = v * powerFactor;
              wattsController.text = calculatedW.toStringAsFixed(0);
              updateDedicatedStatus(v, activeLoadType);
            }
            isUpdatingFromVA = false;
            setDialogState(() {});
          }

          void applyPF(double newPF, String label) {
            powerFactor = newPF;
            activeLoadType = label;
            final double? w = double.tryParse(wattsController.text);
            if (w != null && powerFactor > 0) {
              final double calculatedVA = w / powerFactor;
              vaController.text = calculatedVA.toStringAsFixed(0);
              updateDedicatedStatus(calculatedVA, activeLoadType);
            }
            setDialogState(() {});
          }

          final double currentVA = double.tryParse(vaController.text) ?? 0.0;
          final double currentAmps = currentVA / 230.0;

          return AlertDialog(
            backgroundColor: BanaagTheme.surfaceCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.bolt, color: BanaagTheme.primaryAmber, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Add Appliance: $_activeSpaceName',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Appliance Name',
                      hintText: 'e.g. Espresso Machine / Range / Booster Pump',
                      labelStyle: TextStyle(color: BanaagTheme.textMuted),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Quick 1-Tap Wattage Selector
                  const Text(
                    '1-Tap Wattage Presets (Nameplate Common):',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BanaagTheme.textMuted),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: quickWattages.map((w) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ActionChip(
                            label: Text('${w}W', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.white10,
                            onPressed: () {
                              wattsController.text = w.toString();
                              syncFromWatts(w.toString());
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Dual Input: Watts & VA
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: wattsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Real Power (Watts)',
                            suffixText: 'W',
                            labelStyle: TextStyle(color: BanaagTheme.textMuted),
                          ),
                          onChanged: syncFromWatts,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 16, color: BanaagTheme.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: vaController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Apparent (VA)',
                            suffixText: 'VA',
                            labelStyle: TextStyle(color: BanaagTheme.primaryAmber),
                          ),
                          onChanged: syncFromVA,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Power Factor (PF) Presets
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Power Factor (PF):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'PF: ${powerFactor.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: BanaagTheme.primaryAmber,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: pfPresets.entries.map((entry) {
                      final bool isSelected = (powerFactor - entry.value).abs() < 0.02;
                      return ChoiceChip(
                        label: Text(entry.key, style: const TextStyle(fontSize: 10)),
                        selected: isSelected,
                        selectedColor: BanaagTheme.primaryAmber,
                        backgroundColor: BanaagTheme.surfaceCard,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) applyPF(entry.value, entry.key);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),

                  // Power Factor Fine-Tune Slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: BanaagTheme.primaryAmber,
                      activeTrackColor: BanaagTheme.primaryAmber,
                      inactiveTrackColor: Colors.white24,
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: powerFactor,
                      min: 0.50,
                      max: 1.0,
                      divisions: 50,
                      label: powerFactor.toStringAsFixed(2),
                      onChanged: (val) {
                        applyPF(val, 'Custom');
                      },
                    ),
                  ),

                  // Live Electrical Conversion Summary Ribbon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Formula: VA = Watts ÷ PF', style: TextStyle(fontSize: 10, color: BanaagTheme.textMuted)),
                            Text('${wattsController.text}W ÷ ${powerFactor.toStringAsFixed(2)} = ${currentVA.toStringAsFixed(0)} VA',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Current (230V)', style: TextStyle(fontSize: 10, color: BanaagTheme.textMuted)),
                            Text('${currentAmps.toStringAsFixed(2)} A',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BanaagTheme.primaryAmber)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Dedicated Circuit Checkbox
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: BanaagTheme.primaryAmber,
                    title: Row(
                      children: [
                        const Text('Dedicated Circuit Line', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        if (isDedicated) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('PEC SUGGESTED', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      isDedicated
                          ? 'Automatic flagged: >1.5kVA o Motor load. Nangangailangan ng sariling homerun wire at breaker.'
                          : 'I-check kung kailangan ng sariling homerun wire at breaker sa panelboard.',
                      style: TextStyle(fontSize: 10, color: isDedicated ? Colors.redAccent.shade100 : BanaagTheme.textMuted),
                    ),
                    value: isDedicated,
                    onChanged: (val) => setDialogState(() => isDedicated = val ?? false),
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
                  minimumSize: const Size(120, 42),
                  backgroundColor: BanaagTheme.primaryAmber,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  final name = nameController.text.trim();
                  final double va = double.tryParse(vaController.text.trim()) ?? 200.0;
                  if (name.isNotEmpty) {
                    _addOrIncrementAppliance(name: name, ratingVA: va, isDedicated: isDedicated);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('⚡ Added "$name" (${va.toStringAsFixed(0)} VA, PF: ${powerFactor.toStringAsFixed(2)}) to $_activeSpaceName!')),
                    );
                  }
                },
                child: const Text('Add to Room', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _applyPecStandardPack(String spaceName) {
    final lower = spaceName.toLowerCase();
    final lighting = LightingEngine.calculate(
      roomType: _mapSpaceToRoomType(spaceName),
      areaSqm: _currentSpace.areaSqm,
      ceilingHeightMeters: _currentSpace.ceilingHeight,
    );

    // 1. Add Recommended Smart Lighting
    _addOrIncrementAppliance(
      name: '${lighting.recommendedWattagePerFixture}W LED Downlight ($spaceName)',
      ratingVA: 15.0 * lighting.fixtureCount,
      isDedicated: false,
    );

    // 2. Add Standard Convenience Outlets & Heavy Loads based on PEC
    if (lower.contains('kitchen')) {
      _addOrIncrementAppliance(name: 'Kitchen Counter Duplex Receptacles', ratingVA: 360.0, isDedicated: false);
      _addOrIncrementAppliance(name: 'Dedicated Inverter Refrigerator Outlet', ratingVA: 800.0, isDedicated: true);
      _addOrIncrementAppliance(name: 'Induction / Range Hood Circuit Line', ratingVA: 3500.0, isDedicated: true);
    } else if (lower.contains('bed')) {
      _addOrIncrementAppliance(name: 'Bedside & Desk Convenience Outlets (Duplex)', ratingVA: 360.0, isDedicated: false);
      _addOrIncrementAppliance(name: 'Dedicated 1.5HP Inverter ACU Outlet', ratingVA: 1650.0, isDedicated: true);
    } else if (lower.contains('bath') || lower.contains('laundry')) {
      _addOrIncrementAppliance(name: 'GFCI Protected Shaver/Utility Outlet', ratingVA: 180.0, isDedicated: false);
      _addOrIncrementAppliance(name: 'Dedicated Single-point Shower Heater (3.5kW)', ratingVA: 3500.0, isDedicated: true);
      _addOrIncrementAppliance(name: 'Front-load Washing Machine Outlet', ratingVA: 1800.0, isDedicated: true);
    } else if (lower.contains('garage') || lower.contains('outdoor')) {
      _addOrIncrementAppliance(name: 'Weatherproof Heavy-Duty Outlets (WR/GFCI)', ratingVA: 360.0, isDedicated: false);
      _addOrIncrementAppliance(name: 'Perimeter Security Floodlight Line', ratingVA: 200.0, isDedicated: false);
      _addOrIncrementAppliance(name: 'Dedicated Water Pressure Pump Line', ratingVA: 1200.0, isDedicated: true);
    } else {
      // Living & Dining default
      _addOrIncrementAppliance(name: 'Living Room TV & Entertainment Outlet Pack', ratingVA: 360.0, isDedicated: false);
      _addOrIncrementAppliance(name: 'Dining Table & General Receptacles', ratingVA: 360.0, isDedicated: false);
      _addOrIncrementAppliance(name: 'Dedicated 2.5HP Inverter Split ACU', ratingVA: 2600.0, isDedicated: true);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('⚡ PEC Standard Package successfully applied to $spaceName!')),
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
      body: SafeArea(
        child: Column(
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
                    minimumSize: const Size(0, 36),
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
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(220, 44),
                                backgroundColor: BanaagTheme.primaryAmber,
                                foregroundColor: Colors.black,
                              ),
                              icon: const Icon(Icons.bolt, size: 16),
                              label: const Text('Apply PEC Standard Pack', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () => _applyPecStandardPack(_activeSpaceName),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.flash_on, size: 14, color: Colors.white70),
                              label: const Text('Quick Preset', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              onPressed: _showQuickPresetPicker,
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.add, size: 14, color: BanaagTheme.primaryAmber),
                              label: const Text('Custom Item', style: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 12)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: BanaagTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: item.isDedicatedCircuit
                                ? Colors.redAccent.withValues(alpha: 0.6)
                                : BanaagTheme.surfaceCardBorder,
                            width: item.isDedicatedCircuit ? 1.2 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 17,
                                  backgroundColor: item.isDedicatedCircuit
                                      ? Colors.redAccent.withValues(alpha: 0.15)
                                      : BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                                  foregroundColor: item.isDedicatedCircuit
                                      ? Colors.redAccent
                                      : BanaagTheme.primaryAmber,
                                  child: Icon(
                                    item.isDedicatedCircuit ? Icons.electrical_services : Icons.power,
                                    size: 19,
                                  ),
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
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Colors.white,
                                                height: 1.2,
                                              ),
                                              softWrap: true,
                                            ),
                                          ),
                                          if (item.isDedicatedCircuit) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                                              ),
                                              child: const Text(
                                                'DEDICATED',
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white10,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${item.ratingVA.toStringAsFixed(0)} VA (${(item.ratingVA / 230.0).toStringAsFixed(1)}A)',
                                              style: const TextStyle(
                                                color: BanaagTheme.primaryAmber,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Subtotal: ${(item.totalVA / 1000.0).toStringAsFixed(2)} kVA',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Divider(color: Colors.white10, height: 1),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Dami / Quantity:',
                                  style: TextStyle(fontSize: 12, color: BanaagTheme.textMuted),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 22),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _decrementAppliance(item),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.white12),
                                      ),
                                      child: Text(
                                        '${item.quantity}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: BanaagTheme.primaryAmber, size: 22),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _addOrIncrementAppliance(
                                        name: item.name,
                                        ratingVA: item.ratingVA,
                                        isDedicated: item.isDedicatedCircuit,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _deleteAppliance(item),
                                    ),
                                  ],
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
