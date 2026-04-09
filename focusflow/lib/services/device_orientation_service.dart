import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum DeviceOrientationState {
  faceUp,
  faceDown,
  held,
  unknown
}

class DeviceOrientationService extends ChangeNotifier {
  static final DeviceOrientationService _instance = DeviceOrientationService._internal();
  factory DeviceOrientationService() => _instance;
  DeviceOrientationService._internal();

  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  DeviceOrientationState _currentState = DeviceOrientationState.unknown;
  
  // Track previous events to calculate variance/movement
  final List<AccelerometerEvent> _recentEvents = [];
  static const int _maxEvents = 10; // Keep last 10 events (approx 1-2 seconds)

  DeviceOrientationState get currentState => _currentState;

  bool get isStationary => _currentState == DeviceOrientationState.faceUp || _currentState == DeviceOrientationState.faceDown;
  bool get isFaceDown => _currentState == DeviceOrientationState.faceDown;

  void startMonitoring() {
    if (_accelSubscription != null) return;
    
    _accelSubscription = accelerometerEventStream().listen((event) {
      _processEvent(event);
    });
  }

  void stopMonitoring() {
    _accelSubscription?.cancel();
    _accelSubscription = null;
    _currentState = DeviceOrientationState.unknown;
    _recentEvents.clear();
    notifyListeners();
  }

  void _processEvent(AccelerometerEvent event) {
    _recentEvents.add(event);
    if (_recentEvents.length > _maxEvents) {
      _recentEvents.removeAt(0);
    }

    if (_recentEvents.length < _maxEvents) return;

    // Calculate variance to detect movement
    double sumX = 0, sumY = 0, sumZ = 0;
    for (var e in _recentEvents) {
      sumX += e.x;
      sumY += e.y;
      sumZ += e.z;
    }
    double avgX = sumX / _maxEvents;
    double avgY = sumY / _maxEvents;
    double avgZ = sumZ / _maxEvents;

    double varX = 0, varY = 0, varZ = 0;
    for (var e in _recentEvents) {
      varX += (e.x - avgX) * (e.x - avgX);
      varY += (e.y - avgY) * (e.y - avgY);
      varZ += (e.z - avgZ) * (e.z - avgZ);
    }
    
    double totalVariance = varX + varY + varZ;

    DeviceOrientationState newState;
    
    // Threshold for movement (can be adjusted based on testing)
    if (totalVariance > 5.0) {
      newState = DeviceOrientationState.held;
    } else {
      // If stationary, check orientation via Z axis
      // Z ≈ 9.8 is face up (screen pointing up)
      // Z ≈ -9.8 is face down (screen pointing down)
      if (avgZ < -7.0) {
        newState = DeviceOrientationState.faceDown;
      } else if (avgZ > 7.0 && avgX.abs() < 5.0 && avgY.abs() < 5.0) {
        newState = DeviceOrientationState.faceUp;
      } else {
        // Leaning against a stand or being held very still
        newState = DeviceOrientationState.held; 
      }
    }

    if (newState != _currentState) {
      _currentState = newState;
      notifyListeners();
      debugPrint('Device Orientation Changed: $_currentState');
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
