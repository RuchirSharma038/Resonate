import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonate_app/providers/session_provider.dart';
import 'package:resonate_app/providers/session_state.dart';
import 'package:resonate_app/providers/auth_provider.dart';
import 'package:resonate_app/providers/audioservice_provider.dart';
import 'package:resonate_app/services/music_service.dart';
import 'package:resonate_app/ui/music_search_screen.dart';

class AudioPlay extends ConsumerStatefulWidget {
  const AudioPlay({super.key});

  @override
  ConsumerState<AudioPlay> createState() => _AudioPlayState();
}

class _AudioPlayState extends ConsumerState<AudioPlay> {
  final TextEditingController _urlController = TextEditingController();
  String? _localUrlError;
  double? _dragValue;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  //   Session end listener

  void _handleSessionChange(SessionState? previous, SessionState next) {
    if ((previous?.sessionId.isNotEmpty ?? false) && next.sessionId.isEmpty) {
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }

    if (next.error != null && next.error != previous?.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next.error!),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  //   Host guard

  void _onlyHost(bool isHost, VoidCallback action) {
    if (isHost) {
      action();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the host can control playback'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  //  URL field validation

  void _onUrlChanged(String value) {
    final trimmed = value.trim();
    String? error;
    if (trimmed.isNotEmpty) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null || !uri.isAbsolute) {
        error = 'Enter a valid absolute URL';
      } else if (uri.scheme != 'http' && uri.scheme != 'https') {
        error = 'Must start with http:// or https://';
      }
    }
    if (error != _localUrlError) setState(() => _localUrlError = error);
  }

  void _loadUrlTrack() {
    final url = _urlController.text.trim();
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

  // Music Search Navigation

  Future<void> _openMusicSearch(String sessionId) async {
    final track = await Navigator.push<MusicTrack>(
      context,
      MaterialPageRoute(builder: (_) => const MusicSearchScreen()),
    );
    if (track == null || !mounted) return;

    _showTrackOptions(track, sessionId);
  }

  void _showTrackOptions(MusicTrack track, String sessionId) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          track.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: Text(
          track.artist,
          style: const TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(sessionProvider.notifier).selectTrack(track);
            },
            child: const Text(
              'Play Now',
              style: TextStyle(color: Colors.greenAccent),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // addToQueue goes through the notifier
              ref.read(sessionProvider.notifier).addTrackToQueue(track);
            },
            child: const Text(
              'Add to Queue',
              style: TextStyle(color: Colors.deepPurpleAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }

  //   Build

  @override
  Widget build(BuildContext context) {
    // Listen for session changes
    ref.listen(sessionProvider, _handleSessionChange);

    final session = ref.watch(sessionProvider);
    final myUserId = ref.watch(myUserIdProvider);
    final hasSession = session.sessionId.isNotEmpty;
    final isHost =
        hasSession && myUserId.isNotEmpty && session.hostId == myUserId;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: _buildAppBar(isHost, hasSession),
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
            //  Session info
            _SessionInfoCard(session: session, isHost: isHost),
            const SizedBox(height: 20),

            //  Current track
            if (session.currentTrack != null) ...[
              _CurrentTrackCard(
                track: session.currentTrack!,
                sessionId: session.sessionId,
                isHost: isHost,
                onAddToQueue: (track) => _onlyHost(isHost, () {
                  ref.read(sessionProvider.notifier).addTrackToQueue(track);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to queue')),
                  );
                }),
              ),
              const SizedBox(height: 12),
            ],

            // Seek bar
            _SeekBar(
              isHost: isHost,
              hasSession: hasSession,
              dragValue: _dragValue,
              onDrag: (v) => setState(() => _dragValue = v),
              onSeek: (v) {
                ref.read(sessionProvider.notifier).seek(v.toInt());
                setState(() => _dragValue = null);
              },
              player: ref.read(audioServiceProvider).player,
            ),
            const SizedBox(height: 10),

            // Playback controls
            _PlaybackControls(
              isHost: isHost,
              hasSession: hasSession,
              onPlay: () => _onlyHost(
                isHost,
                () => ref.read(sessionProvider.notifier).play(),
              ),
              onPause: () => _onlyHost(
                isHost,
                () => ref.read(sessionProvider.notifier).pause(),
              ),
              onStop: () => _onlyHost(
                isHost,
                () => ref.read(sessionProvider.notifier).stop(),
              ),
            ),
            const SizedBox(height: 20),

            //  URL input
            if (isHost) ...[
              _UrlInputRow(
                controller: _urlController,
                localUrlError: _localUrlError,
                onChanged: _onUrlChanged,
                onLoadTrack: () => _onlyHost(isHost, _loadUrlTrack),
                onAddToQueue: () => _onlyHost(isHost, () {
                  final url = _urlController.text.trim();
                  if (url.isEmpty) return;
                  if (_localUrlError != null) return;
                  ref.read(sessionProvider.notifier).addUrlToQueue(url);
                }),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Search Music'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: hasSession
                      ? () => _onlyHost(
                          isHost,
                          () => _openMusicSearch(session.sessionId),
                        )
                      : null,
                ),
              ),
            ],

            //  Queue
            if (session.queue.isNotEmpty) ...[
              const Divider(color: Colors.white24, height: 40),
              _QueueList(
                queue: session.queue,
                sessionId: session.sessionId,
                isHost: isHost,
                onPlayNow: (track) => _onlyHost(isHost, () {
                  ref.read(sessionProvider.notifier).selectTrack(track);
                  ref.read(sessionProvider.notifier).removeTrackFromQueue(track.id);
                }),
                onRemove: (trackId) => _onlyHost(isHost, () {
                  ref.read(sessionProvider.notifier).removeTrackFromQueue(trackId);
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(bool isHost, bool hasSession) {
    return AppBar(
      backgroundColor: const Color(0xFF1E1E2C),
      surfaceTintColor: Colors.transparent,
      title: const Text('Resonate Player'),
      leading: IconButton(
        icon: const Icon(Icons.exit_to_app),
        tooltip: 'Leave Session',
        onPressed: hasSession
            ? () {
                ref.read(sessionProvider.notifier).leaveSession();
              }
            : null,
      ),
    );
  }
}

//  Sub widgets
class _SessionInfoCard extends StatelessWidget {
  final SessionState session;
  final bool isHost;
  const _SessionInfoCard({required this.session, required this.isHost});

  Color _stateColor(PlaybackState s) => switch (s) {
    PlaybackState.playing => Colors.green,
    PlaybackState.paused => Colors.orange,
    PlaybackState.stopped => Colors.red,
  };

  String _stateLabel(PlaybackState s) => switch (s) {
    PlaybackState.playing => 'Playing',
    PlaybackState.paused => 'Paused',
    PlaybackState.stopped => 'Stopped',
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Row(
              'Session ID',
              session.sessionId.isEmpty ? 'Not joined' : session.sessionId,
            ),
            const SizedBox(height: 8),
            _Row(
              'Role',
              isHost ? 'Host' : 'Listener',
              valueStyle: TextStyle(
                color: isHost ? Colors.greenAccent : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('State', style: TextStyle(color: Colors.white70)),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _stateColor(session.playbackState),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _stateLabel(session.playbackState),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Row('Listeners', session.participants.length.toString()),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  const _Row(this.label, this.value, {this.valueStyle});

  @override
  Widget build(BuildContext context) {
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

class _CurrentTrackCard extends StatelessWidget {
  final MusicTrack track;
  final String sessionId;
  final bool isHost;
  final void Function(MusicTrack) onAddToQueue;

  const _CurrentTrackCard({
    required this.track,
    required this.sessionId,
    required this.isHost,
    required this.onAddToQueue,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: track.imageUrl != null
              ? Image.network(
                  track.imageUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                )
              : const Icon(Icons.music_note, color: Colors.white54, size: 40),
        ),
        title: Text(
          track.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          track.artist,
          style: const TextStyle(color: Colors.white54),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isHost
            ? IconButton(
                icon: const Icon(
                  Icons.queue_music,
                  color: Colors.deepPurpleAccent,
                ),
                onPressed: () => onAddToQueue(track),
              )
            : null,
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  final bool isHost;
  final bool hasSession;
  final double? dragValue;
  final void Function(double) onDrag;
  final void Function(double) onSeek;
  final dynamic player; // AudioPlayer

  const _SeekBar({
    required this.isHost,
    required this.hasSession,
    required this.dragValue,
    required this.onDrag,
    required this.onSeek,
    required this.player,
  });

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
    }
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: player.positionStream,
      builder: (context, posSnap) => StreamBuilder<Duration?>(
        stream: player.durationStream,
        builder: (context, durSnap) {
          final position = posSnap.data ?? Duration.zero;
          final duration = durSnap.data ?? Duration.zero;
          final maxDur = duration.inMilliseconds > 0
              ? duration.inMilliseconds.toDouble()
              : 1.0;
          final sliderValue = (dragValue ?? position.inMilliseconds.toDouble())
              .clamp(0.0, maxDur);

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
                  max: maxDur,
                  value: sliderValue,
                  onChanged: (isHost && hasSession) ? onDrag : null,
                  onChangeEnd: (isHost && hasSession) ? onSeek : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmt(position),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _fmt(duration),
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
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  final bool isHost;
  final bool hasSession;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStop;

  const _PlaybackControls({
    required this.isHost,
    required this.hasSession,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final active = isHost && hasSession;
    return Container(
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
            tooltip: 'Play',
            icon: Icon(
              Icons.play_arrow,
              color: active ? Colors.white : Colors.white24,
            ),
            onPressed: hasSession ? onPlay : null,
          ),
          IconButton(
            iconSize: 36,
            tooltip: 'Pause',
            icon: Icon(
              Icons.pause,
              color: active ? Colors.white : Colors.white24,
            ),
            onPressed: hasSession ? onPause : null,
          ),
          IconButton(
            iconSize: 36,
            tooltip: 'Stop',
            icon: Icon(
              Icons.stop,
              color: active ? Colors.white : Colors.white24,
            ),
            onPressed: hasSession ? onStop : null,
          ),
        ],
      ),
    );
  }
}

class _UrlInputRow extends StatelessWidget {
  final TextEditingController controller;
  final String? localUrlError;
  final void Function(String) onChanged;
  final VoidCallback onLoadTrack;
  final VoidCallback onAddToQueue;

  const _UrlInputRow({
    required this.controller,
    required this.localUrlError,
    required this.onChanged,
    required this.onLoadTrack,
    required this.onAddToQueue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Paste audio URL here...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            errorText: localUrlError,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: onLoadTrack,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Load Track'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: onAddToQueue,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Add to Queue'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QueueList extends StatelessWidget {
  final List<MusicTrack> queue;
  final String sessionId;
  final bool isHost;
  final void Function(MusicTrack track) onPlayNow;
  final void Function(String trackId) onRemove;

  const _QueueList({
    required this.queue,
    required this.sessionId,
    required this.isHost,
    required this.onPlayNow,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Next in Queue',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: queue.length,
          itemBuilder: (context, index) {
            final track = queue[index];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: track.imageUrl != null
                    ? Image.network(track.imageUrl!, width: 40, height: 40, fit: BoxFit.cover)
                    : Container(
                        width: 40,
                        height: 40,
                        color: Colors.white10,
                        child: const Icon(Icons.music_note, color: Colors.white54, size: 24),
                      ),
              ),
              title: Text(
                track.title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                track.artist,
                style: const TextStyle(fontSize: 11, color: Colors.white54),
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
                          onPressed: () => onPlayNow(track),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => onRemove(track.id),
                        ),
                      ],
                    )
                  : null,
            );
          },
        ),
      ],
    );
  }
}
