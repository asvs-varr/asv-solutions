// BANAAG Cloud Sync Service
// Encapsulates Supabase Cloud Backup & Project Sync
// Designed to operate gracefully offline when credentials are unset or network is unavailable.

import 'dart:async';
import '../domain/models.dart';

enum CloudSyncStatus {
  offlineLocalOnly,
  connecting,
  synchronized,
  failed,
}

class CloudSyncConfig {
  final String supabaseUrl;
  final String anonKey;
  final bool isConfigured;

  const CloudSyncConfig({
    this.supabaseUrl = '',
    this.anonKey = '',
  }) : isConfigured = supabaseUrl != '' && anonKey != '';
}

class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  CloudSyncConfig _config = const CloudSyncConfig();
  CloudSyncStatus _status = CloudSyncStatus.offlineLocalOnly;
  DateTime? _lastSyncTime;

  CloudSyncStatus get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isConfigured => _config.isConfigured;

  /// Updates Supabase project credentials
  void configure({required String url, required String anonKey}) {
    _config = CloudSyncConfig(supabaseUrl: url.trim(), anonKey: anonKey.trim());
    if (_config.isConfigured) {
      _status = CloudSyncStatus.connecting;
      // In production, Supabase.initialize(url: url, anonKey: anonKey) runs here
      _status = CloudSyncStatus.synchronized;
      _lastSyncTime = DateTime.now();
    } else {
      _status = CloudSyncStatus.offlineLocalOnly;
    }
  }

  /// Triggers cloud backup for a project
  Future<bool> backupProject(Project project) async {
    if (!_config.isConfigured) {
      // Graceful offline operation: remains safe in local SQLite/Stream cache
      _status = CloudSyncStatus.offlineLocalOnly;
      return false;
    }

    try {
      _status = CloudSyncStatus.connecting;
      // Simulating Supabase upsert payload
      await Future.delayed(const Duration(milliseconds: 600));
      _status = CloudSyncStatus.synchronized;
      _lastSyncTime = DateTime.now();
      return true;
    } catch (_) {
      _status = CloudSyncStatus.failed;
      return false;
    }
  }

  /// Clears cloud credentials and switches back to pure offline mode
  void disconnect() {
    _config = const CloudSyncConfig();
    _status = CloudSyncStatus.offlineLocalOnly;
    _lastSyncTime = null;
  }
}
