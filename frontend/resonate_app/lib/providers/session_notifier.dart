import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';
import 'package:resonate_app/providers/audio_service.dart';
import 'package:resonate_app/services/drift_corrector.dart';
import 'package:resonate_app/services/time_sync_service.dart';
import '../services/socket_service.dart';
import './session_state.dart';
import '../controllers/socket_controller.dart';
<<<<<<< HEAD
=======
import 'package:firebase_auth/firebase_auth.dart';
>>>>>>> 252dc77c7a8635f6de51f480bea9e375e8d0dc9f

class SessionNotifier extends StateNotifier<SessionState> {
  final SocketController controller;
  final SocketService socket;
  final AudioService audio;
  final TimeSyncService timeSync;

  late final DriftCorrector _driftCorrector;

  SessionNotifier(this.controller, this.socket, this.audio, this.timeSync)
<<<<<<< HEAD
    : super(SessionState.initial()) {
    _driftCorrector = DriftCorrector(
      player: audio.player,
      getServerTime: timeSync.getServerTime,
    );
    _init();
  }

  // ── Init
  
=======
      : super(SessionState.initial()) {
    _init();
  }

>>>>>>> 252dc77c7a8635f6de51f480bea9e375e8d0dc9f
  void _init() {
    controller.init();
    _listenConnection();
    _listenSessionEvents();
    _listenPlaybackEvents();
    _listenErrorEvents();

    audio.onSongComplete = () {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      final isHost = (state.hostId != null) && (state.hostId == currentUserId);

      if (isHost && state.sessionId.isNotEmpty) {
        // Tells the backend to skip to the next song!
        controller.playNext(state.sessionId);
      }
    };
  }

  //  Listeners

  void _listenConnection() {
    socket.listen("connect", (_) {
      state = state.copyWith(isConnected: true);
    });

    socket.listen("disconnect", (_) {
      state = state.copyWith(isConnected: false);
      _driftCorrector.stop();
    });
  }

  void _listenSessionEvents() {
    socket.listen("session_created", (data) {
      state = state.copyWith(
        sessionId: data["sessionId"] as String,
        isLoading: false,
      );
    });

    socket.listen("user_joined", (data) {
      final updated = List<String>.from(state.participants)
        ..add(data["userId"] as String);
      state = state.copyWith(participants: updated);
    });

    socket.listen("user_left", (data) {
      final updated = List<String>.from(state.participants)
        ..removeWhere((u) => u == data["userId"]);
      state = state.copyWith(participants: updated);
    });

    socket.listen("host_changed", (data) {
      state = state.copyWith(hostId: data["hostId"] as String?);
    });

<<<<<<< HEAD
    // Received when a user first joins an already-live session.
    // The server sends the LIVE position (elapsed already added), so we seek
    // directly to it and start drift correction from that baseline.
    socket.listen("session_state", (data) async {
      final url = data["url"] as String?;
      final serverState = data["state"] as String?;

      final serverPos = (data["position"] as num?)?.toInt() ?? 0;
      final serverStartAt = (data["startedAt"] as num?)?.toInt();
      final hostId = data["hostId"] as String?;
=======
    socket.listen("session_state", (data) async {
      final url = data["url"];
      final serverState = data["state"];
      final serverPos = data["position"];
      final serverStartAt = data["startedAt"];
      final hostId = data["hostId"];
      final sessionId = data["sessionId"];
      final participants = data["participants"];

      // 1. GRAB THE QUEUE FROM THE SERVER STATE
      final queueRaw = data["queue"];

      state = state.copyWith(
        sessionId: sessionId ?? state.sessionId,
        participants: participants != null ? List<String>.from(participants) : state.participants,
        // Save the initial queue!
        queue: queueRaw != null ? List<String>.from(queueRaw) : state.queue,
        isLoading: false,
      );
>>>>>>> 252dc77c7a8635f6de51f480bea9e375e8d0dc9f

      if (url != null) {
        await audio.load(url);
        state = state.copyWith(url: url);
      }

      if (serverState == "playing" && serverStartAt != null) {
        // Server sends live position (position + elapsed). Seek there directly.
        await audio.seek(Duration(milliseconds: serverPos));
        await audio.play();

        final startedAt = DateTime.fromMillisecondsSinceEpoch(serverStartAt);
        state = state.copyWith(
          playbackState: PlaybackState.playing,
          position: Duration(milliseconds: serverPos),
          startedAt: startedAt,
          hostId: hostId,
          isLoading: false,
        );

        // Start drift correction. basePosition is the live position we seeked to;
        // startedAt is "now" from the server's perspective (since we already
        // compensated for elapsed, treat serverNow as the new startedAt).
        _driftCorrector.start(
          basePositionMs: serverPos,
          startedAtMs: timeSync.getServerTime().toInt(),
        );
      } else if (serverState == "paused") {
        _driftCorrector.stop();
        await audio.seek(Duration(milliseconds: serverPos));

        state = state.copyWith(
          playbackState: PlaybackState.paused,
          position: Duration(milliseconds: serverPos),
          clearStartedAt: true,
          hostId: hostId,
          isLoading: false,
        );
      } else {
        _driftCorrector.stop();
        await audio.stop();
        state = state.copyWith(
          playbackState: PlaybackState.stopped,
          position: Duration.zero,
          clearStartedAt: true,
          hostId: hostId,
          isLoading: false,
        );
      }
    });
  }

  void _listenPlaybackEvents() {
    socket.listen("song_updated", (data) async {
      _driftCorrector.stop();
      await audio.load(data["url"] as String);
      state = state.copyWith(url: data["url"] as String);
    });

<<<<<<< HEAD
=======
    // ==========================================
    // 2. THE QUEUE LISTENER (Catches real-time updates)
    // ==========================================
    socket.listen("queue_updated", (data) {
      if (data != null) {
        final updatedQueue = List<String>.from(data);
        state = state.copyWith(queue: updatedQueue);
      }
    });

>>>>>>> 252dc77c7a8635f6de51f480bea9e375e8d0dc9f
    socket.listen("play_song", (data) async {
      _driftCorrector.stop();

      final serverStartTime = (data["startTime"] as num).toInt();
      final basePosition = (data["position"] as num).toInt();
      final now = timeSync.getServerTime();
      final timeUntilPlay = serverStartTime - now;

      if (timeUntilPlay > 0) {
        await audio.seek(Duration(milliseconds: basePosition));
        await Future.delayed(Duration(milliseconds: timeUntilPlay.toInt()));

        // Post-delay drift check — did we overshoot the window?
        final now2 = timeSync.getServerTime();
        final drift = (now2 - serverStartTime).toInt();
        if (drift.abs() > 15) {
          await audio.seek(Duration(milliseconds: basePosition + drift));
        }
        await audio.play();
      } else {
        // Already past the start time — correct for the overrun.
        final overrun = (-timeUntilPlay).clamp(0, 10000).toInt();
        await audio.seek(Duration(milliseconds: basePosition + overrun));
        await audio.play();
      }

      final startedAt = DateTime.fromMillisecondsSinceEpoch(serverStartTime);
      state = state.copyWith(
        playbackState: PlaybackState.playing,
        startedAt: startedAt,
        position: Duration(milliseconds: basePosition),
      );

      // Begin continuous drift monitoring from this baseline.
      _driftCorrector.start(
        basePositionMs: basePosition,
        startedAtMs: serverStartTime,
      );
    });

    socket.listen("pause_song", (data) async {
      _driftCorrector.stop();

      final serverPosition = (data["position"] as num).toInt();
      final pauseTime = (data["pauseTime"] as num).toDouble();
      final now = timeSync.getServerTime();
      final drift = (now - pauseTime).toInt();

      await audio.pause();

      // If this event arrived significantly late, correct to exact position.
      if (drift.abs() > 80) {
        await audio.seek(Duration(milliseconds: serverPosition));
      }

      state = state.copyWith(
        playbackState: PlaybackState.paused,
        position: Duration(milliseconds: serverPosition),
        clearStartedAt: true,
      );
    });

    socket.listen("stop_song", (_) async {
      _driftCorrector.stop();
      await audio.stop();
      state = state.copyWith(
        playbackState: PlaybackState.stopped,
        position: Duration.zero,
        clearStartedAt: true,
      );
    });

    socket.listen("seek_song", (data) async {
      final position = (data["position"] as num).toInt();
      await audio.seek(Duration(milliseconds: position));
      state = state.copyWith(position: Duration(milliseconds: position));
    });
  }

  void _listenErrorEvents() {
    socket.listen("error_messsage", (data) {
      state = state.copyWith(
        error: data["message"] as String?,
        isLoading: false,
      );
    });
  }

<<<<<<< HEAD
  // Public actions
=======
  void _listenErrorEvents() {
    socket.listen("error_message", (data) {
      state = state.copyWith(error: data["message"], isLoading: false);
    });
  }
>>>>>>> 252dc77c7a8635f6de51f480bea9e375e8d0dc9f

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
<<<<<<< HEAD
    _driftCorrector.stop();
=======
>>>>>>> 252dc77c7a8635f6de51f480bea9e375e8d0dc9f
    controller.leaveSession(state.sessionId);
    state = SessionState.initial();
  }

  void setUrl(String url) {
    if (state.sessionId.isEmpty) return;

    final error = _validateAudioUrl(url);
    if (error != null) {
      state = state.copyWith(error: error);
      return;
    }
<<<<<<< HEAD

    state = state.copyWith(clearError: true);
=======
    state = state.copyWith(error: null, clearError: true);
>>>>>>> 252dc77c7a8635f6de51f480bea9e375e8d0dc9f
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
    controller.stop(state.sessionId);
  }

<<<<<<< HEAD
  void seek(int positionMs) {
    if (state.sessionId.isEmpty) return;
    controller.seek(state.sessionId, positionMs);
  }

  //  Helpers

=======
  // ==========================================
  // 3. MANUAL QUEUE UPDATE FUNCTION
  // ==========================================
  void updateQueue(List<String> newQueue) {
    state = state.copyWith(queue: newQueue);
  }

>>>>>>> 252dc77c7a8635f6de51f480bea9e375e8d0dc9f
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
      '.mp3', '.wav', '.ogg', '.flac', '.aac', '.m4a', '.opus', '.webm',
    ];
    final pathLower = uri.path.toLowerCase();
    if (!supported.any((ext) => pathLower.contains(ext))) {
      return "Supported formats: mp3, wav, ogg, flac, aac, m4a, opus, webm";
    }
<<<<<<< HEAD
=======

>>>>>>> 252dc77c7a8635f6de51f480bea9e375e8d0dc9f
    return null;
  }

  Duration getCurrentPosition() {
    if (state.playbackState != PlaybackState.playing ||
        state.startedAt == null) {
      return state.position;
    }
    final nowMs = timeSync.getServerTime().toInt();
    final elapsedMs = nowMs - state.startedAt!.millisecondsSinceEpoch;
    return state.position + Duration(milliseconds: elapsedMs);
  }

  @override
  void dispose() {
    _driftCorrector.dispose();
    super.dispose();
  }
}