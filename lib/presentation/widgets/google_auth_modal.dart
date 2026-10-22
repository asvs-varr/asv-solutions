// Interactive Google Account Binding Modal with Offline-First Leasing
import 'package:flutter/material.dart';
import '../../domain/banaag_auth_service.dart';

class GoogleAuthModal extends StatefulWidget {
  const GoogleAuthModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const GoogleAuthModal(),
    );
  }

  @override
  State<GoogleAuthModal> createState() => _GoogleAuthModalState();
}

class _GoogleAuthModalState extends State<GoogleAuthModal> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final current = BanaagAuthService.instance.currentUser;
    if (current != null && !current.isGuest) {
      _emailController.text = current.email;
      _nameController.text = current.displayName;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSignOut() async {
    await BanaagAuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || !email.contains('@') || !email.endsWith('.com')) {
      setState(() {
        _errorMessage = 'Please enter a valid Gmail / Google Account address.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Binds verified account and issues cryptographically signed 30-day offline lease
      await BanaagAuthService.instance.signInWithVerifiedGoogle(
        email: email,
        displayName: name.isEmpty ? email.split('@').first : name,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to bind account: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = BanaagAuthService.instance;
    final user = auth.currentUser;
    final isAlreadyBound = auth.isAuthenticated;

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
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_circle, color: Color(0xFF4285F4), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isAlreadyBound ? 'Verified Account' : 'Anti-Counterfeit Account Sync',
              style: const TextStyle(
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
                  Icon(Icons.offline_bolt_rounded, color: Color(0xFF38BDF8), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '100% Offline-First Protection: Linking your Gmail issues a cryptographically signed 30-Day Offline Lease. All calculations work anywhere without signal.',
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
            if (isAlreadyBound) ...[
              Center(
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Color(0xFFFFB300),
                      child: Icon(Icons.person, size: 36, color: Colors.black),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user?.displayName ?? 'Verified Contractor',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F2B1D),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF22C55E)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 14),
                          SizedBox(width: 6),
                          Text(
                            '30-Day Cryptographic Lease Active',
                            style: TextStyle(
                              color: Color(0xFF4ADE80),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                'Enter your primary Google / Gmail Account to bind your engineering license and enable automated offline backups:',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Engineer / Contractor Name',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0F121A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF232B3D)),
                  ),
                  prefixIcon: const Icon(Icons.badge, color: Color(0xFFFFB300), size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Gmail / Google Account',
                  hintText: 'engr.name@gmail.com',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0F121A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF232B3D)),
                  ),
                  prefixIcon: const Icon(Icons.alternate_email, color: Color(0xFFFFB300), size: 18),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (isAlreadyBound) ...[
          TextButton(
            onPressed: _handleSignOut,
            child: const Text('Sign Out (Guest Mode)', style: TextStyle(color: Color(0xFFEF4444))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue as Guest', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: Colors.black,
            ),
            icon: _isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.verified_user, size: 16),
            label: Text(_isLoading ? 'Securing...' : 'Bind & Activate Offline Lease'),
            onPressed: _isLoading ? null : _handleSignIn,
          ),
        ],
      ],
    );
  }
}






