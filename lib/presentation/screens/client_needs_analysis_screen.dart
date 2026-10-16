// BANAAG Client Needs Analysis Screen: Rapid 1-Tap Appliance Tally & Voice Dictation Assist

import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../data/project_repository.dart';
import '../theme/banaag_theme.dart';

class ClientNeedsAnalysisScreen extends StatefulWidget {
  final Project project;
  const ClientNeedsAnalysisScreen({super.key, required this.project});

  @override
  State<ClientNeedsAnalysisScreen> createState() => _ClientNeedsAnalysisScreenState();
}

class _ClientNeedsAnalysisScreenState extends State<ClientNeedsAnalysisScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _voiceTextController = TextEditingController();

  final List<String> _categories = [
    'Living & Dining',
    'Kitchen',
    'Bedrooms',
    'Bath & Laundry',
    'Outdoor & Utility',
  ];

  // Standard Philippine Appliance Presets with PEC VA Ratings
  final List<Map<String, dynamic>> _presetCatalog = [
    // Living & Dining
    {'name': '2.5HP Split Aircon (Living)', 'category': 'Living & Dining', 'va': 2600.0, 'dedicated': true, 'icon': Icons.ac_unit},
    {'name': '65" Smart 4K TV & Soundbar', 'category': 'Living & Dining', 'va': 350.0, 'dedicated': false, 'icon': Icons.tv},
    {'name': 'Ceiling Fan with Light', 'category': 'Living & Dining', 'va': 150.0, 'dedicated': false, 'icon': Icons.mode_fan_off_outlined},
    {'name': 'Cove / Drop LED Strips', 'category': 'Living & Dining', 'va': 200.0, 'dedicated': false, 'icon': Icons.lightbulb_outline},

    // Kitchen
    {'name': 'Two-Door Inverter Refrigerator', 'category': 'Kitchen', 'va': 800.0, 'dedicated': true, 'icon': Icons.kitchen},
    {'name': 'Induction Cooktop (Double Burner)', 'category': 'Kitchen', 'va': 3500.0, 'dedicated': true, 'icon': Icons.soup_kitchen},
    {'name': 'Microwave & Oven Toaster', 'category': 'Kitchen', 'va': 1800.0, 'dedicated': false, 'icon': Icons.microwave},
    {'name': 'Range Hood Exhaust', 'category': 'Kitchen', 'va': 250.0, 'dedicated': false, 'icon': Icons.air},
    {'name': 'Rice Cooker & Air Fryer', 'category': 'Kitchen', 'va': 1500.0, 'dedicated': false, 'icon': Icons.dinner_dining},

    // Bedrooms
    {'name': '1.5HP Inverter Aircon (Master)', 'category': 'Bedrooms', 'va': 1650.0, 'dedicated': true, 'icon': Icons.ac_unit},
    {'name': '1.0HP Inverter Aircon (Room 2)', 'category': 'Bedrooms', 'va': 1100.0, 'dedicated': true, 'icon': Icons.ac_unit},
    {'name': 'Workstation PC / Laptop Desk', 'category': 'Bedrooms', 'va': 450.0, 'dedicated': false, 'icon': Icons.computer},
    {'name': '43" Bedroom Smart TV', 'category': 'Bedrooms', 'va': 180.0, 'dedicated': false, 'icon': Icons.tv},

    // Bath & Laundry
    {'name': 'Multipoint Water Heater (3.5kW)', 'category': 'Bath & Laundry', 'va': 3500.0, 'dedicated': true, 'icon': Icons.hot_tub},
    {'name': 'Single-point Shower Heater', 'category': 'Bath & Laundry', 'va': 2500.0, 'dedicated': true, 'icon': Icons.shower},
    {'name': 'Front-load Washing Machine', 'category': 'Bath & Laundry', 'va': 1800.0, 'dedicated': true, 'icon': Icons.local_laundry_service},
    {'name': 'Electric Clothes Dryer', 'category': 'Bath & Laundry', 'va': 2200.0, 'dedicated': true, 'icon': Icons.dry},

    // Outdoor & Utility
    {'name': '1.0HP Jet Pump / Water Pressure Pump', 'category': 'Outdoor & Utility', 'va': 1200.0, 'dedicated': true, 'icon': Icons.water_drop},
    {'name': 'Lanai & Perimeter Floodlights', 'category': 'Outdoor & Utility', 'va': 300.0, 'dedicated': false, 'icon': Icons.highlight},
    {'name': 'CCTV System & NVR Rack', 'category': 'Outdoor & Utility', 'va': 250.0, 'dedicated': false, 'icon': Icons.videocam},
    {'name': 'Pressure Washer Outlet', 'category': 'Outdoor & Utility', 'va': 1800.0, 'dedicated': true, 'icon': Icons.cleaning_services},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);

    // Seed realistic sample items if empty
    if (widget.project.applianceLoads.isEmpty) {
      widget.project.applianceLoads = [
        ApplianceItem(id: 'a1', name: '2.5HP Split Aircon (Living)', roomCategory: 'Living & Dining', ratingVA: 2600.0, quantity: 1, isDedicatedCircuit: true),
        ApplianceItem(id: 'a2', name: 'Two-Door Inverter Refrigerator', roomCategory: 'Kitchen', ratingVA: 800.0, quantity: 1, isDedicatedCircuit: true),
        ApplianceItem(id: 'a3', name: '1.5HP Inverter Aircon (Master)', roomCategory: 'Bedrooms', ratingVA: 1650.0, quantity: 2, isDedicatedCircuit: true),
        ApplianceItem(id: 'a4', name: 'Multipoint Water Heater (3.5kW)', roomCategory: 'Bath & Laundry', ratingVA: 3500.0, quantity: 1, isDedicatedCircuit: true),
      ];
    }
  }

  void _incrementAppliance(Map<String, dynamic> preset) {
    setState(() {
      final existingIndex = widget.project.applianceLoads.indexWhere((a) => a.name == preset['name']);
      if (existingIndex != -1) {
        widget.project.applianceLoads[existingIndex].quantity++;
      } else {
        widget.project.applianceLoads.add(ApplianceItem(
          id: 'app-${DateTime.now().millisecondsSinceEpoch}',
          name: preset['name'],
          roomCategory: preset['category'],
          ratingVA: preset['va'],
          quantity: 1,
          isDedicatedCircuit: preset['dedicated'],
        ));
      }
      ProjectRepository.instance.updateProject(widget.project);
    });
  }

  void _decrementAppliance(String name) {
    setState(() {
      final index = widget.project.applianceLoads.indexWhere((a) => a.name == name);
      if (index != -1) {
        if (widget.project.applianceLoads[index].quantity > 1) {
          widget.project.applianceLoads[index].quantity--;
        } else {
          widget.project.applianceLoads.removeAt(index);
        }
        ProjectRepository.instance.updateProject(widget.project);
      }
    });
  }

  int _getQuantity(String name) {
    final item = widget.project.applianceLoads.where((a) => a.name == name).firstOrNull;
    return item?.quantity ?? 0;
  }

  void _processVoiceNotes(String text) {
    final lower = text.toLowerCase();
    int addedCount = 0;

    for (final preset in _presetCatalog) {
      final presetLower = (preset['name'] as String).toLowerCase();
      // Match keywords (e.g. "aircon", "heater", "ref", "pump", "induction", "tv")
      final keywords = ['aircon', 'heater', 'ref', 'pump', 'cooktop', 'microwave', 'tv', 'washer'];
      for (final kw in keywords) {
        if (lower.contains(kw) && presetLower.contains(kw)) {
          _incrementAppliance(preset);
          addedCount++;
          break;
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🎙️ Voice Assist processed: $addedCount appliances recognized & tallied!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalVA = widget.project.totalConnectedLoadVA;
    final totalAmps = totalVA / 230.0;
    final dedicatedCount = widget.project.applianceLoads.where((a) => a.isDedicatedCircuit).fold(0, (sum, a) => sum + a.quantity);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📋 Client Needs Analysis'),
            Text(widget.project.title, style: const TextStyle(color: BanaagTheme.primaryAmber, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic, color: BanaagTheme.primaryAmber),
            tooltip: 'Voice Notes Dictation Assist',
            onPressed: () => _showVoiceDictationDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: BanaagTheme.primaryAmber,
          labelColor: BanaagTheme.primaryAmber,
          unselectedLabelColor: BanaagTheme.textMuted,
          tabs: _categories.map((c) => Tab(text: c)).toList(),
        ),
      ),
      body: Column(
        children: [
          // Live Tally Summary Ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF1B2028),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _metricMini('Total Load', '${(totalVA / 1000).toStringAsFixed(1)} kVA', 'Connected Rating'),
                _metricMini('Total Current', '${totalAmps.toStringAsFixed(1)} A', 'Single Phase 230V'),
                _metricMini('Dedicated Circuits', '$dedicatedCount Lines', 'Heaters/ACU/Ref', color: BanaagTheme.primaryAmber),
                _metricMini('Total Units', '${widget.project.applianceLoads.fold(0, (sum, a) => sum + a.quantity)} pcs', 'Tallied'),
              ],
            ),
          ),

          // Appliance Grid
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.map((category) => _buildCategoryGrid(category)).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: BanaagTheme.surfaceCard,
            border: Border(top: BorderSide(color: BanaagTheme.surfaceCardBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Complete & Proceed to Stage 2'),
                  onPressed: () {
                    // Mark checklist item complete
                    final consultationPhase = widget.project.phases[0];
                    final needsItem = consultationPhase.checklist.firstWhere((c) => c.id == 'c1', orElse: () => consultationPhase.checklist.first);
                    needsItem.isCompleted = true;
                    ProjectRepository.instance.updateProject(widget.project);

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Client Needs Analysis complete! Load tally linked to Project.')),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(String category) {
    final items = _presetCatalog.where((p) => p['category'] == category).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final preset = items[index];
        final String name = preset['name'];
        final int qty = _getQuantity(name);
        final bool isSelected = qty > 0;

        return Card(
          color: isSelected ? const Color(0xFF232A36) : BanaagTheme.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isSelected ? BanaagTheme.primaryAmber : BanaagTheme.surfaceCardBorder,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                      foregroundColor: BanaagTheme.primaryAmber,
                      child: Icon(preset['icon'], size: 18),
                    ),
                    if (preset['dedicated'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('DEDICATED', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  '${preset['va']} VA (${(preset['va'] / 230.0).toStringAsFixed(1)}A)',
                  style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 10),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (qty > 0)
                      InkWell(
                        onTap: () => _decrementAppliance(name),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: const Color(0xFF2F3644), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.remove, size: 16, color: Colors.white),
                        ),
                      )
                    else
                      const SizedBox(width: 24),
                    Text(
                      qty > 0 ? '$qty' : '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: BanaagTheme.primaryAmber),
                    ),
                    InkWell(
                      onTap: () => _incrementAppliance(preset),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: BanaagTheme.primaryAmber, borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.add, size: 16, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVoiceDictationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BanaagTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.mic, color: BanaagTheme.primaryAmber),
            SizedBox(width: 8),
            Text('Voice Dictation Assist'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Habang naglalakad sa site kasama si client, magsalita o mag-paste ng notes (e.g. "May dalawang aircon sa master, isang ref sa kitchen, at water heater sa banyo"):',
              style: TextStyle(fontSize: 12, color: BanaagTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _voiceTextController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Type or speak: "Aircon, heater, ref, water pump..."',
                filled: true,
                fillColor: Color(0xFF16191F),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: BanaagTheme.textMuted)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: BanaagTheme.primaryAmber,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Parse & Add'),
            onPressed: () {
              if (_voiceTextController.text.trim().isNotEmpty) {
                _processVoiceNotes(_voiceTextController.text.trim());
                _voiceTextController.clear();
                Navigator.pop(ctx);
              }
            },
          ),
        ],
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
}
