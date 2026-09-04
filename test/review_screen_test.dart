import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_analyzer/models/chess_game.dart';
import 'package:chess_analyzer/models/move_analysis.dart';
import 'package:chess_analyzer/screens/review_screen.dart';
import 'package:chess_analyzer/widgets/eval_bar.dart';

void main() {
  group('ReviewScreen Widget Tests', () {
    final sampleGame = ChessGame(
      url: 'https://www.chess.com/game/live/12345',
      pgn: '1. e4 e5 2. Nf3 Nc6',
      timeControl: '180+2',
      endTime: DateTime(2026, 3, 4, 12, 0),
      rated: true,
      timeClass: 'blitz',
      white: const ChessPlayerInfo(username: 'hikaru', result: 'win', rating: 2850),
      black: const ChessPlayerInfo(username: 'magnuscarlsen', result: 'resigned', rating: 2820),
    );

    final sampleAnalysis = GameAnalysisResult(
      gameUrl: 'https://www.chess.com/game/live/12345',
      whiteAccuracy: 88.5,
      blackAccuracy: 82.0,
      analyzedAt: DateTime(2026, 3, 4, 12, 5),
      moves: const [
        MoveAnalysis(
          ply: 0,
          moveNumber: 1,
          isWhite: true,
          san: 'e4',
          uci: 'e2e4',
          fenBefore: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          fenAfter: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
          bestMove: 'e2e4',
          scoreBefore: 15,
          scoreAfter: 20,
          classification: MoveClassification.best,
          winProbabilityBefore: 52.0,
          winProbabilityAfter: 52.5,
          winProbabilityDelta: 0.0,
        ),
        MoveAnalysis(
          ply: 1,
          moveNumber: 1,
          isWhite: false,
          san: 'e5',
          uci: 'e7e5',
          fenBefore: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
          fenAfter: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
          bestMove: 'e7e5',
          scoreBefore: 20,
          scoreAfter: 20,
          classification: MoveClassification.best,
          winProbabilityBefore: 47.5,
          winProbabilityAfter: 47.5,
          winProbabilityDelta: 0.0,
        ),
        MoveAnalysis(
          ply: 2,
          moveNumber: 2,
          isWhite: true,
          san: 'Nf3',
          uci: 'g1f3',
          fenBefore: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
          fenAfter: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2',
          bestMove: 'g1f3',
          scoreBefore: 20,
          scoreAfter: 25,
          classification: MoveClassification.best,
          winProbabilityBefore: 52.5,
          winProbabilityAfter: 53.0,
          winProbabilityDelta: 0.0,
        ),
        MoveAnalysis(
          ply: 3,
          moveNumber: 2,
          isWhite: false,
          san: 'Nc6',
          uci: 'b8c6',
          fenBefore: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2',
          fenAfter: 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
          bestMove: 'b8c6',
          scoreBefore: 25,
          scoreAfter: 25,
          classification: MoveClassification.best,
          winProbabilityBefore: 47.0,
          winProbabilityAfter: 47.0,
          winProbabilityDelta: 0.0,
        ),
      ],
    );

    Widget buildTestScreen() {
      return MaterialApp(
        home: ReviewScreen(
          game: sampleGame,
          analysis: sampleAnalysis,
          searchedUsername: 'hikaru',
          boardBuilder: (context, fen, isFlipped, arrows) => Container(
            key: const ValueKey('chessboard_view'),
            child: Text('FEN: $fen'),
          ),
        ),
      );
    }

    testWidgets('renders accuracy for both players and chessboard', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestScreen());

      // Verify Player usernames and accuracies
      expect(find.text('hikaru'), findsOneWidget);
      expect(find.text('magnuscarlsen'), findsOneWidget);
      expect(find.text('88.5%'), findsOneWidget);
      expect(find.text('82.0%'), findsOneWidget);

      // Verify Chessboard and Eval bar are present
      expect(find.byKey(const ValueKey('chessboard_view')), findsOneWidget);
      expect(find.byType(EvalBar), findsOneWidget);

      // Verify moves in move list
      expect(find.text('e4'), findsOneWidget);
      expect(find.text('e5'), findsOneWidget);
      expect(find.text('Nf3'), findsOneWidget);
      expect(find.text('Nc6'), findsOneWidget);
    });

    testWidgets('tapping a move updates the explainer card and active move', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestScreen());

      // Initially on move 1 (e4)
      expect(find.text('1. e4'), findsOneWidget);

      // Tap on Black's move "e5"
      await tester.tap(find.text('e5'));
      await tester.pumpAndSettle();

      // Explainer card should update to "1... e5"
      expect(find.text('1... e5'), findsOneWidget);
    });

    testWidgets('navigation buttons step through moves', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestScreen());

      // Tap next move button
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();

      // Should now be on 1... e5
      expect(find.text('1... e5'), findsOneWidget);

      // Tap next move button again
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();

      // Should now be on 2. Nf3
      expect(find.text('2. Nf3'), findsOneWidget);
    });
  });
}
