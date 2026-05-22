// ignore: library_prefixes
import 'package:firebase_auth/firebase_auth.dart';
// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;
//import 'dart:async';

class SocketService {
  // static final SocketService _instance = SocketService._internal();

  // factory SocketService() {
  //   return _instance;
  // }
  // SocketService._internal();

  late IO.Socket socket;

  SocketService() {
    socket = IO.io(
      "http://10.58.8.243:3001",
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
  }

  Future<void> connect() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final idToken = await user.getIdToken();

    socket.io.options?['auth'] = {'token': idToken};
    socket.auth = {'token': idToken};
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

  void emitAddToQueue(String sessionId, String url) {
    socket.emit('add_to_queue', {'sessionId': sessionId, 'url': url});
  }

  void emitPlayNext(String sessionId) {
    socket.emit('play_next', {'sessionId': sessionId});
  }
  void disconnect() {
    socket.disconnect();
  }
}
