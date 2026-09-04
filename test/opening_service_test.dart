import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chess_analyzer/services/opening_service.dart';

void main() {
  group('OpeningService Unit Tests', () {
    late OpeningService service;

    setUp(() {
      service = OpeningService();
    });

    test('parses opening names and cleans URLs correctly', () {
      const url1 = 'https://www.chess.com/openings/Caro-Kann-Defense-Gurgenidze-System-4.h3-Bg7';
      expect(
        OpeningService.parseOpeningNameFromUrl(url1),
        equals('Caro-Kann Defense: Gurgenidze System'),
      );

      const url2 = 'https://www.chess.com/openings/Indian-Game-Spielmann-Indian-Variation...4.Nxd4-d5-5.Bg2-e5';
      expect(
        OpeningService.parseOpeningNameFromUrl(url2),
        equals('Indian Game: Spielmann Indian Variation'),
      );

      const url3 = 'https://www.chess.com/openings/Reti-Opening-Nimzo-Larsen-Variation-2...g6-3.Bb2-Bg7-4.d4';
      expect(
        OpeningService.parseOpeningNameFromUrl(url3),
        equals('Reti Opening: Nimzo-Larsen Variation'),
      );
    });

    test('extracts book ply counts from opening URLs', () {
      // 4.d4 is White's 4th move = 7 plies
      const url1 = 'https://www.chess.com/openings/Reti-Opening-Nimzo-Larsen-Variation-2...g6-3.Bb2-Bg7-4.d4';
      final plies1 = OpeningService.parseBookPliesFromUrl(url1);
      expect(plies1, greaterThanOrEqualTo(7));

      // 5...e5 is Black's 5th move = 10 plies
      const url2 = 'https://www.chess.com/openings/Indian-Game-Spielmann-Indian-Variation...4.Nxd4-d5-5.Bg2-e5';
      final plies2 = OpeningService.parseBookPliesFromUrl(url2);
      expect(plies2, greaterThanOrEqualTo(10));
    });

    test('detects ECO and opening URL from PGN headers', () {
      const samplePgn = '''
[Event "Live Chess"]
[Site "Chess.com"]
[Date "2026.08.01"]
[White "Hikaru"]
[Black "only_strong_moves"]
[Result "1-0"]
[ECO "B15"]
[ECOUrl "https://www.chess.com/openings/Caro-Kann-Defense-Gurgenidze-System-4.h3-Bg7"]

1. e4 g6 2. d4 c6 3. Nc3 d5 4. h3 Bg7 1-0
''';

      final info = service.detectFromPgnOrUrl(pgn: samplePgn);
      expect(info.eco, equals('B15'));
      expect(info.name, equals('Caro-Kann Defense: Gurgenidze System'));
      expect(info.bookPlyCount, greaterThan(4));
    });

    test('gracefully queries Lichess Opening Explorer with mock response', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'explorer.lichess.ovh') {
          return http.Response(
            jsonEncode({
              'opening': {
                'eco': 'C65',
                'name': "Ruy Lopez: Berlin Defense",
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final mockService = OpeningService(httpClient: mockClient);
      final info = await mockService.queryLichessExplorer(
        'r1bqkb1r/pppp1ppp/2n2n2/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 4 4',
      );

      expect(info, isNotNull);
      expect(info!.eco, equals('C65'));
      expect(info.name, equals("Ruy Lopez: Berlin Defense"));
    });

    test('handles Lichess 401 Authorization Required gracefully without throwing', () async {
      final mockClient = MockClient((request) async {
        return http.Response('401 Authorization Required', 401);
      });

      final mockService = OpeningService(httpClient: mockClient);
      final info = await mockService.queryLichessExplorer('some_fen');

      expect(info, isNull);
    });
  });
}
