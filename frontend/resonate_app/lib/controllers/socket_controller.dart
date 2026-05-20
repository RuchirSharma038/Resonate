//import 'package:flutter_riverpod/flutter_riverpod.dart';
import "../services/socket_service.dart";

// final socketControllerProvider = Provider<SocketController>((ref) {
//   final service = SocketService();
//   return SocketController(service);
// });

class SocketController {
  final SocketService socketService;

  int _commandSeq = 0;
  int _nextSeq() => ++_commandSeq;

  SocketController(this.socketService);

  Future<void> init() async {
    socketService.connect();
  }

  void createSession() {
    socketService.emit("create_session", {});
  }

  void joinSession(String sessionId) {
    socketService.emit("join_session", {"sessionId": sessionId});
  }

  void leaveSession(String sessionId) {
    socketService.emit("leave_session", {"sessionId": sessionId});
  }

  void setUrl(String sessionId, String url) {
    socketService.emit("set_url", {
      "sessionId": sessionId,
      "url": url,
      "seq": _nextSeq(),
    });
  }

  void playSong(String sessionId) {
    socketService.emit("play", {"sessionId": sessionId, "seq": _nextSeq()});
  }

  void pause(String sessionId) {
    socketService.emit("pause", {"sessionId": sessionId, "seq": _nextSeq()});
  }

  void stop(String sessionId) {
    socketService.emit("stop", {"sessionId": sessionId, "seq": _nextSeq()});
  }

  void addToQueue(String sessionId, String url) {
    socketService.emit("add_to_queue", {"sessionId": sessionId, "url": url});
  }

  void playNext(String sessionId) {
    socketService.emit("play_next", {
      "sessionId": sessionId,
      "seq": _nextSeq(),
    });
  }

  void removeFromQueue(String sessionId, String url) {
    socketService.emit('remove_from_queue', {
      'sessionId': sessionId,
      'url': url,
    });
  }

  void seek(String sessionId, int position) {
    socketService.emit("seek", {
      "sessionId": sessionId,
      "position": position,
      "seq": _nextSeq(),
    });
  }
}
