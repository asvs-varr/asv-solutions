// BANAAG GCash Payment & Screenshot Upload Modal
// Allows contractors to pay via GCash (0976 041 8794 - VINCENT A.)
// and submit their transaction reference number and receipt screenshot.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/banaag_auth_service.dart';
import '../../data/payment_repository.dart';

class GcashPaymentModal extends StatefulWidget {
  final String packageType; // 'BASE_PACK_100' or 'TOPUP_50'
  final VoidCallback? onPaymentSuccess;

  const GcashPaymentModal({
    super.key,
    this.packageType = 'BASE_PACK_100',
    this.onPaymentSuccess,
  });

  static Future<bool?> show(
    BuildContext context, {
    String packageType = 'BASE_PACK_100',
    VoidCallback? onPaymentSuccess,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => GcashPaymentModal(
        packageType: packageType,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  @override
  State<GcashPaymentModal> createState() => _GcashPaymentModalState();
}

class _GcashPaymentModalState extends State<GcashPaymentModal> {
  final _refController = TextEditingController();
  String? _selectedImagePath;
  bool _isSubmitting = false;
  String? _statusMessage;
  bool _isPendingReview = false;

  static const String _gcashNumber = '09760418794';
  static const String _gcashName = 'VINCENT A.';

  @override
  void initState() {
    super.initState();
    _checkExistingSubmission();
  }

  Future<void> _checkExistingSubmission() async {
    final user = BanaagAuthService.instance.currentUser;
    if (user == null || user.isGuest) return;

    final submissions = await PaymentRepository.instance.getSubmissions();
    final pending = submissions.where((s) => s.email == user.email && s.status == 'PENDING').toList();
    if (pending.isNotEmpty && mounted) {
      setState(() {
        _isPendingReview = true;
        _refController.text = pending.first.referenceNo;
        _selectedImagePath = pending.first.localReceiptPath;
      });
    }
  }

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: source, imageQuality: 85);
    if (photo != null && mounted) {
      setState(() {
        _selectedImagePath = photo.path;
      });
    }
  }

  Future<void> _handleSubmit() async {
    final user = BanaagAuthService.instance.currentUser;
    if (user == null || user.isGuest) {
      setState(() {
        _statusMessage = '⚠️ Please bind your Google Account before submitting payment.';
      });
      return;
    }

    final refNo = _refController.text.trim();
    if (refNo.isEmpty) {
      setState(() {
        _statusMessage = '⚠️ Please enter the GCash Reference Number from your receipt.';
      });
      return;
    }

    if (_selectedImagePath == null || !File(_selectedImagePath!).existsSync()) {
      setState(() {
        _statusMessage = '⚠️ Please attach your GCash payment screenshot.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    try {
      await PaymentRepository.instance.submitPayment(
        email: user.email,
        packageType: widget.packageType,
        referenceNo: refNo,
        localReceiptPath: _selectedImagePath!,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isPendingReview = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'GCash payment submitted! Admin will verify and activate your slot shortly.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _statusMessage = 'Failed to submit: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBasePack = widget.packageType == 'BASE_PACK_100';
    final amount = isBasePack ? '₱100.00' : '₱50.00';
    final title = isBasePack ? 'Contractor Base Pack' : 'Project Slot Top-Up';
    final subtitle = isBasePack
        ? '1 Verified Google Account • 1-Device Offline License • 1 Full Building Plan'
        : '+1 Additional Full Building / Project Slot';

    return AlertDialog(
      backgroundColor: const Color(0xFF141822),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF232B3D)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.all(20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF007DFE).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_wallet, color: Color(0xFF007DFE), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  amount,
                  style: const TextStyle(color: Color(0xFF00E676), fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 16),

            // GCash Details Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2638),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF007DFE).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.qr_code_2, color: Color(0xFF38BDF8), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'GCash Transfer Details',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007DFE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('OFFICIAL', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF2A364F), height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Account Name:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      Text(_gcashName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('GCash Number:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      Row(
                        children: [
                          const Text(
                            '0976 041 8794',
                            style: TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(const ClipboardData(text: _gcashNumber));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied GCash number to clipboard!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.copy, color: Color(0xFF38BDF8), size: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pending Status Notice (if already submitted)
            if (_isPendingReview) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_top, color: Colors.amber, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Receipt submitted! Your payment is currently under admin verification. Your slot will automatically activate once confirmed.',
                        style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Reference Number Input
            const Text(
              'GCash Reference Number',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _refController,
              enabled: !_isPendingReview,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. 9012 3456 7890',
                hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF0D111A),
                prefixIcon: const Icon(Icons.receipt_long, color: Color(0xFF64748B), size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),

            // Screenshot Upload Section
            const Text(
              'Payment Screenshot Proof',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            if (_selectedImagePath != null && File(_selectedImagePath!).existsSync()) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  color: Colors.black26,
                  child: Stack(
                    children: [
                      Center(
                        child: Image.file(
                          File(_selectedImagePath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                      if (!_isPendingReview)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: InkWell(
                            onTap: () => setState(() => _selectedImagePath = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF2A364F)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _pickReceipt(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library, size: 16),
                      label: const Text('Gallery', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF2A364F)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _pickReceipt(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label: const Text('Camera', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],

            if (_statusMessage != null) ...[
              const SizedBox(height: 10),
              Text(_statusMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
        ),
        if (!_isPendingReview)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007DFE),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: _isSubmitting ? null : _handleSubmit,
            child: _isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit Payment Proof', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
      ],
    );
  }
}
