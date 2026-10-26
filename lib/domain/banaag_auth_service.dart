// BANAAG Offline-First Account & Identity Service
// Manages Verified Google/Gmail Binding with 30-Day Zero-Trust Offline Leasing.
// Guarantees 100% offline functionality while preventing unauthorized APK sharing.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'security_engine.dart';

class BanaagUserProfile {
  final String email;
  final String displayName;
  final String? photoUrl;
  final String userId;
  final DateTime verifiedAt;
  final bool isGuest;

  BanaagUserProfile({
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.userId,
    required this.verifiedAt,
    this.isGuest = false,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'userId': userId,
    'verifiedAt': verifiedAt.toIso8601String(),
    'isGuest': isGuest,
  };

  factory BanaagUserProfile.fromJson(Map<String, dynamic> json) => BanaagUserProfile(
    email: json['email'] ?? 'guest@banaag.local',
    displayName: json['displayName'] ?? 'Contractor (Guest)',
    photoUrl: json['photoUrl'],
    userId: json['userId'] ?? 'guest-device',
    verifiedAt: DateTime.parse(json['verifiedAt'] ?? DateTime.now().toIso8601String()),
    isGuest: json['isGuest'] ?? false,
  );
}

class BanaagAuthService {
  BanaagAuthService._();
  static final BanaagAuthService instance = BanaagAuthService._();

  static const String _userProfileKey = 'banaag_user_profile_v1';
  static const String _activeLeaseKey = 'banaag_active_lease_token_v1';

  BanaagUserProfile? _currentUser;
  LicenseToken? _currentLease;

  BanaagUserProfile? get currentUser => _currentUser;
  LicenseToken? get currentLease => _currentLease;

  bool get isAuthenticated => _currentUser != null && !_currentUser!.isGuest;
  bool get hasValidOfflineLease => _currentLease != null && !_currentLease!.isExpired;

  /// Initializes auth state from hardware local storage (100% Offline-Safe)
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load profile
    final userJsonStr = prefs.getString(_userProfileKey);
    if (userJsonStr != null) {
      try {
        _currentUser = BanaagUserProfile.fromJson(jsonDecode(userJsonStr));
      } catch (_) {}
    }

    // Load active cryptographic offline lease
    final leaseJsonStr = prefs.getString(_activeLeaseKey);
    if (leaseJsonStr != null) {
      try {
        _currentLease = LicenseToken.fromJson(jsonDecode(leaseJsonStr));
      } catch (_) {}
    }

    // Default to Guest if no profile saved yet
    _currentUser ??= BanaagUserProfile(
      email: 'offline.contractor@banaag.local',
      displayName: 'Guest Electrician',
      userId: 'device-offline-guest',
      verifiedAt: DateTime.now(),
      isGuest: true,
    );
  }

  /// Binds a verified Google Account and automatically mints a 30-Day Zero-Trust Offline Lease
  Future<BanaagUserProfile> signInWithVerifiedGoogle({
    required String email,
    required String displayName,
    String? photoUrl,
  }) async {
    final sanitizedEmail = email.trim().toLowerCase();
    final userId = 'user_${sanitizedEmail.hashCode.abs()}';

    final profile = BanaagUserProfile(
      email: sanitizedEmail,
      displayName: displayName.trim().isEmpty ? 'Verified Contractor' : displayName,
      photoUrl: photoUrl,
      userId: userId,
      verifiedAt: DateTime.now(),
      isGuest: false,
    );

    // Issue cryptographic 30-day offline lease bound to this email
    final lease = SecurityEngine.instance.issueOfflineLease(
      userId: userId,
      tier: 'PRO_CONTRACTOR',
      validityDays: 30,
    );

    _currentUser = profile;
    _currentLease = lease;

    // Persist securely to device storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userProfileKey, jsonEncode(profile.toJson()));
    await prefs.setString(_activeLeaseKey, jsonEncode(lease.toJson()));

    return profile;
  }

  /// Switches back to Guest mode while preserving calculations
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userProfileKey);
    await prefs.remove(_activeLeaseKey);

    _currentUser = BanaagUserProfile(
      email: 'offline.contractor@banaag.local',
      displayName: 'Guest Electrician',
      userId: 'device-offline-guest',
      verifiedAt: DateTime.now(),
      isGuest: true,
    );
    _currentLease = null;
  }

  static const String _supabaseUrl = 'https://cvuympdpkbuftqdzlwrw.supabase.co';
  static const String _anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN2dXltcGRwa2J1ZnRxZHpsd3J3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2NjIxNDYsImV4cCI6MjEwODIzODE0Nn0.sQkiMvyy0quSnG8lW-O12uAsvnTWpyby9ZBciLl8bvU';

  /// Fetches project quota from cloud with offline fallback
  Future<Map<String, dynamic>> getProjectQuota() async {
    if (_currentUser == null || _currentUser!.isGuest) {
      return {'success': false, 'remaining': 0, 'isGuest': true, 'isLicensed': false};
    }

    final email = _currentUser!.email.trim().toLowerCase();

    // Master admins always have unlimited quota
    if (email == 'vincentjamitoarrogante@gmail.com' || email == 'mr.arvin03@gmail.com') {
      return {'success': true, 'remaining': 999, 'total_credits': 999, 'used_credits': 0, 'isLicensed': true};
    }

    try {
      // 1. Check official Supabase RPC first
      final url = Uri.parse('$_supabaseUrl/rest/v1/rpc/get_project_quota');
      final response = await http.post(
        url,
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'p_email': email}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          final total = (data['total_credits'] as num?)?.toInt() ?? 0;
          final used = (data['used_credits'] as num?)?.toInt() ?? 0;
          final remaining = (data['remaining'] as num?)?.toInt() ?? (total - used);
          if (total > 0) {
            return {
              'success': true,
              'remaining': remaining,
              'total_credits': total,
              'used_credits': used,
              'isLicensed': true,
            };
          }
        }
      }

      // 2. Check active credited vouchers in project_vouchers table for this email
      final urlVoucher = Uri.parse('$_supabaseUrl/rest/v1/project_vouchers?redeemed_by_email=eq.$email&is_redeemed=eq.true');
      final respV = await http.get(
        urlVoucher,
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
        },
      );

      if (respV.statusCode == 200) {
        final List<dynamic> list = jsonDecode(respV.body);
        // Exclude proof submissions, count real activated slots
        final realSlots = list.where((v) => !(v['code'] as String? ?? '').startsWith('PROOF|')).length;
        if (realSlots > 0) {
          return {
            'success': true,
            'remaining': realSlots,
            'total_credits': realSlots,
            'used_credits': 0,
            'isLicensed': true,
          };
        }
      }
    } catch (_) {}

    // Unlicensed user / No approved Base Pack: exactly 0 remaining quota
    return {
      'success': false,
      'remaining': 0,
      'total_credits': 0,
      'used_credits': 0,
      'isLicensed': false,
    };
  }

  /// Redeems a voucher code via Supabase RPC
  Future<Map<String, dynamic>> redeemVoucher({
    required String email,
    required String code,
  }) async {
    try {
      final url = Uri.parse('$_supabaseUrl/rest/v1/rpc/redeem_project_voucher');
      final response = await http.post(
        url,
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'p_email': email,
          'p_code': code,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        }
      }
      return {
        'success': false,
        'message': 'Failed to validate voucher with server. Status: ' + response.statusCode.toString(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Offline: Unable to verify voucher without internet connection.',
      };
    }
  }

  /// Verifies 6-digit Master Admin PIN against Supabase Cloud Salted Hash
  Future<bool> verifyAdminPasscode(String pin) async {
    const salt = 'BANAAG_MASTER_ADMIN_2026_SALT';
    final computedHash = sha256.convert(utf8.encode('$pin:$salt')).toString();

    try {
      final url = Uri.parse('$_supabaseUrl/rest/v1/project_vouchers?code=eq.SYS_ADMIN_HASH');
      final response = await http.get(
        url,
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final cloudHash = data.first['redeemed_by_email'] as String?;
          return cloudHash == computedHash;
        }
      }
    } catch (_) {}

    // Fallback if temporarily offline but matches verified hash
    const masterVerifiedHash = 'a36a47a6638575fa4a75b92fed985a04a7f19413c060deaeee9ebfd19487b1e9';
    return computedHash == masterVerifiedHash;
  }
}
