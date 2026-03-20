import "../services/socket_service.dart";

class SocketController {
  final SocketService socketService = SocketService();

  void init() {
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
    socketService.emit("set_url", {"sessionId": sessionId, "url": url});
  }

  void playSong(String sessionId) {
    socketService.emit("play", {"sessionId": sessionId});
  }

  void pause(String sessionId) {
    socketService.emit("pause", {"sessionId": sessionId});
  }

  void stop(String sessionId) {
    socketService.emit("stop", {"sessionId": sessionId});
  }
}
