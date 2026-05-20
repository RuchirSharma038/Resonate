import 'dart:async';
import 'dart:math';

import 'package:resonate_app/services/socket_service.dart';

class TimeSyncService {
  final SocketService socket;
  TimeSyncService(this.socket);

  double smoothedOffset = 0;
  bool initialized = false;

  bool _initialSyncComplete = false;

  final List<double> _offsetBuffer = [];
  final List<double> _rttBuffer = [];
  final int bufferSize = 8;

  int _pingId = 0;
  final Map<int, int> _pendingPings = {};

  Timer? periodicTimer;
  bool _initCalled = false; // guards against double-init

  void init() {
    if (_initCalled) return;
    _initCalled = true;

    socket.listen('pong', _onPong);
    _startInitialSync();
    _scheduleAdaptivePing();
  }

  double getServerTime() =>
      DateTime.now().millisecondsSinceEpoch + smoothedOffset;

  // 0 = no data / high variance. 1 = very stable.
  double get syncQuality {
    if (!initialized || _offsetBuffer.length < 2) return 0;
    final v = _variance(_offsetBuffer);
    return (1.0 - v / 100.0).clamp(0.0, 1.0);
  }

  void dispose() {
    periodicTimer?.cancel();
    _pendingPings.clear();
  }

  void _onPong(dynamic data) {
    final id = data['id'];
    if (!_pendingPings.containsKey(id)) return;
    final t0 = _pendingPings.remove(id)!;

    final t1 = (data['t1'] as num).toDouble();
    final t2 = (data['t2'] as num).toDouble();
    final t3 = DateTime.now().millisecondsSinceEpoch.toDouble();

    final rtt = (t3 - t0) - (t2 - t1);
    final offset = ((t1 - t0) + (t2 - t3)) / 2;

    _updateSync(rtt, offset);
    if (_initialSyncComplete) {
      _scheduleAdaptivePing();
    }
  }

  void _startInitialSync() async {
    for (int i = 0; i < 5; i++) {
      await Future.delayed(Duration(milliseconds: 50 + i * 20));
      _sendPing();
    }
    _initialSyncComplete = true;
    _scheduleAdaptivePing();
  }

  void _sendPing() {
    final id = _pingId++;
    final t0 = DateTime.now().millisecondsSinceEpoch;
    _pendingPings[id] = t0;
    socket.emit('ping', {'id': id, 't0': t0});
    Future.delayed(const Duration(seconds: 3), () => _pendingPings.remove(id));
  }

  bool _isRttAcceptable(double rtt) {
    if (_rttBuffer.isEmpty) return rtt < 500;
    final sorted = List<double>.from(_rttBuffer)..sort();
    final p75 =
        sorted[(sorted.length * 0.75).floor().clamp(0, sorted.length - 1)];
    return rtt <= max(50.0, p75 * 1.5);
  }

  void _updateSync(double rtt, double offset) {
    _rttBuffer.add(rtt);
    if (_rttBuffer.length > bufferSize) _rttBuffer.removeAt(0);

    if (!_isRttAcceptable(rtt)) return;

    _offsetBuffer.add(offset);
    if (_offsetBuffer.length > bufferSize) _offsetBuffer.removeAt(0);

    final med = _median(_offsetBuffer);
    if (!initialized) {
      smoothedOffset = med;
      initialized = true;
    } else {
      smoothedOffset = 0.1 * med + 0.9 * smoothedOffset;
    }
  }

  void _scheduleAdaptivePing() {
    periodicTimer?.cancel();
    final v = _variance(_offsetBuffer);
    final seconds = v < 5
        ? 30
        : v < 20
        ? 10
        : 2;
    periodicTimer = Timer.periodic(
      Duration(seconds: seconds),
      (_) => _sendPing(),
    );
  }

  double _median(List<double> vals) {
    if (vals.isEmpty) return 0;
    final s = List<double>.from(vals)..sort();
    final n = s.length;
    return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
  }

  double _variance(List<double> vals) {
    if (vals.length < 2) return 0;
    final mean = vals.reduce((a, b) => a + b) / vals.length;
    return vals.map((v) => pow(v - mean, 2) as double).reduce((a, b) => a + b) /
        vals.length;
  }
}
