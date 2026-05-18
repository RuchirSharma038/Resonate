import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonate_app/providers/session_provider.dart';
import 'package:resonate_app/providers/session_state.dart';
import 'package:resonate_app/providers/auth_provider.dart';
import 'package:resonate_app/controllers/socket_controller.dart' as ctrl;
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

  // --- HELPERS (RESTORED) ---

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

  void _handleHostAction(bool isHost, VoidCallback action) {
    if (isHost) {
      action();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Only the host can control playback"),
          backgroundColor: Colors.orangeAccent,
        ),
      );
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
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: Colors.deepPurpleAccent,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.deepPurpleAccent,
                  ),
                  child: Slider(
                    min: 0.0,
                    max: durValue > 0 ? durValue : 1.0,
                    value: posValue <= (durValue > 0 ? durValue : 1.0)
                        ? posValue
                        : 0.0,
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
                      Text(
                        _formatDuration(position),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
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

  Widget _infoRow(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Flexible(
          child: Text(
            value,
            style: valueStyle ?? const TextStyle(color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final myUserId = ref.watch(myUserIdProvider);
    final hasSession = session.sessionId.isNotEmpty;
    final isHost =
        hasSession && myUserId.isNotEmpty && session.hostId == myUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resonate Player'),
        backgroundColor: const Color(0xFF1E1E2C),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1E2C), Color(0xFF2D2D44)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // SESSION INFO CARD (RESTORED ALL FEATURES)
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
                      "Session ID",
                      session.sessionId.isEmpty
                          ? "Not joined"
                          : session.sessionId,
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      "Role",
                      isHost ? "Host" : "Listener",
                      valueStyle: TextStyle(
                        color: isHost ? Colors.greenAccent : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                                color: _statusColor(session.playbackState),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _statusLabel(session.playbackState),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _infoRow("Users", session.participants.length.toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // URL INPUT
            TextField(
              controller: urlController,
              onChanged: _onUrlChanged,
              decoration: InputDecoration(
                hintText: 'Paste audio URL here...',
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: _localUrlError,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: hasSession
                        ? () => _handleHostAction(
                            isHost,
                            () => _loadTrack(context),
                          )
                        : null,
                    child: const Text("Load Track"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: hasSession
                        ? () => _handleHostAction(
                            isHost,
                            () => ref
                                .read(ctrl.socketControllerProvider)
                                .addToQueue(
                                  session.sessionId,
                                  urlController.text.trim(),
                                ),
                          )
                        : null,
                    child: const Text("Add to Queue"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // SEEK BAR (From main)
            _buildSeekBar(isHost, hasSession),
            const SizedBox(height: 10),

            // PLAYBACK CONTROLS (From main)
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
                            () => ref.read(sessionProvider.notifier).play(),
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
                            () => ref.read(sessionProvider.notifier).pause(),
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
                            () => ref.read(sessionProvider.notifier).stop(),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // QUEUE LIST
            if (session.queue.isNotEmpty) ...[
              const Divider(color: Colors.white24, height: 40),
              const Text(
                "Next in Queue",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: session.queue.length,
                itemBuilder: (context, index) {
                  final queueUrl = session.queue[index];
                  return ListTile(
                    title: Text(
                      queueUrl,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isHost
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.greenAccent,
                                ),
                                onPressed: () => _handleHostAction(isHost, () {
                                  ref
                                      .read(sessionProvider.notifier)
                                      .setUrl(queueUrl);
                                  ref.read(sessionProvider.notifier).play();
                                  ref
                                      .read(ctrl.socketControllerProvider)
                                      .removeFromQueue(
                                        session.sessionId,
                                        queueUrl,
                                      );
                                }),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _handleHostAction(isHost, () {
                                  ref
                                      .read(ctrl.socketControllerProvider)
                                      .removeFromQueue(
                                        session.sessionId,
                                        queueUrl,
                                      );
                                }),
                              ),
                            ],
                          )
                        : null,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
