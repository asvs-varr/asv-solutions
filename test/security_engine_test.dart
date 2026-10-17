// BANAAG Security Engine Tests
// Verifies Zero-Trust Cryptographic Token Verification & Anti-MOD tamper protection

import 'package:flutter_test/flutter_test.dart';
import 'package:banaag/domain/security_engine.dart';

void main() {
  group('BANAAG Security & Anti-MOD Engine Tests', () {
    final engine = SecurityEngine.instance;

    test('Issues valid signed 30-day offline lease token', () {
      final token = engine.issueOfflineLease(
        userId: 'contractor-usr-778',
        tier: 'PRO_CONTRACTOR',
        validityDays: 30,
      );

      expect(token.userId, 'contractor-usr-778');
      expect(token.tier, 'PRO_CONTRACTOR');
      expect(token.isExpired, isFalse);
      expect(engine.verifyToken(token), isTrue);
      expect(engine.isProEntitled(), isTrue);
    });

    test('Rejects tampered tokens (Simulated MOD APK signature forgery)', () {
      final validToken = engine.issueOfflineLease(
        userId: 'contractor-usr-778',
        tier: 'PRO_CONTRACTOR',
        validityDays: 30,
      );

      // Modder attempts to alter token payload (e.g. inject different user or validity)
      final forgedToken = LicenseToken(
        userId: 'hacker-uid',
        tier: validToken.tier,
        issuedAt: validToken.issuedAt,
        expiresAt: validToken.expiresAt,
        signature: validToken.signature, // Reusing original signature on altered payload
      );

      expect(engine.verifyToken(forgedToken), isFalse, reason: 'Cryptographic hash mismatch must invalidate forged token');
    });

    test('Rejects expired offline lease tokens (Must renew online after 30 days)', () {
      final expiredToken = engine.issueOfflineLease(
        userId: 'contractor-usr-778',
        tier: 'PRO_CONTRACTOR',
        validityDays: -1, // Expired yesterday
      );

      expect(expiredToken.isExpired, isTrue);
      expect(engine.verifyToken(expiredToken), isFalse);
    });
  });
}
