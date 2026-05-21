// ignore: library_prefixes
import 'dart:async';
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
  StreamSubscription<User?>? _tokenRefreshSub;

  SocketService() {
    socket = IO.io(
      "http://localhost:3001",
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
      _listenForTokenRefresh();
      //print("Connected to server");
    });

    socket.onDisconnect((_) {
      _tokenRefreshSub?.cancel();
      //print("Disconnected")
    });

    // Handle the server's response to our refresh_token event
    socket.on('token_refresh_result', (data) {
      if (data is Map && data['success'] == false) {
        disconnect();
      }
    });
  }

  void _listenForTokenRefresh() {
    _tokenRefreshSub?.cancel();

    _tokenRefreshSub = FirebaseAuth.instance.idTokenChanges().listen(
      (user) async {
        if (user == null) {
          disconnect();
          return;
        }

        final newToken = await user.getIdToken();

        if (socket.connected) {
          socket.emit('refresh_token', {'token': newToken});
        }
      },
      onError: (_) {
        disconnect();
      },
    );
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
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    socket.disconnect();
  }
}
