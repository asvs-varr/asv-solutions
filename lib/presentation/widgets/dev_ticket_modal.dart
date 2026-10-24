// BANAAG Dev Ticket Modal BottomSheet
// Clean, developer-friendly ticket submission and queue management

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/dev_ticket.dart';
import '../../data/dev_ticket_repository.dart';
import '../theme/banaag_theme.dart';

void showDevTicketSheet(BuildContext context, {String? projectContext}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF161922),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => DevTicketModalContent(projectContext: projectContext),
  );
}

class DevTicketModalContent extends StatefulWidget {
  final String? projectContext;
  const DevTicketModalContent({super.key, this.projectContext});

  @override
  State<DevTicketModalContent> createState() => _DevTicketModalContentState();
}

class _DevTicketModalContentState extends State<DevTicketModalContent> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _selectedType = 'fix'; // 'fix' | 'remove' | 'add' | 'note'
  String _selectedPriority = 'medium'; // 'low' | 'medium' | 'high'
  bool _showListView = false;
  List<DevTicket> _tickets = [];
  bool _isLoading = true;
  final List<String> _attachedImagePaths = [];

  final Map<String, Map<String, dynamic>> _typeMeta = {
    'fix': {
      'label': 'BUG',
      'icon': Icons.bug_report_outlined,
      'color': Colors.redAccent,
    },
    'remove': {
      'label': 'IMPROVE',
      'icon': Icons.tune_rounded,
      'color': Colors.orangeAccent,
    },
    'add': {
      'label': 'FEATURE',
      'icon': Icons.add_circle_outline,
      'color': Colors.tealAccent,
    },
    'note': {
      'label': 'NOTE',
      'icon': Icons.lightbulb_outline,
      'color': Colors.amberAccent,
    },
  };

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    final list = await DevTicketRepository.instance.getTickets();
    if (mounted) {
      setState(() {
        _tickets = list;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Title for the Engineering Dev Ticket')),
      );
      return;
    }

    final newTicket = DevTicket(
      id: 'TKT-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: _descController.text.trim(),
      type: _selectedType,
      priority: _selectedPriority,
      createdAt: DateTime.now(),
      status: 'open',
      projectContext: widget.projectContext,
      imageUris: List<String>.from(_attachedImagePaths),
    );

    await DevTicketRepository.instance.saveTicket(newTicket);
    await _loadTickets();

    _titleController.clear();
    _descController.clear();
    _attachedImagePaths.clear();

    if (mounted) {
      setState(() {
        _showListView = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('âœ… Dev Ticket recorded in local engineering queue!'),
          backgroundColor: BanaagTheme.successGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          padding: const EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Queue Switcher
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.confirmation_number_outlined, color: BanaagTheme.primaryAmber, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Submit Dev Ticket',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                          Text(
                            widget.projectContext != null
                                ? 'Context: ${widget.projectContext}'
                                : 'Log bug, feature request o code tweak',
                            style: const TextStyle(fontSize: 11, color: BanaagTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: BanaagTheme.surfaceCard,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: Icon(_showListView ? Icons.add_comment : Icons.list_alt, size: 16),
                    label: Text(
                      _showListView ? 'New Ticket' : 'Queue (${_tickets.where((t) => t.status == 'open').length})',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => setState(() => _showListView = !_showListView),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: _showListView ? _buildQueueView() : _buildCreateForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _typeMeta.entries.map((entry) {
              final isSelected = _selectedType == entry.key;
              final color = entry.value['color'] as Color;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(entry.value['icon'] as IconData, size: 16, color: isSelected ? Colors.black : color),
                  label: Text(entry.value['label'] as String),
                  selected: isSelected,
                  selectedColor: color,
                  backgroundColor: BanaagTheme.surfaceCard,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedType = entry.key);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Priority Row
        Row(
          children: [
            const Text('Priority:', style: TextStyle(fontSize: 12, color: BanaagTheme.textMuted)),
            const SizedBox(width: 8),
            for (final p in ['low', 'medium', 'high'])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => setState(() => _selectedPriority = p),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _selectedPriority == p
                          ? (p == 'high'
                              ? Colors.redAccent.withValues(alpha: 0.25)
                              : BanaagTheme.primaryAmber.withValues(alpha: 0.25))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _selectedPriority == p
                            ? (p == 'high' ? Colors.redAccent : BanaagTheme.primaryAmber)
                            : Colors.white24,
                      ),
                    ),
                    child: Text(
                      p.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _selectedPriority == p ? Colors.white : Colors.white54,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Title Input
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Ticket Title',
            hintText: 'e.g., Incorrect OCPD breaker rating for ACU feeder...',
            filled: true,
            fillColor: BanaagTheme.surfaceCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),

        // Description Input
        TextField(
          controller: _descController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Description / Technical Scope (Optional)',
            hintText: 'Technical details of required modification, PEC rule basis, or bug reproduction...',
            filled: true,
            fillColor: BanaagTheme.surfaceCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),

        // Multiple Image Attachments Header & Pickers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.attach_file, size: 16, color: BanaagTheme.primaryAmber),
                const SizedBox(width: 6),
                Text(
                  'Screenshots & Photos (${_attachedImagePaths.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined, size: 20, color: BanaagTheme.primaryAmber),
                  tooltip: 'Take Photo with Camera',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    final picker = ImagePicker();
                    final photo = await picker.pickImage(source: ImageSource.camera);
                    if (photo != null) {
                      setState(() {
                        _attachedImagePaths.add(photo.path);
                      });
                    }
                  },
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BanaagTheme.primaryAmber,
                    side: const BorderSide(color: BanaagTheme.primaryAmber),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 15),
                  label: const Text('Add Images', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final picker = ImagePicker();
                    final List<XFile> images = await picker.pickMultiImage();
                    if (images.isNotEmpty) {
                      setState(() {
                        _attachedImagePaths.addAll(images.map((img) => img.path));
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),

        // Image Thumbnails Carousel Preview with Remove (X) Button
        if (_attachedImagePaths.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 74,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _attachedImagePaths.length,
              itemBuilder: (ctx, i) {
                final path = _attachedImagePaths[i];
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8, top: 4),
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.6)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: GestureDetector(
                        onTap: () => _showFullscreenImage(context, path),
                        child: Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Center(
                            child: Icon(Icons.broken_image, size: 24, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _attachedImagePaths.removeAt(i);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: BanaagTheme.primaryAmber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('SUBMIT DEV TICKET', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _submitTicket,
          ),
        ),
      ],
    );
  }

  Widget _buildQueueView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tickets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text('No pending engineering dev tickets found.', style: TextStyle(color: BanaagTheme.textMuted)),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _tickets.length,
        itemBuilder: (context, index) {
          final t = _tickets[index];
          final meta = _typeMeta[t.type] ?? _typeMeta['fix']!;
          final color = meta['color'] as Color;
          final isOpen = t.status == 'open';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BanaagTheme.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isOpen ? color.withValues(alpha: 0.4) : Colors.white12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(meta['icon'] as IconData, size: 20, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              t.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isOpen ? Colors.white : Colors.white54,
                                decoration: isOpen ? null : TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOpen ? color.withValues(alpha: 0.15) : Colors.white10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isOpen ? t.priority.toUpperCase() : 'RESOLVED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isOpen ? color : Colors.white38,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (t.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          t.description,
                          style: const TextStyle(fontSize: 11, color: BanaagTheme.textMuted),
                        ),
                      ],
                      if (t.imageUris.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 44,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: t.imageUris.length,
                            itemBuilder: (ctx, imgIdx) {
                              final imgPath = t.imageUris[imgIdx];
                              return GestureDetector(
                                onTap: () => _showFullscreenImage(context, imgPath),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.file(
                                    File(imgPath),
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 16, color: Colors.grey),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(isOpen ? Icons.check_circle_outline : Icons.replay, size: 18),
                  color: isOpen ? BanaagTheme.successGreen : Colors.white38,
                  onPressed: () async {
                    await DevTicketRepository.instance.updateTicketStatus(
                      t.id,
                      isOpen ? 'resolved' : 'open',
                    );
                    _loadTickets();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFullscreenImage(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 6.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.black87,
                    child: const Text('Unable to load full image file.', style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
