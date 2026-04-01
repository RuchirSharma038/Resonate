enum PlaybackState { playing, paused, stopped }

class SessionState {
  final String sessionId;
  final String? hostId;

  final PlaybackState playbackState;
  final String? url;
  final Duration position;
  final DateTime? startedAt;

  final List<String> participants;

  final bool isConnected;
  final bool isLoading;

  final String? error;

  SessionState({
    required this.sessionId,
    this.hostId,
    required this.playbackState,

    this.url,
    this.position = Duration.zero,
    this.startedAt,
    this.participants = const [],
    this.isConnected = false,
    this.isLoading = false,
    this.error,
  });

  factory SessionState.initial() {
    return SessionState(sessionId: "", playbackState: PlaybackState.stopped);
  }

  SessionState copyWith({
    String? sessionId,
    String? hostId,
    PlaybackState? playbackState,
    String? url,
    Duration? position,
    DateTime? startedAt,
    List<String>? participants,
    bool? isConnected,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SessionState(
      sessionId: sessionId ?? this.sessionId,
      hostId: hostId ?? this.hostId,
      playbackState: playbackState ?? this.playbackState,
      url: url ?? this.url,
      position: position ?? this.position,
      startedAt: startedAt == _keep ? this.startedAt : startedAt,
      participants: participants ?? this.participants,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  static const _keep = Object();
}
