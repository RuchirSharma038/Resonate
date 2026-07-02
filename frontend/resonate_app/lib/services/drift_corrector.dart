import 'dart:async';

import 'package:just_audio/just_audio.dart';

// Correct audio drift by smoothly ramping playback speed or hard seeking
class DriftCorrector {
  // Drift below this is acceptable, no action taken
  static const int _ignoreMs = 20;

  // Drift above this is too large for smooth ramping, hard seek instead
  static const int _rampMaxMs = 5000;

  // Speed delta applied during ramp (5 % )
  static const double _rampDelta = 0.05;

  // How often the correction loop wakes up and checks drift
  static const Duration _checkInterval = Duration(seconds: 3);

  final AudioPlayer _player;
  final double Function() _getServerTime;

  Timer? _checkTimer;
  Timer? _rampResetTimer;
  final StreamController<double> _speedController =
      StreamController<double>.broadcast();

  Stream<double> get speedStream => _speedController.stream;

  int _basePositionMs = 0;
  int _startedAtMs = 0;
  bool _active = false;

  DriftCorrector({
    required AudioPlayer player,
    required double Function() getServerTime,
  }) : _player = player,
       _getServerTime = getServerTime;

  // Start monitoring drift
  void start({required int basePositionMs, required int startedAtMs}) {
    stop();
    _basePositionMs = basePositionMs;
    _startedAtMs = startedAtMs;
    _active = true;
    _checkTimer = Timer.periodic(_checkInterval, (_) => _check());
  }

  // Stop monitoring and resets speed to 1.0
  void stop() {
    _active = false;
    _checkTimer?.cancel();
    _checkTimer = null;
    _cancelRamp();
    _applySpeed(1.0);
  }

  void dispose() {
    stop();
    _speedController.close();
  }

  void _check() {
    if (!_active || !_player.playing) return;
    if (_player.processingState != ProcessingState.ready &&
        _player.processingState != ProcessingState.completed) {
      return;
    }

    final serverNow = _getServerTime();
    final expectedMs = _basePositionMs + (serverNow - _startedAtMs).toInt();
    final actualMs = _player.position.inMilliseconds;

    final driftMs = expectedMs - actualMs;
    final absDrift = driftMs.abs();

    if (absDrift <= _ignoreMs) {
      _cancelRamp();
      _applySpeed(1.0);
      return;
    }

    if (absDrift > _rampMaxMs) {
      _cancelRamp();
      _applySpeed(1.0);
      _player.seek(Duration(milliseconds: expectedMs));
      return;
    }

    // Smooth speed ramp for minor corrections
    final speed = driftMs > 0 ? 1.0 + _rampDelta : 1.0 - _rampDelta;
    final correctionMs = (absDrift / _rampDelta).round();

    _applyRamp(speed, correctionMs);
  }

  void _applySpeed(double speed) {
    if (!_speedController.isClosed) {
      _speedController.add(speed);
    }
    _player.setSpeed(speed);
  }

  void _applyRamp(double speed, int durationMs) {
    _cancelRamp();
    _applySpeed(speed);
    _rampResetTimer = Timer(Duration(milliseconds: durationMs), () {
      _applySpeed(1.0);
    });
  }

  void _cancelRamp() {
    _rampResetTimer?.cancel();
    _rampResetTimer = null;
  }
}
