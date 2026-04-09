//import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:resonate_app/providers/audio_service.dart';
import 'package:resonate_app/services/time_sync_service.dart';
//import 'package:resonate_app/models/session_model.dart';
import '../services/socket_service.dart';
import './session_state.dart';

import '../controllers/socket_controller.dart';

//import './session_state.dart';

class SessionNotifier extends StateNotifier<SessionState> {
  final SocketController controller;
  final SocketService socket;
  final AudioService audio;
  final TimeSyncService timeSync;

  SessionNotifier(this.controller, this.socket, this.audio, this.timeSync)
    : super(SessionState.initial()) {
    _init();
  }

  //INIT
  void _init() {
    controller.init();
    _listenConnection();
    _listenSessionEvents();
    _listenPlaybackEvents();
    _listenErrorEvents();
  }

  void _listenConnection() {
    // Connect
    socket.listen("connect", (_) {
      state = state.copyWith(isConnected: true);
    });

    // Disconnect
    socket.listen("disconnect", (_) {
      state = state.copyWith(isConnected: false);
    });
  }

  void _listenSessionEvents() {
    //Session_created
    socket.listen("session_created", (data) {
      state = state.copyWith(
        sessionId: data["sessionId"],
        hostId: data["hostId"],
        participants: [data["hostId"]],
        isLoading: false,
      );
    });

    //User_joined

    socket.listen("user_joined", (data) {
      final userId = data["userId"] as String;
      if (!state.participants.contains(userId)) {
        final updatedUsers = List<String>.from(state.participants)..add(userId);
        state = state.copyWith(participants: updatedUsers);
      }
    });

    //User_left

    socket.listen("user_left", (data) {
      final updatedUsers = List<String>.from(
        state.participants,
      ).where((u) => u != data["userId"]).toList();

      state = state.copyWith(participants: updatedUsers);
    });

    //Host_changed
    socket.listen("host_changed", (data) {
      state = state.copyWith(hostId: data["hostId"]);
    });

    //Session_state
    socket.listen("session_state", (data) async {
      final url = data["url"];
      final serverState = data["state"];
      final serverPos = data["position"];
      final serverStartAt = data["startedAt"];
      final hostId = data["hostId"];
      final sessionId = data["sessionId"]; // Might be null for older backend version
      final participants = data["participants"];

      state = state.copyWith(
        sessionId: sessionId ?? state.sessionId,
        participants: participants != null ? List<String>.from(participants) : state.participants,
        isLoading: false,
      );

      //Load the url
      if (url != null) {
        await audio.load(url);
        state = state.copyWith(url: url);
      }
      if (serverState == "playing" && serverStartAt != null) {
        final now = timeSync.getServerTime();
        final elapsed = now - serverStartAt;
        final livePosition = elapsed + serverPos;
        await audio.seek(Duration(milliseconds: livePosition.toInt()));
        await audio.play();

        state = state.copyWith(
          playbackState: PlaybackState.playing,
          position: Duration(milliseconds: serverPos.toInt()),
          startedAt: DateTime.fromMillisecondsSinceEpoch(serverStartAt),
          hostId: hostId,
        );
      } else if (serverState == "paused") {
        final exactPosition = Duration(milliseconds: serverPos.toInt());
        await audio.seek(exactPosition);
        await audio.pause();

        state = state.copyWith(
          playbackState: PlaybackState.paused,
          position: exactPosition,
          startedAt: null,
          hostId: hostId,
        );
      } else {
        await audio.stop();
        state = state.copyWith(
          playbackState: PlaybackState.stopped,
          position: Duration.zero,
          startedAt: null,
          hostId: hostId,
        );
      }
    });
  }

  //

  void _listenPlaybackEvents() {
    //Song_updated
    socket.listen("song_updated", (data) async {
      await audio.load(data["url"]);
      state = state.copyWith(url: data["url"]);
    });

    //play_song
    socket.listen("play_song", (data) async {
      final serverStartTime = (data["startTime"] as num).toInt();
      final basePosition = (data["position"] as num).toInt();
      final now = timeSync.getServerTime();
      final timeUntilPlay = serverStartTime - now;
      if (timeUntilPlay > 0) {
        await audio.seek(Duration(milliseconds: basePosition.toInt()));
        await Future.delayed(Duration(milliseconds: timeUntilPlay.toInt()));

        final now2 = timeSync.getServerTime();
        final drift = now2 - serverStartTime;

        if (drift.abs() > 15) {
          await audio.seek(
            Duration(milliseconds: (basePosition + drift).toInt()),
          );
        }
        await audio.play();
      } else {
        final overrun = (-timeUntilPlay).clamp(0, 10000);
        final correctedPosition = Duration(
          milliseconds: (basePosition + overrun).toInt(),
        );

        await audio.seek(correctedPosition);
        await audio.play();
      }

      state = state.copyWith(
        playbackState: PlaybackState.playing,
        startedAt: DateTime.fromMillisecondsSinceEpoch(serverStartTime),
        position: Duration(milliseconds: basePosition),
      );
    });

    //Pause song

    socket.listen("pause_song", (data) async {
      final serverPosition = (data["position"] as num).toDouble();
      final pauseTime = data["pauseTime"];
      final now = timeSync.getServerTime();
      final drift = now - pauseTime;

      await audio.pause();

      if (drift.abs() > 300) {
        final exactPosition = Duration(milliseconds: serverPosition.toInt());
        await audio.seek(exactPosition);

        state = state.copyWith(
          playbackState: PlaybackState.paused,
          position: exactPosition,
        );
      } else {
        state = state.copyWith(
          playbackState: PlaybackState.paused,
          position: Duration(milliseconds: serverPosition.toInt()),
        );
      }
    });

    //Stop Song

    socket.listen("stop_song", (_) async {
      await audio.stop();
      state = state.copyWith(
        playbackState: PlaybackState.stopped,
        position: Duration.zero,

        clearStartedAt: true,
      );
    });
  }

  //Error
  void _listenErrorEvents() {
    socket.listen("error_message", (data) {
      state = state.copyWith(error: data["message"], isLoading: false);
    });
  }

  //Create session
  void createSession() {
    state = state.copyWith(isLoading: true);
    controller.createSession();
  }

  //Join session

  void joinSession(String sessionId) {
    state = state.copyWith(isLoading: true);
    controller.joinSession(sessionId);
  }

  //Leave session
  void leaveSession() {
    if (state.sessionId.isEmpty) return;

    controller.leaveSession(state.sessionId);

    state = SessionState.initial();
  }

  //set Url
  void setUrl(String url) {
    final error = _validateAudioUrl(url);
    if (error != null) {
      state = state.copyWith(error: error);
      return;
    }

    state = state.copyWith(error: null, clearError: true);
    controller.setUrl(state.sessionId, url);
  }

  //play
  void play() {
    if (state.sessionId.isEmpty) return;

    controller.playSong(state.sessionId);
  }

  //pause
  void pause() {
    if (state.sessionId.isEmpty) return;

    controller.pause(state.sessionId);
  }

  //stop
  void stop() {
    if (state.sessionId.isEmpty) return;
    controller.stop(state.sessionId);
  }

  //Validate the url function
  String? _validateAudioUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return "URL cannot be empty";

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return "Invalid URL format";
    if (!uri.isAbsolute) return "URL must be absolute (include http/https)";
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return "URL must use http or https";
    }
    if (uri.host.isEmpty) return "URL must have a valid host";
    if (uri.path.isEmpty || uri.path == '/') {
      return "URL must point to a specific audio resource";
    }

    const supported = [
      '.mp3',
      '.wav',
      '.ogg',
      '.flac',
      '.aac',
      '.m4a',
      '.opus',
      '.webm',
    ];
    final pathLower = uri.path.toLowerCase();
    final hasExtension = supported.any((ext) => pathLower.contains(ext));
    if (!hasExtension) {
      return "URL must point to a supported audio file (mp3, wav, ogg, flac, aac, m4a, opus, webm)";
    }

    return null; // valid
  }

  Duration getCurrentPosition() {
    if (state.playbackState != PlaybackState.playing ||
        state.startedAt == null) {
      return state.position;
    }
    final now = DateTime.fromMillisecondsSinceEpoch(
      timeSync.getServerTime().toInt(),
    );
    final diff = now.difference(state.startedAt!);
    return state.position + diff;
  }
}
