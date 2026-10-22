import 'package:flutter/material.dart';
import '../theme/banaag_theme.dart';
import '../../domain/banaag_auth_service.dart';

class ProjectQuotaVoucherModal extends StatefulWidget {
  final VoidCallback onTopUpSuccess;

  const ProjectQuotaVoucherModal({
    super.key,
    required this.onTopUpSuccess,
  });

  static Future<bool?> show(BuildContext context, {required VoidCallback onTopUpSuccess}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProjectQuotaVoucherModal(onTopUpSuccess: onTopUpSuccess),
    );
  }

  @override
  State<ProjectQuotaVoucherModal> createState() => _ProjectQuotaVoucherModalState();
}

class _ProjectQuotaVoucherModalState extends State<ProjectQuotaVoucherModal> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleRedeem() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter your 6-character voucher code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = BanaagAuthService.instance;
    final userEmail = auth.currentUser?.email ?? '';

    if (userEmail.isEmpty || auth.currentUser?.isGuest == true) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please link a verified Google account before redeeming vouchers.';
      });
      return;
    }

    final result = await auth.redeemVoucher(
      email: userEmail,
      code: code,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result['message'] ?? 'Top-Up Successful! +1 Project Slot added.',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
      widget.onTopUpSuccess();
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['message'] ?? 'Invalid or expired voucher code.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF141822),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF232B3D)),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_clock, color: BanaagTheme.primaryAmber, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Project Quota Reached',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Notice box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2638),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Lifetime Project Slot Policy: 1 project is included with your Base License. Additional student project floor plans require an instant ₱50 project unlock voucher.',
                      style: TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Have an activation voucher code? Enter it below:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
              decoration: InputDecoration(
                labelText: '6-Character Voucher Code',
                hintText: 'e.g. SLOT-1021',
                hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13, letterSpacing: 1),
                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF0F121A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF232B3D)),
                ),
                prefixIcon: const Icon(Icons.confirmation_number_outlined, color: BanaagTheme.primaryAmber, size: 20),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Contact Admin / GCash Info Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F121A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF232B3D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need a ₱50 Project Top-Up Code?',
                    style: TextStyle(color: BanaagTheme.primaryAmber, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'GCash ₱50 to 0912-345-6789 (ASV Solutions). Send screenshot to get your instant voucher code.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: BanaagTheme.primaryAmber,
            foregroundColor: Colors.black,
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Icon(Icons.bolt, size: 16),
          label: Text(_isLoading ? 'Verifying...' : 'Unlock Project Slot'),
          onPressed: _isLoading ? null : _handleRedeem,
        ),
      ],
    );
  }
}
