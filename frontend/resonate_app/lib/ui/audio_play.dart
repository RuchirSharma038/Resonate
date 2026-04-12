import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonate_app/providers/session_provider.dart';
import 'package:resonate_app/providers/session_state.dart';
import 'package:resonate_app/providers/auth_provider.dart';
import 'package:resonate_app/providers/audioservice_provider.dart';

class AudioPlay extends ConsumerStatefulWidget {
  const AudioPlay({super.key});

  @override
  ConsumerState<AudioPlay> createState() => _AudioPlayState();
}

class _AudioPlayState extends ConsumerState<AudioPlay> {
  final TextEditingController urlController = TextEditingController();

  String? _localUrlError;

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }

  Color _statusColor(PlaybackState state) {
    switch (state) {
      case PlaybackState.playing:
        return Colors.green;
      case PlaybackState.paused:
        return Colors.orange;
      case PlaybackState.stopped:
        return Colors.red;
    }
  }

  String _statusLabel(PlaybackState state) {
    switch (state) {
      case PlaybackState.playing:
        return "Playing";
      case PlaybackState.paused:
        return "Paused";
      case PlaybackState.stopped:
        return "Stopped";
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${d.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildSeekBar(bool isHost, bool hasSession) {
    final player = ref.read(audioServiceProvider).player;
    return StreamBuilder<Duration?>(
      stream: player.positionStream,
      builder: (context, posSnap) {
        return StreamBuilder<Duration?>(
          stream: player.durationStream,
          builder: (context, durSnap) {
            final position = posSnap.data ?? Duration.zero;
            final duration = durSnap.data ?? Duration.zero;

            double posValue = position.inMilliseconds.toDouble();
            double durValue = duration.inMilliseconds.toDouble();
            if (posValue > durValue && durValue > 0) posValue = durValue;

            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: Colors.deepPurpleAccent,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.deepPurpleAccent,
                  ),
                  child: Slider(
                    min: 0.0,
                    max: durValue > 0 ? durValue : 1.0,
                    value: posValue <= (durValue > 0 ? durValue : 1.0) ? posValue : 0.0,
                    onChanged: (val) {
                      if (!isHost || !hasSession) {
                        _handleHostAction(isHost, () {});
                        return;
                      }
                    },
                    onChangeEnd: (val) {
                      if (!isHost || !hasSession) return;
                      ref.read(sessionProvider.notifier).seek(val.toInt());
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(position), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      Text(_formatDuration(duration), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Client-side URL check
  void _onUrlChanged(String value) {
    final trimmed = value.trim();
    setState(() {
      if (trimmed.isEmpty) {
        _localUrlError = null;
        return;
      }
      final uri = Uri.tryParse(trimmed);
      if (uri == null || !uri.isAbsolute) {
        _localUrlError = "Enter a valid absolute URL";
        return;
      }
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        _localUrlError = "Must start with http:// or https://";
        return;
      }

      _localUrlError = null;
    });
  }

  void _loadTrack(BuildContext context) {
    final url = urlController.text.trim();
    if (url.isEmpty) return;
    if (_localUrlError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_localUrlError!),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    ref.read(sessionProvider.notifier).setUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final myUserId = ref.watch(myUserIdProvider);
    final hasSession = session.sessionId.isNotEmpty;

    final isHost =
        hasSession && myUserId.isNotEmpty && session.hostId == myUserId;

    ref.listen(sessionProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resonate Player'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (hasSession)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              tooltip: "Leave session",
              onPressed: () {
                ref.read(sessionProvider.notifier).leaveSession();
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1E2C), Color(0xFF2D2D44)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // ICON
                    const CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.white24,
                      child: Icon(
                        Icons.music_note,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // SESSION CARD
                    Card(
                      color: Colors.white10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _infoRow(
                              "Session",
                              session.sessionId.isEmpty
                                  ? "Not joined"
                                  : session.sessionId,
                            ),
                            const SizedBox(height: 8),
                            if (hasSession) ...[
                              _infoRow(
                                "Role",
                                isHost ? "Host" : "Listener",
                                valueStyle: TextStyle(
                                  color: isHost
                                      ? Colors.greenAccent
                                      : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "State",
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: _statusColor(
                                          session.playbackState,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _statusLabel(session.playbackState),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _infoRow(
                              "Users",
                              session.participants.length.toString(),
                            ),
                            if (session.url != null) ...[
                              const SizedBox(height: 8),
                              _infoRow(
                                "Track",
                                session.url!,
                                valueStyle: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // URL INPUT
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isHost
                          ? null
                          : () => _handleHostAction(isHost, () {}),
                      child: AbsorbPointer(
                        absorbing: !isHost,
                        child: TextField(
                          controller: urlController,
                          onChanged: _onUrlChanged,
                          enabled: isHost,
                          style: TextStyle(
                            color: isHost ? Colors.white : Colors.white38,
                          ),
                          decoration: InputDecoration(
                            hintText: isHost
                                ? 'https://example.com/track.mp3'
                                : 'Waiting for host...',
                            hintStyle: const TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                            prefixIcon: Icon(
                              Icons.link,
                              color: isHost ? Colors.white70 : Colors.white24,
                            ),
                            errorText: _localUrlError,
                            errorStyle: const TextStyle(
                              color: Colors.orangeAccent,
                            ),
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: _localUrlError != null
                                  ? const BorderSide(color: Colors.orangeAccent)
                                  : BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // LOAD BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          backgroundColor:
                              (hasSession &&
                                  isHost &&
                                  _localUrlError == null &&
                                  urlController.text.trim().isNotEmpty)
                              ? Colors.deepPurpleAccent
                              : Colors.white24,
                        ),
                        onPressed: hasSession
                            ? () => _handleHostAction(isHost, () {
                                if (_localUrlError == null) _loadTrack(context);
                              })
                            : null,
                        child: Text(
                          "Load Track",
                          style: TextStyle(
                            color: (hasSession && isHost)
                                ? Colors.white
                                : Colors.white54,
                          ),
                        ),
                      ),
                    ),

                    const Expanded(child: SizedBox(height: 20)),

                    // SEEK BAR
                    _buildSeekBar(isHost, hasSession),
                    const SizedBox(height: 10),

                    // PLAYBACK CONTROLS
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            iconSize: 36,
                            tooltip: "Play",
                            icon: Icon(
                              Icons.play_arrow,
                              color: (hasSession && isHost)
                                  ? Colors.white
                                  : Colors.white24,
                            ),
                            onPressed: hasSession
                                ? () => _handleHostAction(
                                    isHost,
                                    () => ref
                                        .read(sessionProvider.notifier)
                                        .play(),
                                  )
                                : null,
                          ),
                          IconButton(
                            iconSize: 36,
                            tooltip: "Pause",
                            icon: Icon(
                              Icons.pause,
                              color: (hasSession && isHost)
                                  ? Colors.white
                                  : Colors.white24,
                            ),
                            onPressed: hasSession
                                ? () => _handleHostAction(
                                    isHost,
                                    () => ref
                                        .read(sessionProvider.notifier)
                                        .pause(),
                                  )
                                : null,
                          ),
                          IconButton(
                            iconSize: 36,
                            tooltip: "Stop",
                            icon: Icon(
                              Icons.stop,
                              color: (hasSession && isHost)
                                  ? Colors.white
                                  : Colors.white24,
                            ),
                            onPressed: hasSession
                                ? () => _handleHostAction(
                                    isHost,
                                    () => ref
                                        .read(sessionProvider.notifier)
                                        .stop(),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: valueStyle ?? const TextStyle(color: Colors.white),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  void _handleHostAction(bool isHost, VoidCallback hostAction) {
    if (isHost) {
      hostAction();
    } else {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Only the host can perform this action."),
          backgroundColor: Colors.orangeAccent,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
