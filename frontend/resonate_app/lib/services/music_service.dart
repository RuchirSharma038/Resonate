import 'dart:async' as async_lib;
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:resonate_app/config/app_config.dart';

// TYPED FAILURES
sealed class MusicFailure {
  const MusicFailure();
  String get userMessage;
}

final class NoResultsFailure extends MusicFailure {
  final String query;
  const NoResultsFailure(this.query);

  @override
  String get userMessage => 'No playable tracks found for "$query".';
}

final class NetworkFailure extends MusicFailure {
  const NetworkFailure();

  @override
  String get userMessage =>
      'No internet connection. Check your network and try again.';
}

final class TimeoutFailure extends MusicFailure {
  const TimeoutFailure();

  @override
  String get userMessage => 'The request timed out. Please try again.';
}

final class RateLimitFailure extends MusicFailure {
  const RateLimitFailure();

  @override
  String get userMessage =>
      'Too many searches. Please wait a moment and try again.';
}

final class ServerFailure extends MusicFailure {
  final int statusCode;
  const ServerFailure(this.statusCode);

  @override
  String get userMessage =>
      'Server error ($statusCode). Please try again later.';
}

final class ParseFailure extends MusicFailure {
  const ParseFailure();

  @override
  String get userMessage => 'Received unexpected data from the server.';
}

// RESULT TYPE
sealed class MusicResult {
  const MusicResult();
}

final class MusicSuccess extends MusicResult {
  final List<MusicTrack> tracks;
  const MusicSuccess(this.tracks);
}

final class MusicError extends MusicResult {
  final MusicFailure failure;
  const MusicError(this.failure);
}

// MUSIC TRACK MODEL

final class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final String? imageUrl;
  final String albumTitle;
  final String genre;
  final String source;
  final Duration? duration;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    this.imageUrl,
    this.albumTitle = '',
    this.genre = '',
    required this.source,
    this.duration,
  });

  // Deserialise
  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    final audioUrl = json['audioUrl'] as String? ?? '';
    if (audioUrl.isEmpty) throw const ParseFailure();

    return MusicTrack(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Unknown',
      artist: json['artist'] as String? ?? 'Unknown',
      audioUrl: audioUrl,
      imageUrl: json['imageUrl'] as String?,
      albumTitle: json['albumTitle'] as String? ?? '',
      genre: json['genre'] as String? ?? '',
      source: json['source'] as String? ?? 'api',
      duration: Duration(seconds: (json['duration'] as num?)?.toInt() ?? 0),
    );
  }

  // Serialise
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'audioUrl': audioUrl,
    'imageUrl': imageUrl,
    'albumTitle': albumTitle,
    'genre': genre,
    'source': source,
    'duration': duration?.inSeconds ?? 0,
  };

  @override
  bool operator ==(Object other) =>
      other is MusicTrack && other.id == id && other.audioUrl == audioUrl;

  @override
  int get hashCode => Object.hash(id, audioUrl);

  @override
  String toString() => 'MusicTrack($title – $artist)';
}

// PRIVATE API CLIENT
class _MusicApiClient {
  // Shared client
  static final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 12);

  static Future<http.Response> search(String query, int limit) {
    final uri = Uri.parse(
      AppConfig.musicSearchUrl,
    ).replace(queryParameters: {'q': query, 'limit': limit.toString()});
    return _client.get(uri).timeout(_timeout);
  }
}

// MUSIC REPOSITORY

class MusicRepository {
  static const int _maxRetries = 2;

  static Future<MusicResult> search(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return MusicError(NoResultsFailure(trimmed));
    }

    final effectiveLimit = limit.clamp(1, 20);

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      final result = await _attempt(trimmed, effectiveLimit);

      // Only retry transient error
      if (result is MusicError) {
        final failure = result.failure;
        final isTransient =
            failure is TimeoutFailure || failure is ServerFailure;

        if (isTransient && attempt < _maxRetries) {
          // Exponential back off
          await Future.delayed(Duration(milliseconds: 400 * (1 << attempt)));
          continue;
        }
      }

      return result;
    }

    return const MusicError(NetworkFailure());
  }

  static Future<MusicResult> _attempt(String query, int limit) async {
    http.Response response;

    try {
      response = await _MusicApiClient.search(query, limit);
    } on SocketException {
      return const MusicError(NetworkFailure());
    } on http.ClientException {
      return const MusicError(NetworkFailure());
    } on async_lib.TimeoutException {
      return const MusicError(TimeoutFailure());
    }

    return _handleResponse(response, query);
  }

  static MusicResult _handleResponse(http.Response response, String query) {
    switch (response.statusCode) {
      case 200:
        return _parseSuccess(response.body, query);
      case 404:
        return MusicError(NoResultsFailure(query));
      case 429:
        return const MusicError(RateLimitFailure());
      case >= 500:
        return MusicError(ServerFailure(response.statusCode));
      default:
        return MusicError(ServerFailure(response.statusCode));
    }
  }

  static MusicResult _parseSuccess(String body, String query) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return const MusicError(ParseFailure());
    }

    if (json['results'] is! List) return const MusicError(ParseFailure());

    final tracks = <MusicTrack>[];
    for (final item in json['results'] as List) {
      if (item is! Map<String, dynamic>) continue;
      try {
        tracks.add(MusicTrack.fromJson(item));
      } on ParseFailure {
        continue; // skip individual malformed tracks
      }
    }

    if (tracks.isEmpty) return MusicError(NoResultsFailure(query));
    return MusicSuccess(tracks);
  }
}
