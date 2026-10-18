// BANAAG Single-Line Diagram (SLD) & Schedule of Loads Interactive Screen
// Interactive Schematic CAD Diagram, Schedule of Loads Matrix, and Manual Override Mode

import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../domain/sld_engine.dart';
import '../../domain/pec_engine.dart';
import '../../data/project_repository.dart';
import '../theme/banaag_theme.dart';

class SingleLineDiagramScreen extends StatefulWidget {
  final Project project;
  const SingleLineDiagramScreen({super.key, required this.project});

  @override
  State<SingleLineDiagramScreen> createState() => _SingleLineDiagramScreenState();
}

class _SingleLineDiagramScreenState extends State<SingleLineDiagramScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SingleLineDiagramData _sldData;
  bool _isApproved = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _sldData = SldEngine.generateFromProject(widget.project);

    // Check if p1 checklist item is already completed
    final p2 = widget.project.phases.firstWhere(
      (p) => p.type == ProjectPhaseType.permitting,
      orElse: () => widget.project.phases[1],
    );
    final p1Item = p2.checklist.firstWhere((i) => i.id == 'p1', orElse: () => p2.checklist.first);
    _isApproved = p1Item.isCompleted;
  }

  void _markApproved() {
    setState(() {
      _isApproved = true;
      final p2 = widget.project.phases.firstWhere(
        (p) => p.type == ProjectPhaseType.permitting,
        orElse: () => widget.project.phases[1],
      );
      final p1Item = p2.checklist.firstWhere((i) => i.id == 'p1', orElse: () => p2.checklist.first);
      p1Item.isCompleted = true;
      p1Item.notes = 'Approved SLD: ${_sldData.feeder.mainBreakerDescription} • ${_sldData.branchCircuits.length} Circuits';

      // Check if all items in Phase 2 are complete
      if (p2.checklist.every((c) => c.isCompleted)) {
        p2.isCompleted = true;
      }
      ProjectRepository.instance.updateProject(widget.project);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Single-Line Diagram & Schedule of Loads approved! Phase 2 Checklist auto-checked.'),
        backgroundColor: BanaagTheme.successGreen,
      ),
    );
  }

  void _editCircuit(SldBranchCircuit circuit) {
    final descController = TextEditingController(text: circuit.description);
    final vaController = TextEditingController(text: circuit.loadVA.toStringAsFixed(0));
    int breaker = circuit.breakerRatingAmps;
    String wire = circuit.wireSizeDescription;
    String conduit = circuit.conduitDescription;

    double selectedWireMm2 = 3.5;
    if (wire.contains('2.0 mm²')) {
      selectedWireMm2 = 2.0;
    } else if (wire.contains('3.5 mm²')) {
      selectedWireMm2 = 3.5;
    } else if (wire.contains('5.5 mm²')) {
      selectedWireMm2 = 5.5;
    } else if (wire.contains('8.0 mm²')) {
      selectedWireMm2 = 8.0;
    } else if (wire.contains('14.0 mm²')) {
      selectedWireMm2 = 14.0;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: BanaagTheme.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.tune, color: BanaagTheme.primaryAmber, size: 22),
              const SizedBox(width: 8),
              Text('Edit Circuit C${circuit.circuitNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Circuit Load Description',
                    labelStyle: TextStyle(color: BanaagTheme.textMuted),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: vaController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Connected Load (VA)',
                    labelStyle: TextStyle(color: BanaagTheme.textMuted),
                  ),
                  onChanged: (val) {
                    final newVA = double.tryParse(val) ?? circuit.loadVA;
                    setModalState(() {
                      circuit.loadVA = newVA;
                      circuit.loadCurrentAmps = newVA / 230.0;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: breaker,
                  dropdownColor: BanaagTheme.surfaceCard,
                  decoration: const InputDecoration(labelText: 'Circuit Breaker Rating (Amps)'),
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15A 2-Pole (Lighting Standard)')),
                    DropdownMenuItem(value: 20, child: Text('20A 2-Pole (Convenience Outlets)')),
                    DropdownMenuItem(value: 30, child: Text('30A 2-Pole (ACU / Water Heater)')),
                    DropdownMenuItem(value: 40, child: Text('40A 2-Pole (Cooking Range / Sub-feed)')),
                    DropdownMenuItem(value: 50, child: Text('50A 2-Pole (Heavy Feeder)')),
                    DropdownMenuItem(value: 60, child: Text('60A 2-Pole (Main / Sub-panel)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        breaker = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<double>(
                  initialValue: selectedWireMm2,
                  dropdownColor: BanaagTheme.surfaceCard,
                  decoration: const InputDecoration(labelText: 'Conductor Size (Wire Spec)'),
                  items: const [
                    DropdownMenuItem(value: 2.0, child: Text('2.0 mm² (#14 AWG) - 20A Limit (Lighting)')),
                    DropdownMenuItem(value: 3.5, child: Text('3.5 mm² (#12 AWG) - 25A Limit (Outlets)')),
                    DropdownMenuItem(value: 5.5, child: Text('5.5 mm² (#10 AWG) - 35A Limit (Heavy Load)')),
                    DropdownMenuItem(value: 8.0, child: Text('8.0 mm² (#8 AWG) - 50A Limit (Feeder)')),
                    DropdownMenuItem(value: 14.0, child: Text('14.0 mm² (#6 AWG) - 65A Limit (Main Feeder)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        selectedWireMm2 = val;
                        wire = '2 - $selectedWireMm2 mm² THHN + 1 - 2.0 mm² Ground';
                        if (selectedWireMm2 >= 8.0) {
                          conduit = '25 mm Ø PVC';
                        } else {
                          conduit = '20 mm Ø PVC';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Real-time PEC Spec Validation for this Circuit
                Builder(
                  builder: (_) {
                    final isLightingCircuit = circuit.description.toLowerCase().contains('light');
                    final validation = PecEngine.validateCircuitSpecs(
                      loadCurrentAmps: circuit.loadVA / 230.0,
                      wireSizeMm2: selectedWireMm2,
                      breakerRatingAmps: breaker,
                      isLighting: isLightingCircuit,
                    );

                    Color statusColor = BanaagTheme.successGreen;
                    IconData statusIcon = Icons.verified_user_outlined;
                    String statusBadge = 'PEC COMPLIANT ✅';

                    switch (validation.status) {
                      case PecComplianceStatus.underSpecs:
                        statusColor = BanaagTheme.alertRed;
                        statusIcon = Icons.dangerous_outlined;
                        statusBadge = 'UNDER-SPECS ❌';
                        break;
                      case PecComplianceStatus.overSpecs:
                        statusColor = BanaagTheme.warningOrange;
                        statusIcon = Icons.warning_amber_rounded;
                        statusBadge = 'OVER-SPECS ⚠️';
                        break;
                      case PecComplianceStatus.compliant:
                        statusColor = BanaagTheme.successGreen;
                        statusIcon = Icons.verified_user_outlined;
                        statusBadge = 'PEC COMPLIANT ✅';
                        break;
                    }

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(statusIcon, color: statusColor, size: 18),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(statusBadge, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            validation.details,
                            style: const TextStyle(fontSize: 11, color: Colors.white, height: 1.3),
                          ),
                          if (validation.pecCitations.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.menu_book, size: 11, color: BanaagTheme.primaryAmber),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'PEC 2017: ${validation.pecCitations.join(" • ")}',
                                      style: const TextStyle(fontSize: 10, color: BanaagTheme.textMuted, height: 1.2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Text('Conduit Raceway: $conduit', style: const TextStyle(fontSize: 11, color: BanaagTheme.textMuted)),
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
                backgroundColor: BanaagTheme.primaryAmber,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                setState(() {
                  circuit.description = descController.text.trim();
                  circuit.loadVA = double.tryParse(vaController.text.trim()) ?? circuit.loadVA;
                  circuit.loadCurrentAmps = circuit.loadVA / 230.0;
                  circuit.breakerRatingAmps = breaker;
                  circuit.wireSizeDescription = wire;
                  circuit.conduitDescription = conduit;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save Override', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }



  void _addNewCircuit() {
    setState(() {
      final newNum = _sldData.branchCircuits.length + 1;
      _sldData.branchCircuits.add(SldBranchCircuit(
        circuitNumber: newNum,
        description: 'New Branch Circuit (C$newNum)',
        loadVA: 1200.0,
        loadCurrentAmps: 1200.0 / 230.0,
        breakerRatingAmps: 20,
        poles: 2,
        wireSizeDescription: '2 - 3.5 mm² THHN + 1 - 2.0 mm² Ground',
        conduitDescription: '20 mm Ø PVC',
        isSpare: false,
      ));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('⚡ Added Circuit C${_sldData.branchCircuits.length}! Pindutin para i-customize.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚡ Single-Line Diagram Engine'),
            Text(widget.project.title, style: const TextStyle(fontSize: 11, color: BanaagTheme.primaryAmber)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: BanaagTheme.primaryAmber,
          labelColor: BanaagTheme.primaryAmber,
          unselectedLabelColor: BanaagTheme.textMuted,
          tabs: const [
            Tab(icon: Icon(Icons.account_tree_outlined, size: 18), text: 'Single-Line Schematic'),
            Tab(icon: Icon(Icons.table_chart_outlined, size: 18), text: 'Schedule of Loads'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: BanaagTheme.primaryAmber),
            tooltip: 'Add Branch Circuit',
            onPressed: _addNewCircuit,
          ),
          IconButton(
            icon: Icon(
              _isApproved ? Icons.verified : Icons.check_circle_outline,
              color: _isApproved ? BanaagTheme.successGreen : BanaagTheme.primaryAmber,
            ),
            tooltip: 'Approve & Check Checklist',
            onPressed: _markApproved,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSchematicView(),
          _buildScheduleOfLoadsView(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFF1B2028),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Main MCB: ${_sldData.feeder.mainBreakerAmps}A 2P • Total: ${_sldData.feeder.totalConnectedVA.toStringAsFixed(0)} VA',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                  ),
                  Text(
                    'Feeder: ${_sldData.feeder.feederWireDescription} in ${_sldData.feeder.conduitDescription}',
                    style: const TextStyle(fontSize: 10, color: BanaagTheme.textMuted),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isApproved ? BanaagTheme.successGreen : BanaagTheme.primaryAmber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: Icon(_isApproved ? Icons.check : Icons.done_all, size: 16),
              label: Text(_isApproved ? 'APPROVED ✅' : 'APPROVE SLD', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              onPressed: _markApproved,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchematicView() {
    return InteractiveViewer(
      constrained: false,
      minScale: 0.6,
      maxScale: 2.5,
      child: Container(
        padding: const EdgeInsets.all(24.0),
        color: const Color(0xFF12151B),
        child: CustomPaint(
          size: Size(540, 180 + (_sldData.branchCircuits.length * 68.0)),
          painter: SldSchematicPainter(
            sldData: _sldData,
            onCircuitTap: _editCircuit,
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleOfLoadsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header summary card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BanaagTheme.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BanaagTheme.surfaceCardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MAIN PANELBOARD (LP-1)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BanaagTheme.primaryAmber)),
                    Text('Utility: ${_sldData.utilityProvider} (230V, 1Ø, 60Hz)', style: const TextStyle(fontSize: 11, color: BanaagTheme.textMuted)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Demand: ${_sldData.feeder.netDemandVA.toStringAsFixed(0)} VA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('${_sldData.feeder.netCurrentAmps.toStringAsFixed(1)} Amperes', style: const TextStyle(fontSize: 11, color: BanaagTheme.successGreen, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Dedicated Non-Disruptive PEC Engineering Basis Card
          _buildPecEngineeringBasisCard(),

          const SizedBox(height: 16),
          const Text('SCHEDULE OF LOADS & BRANCH CIRCUITS (PEC 2017)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 8),

          // Circuits table
          ...List.generate(_sldData.branchCircuits.length, (idx) {
            final c = _sldData.branchCircuits[idx];
            return Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              decoration: BoxDecoration(
                color: c.isSpare ? Colors.white.withValues(alpha: 0.03) : BanaagTheme.surfaceCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.isSpare ? Colors.white12 : BanaagTheme.surfaceCardBorder),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: c.isSpare ? Colors.grey.shade800 : BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                  child: Text('C${c.circuitNumber}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.isSpare ? Colors.white54 : BanaagTheme.primaryAmber)),
                ),
                title: Text(
                  c.description,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: c.isSpare ? BanaagTheme.textMuted : Colors.white),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      '${c.loadVA.toStringAsFixed(0)} VA @ 230V • ${c.loadCurrentAmps.toStringAsFixed(2)}A • ${c.breakerRatingAmps}A 2P Breaker',
                      style: const TextStyle(fontSize: 11, color: BanaagTheme.textMuted),
                    ),
                    Text(
                      'Wire: ${c.wireSizeDescription} in ${c.conduitDescription}',
                      style: const TextStyle(fontSize: 10, color: BanaagTheme.primaryAmber),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: BanaagTheme.primaryAmber),
                  tooltip: 'Edit / Override Circuit',
                  onPressed: () => _editCircuit(c),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPecEngineeringBasisCard() {
    final basisList = _sldData.pecEngineeringBasis;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.menu_book, color: BanaagTheme.primaryAmber, size: 18),
          ),
          title: const Text(
            'Mga Opisyal na Batayan sa PEC 2017 Book',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
          ),
          subtitle: const Text(
            'Load Calculations, Demand Factors & Feeder Compliance',
            style: TextStyle(fontSize: 10, color: BanaagTheme.primaryAmber),
          ),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: basisList.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item['citation'] ?? '',
                                style: const TextStyle(color: BanaagTheme.primaryAmber, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['topic'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['formula'] ?? '',
                          style: const TextStyle(fontSize: 10, color: BanaagTheme.textMuted, height: 1.25),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '⚡ Resulta: ${item['computed'] ?? ''}',
                          style: const TextStyle(fontSize: 10, color: BanaagTheme.successGreen, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SldSchematicPainter extends CustomPainter {
  final SingleLineDiagramData sldData;
  final Function(SldBranchCircuit) onCircuitTap;

  SldSchematicPainter({required this.sldData, required this.onCircuitTap});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final busPaint = Paint()
      ..color = BanaagTheme.primaryAmber
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke;

    final groundPaint = Paint()
      ..color = BanaagTheme.successGreen
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final textStyle = const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace');
    final amberStyle = const TextStyle(color: BanaagTheme.primaryAmber, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace');
    final mutedStyle = const TextStyle(color: BanaagTheme.textMuted, fontSize: 10, fontFamily: 'monospace');

    // 1. Service Drop (Top)
    const double centerX = 160.0;
    double curY = 30.0;

    _drawText(canvas, 'OVERHEAD SERVICE DROP (${sldData.utilityProvider})', 20, curY - 18, amberStyle);
    _drawText(canvas, '230V, 1-PHASE, 2-WIRE, 60 Hz', 20, curY - 4, mutedStyle);

    canvas.drawLine(const Offset(centerX, 20), Offset(centerX, curY + 20), linePaint);
    curY += 20;

    // 2. Kilowatt-Hour Meter (Circle)
    final meterCenter = Offset(centerX, curY + 25);
    final meterPaint = Paint()
      ..color = const Color(0xFF1E2430)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(meterCenter, 22, meterPaint);
    canvas.drawCircle(meterCenter, 22, linePaint);
    _drawText(canvas, 'kWh', meterCenter.dx - 10, meterCenter.dy - 6, amberStyle);
    _drawText(canvas, 'METER', meterCenter.dx + 30, meterCenter.dy - 6, textStyle);

    curY += 47;
    canvas.drawLine(Offset(centerX, curY), Offset(centerX, curY + 25), linePaint);
    curY += 25;

    // 3. Main Circuit Breaker (MCB) Box
    final mcbRect = Rect.fromCenter(center: Offset(centerX, curY + 20), width: 70, height: 36);
    canvas.drawRect(mcbRect, Paint()..color = const Color(0xFF232A36));
    canvas.drawRect(mcbRect, Paint()..color = BanaagTheme.primaryAmber..style = PaintingStyle.stroke..strokeWidth = 2);
    _drawText(canvas, '${sldData.feeder.mainBreakerAmps}A', mcbRect.center.dx - 12, mcbRect.center.dy - 6, amberStyle);

    // Feeder labels
    _drawText(canvas, 'MAIN CB: ${sldData.feeder.mainBreakerDescription}', centerX + 45, mcbRect.top + 2, textStyle);
    _drawText(canvas, 'FEEDER: ${sldData.feeder.feederWireDescription} in ${sldData.feeder.conduitDescription}', centerX + 45, mcbRect.top + 16, mutedStyle);

    curY += 38;
    canvas.drawLine(Offset(centerX, curY), Offset(centerX, curY + 25), linePaint);
    curY += 25;

    // 4. Main Panelboard LP-1 Vertical Busbar
    final double busbarTop = curY;
    final double busbarHeight = sldData.branchCircuits.length * 62.0;
    final double busbarBottom = busbarTop + busbarHeight;

    canvas.drawLine(Offset(centerX, busbarTop), Offset(centerX, busbarBottom), busPaint);
    _drawText(canvas, sldData.panelName, 20, busbarTop - 12, amberStyle);

    // Ground Busbar (Left side)
    const double groundX = centerX - 50;
    canvas.drawLine(Offset(groundX, busbarTop + 10), Offset(groundX, busbarBottom - 10), groundPaint);
    _drawText(canvas, 'GROUND BUS', groundX - 70, busbarTop + 14, const TextStyle(color: BanaagTheme.successGreen, fontSize: 9, fontWeight: FontWeight.bold));

    // Ground Electrode connection to earth
    canvas.drawLine(Offset(groundX, busbarBottom - 10), Offset(groundX, busbarBottom + 25), groundPaint);
    _drawGroundSymbol(canvas, Offset(groundX, busbarBottom + 25));
    _drawText(canvas, sldData.feeder.groundingDescription, groundX + 10, busbarBottom + 22, mutedStyle);

    // 5. Branch Circuits Sprouting from Busbar to the Right
    double branchY = busbarTop + 20;
    for (int i = 0; i < sldData.branchCircuits.length; i++) {
      final c = sldData.branchCircuits[i];

      // Branch tap line from busbar
      canvas.drawLine(Offset(centerX, branchY), Offset(centerX + 35, branchY), linePaint);

      // Branch Breaker rectangle
      final bRect = Rect.fromCenter(center: Offset(centerX + 55, branchY), width: 40, height: 24);
      final bPaint = Paint()
        ..color = c.isSpare ? Colors.grey.shade900 : const Color(0xFF222938)
        ..style = PaintingStyle.fill;
      canvas.drawRect(bRect, bPaint);
      canvas.drawRect(bRect, Paint()..color = c.isSpare ? Colors.white30 : Colors.white70..style = PaintingStyle.stroke..strokeWidth = 1.5);
      _drawText(canvas, '${c.breakerRatingAmps}A', bRect.center.dx - 10, bRect.center.dy - 5, TextStyle(color: c.isSpare ? Colors.white54 : BanaagTheme.primaryAmber, fontSize: 10, fontWeight: FontWeight.bold));

      // Homerun line extending right
      canvas.drawLine(Offset(bRect.right, branchY), Offset(bRect.right + 25, branchY), linePaint);

      // Homerun arrow
      _drawHomerunArrow(canvas, Offset(bRect.right + 25, branchY));

      // Branch Labels
      _drawText(canvas, 'C${c.circuitNumber}: ${c.description}', bRect.right + 34, branchY - 10, TextStyle(color: c.isSpare ? BanaagTheme.textMuted : Colors.white, fontWeight: FontWeight.bold, fontSize: 11));
      _drawText(canvas, '${c.wireSizeDescription} in ${c.conduitDescription}', bRect.right + 34, branchY + 3, mutedStyle);

      branchY += 62.0;
    }
  }

  void _drawText(Canvas canvas, String text, double x, double y, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(x, y));
  }

  void _drawHomerunArrow(Canvas canvas, Offset p) {
    final arrowPaint = Paint()
      ..color = BanaagTheme.primaryAmber
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(p.dx - 5, p.dy - 5)
      ..lineTo(p.dx, p.dy)
      ..lineTo(p.dx - 5, p.dy + 5);
    canvas.drawPath(path, arrowPaint);
  }

  void _drawGroundSymbol(Canvas canvas, Offset p) {
    final gPaint = Paint()
      ..color = BanaagTheme.successGreen
      ..strokeWidth = 2.0;

    canvas.drawLine(Offset(p.dx - 12, p.dy), Offset(p.dx + 12, p.dy), gPaint);
    canvas.drawLine(Offset(p.dx - 8, p.dy + 4), Offset(p.dx + 8, p.dy + 4), gPaint);
    canvas.drawLine(Offset(p.dx - 4, p.dy + 8), Offset(p.dx + 4, p.dy + 8), gPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
