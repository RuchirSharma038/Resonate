//import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:resonate_app/providers/audio_service.dart';
//import 'package:resonate_app/models/session_model.dart';
import '../services/socket_service.dart';
import './session_state.dart';

import '../controllers/socket_controller.dart';

//import './session_state.dart';

class SessionNotifier extends StateNotifier<SessionState> {
  final SocketController controller;
  final SocketService socket;
  final AudioService audio;

  SessionNotifier(this.controller, this.socket, this.audio)
    : super(SessionState.initial()) {
    _init();
  }

  //INIT
  void _init() {
    controller.init();
    _listenConnection();
    _listenSessionEvents();
    _listenPlaybackEvents();
  }

  void _listenConnection() {
    socket.listen("connect", (_) {
      state = state.copyWith(isConnected: true);
    });

    socket.listen("disconnect", (_) {
      state = state.copyWith(isConnected: false);
    });
  }

  void _listenSessionEvents() {
    socket.listen("session_created", (data) {
      state = state.copyWith(sessionId: data["sessionId"]);
    });

    socket.listen("user_joined", (data) {
      final updatedUsers = List<String>.from(state.participants)
        ..add(data["userId"]);
      state = state.copyWith(participants: updatedUsers);
    });

    socket.listen("user_left", (data) {
      final updatedUsers = List<String>.from(
        state.participants,
      ).where((u) => u != data["userId"]).toList();

      state = state.copyWith(participants: updatedUsers);
    });

    socket.listen("host_changed", (data) {
      state = state.copyWith(hostId: data["hostId"]);
    });
  }

  void _listenPlaybackEvents() {
    socket.listen("song_updated", (data) async {
      await audio.load(data["url"]);
      state = state.copyWith(url: data["url"]);
    });

    socket.listen("play_song", (data) async {
      final startedAt = DateTime.fromMillisecondsSinceEpoch(data["startTime"]);
      final position = state.position;
      await audio.seek(position);
      await audio.play();
      state = state.copyWith(
        playbackState: PlaybackState.playing,
        startedAt: startedAt,
      );
    });

    socket.listen("pause_song", (data) async {
      await audio.pause();
      state = state.copyWith(
        playbackState: PlaybackState.paused,
        position: Duration(milliseconds: data["position"]),
      );
    });

    socket.listen("stop_song", (_) async {
      await audio.stop();
      state = state.copyWith(
        playbackState: PlaybackState.stopped,
        position: Duration.zero,
      );
    });
  }

  void createSession() {
    state = state.copyWith(isLoading: true);
    controller.createSession();
  }

  void joinSession(String sessionId) {
    state = state.copyWith(isLoading: true);
    controller.joinSession(sessionId);
  }

  void leaveSession() {
    if (state.sessionId.isEmpty) return;

    controller.leaveSession(state.sessionId);

    state = SessionState.initial();
  }

  void setUrl(String url) {
    if (state.sessionId.isEmpty) return;

    controller.setUrl(state.sessionId, url);
  }

  void play() {
    if (state.sessionId.isEmpty) return;

    controller.playSong(state.sessionId);
  }

  void pause() {
    if (state.sessionId.isEmpty) return;

    controller.pause(state.sessionId);
  }

  void stop() {
    if (state.sessionId.isEmpty) return;
    controller.pause(state.sessionId);
  }

  Duration getCurrentPosition() {
    if (state.playbackState != PlaybackState.playing ||
        state.startedAt == null) {
      return state.position;
    }
    final now = DateTime.now();
    final diff = now.difference(state.startedAt!);
    return state.position + diff;
  }
}
