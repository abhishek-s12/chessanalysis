import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chess_analyzer/models/chess_game.dart';
import 'package:chess_analyzer/services/chess_com_service.dart';

void main() {
  group('ChessGame Model Tests', () {
    final sampleGameJson = {
      'url': 'https://www.chess.com/game/live/123456789',
      'pgn': '[Event "Live Chess"]\n1. e4 e5 2. Nf3 Nc6 3. Bc4 1-0',
      'time_control': '180+2',
      'end_time': 1709423849,
      'rated': true,
      'time_class': 'blitz',
      'white': {
        'username': 'hikaru',
        'rating': 2850,
        'result': 'win',
      },
      'black': {
        'username': 'magnuscarlsen',
        'rating': 2820,
        'result': 'checkmated',
      },
    };

    test('parses correctly from JSON', () {
      final game = ChessGame.fromJson(sampleGameJson);

      expect(game.url, 'https://www.chess.com/game/live/123456789');
      expect(game.pgn, contains('1. e4 e5'));
      expect(game.timeControl, '180+2');
      expect(game.rated, true);
      expect(game.timeClass, 'blitz');
      expect(game.white.username, 'hikaru');
      expect(game.white.rating, 2850);
      expect(game.white.result, 'win');
      expect(game.black.username, 'magnuscarlsen');
      expect(game.black.rating, 2820);
      expect(game.black.result, 'checkmated');
      expect(game.endTime.millisecondsSinceEpoch, 1709423849000);
    });

    test('correctly identifies user color, opponent, and outcome', () {
      final game = ChessGame.fromJson(sampleGameJson);

      // When user is white (hikaru)
      expect(game.isUserWhite('hikaru'), true);
      expect(game.getOpponent('hikaru').username, 'magnuscarlsen');
      expect(game.getUserOutcome('hikaru'), GameOutcome.win);
      expect(game.getOutcomeDescription('hikaru'), 'Won by checkmate');

      // When user is black (magnuscarlsen)
      expect(game.isUserWhite('magnuscarlsen'), false);
      expect(game.getOpponent('magnuscarlsen').username, 'hikaru');
      expect(game.getUserOutcome('magnuscarlsen'), GameOutcome.loss);
      expect(game.getOutcomeDescription('magnuscarlsen'), 'Lost by checkmate');
    });

    test('formats time control and date properly', () {
      final game = ChessGame.fromJson(sampleGameJson);

      expect(game.formattedTimeControl, contains('3+2'));
      expect(game.formattedTimeControl, contains('Blitz'));
      expect(game.formattedDate, isNotEmpty);
    });
  });

  group('ChessComService Tests', () {
    test('fetches and parses games from latest archive successfully', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/archives')) {
          return http.Response(
            jsonEncode({
              'archives': [
                'https://api.chess.com/pub/player/hikaru/games/2026/01',
                'https://api.chess.com/pub/player/hikaru/games/2026/02',
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.endsWith('/2026/02')) {
          return http.Response(
            jsonEncode({
              'games': [
                {
                  'pgn': '1. d4 d5',
                  'time_control': '300',
                  'end_time': 1708000000,
                  'rated': true,
                  'time_class': 'blitz',
                  'white': {'username': 'hikaru', 'rating': 2800, 'result': 'win'},
                  'black': {'username': 'opponent1', 'rating': 2700, 'result': 'resigned'},
                },
                {
                  'pgn': '1. e4 c5',
                  'time_control': '180',
                  'end_time': 1708500000,
                  'rated': true,
                  'time_class': 'blitz',
                  'white': {'username': 'opponent2', 'rating': 2750, 'result': 'checkmated'},
                  'black': {'username': 'hikaru', 'rating': 2805, 'result': 'win'},
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = ChessComService(client: mockClient);
      final games = await service.fetchRecentGames('hikaru');

      expect(games.length, 2);
      // Verify sorted most recent first
      expect(games.first.endTime.isAfter(games.last.endTime), true);
      expect(games.first.black.username, 'hikaru');
    });

    test('throws 404 ChessComApiException when player not found', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = ChessComService(client: mockClient);
      expect(
        () => service.fetchRecentGames('nonexistent_user_12345'),
        throwsA(isA<ChessComApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          404,
        )),
      );
    });

    test('returns empty list when user has no archives', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'archives': []}), 200);
      });

      final service = ChessComService(client: mockClient);
      final games = await service.fetchRecentGames('newuser');

      expect(games, isEmpty);
    });
  });
}
