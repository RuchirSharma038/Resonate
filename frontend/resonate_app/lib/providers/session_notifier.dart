import 'dart:async';
import 'package:flutter_riverpod/legacy.dart';
import 'package:resonate_app/providers/audio_service.dart';
import 'package:resonate_app/services/drift_corrector.dart';
import 'package:resonate_app/services/time_sync_service.dart';
import '../services/socket_service.dart';
import './session_state.dart';
import '../controllers/socket_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:resonate_app/services/music_service.dart';

class SessionNotifier extends StateNotifier<SessionState> {
  final SocketController controller;
  final SocketService socket;
  final AudioService audio;
  final TimeSyncService timeSync;

  late final DriftCorrector _driftCorrector;

  SessionNotifier(this.controller, this.socket, this.audio, this.timeSync)
    : super(SessionState.initial()) {
    _driftCorrector = DriftCorrector(
      player: audio.player,
      getServerTime: timeSync.getServerTime,
    );
    _init();
  }

  // ── Init
  void _init() {
    controller.init();
    _listenConnection();
    _listenSessionEvents();
    _listenPlaybackEvents();
    _listenErrorEvents();

    audio.onLoadError = (errorMsg) {
      state = state.copyWith(error: errorMsg);
    };

    audio.onSongComplete = () {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      final isHost = (state.hostId != null) && (state.hostId == currentUserId);

      if (isHost && state.sessionId.isNotEmpty) {
        controller.playNext(state.sessionId);
      }
    };
  }

  // ── Listeners
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
        hostId: data["hostId"],
        participants: [data["hostId"]],
        isLoading: false,
      );
    });

    socket.listen("user_joined", (data) {
      final userId = data["userId"] as String;
      if (!state.participants.contains(userId)) {
        final updated = List<String>.from(state.participants)..add(userId);
        state = state.copyWith(participants: updated);
      }
    });

    socket.listen("user_left", (data) {
      final updated = List<String>.from(state.participants)
        ..removeWhere((u) => u == data["userId"]);
      state = state.copyWith(participants: updated);
    });

    socket.listen("host_changed", (data) {
      state = state.copyWith(hostId: data["hostId"] as String?);
    });

    socket.listen("session_state", (data) async {
      final url = data["url"] as String?;
      final serverState = data["state"] as String?;
      final serverPos = (data["position"] as num?)?.toInt() ?? 0;
      final serverStartAt = (data["startedAt"] as num?)?.toInt();
      final hostId = data["hostId"] as String?;
      final sessionId = data["sessionId"] as String?;
      final participants = data["participants"];

      // 1. GRAB THE QUEUE FROM THE SERVER STATE
      final queueRaw = data["queue"];

      state = state.copyWith(
        sessionId: sessionId ?? state.sessionId,
        participants: participants != null
            ? List<String>.from(participants)
            : state.participants,
        queue: queueRaw != null ? List<String>.from(queueRaw) : state.queue,
        isLoading: false,
      );

      if (url != null) {
        await audio.load(url);
        state = state.copyWith(url: url);
      }

      if (serverState == "playing" && serverStartAt != null) {
        // Server sends live position. Seek there directly.
        await audio.seek(Duration(milliseconds: serverPos));
        await audio.play();

        final startedAt = DateTime.fromMillisecondsSinceEpoch(serverStartAt);
        state = state.copyWith(
          playbackState: PlaybackState.playing,
          position: Duration(milliseconds: serverPos),
          startedAt: startedAt,
          hostId: hostId,
        );

        // Start drift correction.
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
        );
      } else {
        _driftCorrector.stop();
        await audio.stop();
        state = state.copyWith(
          playbackState: PlaybackState.stopped,
          position: Duration.zero,
          clearStartedAt: true,
          hostId: hostId,
        );
      }
    });
  }

  bool _autoPlayAfterLoad = false;
  void _listenPlaybackEvents() {
    socket.listen("song_updated", (data) async {
      _driftCorrector.stop();
      final newUrl = data["url"] as String;
      state = state.copyWith(url: newUrl);
      await audio.load(newUrl);
      if (_autoPlayAfterLoad) {
        _autoPlayAfterLoad = false;
        controller.playSong(state.sessionId);
      }
    });

    socket.listen("track_selected", (data) async {
      final track = MusicTrack.fromJson(
        Map<String, dynamic>.from(data["track"]),
      );
      await audio.load(track.audioUrl);
      state = state.copyWith(url: track.audioUrl, currentTrack: track);
    });

    // THE QUEUE LISTENER
    socket.listen("queue_updated", (data) {
      if (data != null) {
        final updatedQueue = List<String>.from(data);
        state = state.copyWith(queue: updatedQueue);
      }
    });

    socket.listen("play_song", (data) async {
      _driftCorrector.stop();

      final serverStartTime = (data["startTime"] as num).toInt();
      final basePosition = (data["position"] as num).toInt();
      final now = timeSync.getServerTime();
      final timeUntilPlay = serverStartTime - now;

      if (timeUntilPlay > 0) {
        await audio.seek(Duration(milliseconds: basePosition));
        await Future.delayed(Duration(milliseconds: timeUntilPlay.toInt()));

        // Post-delay drift check
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

      // Begin continuous drift monitoring.
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
    socket.listen("error_message", (data) {
      state = state.copyWith(
        error: data["message"] as String?,
        isLoading: false,
      );
    });
  }

  // ── Public Actions

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
    _driftCorrector.stop();
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

    state = state.copyWith(
      error: null,
      clearCurrentTrack: true,
      clearError: true,
    );
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

  void seek(int positionMs) {
    if (state.sessionId.isEmpty) return;
    controller.seek(state.sessionId, positionMs);
  }

  //  MANUAL QUEUE UPDATE FUNCTION
  void updateQueue(List<String> newQueue) {
    state = state.copyWith(queue: newQueue);
  }

  void selectTrack(MusicTrack track) async {
    if (state.sessionId.isEmpty) return;

    state = state.copyWith(
      url: track.audioUrl,
      currentTrack: track,
      playbackState: PlaybackState.stopped,
      clearStartedAt: true,
    );

    await audio.load(track.audioUrl);

    controller.selectTrack(state.sessionId, track.toJson());
  }

  void setUrlAndPlay(String url) {
    if (state.sessionId.isEmpty) return;
    final error = _validateAudioUrl(url);
    if (error != null) {
      state = state.copyWith(error: error);
      return;
    }
    _autoPlayAfterLoad = true;
    state = state.copyWith(clearError: true);
    controller.setUrl(state.sessionId, url);
  }

  // ── Helpers

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
    if (!supported.any((ext) => pathLower.contains(ext))) {
      return "Supported formats: mp3, wav, ogg, flac, aac, m4a, opus, webm";
    }
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
