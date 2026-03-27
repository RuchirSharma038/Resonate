// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;
//import 'dart:async';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  double smoothedOffset = 0;
  bool initialized = false;

  Stopwatch stopwatch = Stopwatch();

  factory SocketService() {
    return _instance;
  }
  SocketService._internal();

  late IO.Socket socket;

  void connect() {
    socket = IO.io(
      "http://YOUR_SERVER_IP:3000",
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    socket.connect();

    socket.onConnect((_) {
      //print("Connected to server");
      startInitialSync();
    });

    socket.onDisconnect((_) {
      //print("Disconnected")
    });
    socket.on('pong', (data) {
      handlePong(data);
    });
  }

  void emit(String event, dynamic data) {
    socket.emit(event, data);
  }

  void listen(String event, Function(dynamic) callback) {
    socket.on(event, callback);
  }

  void disconnect() {
    socket.disconnect();
  }

  void startInitialSync() async {
    for (int i = 0; i < 5; i++) {
      await Future.delayed(Duration(milliseconds: 50 + (i * 20)));
      sendPing();
    }
  }

  void sendPing() {
    final t0 = DateTime.now().millisecondsSinceEpoch;
    stopwatch.reset();
    stopwatch.start();
    socket.emit('ping', {'t0': t0});
  }

  void handlePong(dynamic data) {
    stopwatch.stop();

    final t3 = DateTime.now().millisecondsSinceEpoch;
    final t0 = data['t0'];
    final t1 = data['t1'];
    final t2 = data['t2'];

    final rtt = stopwatch.elapsedMilliseconds.toDouble();

    final offset = ((t1 - t0) + (t2 - t3)) / 2;
    updateSync(rtt, offset);
  }

  void updateSync(double rtt, double offset) {
    if (rtt > 300) return;

    if (!initialized) {
      initialized = true;
      smoothedOffset = offset;
    } else {
      smoothedOffset = 0.1 * offset + 0.9 * smoothedOffset; //alpha = 1
    }
  }

  double getServerTime() {
    final clientTime = DateTime.now().millisecondsSinceEpoch;
    return clientTime + smoothedOffset;
  }
}
