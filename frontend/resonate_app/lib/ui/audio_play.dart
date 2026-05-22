import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonate_app/providers/session_provider.dart';
import 'package:resonate_app/providers/session_state.dart';
import 'package:resonate_app/providers/auth_provider.dart';
import 'package:resonate_app/controllers/socket_controller.dart' as ctrl;
import 'package:resonate_app/services/music_service.dart';
import 'package:resonate_app/ui/music_search_screen.dart';
class AudioPlay extends ConsumerStatefulWidget {
  const AudioPlay({super.key});

  @override
  ConsumerState<AudioPlay> createState() => _AudioPlayState();
}

class _AudioPlayState extends ConsumerState<AudioPlay> {
  final TextEditingController urlController = TextEditingController();

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }

  // --- HELPERS (RESTORED) ---

  Color _statusColor(PlaybackState state) {
    switch (state) {
      case PlaybackState.playing: return Colors.green;
      case PlaybackState.paused: return Colors.orange;
      case PlaybackState.stopped: return Colors.red;
    }
  }

  String _statusLabel(PlaybackState state) {
    switch (state) {
      case PlaybackState.playing: return "Playing";
      case PlaybackState.paused: return "Paused";
      case PlaybackState.stopped: return "Stopped";
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

  Widget _infoRow(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Flexible(
          child: Text(value,
              style: valueStyle ?? const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis
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
    final isHost = hasSession && myUserId.isNotEmpty && session.hostId == myUserId;

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow("Session ID", session.sessionId.isEmpty ? "Not joined" : session.sessionId),
                    const SizedBox(height: 8),
                    _infoRow("Role", isHost ? "Host" : "Listener",
                        valueStyle: TextStyle(color: isHost ? Colors.greenAccent : Colors.white70, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("State", style: TextStyle(color: Colors.white70)),
                        Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: _statusColor(session.playbackState), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(_statusLabel(session.playbackState), style: const TextStyle(color: Colors.white)),
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
              decoration: InputDecoration(
                hintText: 'Paste audio URL here...',
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: hasSession ? () => _handleHostAction(isHost, () => ref.read(sessionProvider.notifier).setUrl(urlController.text.trim())) : null, child: const Text("Load Track"))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: hasSession ? () => _handleHostAction(isHost, () => ref.read(ctrl.socketControllerProvider).addToQueue(session.sessionId, urlController.text.trim())) : null, child: const Text("Add to Queue"))),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text("Search Music"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent),
                onPressed: hasSession
                    ? () => _handleHostAction(isHost, () async {
                  final MusicTrack? track = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MusicSearchScreen()),
                  );
                  if (track != null) {
                    // Show options dialog
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF2D2D44),
                        title: Text(track.title,
                            style: const TextStyle(color: Colors.white)),
                        content: Text(track.artist,
                            style: const TextStyle(color: Colors.white54)),
                        actions: [
                          TextButton(
                            child: const Text("Play Now",
                                style: TextStyle(color: Colors.greenAccent)),
                            onPressed: () {
                              Navigator.pop(context);
                              ref.read(sessionProvider.notifier).selectTrack(track);
                            },
                          ),
                          TextButton(
                            child: const Text("Add to Queue",
                                style: TextStyle(color: Colors.deepPurpleAccent)),
                            onPressed: () {
                              Navigator.pop(context);
                              ref.read(ctrl.socketControllerProvider)
                                  .addToQueue(session.sessionId, track.audioUrl);
                            },
                          ),
                        ],
                      ),
                    );
                  }
                })
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            if (session.currentTrack != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.white10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: session.currentTrack!.imageUrl != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      session.currentTrack!.imageUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  )
                      : const Icon(Icons.music_note, color: Colors.white54, size: 40),
                  title: Text(
                    session.currentTrack!.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    session.currentTrack!.artist,
                    style: const TextStyle(color: Colors.white54),
                  ),
    trailing: IconButton(
    icon: const Icon(Icons.queue_music, color: Colors.deepPurpleAccent),
    onPressed: hasSession ? () => _handleHostAction(isHost, () {
    ref.read(ctrl.socketControllerProvider)
        .addToQueue(session.sessionId, session.currentTrack!.audioUrl);
    ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Added to queue")),
    );
    }) : null,
    ),
    ),
    ),
    const SizedBox(height: 8),
    ],

            // MAIN CONTROLS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(icon: const Icon(Icons.play_arrow, color: Colors.greenAccent, size: 40), onPressed: hasSession ? () => _handleHostAction(isHost, () => ref.read(sessionProvider.notifier).play()) : null),
                IconButton(icon: const Icon(Icons.pause, color: Colors.orangeAccent, size: 40), onPressed: hasSession ? () => _handleHostAction(isHost, () => ref.read(sessionProvider.notifier).pause()) : null),
                IconButton(icon: const Icon(Icons.stop, color: Colors.redAccent, size: 40), onPressed: hasSession ? () => _handleHostAction(isHost, () => ref.read(sessionProvider.notifier).stop()) : null),
              ],
            ),

            // QUEUE LIST
            if (session.queue.isNotEmpty) ...[
              const Divider(color: Colors.white24, height: 40),
              const Text("Next in Queue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: session.queue.length,
                itemBuilder: (context, index) {
                  final queueUrl = session.queue[index];
                  return ListTile(
                    title: Text(queueUrl, style: const TextStyle(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: isHost ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill, color: Colors.greenAccent),
                          onPressed: () => _handleHostAction(isHost, () {
                            // FIXED: Set URL and Play immediately
                            ref.read(sessionProvider.notifier).setUrl(queueUrl);
                            ref.read(sessionProvider.notifier).play();
                            ref.read(ctrl.socketControllerProvider).removeFromQueue(session.sessionId, queueUrl);
                          }),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _handleHostAction(isHost, () {
                            // FIXED: Immediate delete call to socket controller
                            ref.read(ctrl.socketControllerProvider).removeFromQueue(session.sessionId, queueUrl);
                          }),
                        ),
                      ],
                    ) : null,
                  );
                },
              ),
            ]
          ],
        ),
      ),
    );
  }
}