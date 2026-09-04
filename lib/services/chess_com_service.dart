import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chess_game.dart';

class ChessComApiException implements Exception {
  final String message;
  final int? statusCode;

  ChessComApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ChessComService {
  final http.Client _client;
  static const String _baseUrl = 'https://api.chess.com/pub';
  static const Map<String, String> _headers = {
    'User-Agent': 'ChessAnalyzerApp/1.0 (Flutter; contact: chess_analyzer@dev.local)',
    'Accept': 'application/json',
  };

  ChessComService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches games from the most recent monthly archive for the given [username].
  Future<List<ChessGame>> fetchRecentGames(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) {
      throw ChessComApiException('Username cannot be empty');
    }

    final archivesUri = Uri.parse('$_baseUrl/player/$cleanUsername/games/archives');

    http.Response archivesResponse;
    try {
      archivesResponse = await _client.get(archivesUri, headers: _headers);
    } catch (e) {
      throw ChessComApiException('Failed to connect to Chess.com: $e');
    }

    if (archivesResponse.statusCode == 404) {
      throw ChessComApiException('Player "$username" was not found on Chess.com.', 404);
    } else if (archivesResponse.statusCode == 429) {
      throw ChessComApiException('Chess.com rate limit reached. Please wait a moment.', 429);
    } else if (archivesResponse.statusCode != 200) {
      throw ChessComApiException(
        'Failed to fetch archives (status ${archivesResponse.statusCode}).',
        archivesResponse.statusCode,
      );
    }

    final Map<String, dynamic> archivesData;
    try {
      archivesData = jsonDecode(archivesResponse.body) as Map<String, dynamic>;
    } catch (e) {
      throw ChessComApiException('Invalid response format from Chess.com archives.');
    }

    final archives = archivesData['archives'] as List<dynamic>?;
    if (archives == null || archives.isEmpty) {
      return [];
    }

    // The archives list is chronological; the last entry is the most recent month.
    final String latestArchiveUrl = archives.last as String;
    final archiveUri = Uri.parse(latestArchiveUrl);

    http.Response gamesResponse;
    try {
      gamesResponse = await _client.get(archiveUri, headers: _headers);
    } catch (e) {
      throw ChessComApiException('Failed to fetch monthly archive from Chess.com: $e');
    }

    if (gamesResponse.statusCode != 200) {
      throw ChessComApiException(
        'Failed to fetch games for recent archive (status ${gamesResponse.statusCode}).',
        gamesResponse.statusCode,
      );
    }

    final Map<String, dynamic> gamesData;
    try {
      gamesData = jsonDecode(gamesResponse.body) as Map<String, dynamic>;
    } catch (e) {
      throw ChessComApiException('Invalid games data received from Chess.com.');
    }

    final rawGames = gamesData['games'] as List<dynamic>?;
    if (rawGames == null || rawGames.isEmpty) {
      return [];
    }

    final games = rawGames
        .whereType<Map<String, dynamic>>()
        .map((gameJson) => ChessGame.fromJson(gameJson))
        .toList();

    // Sort most recent first (descending end_time)
    games.sort((a, b) => b.endTime.compareTo(a.endTime));

    return games;
  }
}
