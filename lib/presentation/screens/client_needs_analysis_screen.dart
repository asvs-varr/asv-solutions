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
  List<RoomSpace> get _spaces => widget.project.spaces;

  late String _activeSpaceName;

  // Standard Philippine Quick-Pick Preset Catalog
  final List<Map<String, dynamic>> _quickPresets = [
    {'name': '2.5HP Inverter Split ACU', 'va': 2600.0, 'dedicated': true, 'lighting': false, 'icon': Icons.ac_unit},
    {'name': '1.5HP Inverter Split ACU', 'va': 1650.0, 'dedicated': true, 'lighting': false, 'icon': Icons.ac_unit},
    {'name': 'Two-Door Inverter Refrigerator', 'va': 800.0, 'dedicated': true, 'lighting': false, 'icon': Icons.kitchen},
    {'name': 'Induction Cooktop (Double Burner)', 'va': 3500.0, 'dedicated': true, 'lighting': false, 'icon': Icons.soup_kitchen},
    {'name': 'Multipoint Water Heater (3.5kW)', 'va': 3500.0, 'dedicated': true, 'lighting': false, 'icon': Icons.hot_tub},
    {'name': 'Single-point Shower Heater', 'va': 2500.0, 'dedicated': true, 'lighting': false, 'icon': Icons.shower},
    {'name': 'Front-load Washing Machine', 'va': 1800.0, 'dedicated': true, 'lighting': false, 'icon': Icons.local_laundry_service},
    {'name': 'Microwave & Oven Toaster', 'va': 1800.0, 'dedicated': false, 'lighting': false, 'icon': Icons.microwave},
    {'name': '65" Smart 4K TV & Audio Rack', 'va': 350.0, 'dedicated': false, 'lighting': false, 'icon': Icons.tv},
    {'name': 'General Convenience Outlet (Duplex)', 'va': 180.0, 'dedicated': false, 'lighting': false, 'icon': Icons.power},
    {'name': 'Workstation PC / Desktop', 'va': 450.0, 'dedicated': false, 'lighting': false, 'icon': Icons.computer},
    {'name': 'Ceiling Fan with Drop Light', 'va': 120.0, 'dedicated': false, 'lighting': true, 'icon': Icons.mode_fan_off_outlined},
  ];

  @override
  void initState() {
    super.initState();
    if (_spaces.isEmpty) {
      _spaces.addAll([
        RoomSpace(id: 'sp-1', name: 'Living & Dining', areaSqm: 24.0, ceilingHeight: 2.7),
        RoomSpace(id: 'sp-2', name: 'Kitchen', areaSqm: 14.0, ceilingHeight: 2.7),
        RoomSpace(id: 'sp-3', name: 'Master Bedroom', areaSqm: 18.0, ceilingHeight: 2.7),
        RoomSpace(id: 'sp-4', name: 'Bath & Laundry', areaSqm: 8.0, ceilingHeight: 2.6),
      ]);
      ProjectRepository.instance.updateProject(widget.project);
    }
    _activeSpaceName = _spaces.first.name;
  }

  RoomSpace get _currentSpace => _spaces.firstWhere(
        (s) => s.name == _activeSpaceName,
        orElse: () => _spaces.isNotEmpty
            ? _spaces.first
            : RoomSpace(id: 'sp-def', name: 'General Space', areaSqm: 16.0, ceilingHeight: 2.7),
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
    bool isLighting = false,
    int? circuitNumber,
  }) {
    setState(() {
      // Determine PEC auto-assigned circuit number if not specified
      final int assignedCircuit = circuitNumber ??
          (isLighting
              ? 1
              : (isDedicated
                  ? _getNextDedicatedCircuitNumber()
                  : 2));

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
          isLighting: isLighting,
          circuitNumber: assignedCircuit,
        ));
      }
      ProjectRepository.instance.updateProject(widget.project);
    });
  }

  int _getNextDedicatedCircuitNumber() {
    final dedicatedItems = widget.project.applianceLoads.where((a) => a.isDedicatedCircuit).toList();
    if (dedicatedItems.isEmpty) return 3;
    final maxCkt = dedicatedItems.map((a) => a.circuitNumber).fold(2, (max, c) => c > max ? c : max);
    return maxCkt + 1;
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
    // Smart Appliance Catalog with standard wattage variants & system-decided default PF
    final List<Map<String, dynamic>> applianceCatalog = [
      {
        'category': 'HVAC & Cooling',
        'name': 'Split-Type Air Conditioner (ACU)',
        'defaultPF': 0.85, // Inverter standard
        'isLighting': false,
        'wattagePresets': [
          {'label': '1.0 HP Inverter (850W)', 'watts': 850, 'pf': 0.85},
          {'label': '1.5 HP Inverter (1200W)', 'watts': 1200, 'pf': 0.85},
          {'label': '2.0 HP Inverter (1600W)', 'watts': 1600, 'pf': 0.85},
          {'label': '2.5 HP Inverter (2000W)', 'watts': 2000, 'pf': 0.85},
          {'label': '1.5 HP Non-Inverter / Conventional (1400W)', 'watts': 1400, 'pf': 0.78},
        ],
      },
      {
        'category': 'HVAC & Cooling',
        'name': 'Window-Type Aircon',
        'defaultPF': 0.80,
        'isLighting': false,
        'wattagePresets': [
          {'label': '0.5 HP Window (450W)', 'watts': 450, 'pf': 0.80},
          {'label': '0.75 HP Window (650W)', 'watts': 650, 'pf': 0.80},
          {'label': '1.0 HP Window (900W)', 'watts': 900, 'pf': 0.80},
          {'label': '1.5 HP Inverter Window (1250W)', 'watts': 1250, 'pf': 0.85},
        ],
      },
      {
        'category': 'Kitchen & Heating',
        'name': 'Induction Cooktop',
        'defaultPF': 0.95,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Single Burner Portable (1800W)', 'watts': 1800, 'pf': 0.95},
          {'label': 'Double Burner Built-in (3500W)', 'watts': 3500, 'pf': 0.95},
          {'label': 'Heavy 3-Zone Cooktop (5500W)', 'watts': 5500, 'pf': 0.98},
        ],
      },
      {
        'category': 'Kitchen & Heating',
        'name': 'Refrigerator / Freezer',
        'defaultPF': 0.85,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Personal / Compact 1-Door (90W)', 'watts': 90, 'pf': 0.80},
          {'label': '2-Door Inverter (150W)', 'watts': 150, 'pf': 0.88},
          {'label': 'French Door / Side-by-Side Inverter (250W)', 'watts': 250, 'pf': 0.90},
          {'label': 'Chest Freezer Commercial (350W)', 'watts': 350, 'pf': 0.78},
        ],
      },
      {
        'category': 'Water & Bath',
        'name': 'Shower Water Heater',
        'defaultPF': 1.0, // Pure resistive heating
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Single-Point Instant Heater (3500W)', 'watts': 3500, 'pf': 1.0},
          {'label': 'Single-Point Compact (2500W)', 'watts': 2500, 'pf': 1.0},
          {'label': 'Multipoint Storage Heater (4500W)', 'watts': 4500, 'pf': 1.0},
        ],
      },
      {
        'category': 'Laundry & Utility',
        'name': 'Washing Machine & Dryer',
        'defaultPF': 0.80,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Top-Load Inverter Washer (400W)', 'watts': 400, 'pf': 0.85},
          {'label': 'Front-Load Washer (1800W with heater)', 'watts': 1800, 'pf': 0.90},
          {'label': 'Electric Heat Pump Clothes Dryer (1200W)', 'watts': 1200, 'pf': 0.88},
          {'label': 'Booster / Pressure Water Pump (750W)', 'watts': 750, 'pf': 0.75},
        ],
      },
      {
        'category': 'Lighting & Ambience',
        'name': 'Luminaires & LED Fixtures',
        'defaultPF': 0.85,
        'isLighting': true,
        'wattagePresets': [
          {'label': 'LED Downlight / Slim Panel (12W)', 'watts': 12, 'pf': 0.85},
          {'label': 'High-Output LED Downlight (18W)', 'watts': 18, 'pf': 0.88},
          {'label': 'Ceiling Fan with Integrated Light (75W)', 'watts': 75, 'pf': 0.80},
          {'label': 'Outdoor Security Floodlight (50W)', 'watts': 50, 'pf': 0.90},
        ],
      },
      {
        'category': 'General & Entertainment',
        'name': 'General Convenience Outlets / TV',
        'defaultPF': 0.90,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'PEC Standard Duplex Receptacle (180VA)', 'watts': 180, 'pf': 1.0},
          {'label': 'Smart 4K TV & Soundbar Rack (250W)', 'watts': 250, 'pf': 0.90},
          {'label': 'Gaming PC / Workstation (500W)', 'watts': 500, 'pf': 0.92},
          {'label': 'Microwave & Oven Toaster (1200W)', 'watts': 1200, 'pf': 0.95},
        ],
      },
      {
        'category': 'Custom',
        'name': 'Custom User-Defined Appliance',
        'defaultPF': 0.85,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Manual Input / Custom', 'watts': 1000, 'pf': 0.85},
        ],
      },
    ];

    String selectedApplianceName = applianceCatalog.first['name'];
    Map<String, dynamic> selectedCatalogItem = applianceCatalog.first;
    List<Map<String, dynamic>> currentWattagePresets = List<Map<String, dynamic>>.from(selectedCatalogItem['wattagePresets']);
    String selectedPresetLabel = currentWattagePresets.first['label'];

    final nameController = TextEditingController(text: selectedCatalogItem['name']);
    final wattsController = TextEditingController(text: currentWattagePresets.first['watts'].toString());
    final vaController = TextEditingController(
      text: ((currentWattagePresets.first['watts'] as int) / (currentWattagePresets.first['pf'] as double)).toStringAsFixed(0),
    );

    double powerFactor = (currentWattagePresets.first['pf'] as num).toDouble();
    String activeLoadType = 'Inverter';
    bool isDedicated = false;
    bool isLighting = selectedCatalogItem['isLighting'] ?? false;
    bool isUpdatingFromWatts = false;
    bool isUpdatingFromVA = false;

    // Power factor preset definitions for quick override
    final Map<String, double> pfPresets = {
      'Resistive (1.0)': 1.0,
      'High-Eff Inverter (0.90)': 0.90,
      'Standard Inverter (0.85)': 0.85,
      'Motor/Conventional (0.80)': 0.80,
      'Heavy Inductive (0.75)': 0.75,
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          void updateDedicatedStatus(double calculatedVA, String loadType) {
            if (calculatedVA >= 1500.0 ||
                loadType.toLowerCase().contains('motor') ||
                loadType.toLowerCase().contains('acu') ||
                selectedApplianceName.toLowerCase().contains('heater') ||
                selectedApplianceName.toLowerCase().contains('aircon') ||
                selectedApplianceName.toLowerCase().contains('induction')) {
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
                  // 1. SMART APPLIANCE NAME DROPDOWN
                  DropdownButtonFormField<String>(
                    initialValue: selectedApplianceName,
                    dropdownColor: BanaagTheme.surfaceCard,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Appliance Type',
                      labelStyle: TextStyle(color: BanaagTheme.primaryAmber),
                      prefixIcon: Icon(Icons.category_outlined, color: BanaagTheme.primaryAmber, size: 20),
                    ),
                    items: applianceCatalog.map((item) {
                      return DropdownMenuItem<String>(
                        value: item['name'] as String,
                        child: Text(
                          '${item['name']} (${item['category']})',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedApplianceName = val;
                          selectedCatalogItem = applianceCatalog.firstWhere((i) => i['name'] == val);
                          currentWattagePresets = List<Map<String, dynamic>>.from(selectedCatalogItem['wattagePresets']);
                          selectedPresetLabel = currentWattagePresets.first['label'];
                          isLighting = selectedCatalogItem['isLighting'] ?? false;

                          if (val != 'Custom User-Defined Appliance') {
                            nameController.text = val;
                          }

                          // Auto-apply system decided default PF & Wattage
                          final preset = currentWattagePresets.first;
                          powerFactor = (preset['pf'] as num).toDouble();
                          wattsController.text = preset['watts'].toString();
                          final double calcVA = (preset['watts'] as num) / powerFactor;
                          vaController.text = calcVA.toStringAsFixed(0);
                          updateDedicatedStatus(calcVA, val);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  // Editable Name Field (Auto-filled, but free to modify like brand or model)
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Specific Appliance Name / Label',
                      hintText: 'e.g. Carrier 1.5HP Inverter ACU (Living)',
                      labelStyle: TextStyle(color: BanaagTheme.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. WATTAGE & VARIANT PRESETS DROPDOWN
                  DropdownButtonFormField<String>(
                    initialValue: currentWattagePresets.any((p) => p['label'] == selectedPresetLabel) ? selectedPresetLabel : null,
                    dropdownColor: BanaagTheme.surfaceCard,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '1-Tap Wattage & Variant Preset',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.flash_on, color: BanaagTheme.primaryAmber, size: 20),
                    ),
                    items: currentWattagePresets.map((preset) {
                      return DropdownMenuItem<String>(
                        value: preset['label'] as String,
                        child: Text(
                          '${preset['label']} • [System PF: ${(preset['pf'] as num).toStringAsFixed(2)}]',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedPresetLabel = val;
                          final match = currentWattagePresets.firstWhere((p) => p['label'] == val);
                          powerFactor = (match['pf'] as num).toDouble();
                          wattsController.text = match['watts'].toString();
                          final double calcVA = (match['watts'] as num) / powerFactor;
                          vaController.text = calcVA.toStringAsFixed(0);
                          updateDedicatedStatus(calcVA, selectedApplianceName);
                        });
                      }
                    },
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
                    _addOrIncrementAppliance(
                      name: name,
                      ratingVA: va,
                      isDedicated: isDedicated,
                      isLighting: isLighting,
                    );
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

    // 1. Add Recommended Smart Lighting (Assigned to Ckt #1)
    _addOrIncrementAppliance(
      name: '${lighting.recommendedWattagePerFixture}W LED Downlight ($spaceName)',
      ratingVA: 15.0 * lighting.fixtureCount,
      isDedicated: false,
      isLighting: true,
      circuitNumber: 1,
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
                  ProjectRepository.instance.updateProject(widget.project);
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✨ Space "$name" created and saved!')),
                );
              }
            },
            child: const Text('Create Space'),
          ),
        ],
      ),
    );
  }

  void _promptEditCustomSpace(RoomSpace space) {
    final nameController = TextEditingController(text: space.name);
    final areaController = TextEditingController(text: space.areaSqm.toStringAsFixed(1));
    final heightController = TextEditingController(text: space.ceilingHeight.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BanaagTheme.surfaceCard,
        title: Row(
          children: [
            const Icon(Icons.edit_note, color: BanaagTheme.primaryAmber),
            const SizedBox(width: 8),
            Expanded(child: Text('Modify Space: ${space.name}', style: const TextStyle(fontSize: 16))),
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
            const SizedBox(height: 16),
            if (_spaces.length > 1)
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: BanaagTheme.alertRed),
                  icon: const Icon(Icons.delete_forever, size: 18),
                  label: const Text('Delete this Space', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () {
                    final oldName = space.name;
                    setState(() {
                      _spaces.removeWhere((s) => s.id == space.id);
                      widget.project.applianceLoads.removeWhere((a) => a.roomCategory == oldName);
                      _activeSpaceName = _spaces.first.name;
                      ProjectRepository.instance.updateProject(widget.project);
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('🗑️ Space "$oldName" and its loads were deleted.')),
                    );
                  },
                ),
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
              minimumSize: const Size(120, 42),
              backgroundColor: BanaagTheme.primaryAmber,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final newName = nameController.text.trim();
              final area = double.tryParse(areaController.text.trim()) ?? space.areaSqm;
              final height = double.tryParse(heightController.text.trim()) ?? space.ceilingHeight;
              if (newName.isNotEmpty) {
                final oldName = space.name;
                setState(() {
                  final idx = _spaces.indexWhere((s) => s.id == space.id);
                  if (idx != -1) {
                    _spaces[idx] = RoomSpace(
                      id: space.id,
                      name: newName,
                      areaSqm: area,
                      ceilingHeight: height,
                    );
                  }
                  // Update appliances tied to the old room name
                  if (oldName != newName) {
                    for (var app in widget.project.applianceLoads.where((a) => a.roomCategory == oldName)) {
                      final itemIdx = widget.project.applianceLoads.indexOf(app);
                      widget.project.applianceLoads[itemIdx] = ApplianceItem(
                        id: app.id,
                        name: app.name,
                        roomCategory: newName,
                        ratingVA: app.ratingVA,
                        quantity: app.quantity,
                        isDedicatedCircuit: app.isDedicatedCircuit,
                        isLighting: app.isLighting,
                        circuitNumber: app.circuitNumber,
                      );
                    }
                    _activeSpaceName = newName;
                  }
                  ProjectRepository.instance.updateProject(widget.project);
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ Space "$newName" (${area.toStringAsFixed(0)}m²) details updated!')),
                );
              }
            },
            child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        isLighting: preset['lighting'] ?? false,
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
                  child: InkWell(
                    onLongPress: () => _promptEditCustomSpace(space),
                    child: ChoiceChip(
                      avatar: isSelected
                          ? const Icon(Icons.edit, size: 14, color: Colors.black)
                          : null,
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
                        if (val) {
                          if (isSelected) {
                            // Tapping an already selected space opens edit
                            _promptEditCustomSpace(space);
                          } else {
                            setState(() => _activeSpaceName = space.name);
                          }
                        }
                      },
                    ),
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

          // High-Density Unified Sectioned View (Lighting vs Power & Wiring)
          Expanded(
            child: currentSpaceItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox_outlined, size: 48, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text('Walang nakalistang karga sa $_activeSpaceName.', style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 13)),
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
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    children: [
                      // SECTION 1: LIGHTING FIXTURES
                      _buildSectionHeader(
                        title: '💡 Lighting Fixtures',
                        badge: 'Ckt #1',
                        badgeColor: BanaagTheme.primaryAmber,
                        count: currentSpaceItems.where((a) => a.isLighting || a.name.toLowerCase().contains('light') || a.name.toLowerCase().contains('led')).length,
                        onAdd: () {
                          _addOrIncrementAppliance(
                            name: '${lightingRec.recommendedWattagePerFixture}W LED Downlight ($_activeSpaceName)',
                            ratingVA: 15.0,
                            isDedicated: false,
                            isLighting: true,
                            circuitNumber: 1,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('💡 Added LED fixture to $_activeSpaceName!')),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      ...currentSpaceItems
                          .where((a) => a.isLighting || a.name.toLowerCase().contains('light') || a.name.toLowerCase().contains('led'))
                          .map((item) => _buildApplianceCard(item)),
                      if (currentSpaceItems.where((a) => a.isLighting || a.name.toLowerCase().contains('light') || a.name.toLowerCase().contains('led')).isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lightbulb_outline, size: 18, color: BanaagTheme.textMuted),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text('Walang nakatalagang ilaw. I-tap ang "+ Add Light" para magdagdag.',
                                    style: TextStyle(color: BanaagTheme.textMuted, fontSize: 11)),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // SECTION 2: POWER & CONVENIENCE OUTLETS (WIRING)
                      _buildSectionHeader(
                        title: '🔌 Power, Outlets & Appliances',
                        badge: 'Ckt #2+',
                        badgeColor: Colors.blueAccent,
                        count: currentSpaceItems.where((a) => !a.isLighting && !a.name.toLowerCase().contains('light') && !a.name.toLowerCase().contains('led')).length,
                        onAdd: _promptAddCustomAppliance,
                      ),
                      const SizedBox(height: 8),
                      ...currentSpaceItems
                          .where((a) => !a.isLighting && !a.name.toLowerCase().contains('light') && !a.name.toLowerCase().contains('led'))
                          .map((item) => _buildApplianceCard(item)),
                      if (currentSpaceItems.where((a) => !a.isLighting && !a.name.toLowerCase().contains('light') && !a.name.toLowerCase().contains('led')).isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.power_outlined, size: 18, color: BanaagTheme.textMuted),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text('Walang outlets/appliances. Mag-add gamit ang Quick Presets o Custom Item.',
                                    style: TextStyle(color: BanaagTheme.textMuted, fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
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

  Widget _buildSectionHeader({
    required String title,
    required String badge,
    required Color badgeColor,
    required int count,
    required VoidCallback onAdd,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                '$badge ($count)',
                style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            ),
          ],
        ),
        TextButton.icon(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            visualDensity: VisualDensity.compact,
            foregroundColor: BanaagTheme.primaryAmber,
          ),
          icon: const Icon(Icons.add, size: 14),
          label: const Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          onPressed: onAdd,
        ),
      ],
    );
  }

  Widget _buildApplianceCard(ApplianceItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
                    : (item.isLighting
                        ? BanaagTheme.primaryAmber.withValues(alpha: 0.15)
                        : Colors.blueAccent.withValues(alpha: 0.15)),
                foregroundColor: item.isDedicatedCircuit
                    ? Colors.redAccent
                    : (item.isLighting ? BanaagTheme.primaryAmber : Colors.blueAccent),
                child: Icon(
                  item.isDedicatedCircuit
                      ? Icons.electrical_services
                      : (item.isLighting ? Icons.lightbulb_outline : Icons.power),
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
                        // Interactive Circuit Number Chip
                        InkWell(
                          onTap: () => _promptChangeCircuitNumber(item),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tune, size: 10, color: BanaagTheme.primaryAmber),
                                const SizedBox(width: 4),
                                Text(
                                  'Ckt #${item.circuitNumber}',
                                  style: const TextStyle(
                                    color: BanaagTheme.primaryAmber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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
                      isLighting: item.isLighting,
                      circuitNumber: item.circuitNumber,
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
  }

  void _promptChangeCircuitNumber(ApplianceItem item) {
    int selectedCircuit = item.circuitNumber;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: BanaagTheme.surfaceCard,
          title: Row(
            children: [
              const Icon(Icons.linear_scale, color: BanaagTheme.primaryAmber),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Assign Circuit: ${item.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pumili ng Panelboard Branch Circuit Number para sa kargang ito:',
                  style: TextStyle(color: BanaagTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(12, (index) {
                  final ckt = index + 1;
                  final isSelected = ckt == selectedCircuit;
                  return ChoiceChip(
                    label: Text('Ckt #$ckt'),
                    selected: isSelected,
                    selectedColor: BanaagTheme.primaryAmber,
                    backgroundColor: Colors.white10,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) setDialogState(() => selectedCircuit = ckt);
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),
              Text(
                selectedCircuit == 1
                    ? '💡 Ckt #1: General Lighting Circuit (PEC standard 15A breaker, 2.0 mm² THHN).'
                    : (selectedCircuit == 2
                        ? '🔌 Ckt #2: Small Appliance Branch Circuit (PEC standard 20A breaker, 3.5 mm² THHN).'
                        : '⚡ Ckt #$selectedCircuit: Dedicated / Heavy Load Branch Circuit.'),
                style: const TextStyle(fontSize: 11, color: BanaagTheme.primaryAmber, fontStyle: FontStyle.italic),
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
                setState(() {
                  item.circuitNumber = selectedCircuit;
                  ProjectRepository.instance.updateProject(widget.project);
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('⚡ ${item.name} assigned to Circuit #$selectedCircuit!')),
                );
              },
              child: const Text('Save Circuit'),
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
