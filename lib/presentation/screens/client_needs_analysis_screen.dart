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
    {'name': 'Electric Stand Fan (16")', 'va': 75.0, 'dedicated': false, 'lighting': false, 'icon': Icons.toys_outlined},
    {'name': 'Wall-Mounted Orbit Fan', 'va': 90.0, 'dedicated': false, 'lighting': false, 'icon': Icons.rotate_right},
    {'name': 'Standard Ceiling Fan (52" 3-Blade)', 'va': 85.0, 'dedicated': false, 'lighting': false, 'icon': Icons.mode_fan_off_outlined},
    {'name': 'DC Inverter Smart Ceiling Fan', 'va': 40.0, 'dedicated': false, 'lighting': false, 'icon': Icons.mode_fan_off_outlined},
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
    // Comprehensive Philippine Electrical Load Catalog categorized cleanly
    final List<Map<String, dynamic>> applianceCatalog = [
      // 1. HVAC & COOLING
      {
        'category': '❄️ HVAC & Cooling',
        'name': 'Split-Type Aircon (Inverter)',
        'defaultPF': 0.85,
        'isLighting': false,
        'wattagePresets': [
          {'label': '1.0 HP Inverter (850W)', 'watts': 850, 'pf': 0.85},
          {'label': '1.5 HP Inverter (1200W)', 'watts': 1200, 'pf': 0.85},
          {'label': '2.0 HP Inverter (1600W)', 'watts': 1600, 'pf': 0.85},
          {'label': '2.5 HP Inverter (2000W)', 'watts': 2000, 'pf': 0.85},
          {'label': '3.0 HP Inverter (2500W)', 'watts': 2500, 'pf': 0.85},
        ],
      },
      {
        'category': '❄️ HVAC & Cooling',
        'name': 'Split-Type Aircon (Conventional / Non-Inverter)',
        'defaultPF': 0.78,
        'isLighting': false,
        'wattagePresets': [
          {'label': '1.0 HP Conventional (1000W)', 'watts': 1000, 'pf': 0.78},
          {'label': '1.5 HP Conventional (1450W)', 'watts': 1450, 'pf': 0.78},
          {'label': '2.0 HP Conventional (1950W)', 'watts': 1950, 'pf': 0.78},
          {'label': '2.5 HP Conventional (2500W)', 'watts': 2500, 'pf': 0.78},
        ],
      },
      {
        'category': '❄️ HVAC & Cooling',
        'name': 'Window-Type Aircon (Inverter)',
        'defaultPF': 0.85,
        'isLighting': false,
        'wattagePresets': [
          {'label': '0.75 HP Inverter Window (650W)', 'watts': 650, 'pf': 0.85},
          {'label': '1.0 HP Inverter Window (900W)', 'watts': 900, 'pf': 0.85},
          {'label': '1.5 HP Inverter Window (1250W)', 'watts': 1250, 'pf': 0.85},
        ],
      },
      {
        'category': '❄️ HVAC & Cooling',
        'name': 'Window-Type Aircon (Conventional)',
        'defaultPF': 0.80,
        'isLighting': false,
        'wattagePresets': [
          {'label': '0.5 HP Compact Window (450W)', 'watts': 450, 'pf': 0.80},
          {'label': '0.75 HP Window (720W)', 'watts': 720, 'pf': 0.80},
          {'label': '1.0 HP Window (1050W)', 'watts': 1050, 'pf': 0.80},
          {'label': '1.5 HP Window (1500W)', 'watts': 1500, 'pf': 0.80},
        ],
      },
      {
        'category': '❄️ HVAC & Cooling',
        'name': 'Floor Mounted / Cassette Commercial ACU',
        'defaultPF': 0.85,
        'isLighting': false,
        'wattagePresets': [
          {'label': '3.0 Ton / 4.0 HP Commercial (3500W)', 'watts': 3500, 'pf': 0.85},
          {'label': '5.0 Ton / 6.0 HP Heavy Commercial (5200W)', 'watts': 5200, 'pf': 0.88},
        ],
      },
      {
        'category': '❄️ HVAC & Cooling',
        'name': 'Electric Fans & Air Circulators',
        'defaultPF': 0.85,
        'isLighting': false,
        'wattagePresets': [
          {'label': '12" Desk / Table Fan (45W)', 'watts': 45, 'pf': 0.85},
          {'label': '16" Standard Stand Fan (65W)', 'watts': 65, 'pf': 0.85},
          {'label': '18" Heavy-Duty Stand Fan (90W)', 'watts': 90, 'pf': 0.85},
          {'label': '16" Wall-Mounted Orbit Fan (75W)', 'watts': 75, 'pf': 0.85},
          {'label': '48" DC Inverter Smart Ceiling Fan (35W)', 'watts': 35, 'pf': 0.90},
          {'label': '52" Standard 3-Blade Ceiling Fan (75W)', 'watts': 75, 'pf': 0.85},
          {'label': '56" Heavy-Duty 5-Blade Ceiling Fan (90W)', 'watts': 90, 'pf': 0.85},
          {'label': 'Ceiling Fan with Integrated LED Light (100W)', 'watts': 100, 'pf': 0.88},
          {'label': '20" High-Velocity Floor Blower (150W)', 'watts': 150, 'pf': 0.80},
          {'label': '24" Industrial Drum / Warehouse Fan (220W)', 'watts': 220, 'pf': 0.80},
          {'label': 'Commercial High-Volume Low-Speed (HVLS) Fan (450W)', 'watts': 450, 'pf': 0.88},
        ],
      },
      {
        'category': '❄️ HVAC & Cooling',
        'name': 'Ventilation / Exhaust Fan',
        'defaultPF': 0.80,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Ceiling Exhaust 8-inch (35W)', 'watts': 35, 'pf': 0.80},
          {'label': 'Wall Mounted Shutter Exhaust (50W)', 'watts': 50, 'pf': 0.80},
          {'label': 'Heavy Kitchen Inline Blower (150W)', 'watts': 150, 'pf': 0.78},
        ],
      },

      // 2. KITCHEN & COOKING
      {
        'category': '🍳 Kitchen & Cooking',
        'name': 'Induction Cooktop',
        'defaultPF': 0.95,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Single Burner Portable (1800W)', 'watts': 1800, 'pf': 0.95},
          {'label': 'Single Burner Turbo (2100W)', 'watts': 2100, 'pf': 0.95},
          {'label': 'Double Burner Built-in (3500W)', 'watts': 3500, 'pf': 0.95},
          {'label': '4-Zone Induction Range (7000W)', 'watts': 7000, 'pf': 0.98},
        ],
      },
      {
        'category': '🍳 Kitchen & Cooking',
        'name': 'Electric Range / Built-in Oven',
        'defaultPF': 1.0,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Standard Built-in Oven (2500W)', 'watts': 2500, 'pf': 1.0},
          {'label': 'Electric Free-Standing Range & Oven (4500W)', 'watts': 4500, 'pf': 1.0},
          {'label': 'Commercial Convection Oven (6000W)', 'watts': 6000, 'pf': 1.0},
        ],
      },
      {
        'category': '🍳 Kitchen & Cooking',
        'name': 'Microwave & Oven Toaster',
        'defaultPF': 0.92,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Standard Microwave 20L (800W)', 'watts': 800, 'pf': 0.92},
          {'label': 'Medium Inverter Microwave (1200W)', 'watts': 1200, 'pf': 0.95},
          {'label': 'Convection Microwave Grill (1500W)', 'watts': 1500, 'pf': 0.95},
          {'label': 'Pop-up Toaster / Sandwich Press (900W)', 'watts': 900, 'pf': 1.0},
        ],
      },
      {
        'category': '🍳 Kitchen & Cooking',
        'name': 'Air Fryer / Instant Pot',
        'defaultPF': 1.0,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Compact Air Fryer (1400W)', 'watts': 1400, 'pf': 1.0},
          {'label': 'XL Dual-Basket Air Fryer (1800W)', 'watts': 1800, 'pf': 1.0},
          {'label': 'Electric Pressure Cooker / Instant Pot (1000W)', 'watts': 1000, 'pf': 1.0},
        ],
      },
      {
        'category': '🍳 Kitchen & Cooking',
        'name': 'Refrigerator / Freezer',
        'defaultPF': 0.88,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Personal / Compact 1-Door (80W)', 'watts': 80, 'pf': 0.80},
          {'label': 'Two-Door Inverter (150W)', 'watts': 150, 'pf': 0.88},
          {'label': 'Two-Door Non-Inverter (220W)', 'watts': 220, 'pf': 0.78},
          {'label': 'Side-by-Side / French Door Inverter (280W)', 'watts': 280, 'pf': 0.90},
          {'label': 'Chest Freezer Commercial (350W)', 'watts': 350, 'pf': 0.78},
        ],
      },
      {
        'category': '🍳 Kitchen & Cooking',
        'name': 'Rice Cooker & Water Kettle',
        'defaultPF': 1.0,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Electric Rice Cooker 1.8L (700W)', 'watts': 700, 'pf': 1.0},
          {'label': 'Commercial Rice Cooker 5L (1500W)', 'watts': 1500, 'pf': 1.0},
          {'label': 'Electric Fast-Boil Kettle (1500W)', 'watts': 1500, 'pf': 1.0},
          {'label': 'Hot & Cold Water Dispenser (550W)', 'watts': 550, 'pf': 0.95},
        ],
      },
      {
        'category': '🍳 Kitchen & Cooking',
        'name': 'Range Hood & Dishwasher',
        'defaultPF': 0.85,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Kitchen Range Hood Telescopic (180W)', 'watts': 180, 'pf': 0.85},
          {'label': 'Commercial Island Chimney Hood (320W)', 'watts': 320, 'pf': 0.85},
          {'label': 'Built-in Dishwasher w/ Water Heater (1800W)', 'watts': 1800, 'pf': 0.95},
        ],
      },

      // 3. BATHROOM & WATER HEATING
      {
        'category': '🚿 Bathroom & Water Heating',
        'name': 'Shower Water Heater (Instant / Multipoint)',
        'defaultPF': 1.0,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Single-Point Instant Shower (3500W)', 'watts': 3500, 'pf': 1.0},
          {'label': 'Single-Point Eco (2500W)', 'watts': 2500, 'pf': 1.0},
          {'label': 'Multipoint Fast Heater (4500W)', 'watts': 4500, 'pf': 1.0},
          {'label': 'Multipoint Heavy Storage Tank (6000W)', 'watts': 6000, 'pf': 1.0},
        ],
      },
      {
        'category': '🚿 Bathroom & Water Heating',
        'name': 'Bathroom Convenience & Shaver Receptacle',
        'defaultPF': 1.0,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'GFCI Protected Vanity Outlet (180VA)', 'watts': 180, 'pf': 1.0},
          {'label': 'Hair Dryer / Hair Iron Load (1600W)', 'watts': 1600, 'pf': 1.0},
          {'label': 'Bidet Seat Heater (450W)', 'watts': 450, 'pf': 1.0},
        ],
      },

      // 4. LAUNDRY & UTILITY
      {
        'category': '🧺 Laundry & Utility',
        'name': 'Washing Machine',
        'defaultPF': 0.85,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Top-Load Inverter Washer (400W)', 'watts': 400, 'pf': 0.85},
          {'label': 'Twin-Tub Semi-Auto Washer (450W)', 'watts': 450, 'pf': 0.75},
          {'label': 'Front-Load Washer with Water Heater (1800W)', 'watts': 1800, 'pf': 0.92},
        ],
      },
      {
        'category': '🧺 Laundry & Utility',
        'name': 'Clothes Dryer & Press',
        'defaultPF': 0.95,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Heat Pump Dryer Inverter (1200W)', 'watts': 1200, 'pf': 0.88},
          {'label': 'Electric Tumble Dryer Resistive (2400W)', 'watts': 2400, 'pf': 1.0},
          {'label': 'Heavy Steam Ironing Station (1800W)', 'watts': 1800, 'pf': 1.0},
        ],
      },

      // 5. LIGHTING & FIXTURES
      {
        'category': '💡 Lighting & Fixtures',
        'name': 'Luminaires & LED Fixtures',
        'defaultPF': 0.88,
        'isLighting': true,
        'wattagePresets': [
          {'label': 'LED Downlight / Slim Panel (12W)', 'watts': 12, 'pf': 0.85},
          {'label': 'High-Output LED Downlight (18W)', 'watts': 18, 'pf': 0.88},
          {'label': 'Ceiling Fan with Integrated Light (75W)', 'watts': 75, 'pf': 0.80},
          {'label': 'Outdoor Security Floodlight (50W)', 'watts': 50, 'pf': 0.90},
          {'label': 'LED Strip / Accent Cove Lighting (60W)', 'watts': 60, 'pf': 0.90},
          {'label': 'Chandelier / Pendant Fixture (100W)', 'watts': 100, 'pf': 0.95},
        ],
      },

      // 6. PUMPS, MOTORS & HEAVY TOOLS
      {
        'category': '⚡ Pumps, Motors & Heavy Tools',
        'name': 'Water Pumps & Pressure Systems',
        'defaultPF': 0.75,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Automatic Constant Pressure Booster Pump (550W / 0.75HP)', 'watts': 550, 'pf': 0.75},
          {'label': 'Deep Well Jet Pump (750W / 1.0HP)', 'watts': 750, 'pf': 0.75},
          {'label': 'Submersible Deep Well Motor (1100W / 1.5HP)', 'watts': 1100, 'pf': 0.75},
          {'label': 'Swimming Pool Filtration Pump (1500W / 2.0HP)', 'watts': 1500, 'pf': 0.78},
        ],
      },
      {
        'category': '⚡ Pumps, Motors & Heavy Tools',
        'name': 'Gate Motors & Workshop Tools',
        'defaultPF': 0.78,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Automated Sliding Gate Motor (370W / 0.5HP)', 'watts': 370, 'pf': 0.78},
          {'label': 'Air Compressor Portable (1500W / 2.0HP)', 'watts': 1500, 'pf': 0.75},
          {'label': 'Workshop Table Saw / Cut-off (2000W)', 'watts': 2000, 'pf': 0.85},
          {'label': 'Inverter Arc Welder Outlet (3500W)', 'watts': 3500, 'pf': 0.88},
        ],
      },

      // 7. EV & RENEWABLE TECH
      {
        'category': '🚗 EV & Renewable Tech',
        'name': 'Electric Vehicle (EV) Charger',
        'defaultPF': 0.98,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Level 1 Portable Emergency Charger (16A / 3680W)', 'watts': 3680, 'pf': 0.98},
          {'label': 'Level 2 Fast Home Wallbox (32A / 7400W)', 'watts': 7400, 'pf': 0.99},
        ],
      },
      {
        'category': '🚗 EV & Renewable Tech',
        'name': 'Solar Inverter / Battery Storage Circuit',
        'defaultPF': 0.98,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Hybrid Solar Inverter Line (3.0 kW)', 'watts': 3000, 'pf': 0.98},
          {'label': 'Hybrid Solar Inverter Line (5.0 kW)', 'watts': 5000, 'pf': 0.98},
          {'label': 'Home UPS / Backup Battery Charger (1200W)', 'watts': 1200, 'pf': 0.95},
        ],
      },

      // 8. ENTERTAINMENT & TECH
      {
        'category': '📺 Entertainment & Tech',
        'name': 'Entertainment & Audio Hub',
        'defaultPF': 0.90,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Smart 4K TV & Soundbar Rack (250W)', 'watts': 250, 'pf': 0.90},
          {'label': 'Full Home Theater & AV Receiver (600W)', 'watts': 600, 'pf': 0.88},
          {'label': 'Desktop PC / Gaming Workstation (500W)', 'watts': 500, 'pf': 0.92},
          {'label': 'Server Rack / PoE Switch Hub (300W)', 'watts': 300, 'pf': 0.92},
        ],
      },
      {
        'category': '📺 Entertainment & Tech',
        'name': 'General Convenience Outlets',
        'defaultPF': 1.0,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'PEC Standard Duplex Receptacle (180VA)', 'watts': 180, 'pf': 1.0},
          {'label': 'Heavy-Duty Quad Receptacle Pack (360VA)', 'watts': 360, 'pf': 1.0},
          {'label': 'Weatherproof Outdoor WR Receptacle (180VA)', 'watts': 180, 'pf': 1.0},
        ],
      },

      // 9. CUSTOM APPLIANCE
      {
        'category': '⚙️ Custom / Manual Input',
        'name': 'Custom User-Defined Load',
        'defaultPF': 0.85,
        'isLighting': false,
        'wattagePresets': [
          {'label': 'Manual Input Load (1000W)', 'watts': 1000, 'pf': 0.85},
        ],
      },
    ];

    String selectedApplianceKey = '${applianceCatalog.first['category']}::${applianceCatalog.first['name']}';
    Map<String, dynamic> selectedCatalogItem = applianceCatalog.first;
    List<Map<String, dynamic>> currentWattagePresets = List<Map<String, dynamic>>.from(selectedCatalogItem['wattagePresets']);
    String selectedPresetLabel = currentWattagePresets.first['label'];

    final nameController = TextEditingController(text: selectedCatalogItem['name']);
    final wattsController = TextEditingController(text: currentWattagePresets.first['watts'].toString());
    final vaController = TextEditingController(
      text: ((currentWattagePresets.first['watts'] as int) / (currentWattagePresets.first['pf'] as double)).toStringAsFixed(0),
    );

    double powerFactor = (currentWattagePresets.first['pf'] as num).toDouble();
    bool isDedicated = false;
    bool isLighting = selectedCatalogItem['isLighting'] ?? false;
    bool isUpdatingFromWatts = false;
    bool isUpdatingFromVA = false;
    bool isAdvancedPfExpanded = false;

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
          void updateDedicatedStatus(double calculatedVA, String loadName) {
            final lower = loadName.toLowerCase();
            if (calculatedVA >= 1400.0 ||
                lower.contains('motor') ||
                lower.contains('acu') ||
                lower.contains('aircon') ||
                lower.contains('heater') ||
                lower.contains('induction') ||
                lower.contains('pump') ||
                lower.contains('charger') ||
                lower.contains('welder') ||
                lower.contains('dryer')) {
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
              updateDedicatedStatus(calculatedVA, selectedCatalogItem['name']);
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
              updateDedicatedStatus(v, selectedCatalogItem['name']);
            }
            isUpdatingFromVA = false;
            setDialogState(() {});
          }

          void applyPF(double newPF) {
            powerFactor = newPF;
            final double? w = double.tryParse(wattsController.text);
            if (w != null && powerFactor > 0) {
              final double calculatedVA = w / powerFactor;
              vaController.text = calculatedVA.toStringAsFixed(0);
              updateDedicatedStatus(calculatedVA, selectedCatalogItem['name']);
            }
            setDialogState(() {});
          }

          final double currentVA = double.tryParse(vaController.text) ?? 0.0;
          final double currentAmps = currentVA / 230.0;
          final double currentWatts = double.tryParse(wattsController.text) ?? (currentVA * powerFactor);

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
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SINGLE UNIFIED CATEGORY-GROUPED APPLIANCE DROPDOWN WITH SECTION HEADERS
                    DropdownButtonFormField<String>(
                      initialValue: selectedApplianceKey,
                      dropdownColor: const Color(0xFF1B2028),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Appliance',
                        labelStyle: TextStyle(color: BanaagTheme.primaryAmber, fontWeight: FontWeight.bold),
                        prefixIcon: Icon(Icons.electrical_services, color: BanaagTheme.primaryAmber, size: 20),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: () {
                        final List<DropdownMenuItem<String>> menuItems = [];
                        String? lastCategory;

                        for (final item in applianceCatalog) {
                          final currentCat = item['category'] as String;
                          // If new category, insert concise, styled non-selectable section header
                          if (currentCat != lastCategory) {
                            lastCategory = currentCat;
                            menuItems.add(
                              DropdownMenuItem<String>(
                                enabled: false,
                                value: 'HEADER::$currentCat',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Text(
                                        currentCat.toUpperCase(),
                                        style: const TextStyle(
                                          color: BanaagTheme.primaryAmber,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Divider(
                                          color: BanaagTheme.surfaceCardBorder,
                                          thickness: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          // Regular selectable clean item (no redundant category suffix)
                          final key = '${item['category']}::${item['name']}';
                          menuItems.add(
                            DropdownMenuItem<String>(
                              value: key,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Row(
                                  children: [
                                    const Text('• ', style: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 14)),
                                    Expanded(
                                      child: Text(
                                        item['name'] as String,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        return menuItems;
                      }(),
                      onChanged: (val) {
                        if (val != null && !val.startsWith('HEADER::')) {
                          setDialogState(() {
                            selectedApplianceKey = val;
                            selectedCatalogItem = applianceCatalog.firstWhere((i) => '${i['category']}::${i['name']}' == val);
                            currentWattagePresets = List<Map<String, dynamic>>.from(selectedCatalogItem['wattagePresets']);
                            selectedPresetLabel = currentWattagePresets.first['label'];
                            isLighting = selectedCatalogItem['isLighting'] ?? false;

                            if (!val.contains('Custom')) {
                              nameController.text = selectedCatalogItem['name'];
                            }

                            final preset = currentWattagePresets.first;
                            powerFactor = (preset['pf'] as num).toDouble();
                            wattsController.text = preset['watts'].toString();
                            final double calcVA = (preset['watts'] as num) / powerFactor;
                            vaController.text = calcVA.toStringAsFixed(0);
                            updateDedicatedStatus(calcVA, selectedCatalogItem['name']);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // Specific Label / Model Override (Optional)
                    TextField(
                      controller: nameController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Appliance Label / Specific Brand (Optional)',
                        hintText: 'e.g. Carrier 1.5HP Inverter or Panasonic Ref',
                        labelStyle: TextStyle(color: BanaagTheme.textMuted, fontSize: 12),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // WATTAGE & VARIANT PRESETS DROPDOWN
                    DropdownButtonFormField<String>(
                      key: ValueKey('preset-dropdown-$selectedApplianceKey'),
                      initialValue: currentWattagePresets.any((p) => p['label'] == selectedPresetLabel)
                          ? selectedPresetLabel
                          : currentWattagePresets.first['label'] as String,
                      dropdownColor: const Color(0xFF1B2028),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Wattage Variant Preset',
                        labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                        prefixIcon: Icon(Icons.flash_on, color: BanaagTheme.primaryAmber, size: 20),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: currentWattagePresets.map((preset) {
                        return DropdownMenuItem<String>(
                          value: preset['label'] as String,
                          child: Text(
                            preset['label'] as String,
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
                            updateDedicatedStatus(calcVA, selectedCatalogItem['name']);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // STREAMLINED HIGH-CONTRAST POWER SUMMARY PILL (Overflow Safe)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('REAL POWER', style: TextStyle(color: BanaagTheme.textMuted, fontSize: 8, letterSpacing: 0.5)),
                                const SizedBox(height: 2),
                                Text('${currentWatts.toStringAsFixed(0)} W',
                                    style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 26, color: Colors.white12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('APPARENT LOAD', style: TextStyle(color: BanaagTheme.textMuted, fontSize: 8, letterSpacing: 0.5)),
                                const SizedBox(height: 2),
                                Text('${currentVA.toStringAsFixed(0)} VA',
                                    style: const TextStyle(color: BanaagTheme.primaryAmber, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 26, color: Colors.white12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('CURRENT (230V)', style: TextStyle(color: BanaagTheme.textMuted, fontSize: 8, letterSpacing: 0.5)),
                                const SizedBox(height: 2),
                                Text('${currentAmps.toStringAsFixed(1)} A',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // MANUAL WATTS & VA EDITABLE FIELDS (Side-by-Side)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: wattsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              labelText: 'Watts (P)',
                              suffixText: 'W',
                              labelStyle: TextStyle(color: Colors.cyanAccent, fontSize: 11),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: syncFromWatts,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: vaController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              labelText: 'Apparent (VA)',
                              suffixText: 'VA',
                              labelStyle: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 11),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: syncFromVA,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // COLLAPSIBLE ADVANCED POWER FACTOR (PF) ACCORDION (Overflow Safe)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setDialogState(() {
                          isAdvancedPfExpanded = !isAdvancedPfExpanded;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.tune, size: 14, color: BanaagTheme.primaryAmber),
                            const SizedBox(width: 6),
                            const Text('Power Factor: ', style: TextStyle(fontSize: 11, color: Colors.white70)),
                            Text(
                              powerFactor.toStringAsFixed(2),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: BanaagTheme.primaryAmber),
                            ),
                            const Spacer(),
                            Text(
                              isAdvancedPfExpanded ? 'Hide' : 'Fine-tune PF',
                              style: const TextStyle(fontSize: 11, color: BanaagTheme.textMuted),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isAdvancedPfExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              size: 16,
                              color: BanaagTheme.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // EXPANDABLE PF CONTROLS (Only visible when toggled)
                    if (isAdvancedPfExpanded) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Quick PF Presets (PEC Standards):', style: TextStyle(color: BanaagTheme.textMuted, fontSize: 10)),
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
                                    if (val) applyPF(entry.value);
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 6),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                thumbColor: BanaagTheme.primaryAmber,
                                activeTrackColor: BanaagTheme.primaryAmber,
                                inactiveTrackColor: Colors.white24,
                                trackHeight: 2,
                              ),
                              child: Slider(
                                value: powerFactor,
                                min: 0.50,
                                max: 1.0,
                                divisions: 50,
                                label: powerFactor.toStringAsFixed(2),
                                onChanged: (val) => applyPF(val),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),

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
                            ? 'Automatic flagged: >1.4kVA o Heavy Motor/Heater load. Nangangailangan ng sariling homerun wire at breaker.'
                            : 'I-check kung kailangan ng sariling homerun wire at breaker sa panelboard.',
                        style: TextStyle(fontSize: 10, color: isDedicated ? Colors.redAccent.shade100 : BanaagTheme.textMuted),
                      ),
                      value: isDedicated,
                      onChanged: (val) => setDialogState(() => isDedicated = val ?? false),
                    ),
                  ],
                ),
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

  void _promptPecStandardPackPreview(String spaceName) {
    final lower = spaceName.toLowerCase();
    final lighting = LightingEngine.calculate(
      roomType: _mapSpaceToRoomType(spaceName),
      areaSqm: _currentSpace.areaSqm,
      ceilingHeightMeters: _currentSpace.ceilingHeight,
    );

    // Prepare Pack Items with their respective PEC Articles & Justifications
    final List<Map<String, dynamic>> previewItems = [];

    // 1. Lighting rule
    previewItems.add({
      'name': '${lighting.recommendedWattagePerFixture}W LED Downlights (${lighting.fixtureCount} pcs)',
      'va': 15.0 * lighting.fixtureCount,
      'isLighting': true,
      'isDedicated': false,
      'citation': 'PEC 2017 Art 2.10.3.2',
      'rule': 'Lighting Load Minimum Standard (${lighting.roomType.recommendedLux} Lux for $spaceName)',
      'icon': Icons.lightbulb_outline,
    });

    if (lower.contains('kitchen')) {
      previewItems.addAll([
        {
          'name': 'Kitchen Counter Duplex Receptacles (Small Appliance)',
          'va': 360.0,
          'isLighting': false,
          'isDedicated': false,
          'citation': 'PEC 2017 Art 2.10.1.11(C)(1) & Art 2.10.3.3',
          'rule': 'Minimum dalawang 20A Small Appliance Branch Circuits sa kusina',
          'icon': Icons.power,
        },
        {
          'name': 'GFCI Protected Countertop Receptacles',
          'va': 180.0,
          'isLighting': false,
          'isDedicated': false,
          'citation': 'PEC 2017 Art 2.10.1.8(A)(6)',
          'rule': 'Mandatory GFCI protection sa lahat ng receptacles sa loob ng 1.8m mula sa lababo/sink',
          'icon': Icons.security,
        },
        {
          'name': 'Dedicated Inverter Refrigerator Outlet',
          'va': 800.0,
          'isLighting': false,
          'isDedicated': true,
          'citation': 'PEC 2017 Art 2.10.2.5',
          'rule': 'Dedicated branch circuit para sa continuous refrigeration load',
          'icon': Icons.kitchen,
        },
        {
          'name': 'Induction / Range Hood Circuit Line',
          'va': 3500.0,
          'isLighting': false,
          'isDedicated': true,
          'citation': 'PEC 2017 Art 4.22.2.1',
          'rule': 'Individual branch circuit para sa cooking appliances na lumalagpas sa 20A',
          'icon': Icons.soup_kitchen,
        },
      ]);
    } else if (lower.contains('bed')) {
      previewItems.addAll([
        {
          'name': 'Bedside & Desk Convenience Outlets (Duplex)',
          'va': 360.0,
          'isLighting': false,
          'isDedicated': false,
          'citation': 'PEC 2017 Art 2.10.3.3',
          'rule': 'Receptacle spacing rule (walang punto sa pader na higit 1.8m mula sa saksakan)',
          'icon': Icons.power,
        },
        {
          'name': 'Standard Ceiling Fan (52" 3-Blade, 75W)',
          'va': 85.0,
          'isLighting': false,
          'isDedicated': false,
          'citation': 'PEC 2017 Art 3.14.2.13(B) & Art 4.22.2.9',
          'rule': 'Mandatory Fan-Rated Heavy Duty Octagonal Box (suporta hanggang 16-32 kg vibration load)',
          'icon': Icons.mode_fan_off_outlined,
        },
        {
          'name': 'Dedicated 1.5HP Inverter ACU Outlet',
          'va': 1650.0,
          'isLighting': false,
          'isDedicated': true,
          'citation': 'PEC 2017 Art 4.40.4.2',
          'rule': 'Dedicated Hermetic Refrigerant Motor-Compressor branch circuit protection',
          'icon': Icons.ac_unit,
        },
      ]);
    } else if (lower.contains('bath') || lower.contains('laundry')) {
      previewItems.addAll([
        {
          'name': 'GFCI Protected Shaver & Mirror Vanity Outlet',
          'va': 180.0,
          'isLighting': false,
          'isDedicated': false,
          'citation': 'PEC 2017 Art 2.10.1.8(A)(1)',
          'rule': 'Mandatory Class A GFCI (4-6mA trip threshold) sa banyo upang maiwasan ang electric shock',
          'icon': Icons.security,
        },
        {
          'name': 'Dedicated Single-point Shower Heater (3.5kW)',
          'va': 3500.0,
          'isLighting': false,
          'isDedicated': true,
          'citation': 'PEC 2017 Art 4.22.2.3 & Art 2.10.2.1',
          'rule': 'Direct dedicated circuit na may kasamang 30A 2P breaker at ELCB/GFCI protection',
          'icon': Icons.shower,
        },
        {
          'name': 'Front-load Washing Machine Dedicated Line',
          'va': 1800.0,
          'isLighting': false,
          'isDedicated': true,
          'citation': 'PEC 2017 Art 2.10.1.11(C)(2)',
          'rule': 'Minimum 20A individual branch circuit para sa laundry area',
          'icon': Icons.local_laundry_service,
        },
      ]);
    } else if (lower.contains('garage') || lower.contains('outdoor')) {
      previewItems.addAll([
        {
          'name': 'Weatherproof Heavy-Duty Outlets (WR/GFCI)',
          'va': 360.0,
          'isLighting': false,
          'isDedicated': false,
          'citation': 'PEC 2017 Art 4.6.1.9 & Art 2.10.1.8(A)(2)',
          'rule': 'Weather-Resistant (WR) enclosure na may extra-duty while-in-use cover at GFCI',
          'icon': Icons.power,
        },
        {
          'name': 'Perimeter Security Floodlight Line',
          'va': 200.0,
          'isLighting': false,
          'isDedicated': false,
          'citation': 'PEC 2017 Art 2.25.1.1',
          'rule': 'Outside branch circuits and feeders para sa architectural lighting',
          'icon': Icons.flash_on,
        },
        {
          'name': 'Dedicated Water Pressure Pump Line',
          'va': 1200.0,
          'isLighting': false,
          'isDedicated': true,
          'citation': 'PEC 2017 Art 4.30.2.2',
          'rule': 'Motor branch circuit conductor sized at 125% of motor full-load current (FLC)',
          'icon': Icons.water_drop,
        },
      ]);
    } else {
      // Living & Dining default
      previewItems.addAll([
        {
          'name': 'Living Room TV & Entertainment Outlet Pack',
          'va': 360.0,
          'isLighting': false,
          'isDedicated': false,
          'citation': 'PEC 2017 Art 2.10.3.3',
          'rule': 'General Purpose Receptacle spacing sa living space',
          'icon': Icons.tv,
        },
        {
          'name': 'Standard 52" Ceiling Fan / DC Inverter Fan',
          'va': 85.0,
          'isLighting': false,
          'isDedicated': false,
          'citation': 'PEC 2017 Art 3.14.2.13(B)',
          'rule': 'Fan-rated ceiling box with direct joist/beam anchoring',
          'icon': Icons.mode_fan_off_outlined,
        },
        {
          'name': 'Dining Table & General Receptacles',
          'va': 360.0,
          'isLighting': false,
          'isDedicated': false,
          'citation': 'PEC 2017 Art 2.10.3.3',
          'rule': 'Convenience outlets para sa dining and buffet warmers',
          'icon': Icons.power,
        },
        {
          'name': 'Dedicated 2.5HP Inverter Split ACU',
          'va': 2600.0,
          'isLighting': false,
          'isDedicated': true,
          'citation': 'PEC 2017 Art 4.40.4.2',
          'rule': 'Dedicated Hermetic ACU branch circuit (Minimum 20A / 30A 2P)',
          'icon': Icons.ac_unit,
        },
      ]);
    }

    // Show BottomSheet Preview
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.82,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          decoration: const BoxDecoration(
            color: Color(0xFF13171F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: BanaagTheme.primaryAmber, width: 2.0),
              left: BorderSide(color: Colors.white12),
              right: BorderSide(color: Colors.white12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_user, color: BanaagTheme.primaryAmber, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PEC Standard Pack para sa $spaceName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                        const Text(
                          'Opisyal na Batayan mula sa Philippine Electrical Code Book',
                          style: TextStyle(fontSize: 10, color: BanaagTheme.primaryAmber),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: BanaagTheme.primaryAmber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ang mga kargang ito ay awtomatikong ia-apply alinsunod sa minimum electrical code safety regulations.',
                        style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('MGA ILALAGAY NA APPLIANCES & BATAYAN:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: BanaagTheme.textMuted)),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.builder(
                  itemCount: previewItems.length,
                  itemBuilder: (c, idx) {
                    final item = previewItems[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: BanaagTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: BanaagTheme.surfaceCardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(item['icon'] as IconData, size: 16, color: BanaagTheme.primaryAmber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item['name'] as String,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (item['isDedicated'] as bool)
                                      ? Colors.purple.withValues(alpha: 0.2)
                                      : BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  (item['isDedicated'] as bool) ? 'DEDICATED' : '${(item['va'] as double).toStringAsFixed(0)} VA',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: (item['isDedicated'] as bool) ? Colors.purpleAccent : BanaagTheme.primaryAmber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.bookmark_border, size: 11, color: BanaagTheme.primaryAmber),
                                const SizedBox(width: 4),
                                Text(
                                  item['citation'] as String,
                                  style: const TextStyle(fontSize: 10, color: BanaagTheme.primaryAmber, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item['rule'] as String,
                            style: const TextStyle(fontSize: 10, color: BanaagTheme.textMuted, height: 1.25),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BanaagTheme.primaryAmber,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('Kumpirmahin at I-apply sa Kwarto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _executeApplyPecStandardPack(spaceName, previewItems);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _executeApplyPecStandardPack(String spaceName, List<Map<String, dynamic>> items) {
    for (final item in items) {
      _addOrIncrementAppliance(
        name: item['name'] as String,
        ratingVA: item['va'] as double,
        isDedicated: item['isDedicated'] as bool,
        isLighting: item['isLighting'] as bool,
        circuitNumber: (item['isLighting'] as bool) ? 1 : null,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: BanaagTheme.surfaceCard,
        content: Row(
          children: [
            const Icon(Icons.verified, color: BanaagTheme.successGreen, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '⚡ Matagumpay na nailagay ang ${items.length} PEC appliances & citations sa $spaceName!',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
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
                              onPressed: () => _promptPecStandardPackPreview(_activeSpaceName),
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

          // Bottom Action Hub: Room Load Controls & Stage 2 Navigation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF161922),
              border: Border(top: BorderSide(color: BanaagTheme.surfaceCardBorder)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Primary Action: Add Appliance Button (Full Width, Spacious)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BanaagTheme.primaryAmber,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.add_circle, size: 20),
                  label: const Text(
                    'Add Appliance to Room',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.3),
                  ),
                  onPressed: _promptAddCustomAppliance,
                ),
                const SizedBox(height: 10),

                // Secondary Row: Quick Presets & Proceed to Canvas
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BanaagTheme.primaryAmber,
                          side: const BorderSide(color: BanaagTheme.surfaceCardBorder, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.flash_on, size: 16),
                        label: const Text('Presets', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _showQuickPresetPicker,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BanaagTheme.primaryAmber,
                          side: BorderSide(color: BanaagTheme.primaryAmber.withValues(alpha: 0.6), width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.bolt, size: 16),
                        label: const Text('PEC Pack', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => _promptPecStandardPackPreview(_activeSpaceName),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 6,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: BanaagTheme.primaryAmber),
                        label: const Text(
                          'Proceed to Canvas',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
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
              ],
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: BanaagTheme.primaryAmber.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '${item.ratingVA.toStringAsFixed(0)} VA (${(item.ratingVA / 230.0).toStringAsFixed(1)}A)',
                            style: const TextStyle(
                              color: BanaagTheme.primaryAmber,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            'Total: ${(item.totalVA / 1000.0).toStringAsFixed(2)} kVA',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 6),
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
