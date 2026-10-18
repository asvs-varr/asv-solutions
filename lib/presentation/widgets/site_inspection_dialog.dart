import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../data/project_repository.dart';
import '../theme/banaag_theme.dart';

class SiteInspectionAssessmentDialog extends StatefulWidget {
  final Project project;
  final PhaseCheckItem checkItem;
  final VoidCallback onSaved;

  const SiteInspectionAssessmentDialog({
    super.key,
    required this.project,
    required this.checkItem,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required Project project,
    required PhaseCheckItem checkItem,
    required VoidCallback onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SiteInspectionAssessmentDialog(
        project: project,
        checkItem: checkItem,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<SiteInspectionAssessmentDialog> createState() => _SiteInspectionAssessmentDialogState();
}

class _SiteInspectionAssessmentDialogState extends State<SiteInspectionAssessmentDialog> {
  final Set<String> _selectedStructures = {};
  late TextEditingController _notesController;

  final List<Map<String, dynamic>> _structureOptions = [
    {
      'title': 'Concrete / CHB Masonry',
      'subtitle': 'Pader na hollow block o ibinuhos na poste at beam',
      'icon': Icons.foundation,
      'raceway': 'Schedule 40 Thick-Wall uPVC Pipe (Chipping & Embedment)',
      'box': 'Deep PVC Utility & Junction Box with Solvent Cement',
      'fastener': 'Masonry Tox #6/#8 + Stainless Steel Wood/Tox Screws',
      'codeRef': 'PEC 2017 Art 3.52: Rigid Polyvinyl Chloride Conduit (Type PVC)'
    },
    {
      'title': 'Timber / Wood Frame',
      'subtitle': 'Kahoy na kisame, trusses, o kahoy na partition walls',
      'icon': Icons.park,
      'raceway': 'Electrical Metallic Tubing (EMT) o Metal Clad (MC) Cable',
      'box': 'Galvanized Octagonal/Deep Metal Box (with ground screw)',
      'fastener': 'Wood Screws / Lag Screws with One-Hole Steel Straps',
      'codeRef': 'PEC 2017 Art 3.58 & Art 3.30: Metal Raceways in Combustible Framing'
    },
    {
      'title': 'Light Steel Frame / Drywall',
      'subtitle': 'Furring channels, stud partitions, o hardiflex ceiling',
      'icon': Icons.grid_view,
      'raceway': 'Flexible Metallic Conduit (FMC) o EMT na may Bushings',
      'box': 'Handy Metal Box na may Conduit Bushings at Locknuts',
      'fastener': 'Wafer Head Metal-to-Metal Drill Screws',
      'codeRef': 'PEC 2017 Art 3.48 & Art 3.0.1.4: Protection Against Physical Damage'
    },
    {
      'title': 'Exposed Industrial Ceiling',
      'subtitle': 'Bukas na bubong, steel trusses, slab soffit (Loft style)',
      'icon': Icons.roofing,
      'raceway': 'Intermediate Metal Conduit (IMC) o Hot-Dip Galvanized EMT',
      'box': 'Cast Metal Conduit Bodies (LB, LL, T) with Gasketed Covers',
      'fastener': 'Beam Clamps, Threaded Rods, Unistrut Channels & Caddy Clips',
      'codeRef': 'PEC 2017 Art 3.42 & Art 3.14: Boxes and Fittings for Exposed Rerouting'
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.project.siteStructure != null && widget.project.siteStructure!.structureTypes.isNotEmpty) {
      _selectedStructures.addAll(widget.project.siteStructure!.structureTypes);
      _notesController = TextEditingController(text: widget.project.siteStructure!.notes);
    } else {
      _selectedStructures.add('Concrete / CHB Masonry');
      _notesController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Map<String, String> _deriveRecommendations() {
    if (_selectedStructures.contains('Timber / Wood Frame')) {
      return {
        'raceway': 'Electrical Metallic Tubing (EMT) / Metal Clad (MC)',
        'box': 'Galvanized Deep Metal Box (Mandatory Ground Bonding)',
        'fastener': 'Zinc-Plated Wood Screws + Heavy-duty Conduit Straps',
        'citation': 'PEC 2017 Art 3.58 & Art 3.30: Mandatory metallic protection against fire in combustible wood framing.',
      };
    } else if (_selectedStructures.contains('Light Steel Frame / Drywall')) {
      return {
        'raceway': 'EMT / Flexible Metallic Conduit (FMC) with Anti-Short Bushings',
        'box': 'Steel Utility Box with Snap-in Grommets & Locknuts',
        'fastener': 'Self-Drilling Metal Screws (Wafer/Tek Screws)',
        'citation': 'PEC 2017 Art 3.0.1.4: Anti-short bushings required on steel stud penetrations to prevent wire abrasion.',
      };
    } else if (_selectedStructures.contains('Exposed Industrial Ceiling')) {
      return {
        'raceway': 'Heavy-duty Rigid EMT / IMC with Compression Fittings',
        'box': 'Cast Aluminum Conduit Bodies (FS/FD boxes) with Neoprene Gasket',
        'fastener': 'Steel Unistrut & Beam Clamps',
        'citation': 'PEC 2017 Art 3.42: High impact resistance and dust/moisture seal in exposed structural spans.',
      };
    }

    // Default: Concrete / CHB
    return {
      'raceway': 'Schedule 40 Thick-Wall Rigid uPVC Conduit (Deep Chipping)',
      'box': 'Deep PVC Utility Box & Junction Box with Solvent Weld',
      'fastener': 'Masonry Tox #6/#8 with Stainless Wood Screws & Tie Wires',
      'citation': 'PEC 2017 Art 3.52: Rigid Nonmetallic Conduit embedded in masonry poured walls.',
    };
  }

  void _saveAssessment() {
    final rec = _deriveRecommendations();
    final assessment = SiteStructureAssessment(
      structureTypes: _selectedStructures.toList(),
      racewayRecommendation: rec['raceway']!,
      boxRecommendation: rec['box']!,
      fastenerRecommendation: rec['fastener']!,
      notes: _notesController.text.trim(),
    );

    widget.project.siteStructure = assessment;
    widget.checkItem.isCompleted = true;
    widget.checkItem.notes = 'Structure: ${_selectedStructures.join(", ")} | Raceway: ${rec["raceway"]}';

    ProjectRepository.instance.updateProject(widget.project);
    widget.onSaved();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: BanaagTheme.successGreen, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Site Structure & Materials assessed: ${rec["raceway"]}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: BanaagTheme.surfaceCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rec = _deriveRecommendations();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: BanaagTheme.darkBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: BanaagTheme.primaryAmber, width: 2)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.home_work, color: BanaagTheme.primaryAmber, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Site Inspection & Material Assessor',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                          Text(
                            'PEC 2017 Compliant Structure-to-Material Engine',
                            style: TextStyle(color: BanaagTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: BanaagTheme.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: BanaagTheme.surfaceCardBorder),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Pumili ng Uri ng Istruktura sa Site:',
                      style: TextStyle(color: BanaagTheme.primaryAmber, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'I-tap ang naaayon na istraktura (maaaring pumili ng higit sa isa kung combination, e.g. Concrete ground floor + Timber 2nd floor).',
                      style: TextStyle(color: BanaagTheme.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 14),

                    // Structure Type Selection Cards
                    ..._structureOptions.map((opt) {
                      final bool isSelected = _selectedStructures.contains(opt['title']);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              if (_selectedStructures.length > 1) {
                                _selectedStructures.remove(opt['title']);
                              }
                            } else {
                              _selectedStructures.add(opt['title'] as String);
                            }
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1E2838) : BanaagTheme.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? BanaagTheme.primaryAmber : BanaagTheme.surfaceCardBorder,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                activeColor: BanaagTheme.primaryAmber,
                                checkColor: Colors.black,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedStructures.add(opt['title'] as String);
                                    } else if (_selectedStructures.length > 1) {
                                      _selectedStructures.remove(opt['title']);
                                    }
                                  });
                                },
                              ),
                              Icon(opt['icon'] as IconData, color: isSelected ? BanaagTheme.primaryAmber : BanaagTheme.textMuted, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      opt['title'] as String,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isSelected ? Colors.white : BanaagTheme.textHighEmphasis,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      opt['subtitle'] as String,
                                      style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 16),

                    // AI Material Recommendation Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF182230),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.6), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: BanaagTheme.primaryAmber, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Awtomatikong Material Assessment (PEC 2017)',
                                style: TextStyle(color: BanaagTheme.primaryAmber, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildRecRow(Icons.cable, 'Raceway / Conduit:', rec['raceway']!),
                          const SizedBox(height: 8),
                          _buildRecRow(Icons.check_box_outline_blank, 'Boxes / Fittings:', rec['box']!),
                          const SizedBox(height: 8),
                          _buildRecRow(Icons.hardware, 'Fasteners & Straps:', rec['fastener']!),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.menu_book, color: Colors.blueAccent, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    rec['citation']!,
                                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Site Notes
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Site Observation Notes (Optional)',
                        labelStyle: const TextStyle(color: BanaagTheme.textMuted, fontSize: 12),
                        hintText: 'e.g. Makapal ang plaster, kailangan ng 1-1/2" tox; ceiling is exposed steel trusses.',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                        filled: true,
                        fillColor: BanaagTheme.surfaceCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: BanaagTheme.surfaceCardBorder),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Confirm Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BanaagTheme.primaryAmber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text(
                        'I-APPLY MATERIAL ASSESSMENT & COMPLETE CHECK',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: _saveAssessment,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
