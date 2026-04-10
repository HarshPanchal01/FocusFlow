import 'package:flutter/services.dart';

/// Haptic feedback helpers for key user interactions.
/// Provides satisfying tactile responses that make the app feel polished.
class HapticUtils {
  /// Light tap — for checkboxes, toggles, nav taps
  static void lightTap() {
    HapticFeedback.lightImpact();
  }

  /// Medium tap — for button presses like "Start Focus", "Create Task"
  static void mediumTap() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy tap — for destructive actions like delete confirmation
  static void heavyTap() {
    HapticFeedback.heavyImpact();
  }

  /// Selection tick — for rating emojis, priority selector
  static void selectionTick() {
    HapticFeedback.selectionClick();
  }

  /// Success pattern — for session complete, task created
  static Future<void> successBuzz() async {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.lightImpact();
  }
}
