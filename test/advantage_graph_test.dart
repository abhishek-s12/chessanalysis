import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_analyzer/models/move_analysis.dart';
import 'package:chess_analyzer/widgets/advantage_graph.dart';

void main() {
  group('AdvantageGraph Widget Tests', () {
    final sampleMoves = [
      const MoveAnalysis(
        ply: 0,
        moveNumber: 1,
        isWhite: true,
        san: 'e4',
        uci: 'e2e4',
        fenBefore: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        fenAfter: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
        bestMove: 'e2e4',
        scoreBefore: 20,
        scoreAfter: 35,
        classification: MoveClassification.book,
        winProbabilityBefore: 51.0,
        winProbabilityAfter: 52.5,
        winProbabilityDelta: 0.0,
      ),
      const MoveAnalysis(
        ply: 1,
        moveNumber: 1,
        isWhite: false,
        san: 'e5',
        uci: 'e7e5',
        fenBefore: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
        fenAfter: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
        bestMove: 'e7e5',
        scoreBefore: 35,
        scoreAfter: 30,
        classification: MoveClassification.book,
        winProbabilityBefore: 47.5,
        winProbabilityAfter: 48.0,
        winProbabilityDelta: 0.0,
      ),
      const MoveAnalysis(
        ply: 2,
        moveNumber: 2,
        isWhite: true,
        san: 'Nf3',
        uci: 'g1f3',
        fenBefore: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
        fenAfter: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2',
        bestMove: 'g1f3',
        scoreBefore: 30,
        scoreAfter: 40,
        classification: MoveClassification.best,
        winProbabilityBefore: 52.0,
        winProbabilityAfter: 53.0,
        winProbabilityDelta: 0.0,
      ),
      const MoveAnalysis(
        ply: 3,
        moveNumber: 2,
        isWhite: false,
        san: 'f6??',
        uci: 'f7f6',
        fenBefore: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2',
        fenAfter: 'rnbqkbnr/ppppp1pp/5p2/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 0 3',
        bestMove: 'b8c6',
        scoreBefore: 40,
        scoreAfter: 250,
        classification: MoveClassification.blunder,
        winProbabilityBefore: 47.0,
        winProbabilityAfter: 20.0,
        winProbabilityDelta: 27.0,
      ),
    ];

    testWidgets('renders custom painter and header overlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvantageGraph(
              moves: sampleMoves,
              selectedPlyIndex: 2,
              onSelectPly: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Advantage Momentum'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('tapping or dragging horizontally triggers onSelectPly with expected index', (tester) async {
      int selected = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 90,
                child: AdvantageGraph(
                  moves: sampleMoves,
                  selectedPlyIndex: 0,
                  onSelectPly: (idx) {
                    selected = idx;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // Tap near the end of the graph (around width 380 of 400)
      final graphFinder = find.byType(AdvantageGraph);
      final topLeft = tester.getTopLeft(graphFinder);
      await tester.tapAt(Offset(topLeft.dx + 390, topLeft.dy + 45));
      await tester.pump();

      // Closest ply should be the last move (index 3)
      expect(selected, equals(3));
    });
  });
}
