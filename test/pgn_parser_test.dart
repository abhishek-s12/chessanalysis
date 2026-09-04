import 'package:flutter_test/flutter_test.dart';
import 'package:chess_analyzer/services/pgn_parser.dart';

void main() {
  group('PgnParser Tests', () {
    const knownPgn = '''
[Event "F/S Return Match"]
[Site "Belgrade, Serbia JUG"]
[Date "1992.11.04"]
[Round "29"]
[White "Fischer, Robert J."]
[Black "Spassky, Boris V."]
[Result "1/2-1/2"]

1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 1/2-1/2
''';

    test('replays known PGN and asserts FEN after 1.e4 matches expected position', () {
      final parsed = PgnParser.parse(knownPgn);

      expect(parsed.moveCount, 14);

      // Verify move 1 is e4 / e2e4
      expect(parsed.sanMoves[0], 'e4');
      expect(parsed.uciMoves[0], 'e2e4');

      // FEN before move 1 is initial position
      expect(
        parsed.fensBeforeMoves[0],
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      );

      // FEN after 1.e4 (which is the FEN before move 2)
      const expectedFenAfterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
      expect(parsed.fensBeforeMoves[1], expectedFenAfterE4);
      expect(parsed.fenAfterMove(0), expectedFenAfterE4);

      // Verify move 2 is e5 / e7e5
      expect(parsed.sanMoves[1], 'e5');
      expect(parsed.uciMoves[1], 'e7e5');
    });

    test('asserts three index-aligned lists have identical lengths', () {
      final parsed = PgnParser.parse(knownPgn);

      expect(parsed.sanMoves.length, parsed.uciMoves.length);
      expect(parsed.uciMoves.length, parsed.fensBeforeMoves.length);
      expect(parsed.sanMoves.length, 14);

      // Test castling move conversion (Move 9: 5. O-O)
      expect(parsed.sanMoves[8], 'O-O');
      expect(parsed.uciMoves[8], 'e1g1');
    });

    test('correctly parses PGN with Chess.com clock annotations and comments', () {
      const chessComPgn = '''
[Event "Live Chess"]
[Site "Chess.com"]
[Date "2026.03.01"]
[White "hikaru"]
[Black "magnuscarlsen"]
[Result "1-0"]

1. e4 {[%clk 0:03:00]} 1... c5 {[%clk 0:02:59]} 2. Nf3 {[%clk 0:02:58]} 2... d6 {[%clk 0:02:57]} 1-0
''';

      final parsed = PgnParser.parse(chessComPgn);

      expect(parsed.moveCount, 4);
      expect(parsed.sanMoves, ['e4', 'c5', 'Nf3', 'd6']);
      expect(parsed.uciMoves, ['e2e4', 'c7c5', 'g1f3', 'd7d6']);
      expect(
        parsed.fensBeforeMoves[1],
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
      );
    });

    test('handles pawn promotions in UCI format', () {
      const promotionPgn = '''
[FEN "8/4P3/8/8/8/8/8/4K2k w - - 0 1"]

1. e8=Q 1-0
''';

      final parsed = PgnParser.parse(promotionPgn);

      expect(parsed.moveCount, 1);
      expect(parsed.sanMoves[0], 'e8=Q');
      expect(parsed.uciMoves[0], 'e7e8q');
      expect(parsed.fensBeforeMoves[0], '8/4P3/8/8/8/8/8/4K2k w - - 0 1');
      expect(parsed.finalFen, '4Q3/8/8/8/8/8/8/4K2k b - - 0 1');
    });

    test('handles empty or invalid PGN gracefully', () {
      final parsed = PgnParser.parse('');

      expect(parsed.moveCount, 0);
      expect(parsed.sanMoves, isEmpty);
      expect(parsed.uciMoves, isEmpty);
      expect(parsed.fensBeforeMoves, isEmpty);
    });
  });
}
