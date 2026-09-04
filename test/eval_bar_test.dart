import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_analyzer/widgets/eval_bar.dart';

void main() {
  group('EvalBar Math & Probability Tests', () {
    test('calculateWinProbability matches Chess.com/Lichess logistic formula', () {
      // 0 centipawns is exactly 50%
      final zeroCp = EvalBar.calculateWinProbability(centipawns: 0);
      expect(zeroCp, closeTo(50.0, 0.1));

      // +300 centipawns (~3 pawns) is ~75%
      final plus300 = EvalBar.calculateWinProbability(centipawns: 300);
      expect(plus300, closeTo(75.1, 1.0));

      // -300 centipawns is ~25%
      final minus300 = EvalBar.calculateWinProbability(centipawns: -300);
      expect(minus300, closeTo(24.9, 1.0));

      // Forced mate for White is 100%
      final mateWhite = EvalBar.calculateWinProbability(mateIn: 2);
      expect(mateWhite, equals(100.0));

      // Forced mate for Black is 0%
      final mateBlack = EvalBar.calculateWinProbability(mateIn: -1);
      expect(mateBlack, equals(0.0));

      // Null values default to 50%
      final nullEval = EvalBar.calculateWinProbability();
      expect(nullEval, equals(50.0));
    });
  });

  group('EvalBar Widget & Interactivity Tests', () {
    testWidgets('displays eval score and toggles to win% on tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                height: 300,
                child: EvalBar(
                  centipawns: 150,
                  animationDuration: Duration.zero,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially displays eval score +1.5
      expect(find.text('+1.5'), findsOneWidget);

      // Tap on EvalBar to toggle win%
      await tester.tap(find.byType(EvalBar));
      await tester.pumpAndSettle();

      // Win % for +150 cp is ~63%
      expect(find.text('63%'), findsOneWidget);

      // Tap again to toggle back to score
      await tester.tap(find.byType(EvalBar));
      await tester.pumpAndSettle();

      expect(find.text('+1.5'), findsOneWidget);
    });

    testWidgets('correctly displays forced mate string M2 and flips', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                height: 300,
                child: EvalBar(
                  mateIn: 2,
                  isFlipped: true,
                  animationDuration: Duration.zero,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('M2'), findsOneWidget);

      // Tap to toggle win%
      await tester.tap(find.byType(EvalBar));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
    });
  });
}
