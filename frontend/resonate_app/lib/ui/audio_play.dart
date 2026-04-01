import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonate_app/providers/session_provider.dart';
import 'package:resonate_app/providers/session_state.dart';

class AudioPlay extends ConsumerStatefulWidget {
  const AudioPlay({super.key});

  @override
  ConsumerState<AudioPlay> createState() => _AudioPlayState();
}

class _AudioPlayState extends ConsumerState<AudioPlay> {
  final TextEditingController urlcontroller = TextEditingController();

  // ── local validation state ─────────────────────────────────────────────────
  String? _localUrlError;

  @override
  void dispose() {
    urlcontroller.dispose();
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

  /// Client-side URL check — mirrors the notifier's _validateAudioUrl.
  /// Runs on every keystroke so the user gets instant feedback.
  void _onUrlChanged(String value) {
    final trimmed = value.trim();
    setState(() {
      if (trimmed.isEmpty) {
        _localUrlError = null; // don't nag on empty
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
      final hasExt = supported.any((e) => uri.path.toLowerCase().contains(e));
      if (!hasExt) {
        _localUrlError = "Must be a direct link to an audio file";
        return;
      }
      _localUrlError = null; // all good
    });
  }

  void _loadTrack(BuildContext context) {
    final url = urlcontroller.text.trim();
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
    final hasSession = session.sessionId.isNotEmpty;

    // Show server-side errors from state (e.g. validation rejection)
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
          // Leave session button
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ICON
              const CircleAvatar(
                radius: 45,
                backgroundColor: Colors.white24,
                child: Icon(Icons.music_note, size: 50, color: Colors.white),
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
                      if (session.url != null) ...[
                        const SizedBox(height: 8),
                        _infoRow(
                          "Track",
                          session.url!,
                          valueStyle: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // URL INPUT
              TextField(
                controller: urlcontroller,
                onChanged: _onUrlChanged,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'https://example.com/track.mp3',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(Icons.link, color: Colors.white70),
                  // Show inline validation error in real-time
                  errorText: _localUrlError,
                  errorStyle: const TextStyle(color: Colors.orangeAccent),
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
                    // Grey out if not in session or local validation failed
                    backgroundColor: (hasSession && _localUrlError == null)
                        ? null
                        : Colors.white24,
                  ),
                  onPressed: (hasSession && _localUrlError == null)
                      ? () => _loadTrack(context)
                      : null,
                  child: const Text("Load Track"),
                ),
              ),

              const Spacer(),

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
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      onPressed: hasSession
                          ? () => ref.read(sessionProvider.notifier).play()
                          : null,
                    ),
                    IconButton(
                      iconSize: 36,
                      tooltip: "Pause",
                      icon: const Icon(Icons.pause, color: Colors.white),
                      onPressed: hasSession
                          ? () => ref.read(sessionProvider.notifier).pause()
                          : null,
                    ),
                    IconButton(
                      iconSize: 36,
                      tooltip: "Stop",
                      icon: const Icon(Icons.stop, color: Colors.white),
                      // Stop button is always accessible when in a session
                      onPressed: hasSession
                          ? () => ref.read(sessionProvider.notifier).stop()
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
    );
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
}
