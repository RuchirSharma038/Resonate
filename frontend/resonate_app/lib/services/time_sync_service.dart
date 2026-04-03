import 'dart:async';

import 'package:resonate_app/services/socket_service.dart';

class TimeSyncService {
  final SocketService socket;
  TimeSyncService(this.socket);

  double smoothedOffset = 0;
  bool initialized = false;

  List<double> offsetBuffer = [];
  int _pingId = 0;
  final Map<int, int> _pendingPings = {};

  final int bufferSize = 8;
  bool _initCalled = false;
  Timer? periodicTimer;

  void init() {
    if (_initCalled) return;
    _initCalled = true; // guards against double-init
    socket.listen('pong', _onPong);
    _startInitialSync();
    _startPeriodicSync();
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
  }

  void _startInitialSync() async {
    for (int i = 0; i < 5; i++) {
      await Future.delayed(Duration(milliseconds: 50 + (i * 20)));
      sendPing();
    }
  }

  void _startPeriodicSync() {
    periodicTimer = Timer.periodic(Duration(seconds: 5), (_) {
      sendPing();
    });
  }

  void sendPing() {
    final id = _pingId++;

    final t0 = DateTime.now().millisecondsSinceEpoch;
    _pendingPings[id] = t0;

    socket.emit('ping', {'id': id, 't0': t0});
    Future.delayed(Duration(seconds: 3), () {
      _pendingPings.remove(id);
    });
  }

  void _updateSync(double rtt, double offset) {
    if (rtt > 300) return;

    offsetBuffer.add(offset);
    if (offsetBuffer.length > bufferSize) {
      offsetBuffer.removeAt(0);
    }

    final medianOffset = getMedian(offsetBuffer);

    if (!initialized) {
      smoothedOffset = medianOffset;
      initialized = true;
    } else {
      smoothedOffset = 0.1 * medianOffset + 0.9 * smoothedOffset;
    }
  }

  double getMedian(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    int n = sorted.length;

    if (n % 2 == 1) {
      return sorted[n ~/ 2];
    } else {
      return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
    }
  }

  double getServerTime() {
    final clientTime = DateTime.now().millisecondsSinceEpoch;
    return clientTime + smoothedOffset;
  }
}
