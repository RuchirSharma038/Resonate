import 'dart:async';

import 'package:resonate_app/services/socket_service.dart';

class TimeSyncService {
  final SocketService socket;
  TimeSyncService(this.socket);

  double smoothedOffset = 0;
  bool initialized = false;

  List<double> offsetBuffer = [];
  int pingId = 0;
  Map<int, int> pendingPings = {};

  final int bufferSize = 5;

  Timer? periodicTimer;

  void init() {
    socket.listen('pong', (data) {
      final id = data['id'];
      if (!pendingPings.containsKey(id)) return;
      final t0 = pendingPings[id]!;
      pendingPings.remove(id);

      final t1 = data['t1'];
      final t2 = data['t2'];
      final t3 = DateTime.now().millisecondsSinceEpoch;

      final rtt = (t3 - t0) - (t2 - t1);
      final offset = ((t1 - t0) + (t2 - t3)) / 2;

      updateSync(rtt.toDouble(), offset.toDouble());
    });
    startInitialSync();
    startPeriodicSync();
  }

  void startInitialSync() async {
    for (int i = 0; i < 5; i++) {
      await Future.delayed(Duration(milliseconds: 50 + (i * 20)));
      sendPing();
    }
  }

  void startPeriodicSync() {
    periodicTimer = Timer.periodic(Duration(seconds: 5), (_) {
      sendPing();
    });
  }

  void sendPing() {
    final id = pingId++;

    final t0 = DateTime.now().millisecondsSinceEpoch;
    pendingPings[id] = t0;

    socket.emit('ping', {'id': id, 't0': t0});
    Future.delayed(Duration(seconds: 2), () {
      pendingPings.remove(id);
    });
  }

  void updateSync(double rtt, double offset) {
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
