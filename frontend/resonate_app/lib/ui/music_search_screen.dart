import 'package:flutter/material.dart';
import 'package:resonate_app/services/music_service.dart';

class MusicSearchScreen extends StatefulWidget {
  const MusicSearchScreen({super.key});

  @override
  State<MusicSearchScreen> createState() => _MusicSearchScreenState();
}

class _MusicSearchScreenState extends State<MusicSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  _SearchState _state = const _Idle();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    _focusNode.unfocus();
    setState(() => _state = const _Loading());

    final result = await MusicRepository.search(query);

    if (!mounted) return;

    setState(() {
      _state = switch (result) {
        MusicSuccess(:final tracks) => _Loaded(tracks),
        MusicError(:final failure) => _Failed(failure.userMessage),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('Search Music'),
        backgroundColor: const Color(0xFF1E1E2C),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            focusNode: _focusNode,
            onSearch: _search,
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() => switch (_state) {
    _Idle() => const _EmptyPrompt(),
    _Loading() => const _LoadingIndicator(),
    _Failed(:final message) => _ErrorMessage(message),
    _Loaded(:final tracks) => _TrackList(
      tracks: tracks,
      onTrackTap: (track) => Navigator.pop(context, track),
    ),
  };
}

//   Local state ADT
sealed class _SearchState {
  const _SearchState();
}

final class _Idle extends _SearchState {
  const _Idle();
}

final class _Loading extends _SearchState {
  const _Loading();
}

final class _Failed extends _SearchState {
  final String message;
  const _Failed(this.message);
}

final class _Loaded extends _SearchState {
  final List<MusicTrack> tracks;
  const _Loaded(this.tracks);
}

//  Sub widgets

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSearch;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search songs, artists...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            width: 48,
            child: ElevatedButton(
              onPressed: onSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Icon(Icons.search, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            'Search for a song or artist',
            style: TextStyle(color: Colors.white38, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  final String message;
  const _ErrorMessage(this.message);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackList extends StatelessWidget {
  final List<MusicTrack> tracks;
  final void Function(MusicTrack track) onTrackTap;

  const _TrackList({required this.tracks, required this.onTrackTap});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tracks.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Colors.white10, height: 1, indent: 72),
      itemBuilder: (context, index) {
        final track = tracks[index];
        return _TrackTile(track: track, onTap: () => onTrackTap(track));
      },
    );
  }
}

class _TrackTile extends StatelessWidget {
  final MusicTrack track;
  final VoidCallback onTap;

  const _TrackTile({required this.track, required this.onTap});

  String _formatDuration(Duration? d) {
    if (d == null || d.inSeconds == 0) return '';
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: track.imageUrl != null
            ? Image.network(
                track.imageUrl!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
      title: Text(
        track.title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        track.albumTitle.isNotEmpty
            ? '${track.artist} · ${track.albumTitle}'
            : track.artist,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatDuration(track.duration),
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
      onTap: onTap,
    );
  }

  Widget _placeholder() => Container(
    width: 50,
    height: 50,
    color: Colors.white10,
    child: const Icon(Icons.music_note, color: Colors.white38, size: 24),
  );
}
