import 'package:flutter/material.dart';
import 'package:resonate_app/services/music_service.dart';

class MusicSearchScreen extends StatefulWidget {
  const MusicSearchScreen({super.key});

  @override
  State<MusicSearchScreen> createState() => _MusicSearchScreenState();
}

class _MusicSearchScreenState extends State<MusicSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<MusicTrack> _results = [];
  bool _isLoading = false;
  String? _error;

  Future<void> _search() async {
    setState(() { _isLoading = true; _error = null; _results = []; });
    try {
      final results = await MusicService.searchMusic(_searchController.text);
      setState(() { _results = results; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Music'),
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
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search songs, artists...',
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _search,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                    ),
                    child: const Icon(Icons.search),
                  ),
                ],
              ),
            ),

            // Loading / Error
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.redAccent)),
              ),

            // Results list
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final track = _results[index];
                  return ListTile(
                    leading: track.imageUrl != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        track.imageUrl!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    )
                        : const Icon(Icons.music_note, color: Colors.white54),
                    title: Text(track.title,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(track.artist,
                        style: const TextStyle(color: Colors.white54)),
                    trailing: track.duration != null
                        ? Text(
                      '${track.duration!.inMinutes}:${(track.duration!.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white38),
                    )
                        : null,

                    onTap: () => Navigator.pop(context, track),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}