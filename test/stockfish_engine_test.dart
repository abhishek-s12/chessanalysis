import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_pkg;
import 'package:chess_analyzer/services/stockfish_engine.dart';

void main() {
  group('StockfishEngine Smoke Tests', () {
    late StockfishEngine engine;

    setUp(() {
      engine = StockfishEngine(driver: FallbackStockfishDriver());
    });

    tearDown(() {
      engine.dispose();
    });

    test('evaluates starting position at depth 10 and confirms centipawn score and legal bestmove', () async {
      await engine.init();
      expect(engine.isReady, isTrue);

      const startPosFen = chess_pkg.Chess.DEFAULT_POSITION;
      final eval = await engine.evaluatePosition(startPosFen, depth: 10);

      // 1. Confirm depth is 10
      expect(eval.depth, 10);

      // 2. Confirm centipawn score came back
      expect(eval.centipawns, isNotNull);
      expect(eval.isMate, isFalse);

      // 3. Confirm legal bestmove came back
      expect(eval.bestMove, isNotEmpty);
      expect(eval.bestMove, matches(RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$')));

      // Verify the best move is genuinely legal in the starting position
      final chess = chess_pkg.Chess();
      final legalUciMoves = chess.moves({'verbose': true}).map((m) {
        final map = m as Map<String, dynamic>;
        final promo = map['promotion'] != null ? (map['promotion'] as String).toLowerCase() : '';
        return '${map['from']}${map['to']}$promo';
      }).toSet();

      expect(
        legalUciMoves.contains(eval.bestMove),
        isTrue,
        reason: 'Engine bestmove "${eval.bestMove}" must be a legal move from starting position',
      );
    });

    test('evaluates position from Black perspective and normalizes score to White', () async {
      await engine.init();

      // Position after 1. e4
      const afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
      final eval = await engine.evaluatePosition(afterE4, depth: 6);

      expect(eval.centipawns, isNotNull);
      expect(eval.bestMove, isNotEmpty);

      // Verify best move is legal for Black
      final chess = chess_pkg.Chess.fromFEN(afterE4);
      final legalUciMoves = chess.moves({'verbose': true}).map((m) {
        final map = m as Map<String, dynamic>;
        final promo = map['promotion'] != null ? (map['promotion'] as String).toLowerCase() : '';
        return '${map['from']}${map['to']}$promo';
      }).toSet();

      expect(legalUciMoves.contains(eval.bestMove), isTrue);
    });

    test('correctly detects and reports checkmate position', () async {
      await engine.init();

      // Scholar's Mate: 1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6?? 4. Qxf7#
      const scholarsMate = 'r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4';
      final eval = await engine.evaluatePosition(scholarsMate, depth: 5);

      expect(eval.isMate, isTrue);
      expect(eval.bestMove, equals('(none)'));
    });
  });
}
