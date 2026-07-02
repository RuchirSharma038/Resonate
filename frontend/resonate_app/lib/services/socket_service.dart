// ignore: library_prefixes
import 'dart:async';
import 'package:resonate_app/config/app_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;
//import 'dart:async';

class SocketService {
  late IO.Socket socket;

  StreamSubscription<User?>? _tokenRefreshSub;

  SocketService() {
    socket = IO.io(
      AppConfig.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
  }

  Future<void> connect() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("SocketService: User is null, cannot connect.");
      return;
    }

    try {
      final idToken = await user.getIdToken();

      socket.io.options?['auth'] = {'token': idToken};
      socket.auth = {'token': idToken};
      socket.connect();

      socket.onConnect((_) {
        print("SocketService: Connected successfully!");
        _listenForTokenRefresh();
      });

      socket.onConnectError((err) {
        print("SocketService: Connection Error: $err");
      });

      socket.onDisconnect((_) {
        print("SocketService: Disconnected.");
        _tokenRefreshSub?.cancel();
      });

      // Handle the server's response to our refresh_token event
      socket.on('token_refresh_result', (data) {
        if (data is Map && data['success'] == false) {
          disconnect();
        }
      });
    } catch (e) {
      print("SocketService: Error fetching token or connecting: $e");
    }
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
