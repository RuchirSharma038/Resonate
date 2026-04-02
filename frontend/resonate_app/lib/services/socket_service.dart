// ignore: library_prefixes
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
//import 'dart:async';

class SocketService {
  // static final SocketService _instance = SocketService._internal();

  // factory SocketService() {
  //   return _instance;
  // }
  // SocketService._internal();

  late IO.Socket socket;

  Future<void> connect() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final idToken = await user.getIdToken();

    socket = IO.io(
      "http://YOUR_SERVER_IP:3000",
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': idToken})
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
