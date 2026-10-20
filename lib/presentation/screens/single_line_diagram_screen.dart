// BANAAG Single-Line Diagram (SLD) & Schedule of Loads Interactive Screen
// Interactive Schematic CAD Diagram, Schedule of Loads Matrix, and Manual Override Mode

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/models.dart';
import '../../domain/sld_engine.dart';
import '../../domain/pec_engine.dart';
import '../../domain/takeoff_engine.dart';
import '../../domain/institutional_building_presets.dart';
import '../../domain/bom_excel_exporter.dart';
import '../../domain/blueprint_pdf_exporter.dart';
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

  MultiPanelInstitutionalRiser? _multiPanelRiser;
  String _activePanelKey = 'MAIN'; // 'MDP', 'LP-1', 'LP-2' etc.
  final Map<String, SingleLineDiagramData> _panelsMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Check if project is institutional or default
    final isInstitutional = widget.project.title.toLowerCase().contains('institutional') ||
        widget.project.title.toLowerCase().contains('college') ||
        widget.project.title.toLowerCase().contains('school') ||
        widget.project.spaces.any((s) => s.name.contains('Classroom') || s.name.contains('Demonstration') || s.name.contains('Faculty'));

    if (isInstitutional) {
      final preset = InstitutionalBuildingPreset.sanLorenzoRuizCollege();
      _multiPanelRiser = MultiPanelInstitutionalRiser.compute(preset, utility: widget.project.utilityProvider);
      _sldData = _multiPanelRiser!.mdp;
      _activePanelKey = 'MDP';
      _panelsMap['MDP'] = _multiPanelRiser!.mdp;
      _panelsMap['LP-1'] = _multiPanelRiser!.lp1;
      _panelsMap['LP-2'] = _multiPanelRiser!.lp2;
    } else {
      // Normal project: generate base SLD
      _sldData = SldEngine.generateFromProject(widget.project);
      _activePanelKey = widget.project.panelboards.first.tag;
      _panelsMap[_activePanelKey] = _sldData;

      // Populate any additional subpanels configured in widget.project.panelboards
      for (final pb in widget.project.panelboards) {
        if (!_panelsMap.containsKey(pb.tag)) {
          _panelsMap[pb.tag] = _createSubpanelSld(pb);
        }
      }
    }

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

  SingleLineDiagramData _createSubpanelSld(PanelboardSpec pb) {
    // Sizing sub-feeder for subpanel (standard 60A / 100A subpanel)
    final double defaultSubDemandVA = 6000.0;
    final double netCurrent = defaultSubDemandVA / 230.0;
    return SingleLineDiagramData(
      feeder: SldFeederSpec(
        totalConnectedVA: defaultSubDemandVA,
        netDemandVA: defaultSubDemandVA,
        netCurrentAmps: netCurrent,
        mainBreakerAmps: 60,
        mainBreakerDescription: '60 AT / 100 AF, 2-Pole, 230V, 60Hz MCB',
        feederWireDescription: '2 - 14.0 mm² THHN',
        groundingDescription: '1 - 8.0 mm² Bare Cu to Ground Bus',
        conduitDescription: '25 mm Ø PVC',
        serviceDropDescription: 'Fed from Main Distribution Panel (${pb.fedFromPanelId ?? "MDP"})',
      ),
      branchCircuits: [
        SldBranchCircuit(
          circuitNumber: 1,
          description: 'Subpanel Branch Circuits (Lighting & Power)',
          loadVA: 2400.0,
          loadCurrentAmps: 2400.0 / 230.0,
          breakerRatingAmps: 20,
          wireSizeDescription: '2 - 3.5 mm² THHN + 1 - 3.5 mm² Ground',
          conduitDescription: '20 mm Ø PVC',
        ),
        SldBranchCircuit(
          circuitNumber: 2,
          description: 'Subpanel Convenience Receptacles',
          loadVA: 3600.0,
          loadCurrentAmps: 3600.0 / 230.0,
          breakerRatingAmps: 20,
          wireSizeDescription: '2 - 3.5 mm² THHN + 1 - 3.5 mm² Ground',
          conduitDescription: '20 mm Ø PVC',
        ),
        SldBranchCircuit(
          circuitNumber: 3,
          description: 'SPARE (Future Expansion)',
          loadVA: 0.0,
          loadCurrentAmps: 0.0,
          breakerRatingAmps: 20,
          wireSizeDescription: '2 - 3.5 mm² THHN + 1 - 3.5 mm² Ground',
          conduitDescription: '20 mm Ø PVC',
          isSpare: true,
        ),
      ],
      panelName: '${pb.tag} (${pb.name})',
      utilityProvider: widget.project.utilityProvider,
    );
  }

  void _showAddSubpanelDialog() {
    final tagController = TextEditingController(text: 'LP-${widget.project.panelboards.length + 1}');
    final nameController = TextEditingController(text: 'Secondary Subpanel');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BanaagTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.domain_add, color: BanaagTheme.primaryAmber, size: 22),
            SizedBox(width: 8),
            Text('Add Subpanel / Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'In accordance with PEC 2017 Article 2.15 & 4.08, a dedicated sub-feeder overcurrent protection device (OCPD) will be routed from the Main Distribution Panel to supply this subpanel.',
              style: TextStyle(color: BanaagTheme.textMuted, fontSize: 12, height: 1.3),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: tagController,
              decoration: const InputDecoration(
                labelText: 'Panel Tag (e.g. LP-2, PP-ACU, Sub-1)',
                labelStyle: TextStyle(color: BanaagTheme.textMuted),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Panel Description / Area',
                labelStyle: TextStyle(color: BanaagTheme.textMuted),
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
              backgroundColor: BanaagTheme.primaryAmber,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final tag = tagController.text.trim().toUpperCase();
              final name = nameController.text.trim();
              if (tag.isNotEmpty) {
                final newPb = PanelboardSpec(
                  id: 'panel-${DateTime.now().millisecondsSinceEpoch}',
                  tag: tag,
                  name: name.isEmpty ? 'Subpanel $tag' : name,
                  isMain: false,
                  fedFromPanelId: _activePanelKey,
                );

                setState(() {
                  widget.project.panelboards.add(newPb);
                  final newSld = _createSubpanelSld(newPb);
                  _panelsMap[tag] = newSld;
                  _activePanelKey = tag;
                  _sldData = newSld;

                  // Also add a sub-feeder breaker on the active main panel if not yet present
                  final mainData = _panelsMap['MDP'] ?? _panelsMap['LP-1'] ?? _panelsMap.values.first;
                  mainData.branchCircuits.insert(
                    mainData.branchCircuits.length > 2 ? mainData.branchCircuits.length - 2 : mainData.branchCircuits.length,
                    SldBranchCircuit(
                      circuitNumber: mainData.branchCircuits.length + 1,
                      description: 'Sub-feeder to Panel $tag ($name)',
                      loadVA: newSld.feeder.netDemandVA,
                      loadCurrentAmps: newSld.feeder.netCurrentAmps,
                      breakerRatingAmps: 60,
                      wireSizeDescription: '2 - 14.0 mm² THHN',
                      conduitDescription: '25 mm Ø PVC',
                    ),
                  );

                  ProjectRepository.instance.updateProject(widget.project);
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('⚡ Subpanel $tag added successfully! Sub-feeder linked to Main Distribution Panel.'),
                    backgroundColor: BanaagTheme.successGreen,
                  ),
                );
              }
            },
            child: const Text('Add Subpanel', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _editCircuit(SldBranchCircuit circuit) {
    final descController = TextEditingController(text: circuit.description);
    final vaController = TextEditingController(text: circuit.loadVA.toStringAsFixed(0));
    int breaker = circuit.breakerRatingAmps;
    String wire = circuit.wireSizeDescription;
    String conduit = circuit.conduitDescription;

    final phaseMatch = RegExp(r'2\s*-\s*([0-9.]+)\s*mm').firstMatch(wire);
    double selectedWireMm2 = 3.5;
    if (phaseMatch != null) {
      selectedWireMm2 = double.tryParse(phaseMatch.group(1) ?? '3.5') ?? 3.5;
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
                        final egc = PecEngine.formatEquipmentGroundingConductor(breaker);
                        final wireSizeStr = selectedWireMm2.toStringAsFixed(1).replaceAll('.0', '');
                        wire = '2 - $wireSizeStr mm² THHN + 1 - $egc Ground';
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
                        final egc = PecEngine.formatEquipmentGroundingConductor(breaker);
                        final wireSizeStr = selectedWireMm2.toStringAsFixed(1).replaceAll('.0', '');
                        wire = '2 - $wireSizeStr mm² THHN + 1 - $egc Ground';
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

                  // Recompute Voltage Drop with edited parameters
                  final spec = PecEngine.wireSpecs.firstWhere(
                    (w) => w.sizeMm2 >= selectedWireMm2,
                    orElse: () => PecEngine.wireSpecs.first,
                  );
                  circuit.voltageDropPercent = PecEngine.computeVoltageDropPercent(
                    loadCurrentAmps: circuit.loadCurrentAmps,
                    oneWayLengthMeters: circuit.measuredRunMeters,
                    wireSpec: spec,
                  );
                  circuit.isUpsized = false;
                  circuit.upsizeReason = '';
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
        wireSizeDescription: '2 - 3.5 mm² THHN + 1 - 3.5 mm² Ground',
        conduitDescription: '20 mm Ø PVC',
        isSpare: false,
      ));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('⚡ Added Circuit C${_sldData.branchCircuits.length}! Tap to configure parameters.')),
    );
  }

  Future<void> _exportExcelBom() async {
    try {
      final takeoff = TakeoffEngine.calculate(
        points: widget.project.canvasPoints,
        routes: widget.project.conduitRoutes,
      );

      final bytes = BomExcelExporter.generateWorkbook(
        project: widget.project,
        sldData: _sldData,
        takeoff: takeoff,
      );

      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = widget.project.title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final file = File('${tempDir.path}/${sanitizedTitle}_BOM_and_Schedule_of_Loads.xlsx');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '📊 BANAAG Multi-Tab Excel BOM & Schedule of Loads Export: ${widget.project.title}\nCompliant with PEC 2017 Part 1.',
          subject: '${widget.project.title} - Excel BOM & Sched of Loads',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📊 3-Tab Excel Workbook generated successfully! (.xlsx)'),
            backgroundColor: BanaagTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel Export Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _exportBlueprintPdf() async {
    try {
      final bytes = await BlueprintPdfExporter.generateBlueprintPdf(
        project: widget.project,
        sldData: _sldData,
        sheetNumber: 'E-1',
        sheetTitle: 'SINGLE-LINE DIAGRAM & SCHEDULE OF LOADS',
      );

      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = widget.project.title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final file = File('${tempDir.path}/${sanitizedTitle}_Sheet_E1_Blueprint.pdf');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '📐 BANAAG Blueprint Vector PDF Export (Sheet E-1): ${widget.project.title}\nCompliant with PEC 2017 Part 1 & Title Block Specs.',
          subject: '${widget.project.title} - Sheet E-1 Blueprint PDF',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚡ Sheet E-1 Blueprint PDF generated! Ready for PEE Seal & Permitting.'),
            backgroundColor: BanaagTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF Export Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
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
            icon: const Icon(Icons.table_view_outlined, color: Colors.greenAccent),
            tooltip: 'Export Excel BOM & Sched of Loads (.xlsx)',
            onPressed: _exportExcelBom,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.cyanAccent),
            tooltip: 'Export Blueprint PDF Sheet E-1 (A1/20x30)',
            onPressed: _exportBlueprintPdf,
          ),
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
      body: Column(
        children: [
          // Dynamic Multi-Panel Switcher Bar (MDP / Subpanels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFF141922),
            child: Row(
              children: [
                const Icon(Icons.domain, color: BanaagTheme.primaryAmber, size: 18),
                const SizedBox(width: 8),
                const Text('PANEL:', style: TextStyle(color: BanaagTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ..._panelsMap.entries.map((entry) {
                          final label = entry.key == 'MDP' ? 'MDP (Main)' : 'Panel ${entry.key}';
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: _buildPanelChip(label, entry.key, entry.value),
                          );
                        }),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 14, color: BanaagTheme.primaryAmber),
                          label: const Text('+ Subpanel', style: TextStyle(fontSize: 11, color: BanaagTheme.primaryAmber, fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.white10,
                          side: const BorderSide(color: BanaagTheme.primaryAmber, width: 0.8),
                          onPressed: _showAddSubpanelDialog,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSchematicView(),
                _buildScheduleOfLoadsView(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF1B2028),
            border: Border(top: BorderSide(color: BanaagTheme.surfaceCardBorder, width: 1)),
          ),
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
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isApproved ? BanaagTheme.successGreen : BanaagTheme.primaryAmber,
                  foregroundColor: Colors.black,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: Icon(_isApproved ? Icons.check : Icons.done_all, size: 16),
                label: Text(_isApproved ? 'APPROVED ✅' : 'APPROVE SLD', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: _markApproved,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanelChip(String label, String key, SingleLineDiagramData data) {
    final isSelected = _activePanelKey == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: BanaagTheme.primaryAmber,
      backgroundColor: Colors.white10,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11,
      ),
      onSelected: (val) {
        if (val) {
          setState(() {
            _activePanelKey = key;
            _sldData = data;
          });
        }
      },
    );
  }

  final TransformationController _transformController = TransformationController();

  Widget _buildSchematicView() {
    final canvasWidth = 760.0;
    final canvasHeight = 240.0 + (_sldData.branchCircuits.length * 84.0);
    return Stack(
      children: [
        InteractiveViewer(
          transformationController: _transformController,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(80.0),
          minScale: 0.25,
          maxScale: 3.5,
          child: Container(
            width: canvasWidth,
            height: canvasHeight,
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            color: const Color(0xFF0D1117), // Blueprint dark CAD canvas
            child: CustomPaint(
              size: Size(canvasWidth - 40, canvasHeight - 48),
              painter: SldSchematicPainter(
                sldData: _sldData,
                onCircuitTap: _editCircuit,
              ),
            ),
          ),
        ),
        // Floating Zoom & Reset Toolbar
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1B2028).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.zoom_out, color: Colors.white, size: 20),
                  tooltip: 'Zoom Out',
                  onPressed: () {
                    final Matrix4 current = _transformController.value;
                    // ignore: deprecated_member_use
                    _transformController.value = current.clone()..scale(0.80, 0.80);
                  },
                ),
                Container(width: 1, height: 20, color: Colors.white12),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.fit_screen, color: BanaagTheme.primaryAmber, size: 16),
                  label: const Text('FIT', style: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final targetScale = (screenWidth / 780.0).clamp(0.40, 1.0);
                    // ignore: deprecated_member_use
                    _transformController.value = Matrix4.identity()..scale(targetScale, targetScale);
                  },
                ),
                Container(width: 1, height: 20, color: Colors.white12),
                IconButton(
                  icon: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                  tooltip: 'Zoom In',
                  onPressed: () {
                    final Matrix4 current = _transformController.value;
                    // ignore: deprecated_member_use
                    _transformController.value = current.clone()..scale(1.25, 1.25);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
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
            final bool isVdPass = c.voltageDropPercent <= 3.0;
            final Color vdColor = c.isUpsized
                ? BanaagTheme.primaryAmber
                : (isVdPass ? BanaagTheme.successGreen : BanaagTheme.alertRed);

            return Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              decoration: BoxDecoration(
                color: c.isSpare ? Colors.white.withValues(alpha: 0.03) : BanaagTheme.surfaceCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: c.isUpsized
                      ? BanaagTheme.primaryAmber.withValues(alpha: 0.5)
                      : (c.isSpare ? Colors.white12 : BanaagTheme.surfaceCardBorder),
                ),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                leading: CircleAvatar(
                  backgroundColor: c.isSpare ? Colors.grey.shade800 : BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                  child: Text('C${c.circuitNumber}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.isSpare ? Colors.white54 : BanaagTheme.primaryAmber)),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.description,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: c.isSpare ? BanaagTheme.textMuted : Colors.white),
                      ),
                    ),
                    if (!c.isSpare) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: vdColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: vdColor.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          c.isUpsized
                              ? 'VD: ${c.voltageDropPercent.toStringAsFixed(1)}% [UPSIZED]'
                              : 'VD: ${c.voltageDropPercent.toStringAsFixed(1)}% [PASS]',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: vdColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 3),
                    Text(
                      '${c.loadVA.toStringAsFixed(0)} VA @ 230V • ${c.loadCurrentAmps.toStringAsFixed(2)}A • ${c.breakerRatingAmps}A 2P Breaker',
                      style: const TextStyle(fontSize: 11, color: BanaagTheme.textMuted),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Wire: ${c.wireSizeDescription} in ${c.conduitDescription}',
                            style: const TextStyle(fontSize: 10, color: BanaagTheme.primaryAmber),
                          ),
                        ),
                        if (!c.isSpare)
                          Text(
                            '3D Run: ${c.measuredRunMeters.toStringAsFixed(1)}m',
                            style: const TextStyle(fontSize: 10, color: Colors.white60, fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                    if (c.isUpsized && c.upsizeReason.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: BanaagTheme.primaryAmber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.bolt, size: 12, color: BanaagTheme.primaryAmber),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                c.upsizeReason,
                                style: const TextStyle(fontSize: 9.5, color: BanaagTheme.primaryAmber, height: 1.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

    final textStyle = const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace');
    final amberStyle = const TextStyle(color: BanaagTheme.primaryAmber, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace');
    final mutedStyle = const TextStyle(color: BanaagTheme.textMuted, fontSize: 11, fontFamily: 'monospace');

    // Draw Subtle Engineering CAD Grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1.0;
    for (double x = 0; x < size.width; x += 40.0) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 1. Service Drop (Top)
    const double centerX = 220.0;
    double curY = 36.0;

    _drawText(canvas, '⚡ OVERHEAD SERVICE ENTRANCE (${sldData.utilityProvider})', 30, curY - 20, amberStyle);
    _drawText(canvas, '230V AC, 1-PHASE, 2-WIRE, 60 Hz • PEC COMPLIANT', 30, curY - 4, mutedStyle);

    canvas.drawLine(const Offset(centerX, 20), Offset(centerX, curY + 28), linePaint);
    curY += 28;

    // 2. Kilowatt-Hour Meter (Circle)
    final meterCenter = Offset(centerX, curY + 30);
    final meterPaint = Paint()
      ..color = const Color(0xFF1E2430)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(meterCenter, 26, meterPaint);
    canvas.drawCircle(meterCenter, 26, linePaint);
    _drawText(canvas, 'kWh', meterCenter.dx - 12, meterCenter.dy - 7, amberStyle);
    _drawText(canvas, 'REVENUE METER', meterCenter.dx + 38, meterCenter.dy - 7, textStyle);

    curY += 56;
    canvas.drawLine(Offset(centerX, curY), Offset(centerX, curY + 28), linePaint);
    curY += 28;

    // 3. Main Circuit Breaker (MCB) Box
    final mcbRect = Rect.fromCenter(center: Offset(centerX, curY + 22), width: 84, height: 44);
    canvas.drawRect(mcbRect, Paint()..color = const Color(0xFF232A36));
    canvas.drawRect(mcbRect, Paint()..color = BanaagTheme.primaryAmber..style = PaintingStyle.stroke..strokeWidth = 2);
    _drawText(canvas, '${sldData.feeder.mainBreakerAmps}A', mcbRect.center.dx - 16, mcbRect.center.dy - 7, amberStyle);

    // Feeder labels
    _drawText(canvas, 'MAIN CB: ${sldData.feeder.mainBreakerDescription}', centerX + 56, mcbRect.top + 4, textStyle);
    _drawText(canvas, 'FEEDER: ${sldData.feeder.feederWireDescription} in ${sldData.feeder.conduitDescription}', centerX + 56, mcbRect.top + 22, mutedStyle);

    curY += 44;
    canvas.drawLine(Offset(centerX, curY), Offset(centerX, curY + 28), linePaint);
    curY += 28;

    // 4. Main Panelboard LP-1 Vertical Busbar
    final double busbarTop = curY;
    final double busbarSpacing = 78.0;
    final double busbarHeight = sldData.branchCircuits.length * busbarSpacing;
    final double busbarBottom = busbarTop + busbarHeight;

    canvas.drawLine(Offset(centerX, busbarTop), Offset(centerX, busbarBottom), busPaint);
    _drawText(canvas, 'PANEL: ${sldData.panelName}', 30, busbarTop - 14, amberStyle);

    // Ground Busbar (Left side)
    const double groundX = centerX - 70;
    canvas.drawLine(Offset(groundX, busbarTop + 10), Offset(groundX, busbarBottom - 10), groundPaint);
    _drawText(canvas, 'GROUND BUS', groundX - 90, busbarTop + 14, const TextStyle(color: BanaagTheme.successGreen, fontSize: 10, fontWeight: FontWeight.bold));

    // Ground Electrode connection to earth
    canvas.drawLine(Offset(groundX, busbarBottom - 10), Offset(groundX, busbarBottom + 30), groundPaint);
    _drawGroundSymbol(canvas, Offset(groundX, busbarBottom + 30));
    _drawText(canvas, sldData.feeder.groundingDescription, groundX + 12, busbarBottom + 26, mutedStyle);

    // 5. Branch Circuits Sprouting from Busbar to the Right
    double branchY = busbarTop + 24;
    for (int i = 0; i < sldData.branchCircuits.length; i++) {
      final c = sldData.branchCircuits[i];

      // Branch tap line from busbar
      canvas.drawLine(Offset(centerX, branchY), Offset(centerX + 40, branchY), linePaint);

      // Branch Breaker rectangle
      final bRect = Rect.fromCenter(center: Offset(centerX + 68, branchY), width: 50, height: 28);
      final bPaint = Paint()
        ..color = c.isSpare ? Colors.grey.shade900 : const Color(0xFF222938)
        ..style = PaintingStyle.fill;
      canvas.drawRect(bRect, bPaint);
      canvas.drawRect(bRect, Paint()..color = c.isSpare ? Colors.white30 : Colors.white70..style = PaintingStyle.stroke..strokeWidth = 1.8);
      _drawText(canvas, '${c.breakerRatingAmps}A', bRect.center.dx - 12, bRect.center.dy - 6, TextStyle(color: c.isSpare ? Colors.white54 : BanaagTheme.primaryAmber, fontSize: 11, fontWeight: FontWeight.bold));

      // Homerun line extending right
      canvas.drawLine(Offset(bRect.right, branchY), Offset(bRect.right + 35, branchY), linePaint);

      // Homerun arrow
      _drawHomerunArrow(canvas, Offset(bRect.right + 35, branchY));

      // Branch Labels
      _drawText(canvas, 'C${c.circuitNumber}: ${c.description}', bRect.right + 48, branchY - 14, TextStyle(color: c.isSpare ? BanaagTheme.textMuted : Colors.white, fontWeight: FontWeight.bold, fontSize: 12));
      _drawText(canvas, '${c.wireSizeDescription} in ${c.conduitDescription}', bRect.right + 48, branchY + 1, mutedStyle);

      if (!c.isSpare) {
        final vdStyle = TextStyle(
          color: c.isUpsized
              ? BanaagTheme.primaryAmber
              : (c.voltageDropPercent <= 3.0 ? BanaagTheme.successGreen : BanaagTheme.alertRed),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        );
        final String tag = c.isUpsized ? ' [UPSIZED]' : ' [PASS]';
        _drawText(
          canvas,
          'VD: ${c.voltageDropPercent.toStringAsFixed(1)}%$tag • 3D Run: ${c.measuredRunMeters.toStringAsFixed(1)}m',
          bRect.right + 48,
          branchY + 16,
          vdStyle,
        );
      }

      branchY += busbarSpacing;
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
