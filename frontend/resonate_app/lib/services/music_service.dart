import 'dart:convert';
import 'package:http/http.dart' as http;

class MusicService {
  // Replace with your actual Pixabay API key from https://pixabay.com/api/
  static const String pixabayApiKey = 'YOUR_PIXABAY_API_KEY_HERE';
  static const String pixabayBaseUrl = 'https://pixabay.com/api/audio/';

  /// Search music on Pixabay
  /// Returns a list of MusicTrack objects
  static Future<List<MusicTrack>> searchPixabayMusic(String query) async {
    try {
      if (query.trim().isEmpty) {
        throw Exception('Search query cannot be empty');
      }

      final url = Uri.parse(
        '$pixabayBaseUrl?key=$pixabayApiKey&q=${Uri.encodeComponent(query)}&per_page=20',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timed out'),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> hits = jsonData['hits'] ?? [];

        if (hits.isEmpty) {
          throw Exception('No songs found for "$query"');
        }

        return hits
            .map((track) => MusicTrack.fromPixabay(track))
            .toList();
      } else if (response.statusCode == 400) {
        throw Exception('Invalid API key or search parameters');
      } else {
        throw Exception('Failed to search music: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching music: $e');
    }
  }
}

/// Model class for music tracks
class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final String? imageUrl;
  final String source; // 'pixabay'
  final Duration? duration;

  MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    this.imageUrl,
    required this.source,
    this.duration,
  });

  /// Parse Pixabay API response
  factory MusicTrack.fromPixabay(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['id'].toString(),
      title: json['tags'] ?? 'Unknown Title',
      artist: json['user'] ?? 'Unknown Artist',
      // Pixabay provides preview URL - use the full audio if available
      audioUrl: json['preview'] ?? json['audio'] ?? '',
      imageUrl: json['image'],
      source: 'pixabay',
      duration: Duration(
        seconds: json['duration'] ?? 0,
      ),
    );
  }

  /// Convert to JSON for sending to backend via Socket.IO
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'audioUrl': audioUrl,
      'imageUrl': imageUrl,
      'source': source,
      'duration': duration?.inSeconds ?? 0,
    };
  }

  @override
  String toString() => 'MusicTrack(id: $id, title: $title, artist: $artist)';
}
