// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;
//import 'dart:async';

class SocketService {
  static final SocketService _instance = SocketService._internal();

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
    });

    socket.onDisconnect((_) {
      //print("Disconnected")
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
}
