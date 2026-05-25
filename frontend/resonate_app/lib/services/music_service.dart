import 'dart:convert';
import 'package:http/http.dart' as http;

class MusicService {

  static const String backendUrl = 'http://10.58.8.243:3001/api/music/search';

  static Future<List<MusicTrack>> searchMusic(String query) async {
    try {
      if (query.trim().isEmpty) throw Exception('Search query cannot be empty');

      final url = Uri.parse('$backendUrl?q=${Uri.encodeComponent(query)}');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);


        final List<dynamic> results = jsonData['results'] ?? [];
        if (results.isEmpty) throw Exception('No songs found for "$query"');

        return results.map((track) => MusicTrack.fromApi(track)).toList();
      } else {
        throw Exception('Failed to search music: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching music: $e');
    }
  }
}

class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final String? imageUrl;
  final String source;
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


  factory MusicTrack.fromApi(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['trackId'].toString(),
      title: json['trackName'] ?? 'Unknown',
      artist: json['artistName'] ?? 'Unknown',
      audioUrl: json['previewUrl'] ?? '',
      imageUrl: json['artworkUrl100'],
      source: 'itunes',
      duration: Duration(milliseconds: json['trackTimeMillis'] ?? 0),
    );
  }

  // Used when sending track over Socket.IO to other users
  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['id'].toString(),
      title: json['title'] ?? 'Unknown',
      artist: json['artist'] ?? 'Unknown',
      audioUrl: json['audioUrl'] ?? '',
      imageUrl: json['imageUrl'],
      source: json['source'] ?? 'api',
      duration: Duration(seconds: json['duration'] ?? 0),
    );
  }

  // Used when receiving track over Socket.IO
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
}