import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only: listens for [Intent.ACTION_SCREEN_OFF], [ACTION_SCREEN_ON],
/// and [ACTION_USER_PRESENT] via a broadcast receiver in [MainActivity].
///
/// On other platforms this is a no-op.
class PhoneActivityService {
  PhoneActivityService._();
  static final PhoneActivityService instance = PhoneActivityService._();

  static const EventChannel _channel = EventChannel('focusflow/phone_activity');

  StreamSubscription<dynamic>? _subscription;

  bool get isListening => _subscription != null;

  /// Starts emitting events: `screen_off`, `screen_on`, `user_present`.
  void start(void Function(String event) onEvent) {
    if (kIsWeb) return;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        break;
      default:
        return;
    }

    _subscription?.cancel();
    _subscription = _channel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is String) onEvent(event);
      },
      onError: (Object e) => debugPrint('PhoneActivityService stream error: $e'),
    );
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
