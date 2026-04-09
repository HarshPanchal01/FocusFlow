import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'data_sync_service.dart';

/// Monitors network connectivity and notifies listeners when status changes.
///
/// When the device goes offline: UI shows "Offline" banner.
/// When the device comes back online: triggers a cloud sync and shows
/// a brief "Back online" confirmation.
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool _isSyncing = false;
  bool _justReconnected = false;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  bool get justReconnected => _justReconnected;

  /// Start listening for connectivity changes. Call once on app startup.
  Future<void> initialize() async {
    // Check initial state
    final results = await _connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);
    debugPrint('Connectivity: Initial state — ${_isOnline ? "online" : "offline"}');

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final nowOnline = !results.contains(ConnectivityResult.none);

      if (nowOnline && !_isOnline) {
        // Just came back online
        _isOnline = true;
        _justReconnected = true;
        notifyListeners();
        _syncAfterReconnect();
      } else if (!nowOnline && _isOnline) {
        // Just went offline
        _isOnline = false;
        _justReconnected = false;
        notifyListeners();
        debugPrint('Connectivity: Went offline');
      }
    });
  }

  /// Sync data after reconnecting, then dismiss the "Back online" banner.
  Future<void> _syncAfterReconnect() async {
    debugPrint('Connectivity: Back online — syncing...');
    _isSyncing = true;
    notifyListeners();

    try {
      await DataSyncService().syncFromCloud();
    } catch (e) {
      debugPrint('Connectivity: Sync after reconnect failed — $e');
    }

    _isSyncing = false;
    notifyListeners();

    // Auto-dismiss the "Back online" banner after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      _justReconnected = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
