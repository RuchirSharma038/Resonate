import "../services/socket_service.dart";

class SocketController {
  final SocketService socketService = SocketService();

  void init() {
    socketService.connect();
  }

  void joinSession(String code) {
    socketService.emit("join-session", {"code": code});
  }

  void playSong(String url) {
    socketService.emit("play-song", {"url": url});
  }

  void listenNewSong(Function(dynamic) callback) {
    socketService.listen("new-song", callback);
  }
}
