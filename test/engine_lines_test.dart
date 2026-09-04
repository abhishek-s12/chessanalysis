import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_pkg;
import 'package:chess_analyzer/services/stockfish_engine.dart';
import 'package:chess_analyzer/widgets/engine_lines_panel.dart';

void main() {
  group('StockfishEngine MultiPV Tests', () {
    late StockfishEngine engine;

    setUp(() {
      engine = StockfishEngine(driver: FallbackStockfishDriver());
    });

    tearDown(() {
      engine.dispose();
    });

    test('evaluateTopLines returns top 3 lines with SAN notation', () async {
      await engine.init();
      const startPosFen = chess_pkg.Chess.DEFAULT_POSITION;

      final lines = await engine.evaluateTopLines(startPosFen, multiPv: 3, depth: 6);

      // Verify 3 candidate lines returned
      expect(lines.length, equals(3));

      // Verify ranks 1, 2, 3
      expect(lines[0].multipv, equals(1));
      expect(lines[1].multipv, equals(2));
      expect(lines[2].multipv, equals(3));

      // Verify best moves and SAN
      for (final line in lines) {
        expect(line.bestMoveUci, isNotEmpty);
        expect(line.bestMoveSan, isNotEmpty);
        expect(line.pvSan, isNotEmpty);
        expect(line.scoreString, isNotEmpty);
      }
    });

    test('EngineLine model formatting helpers', () {
      const line = EngineLine(
        multipv: 1,
        centipawns: 120,
        bestMoveUci: 'e2e4',
        bestMoveSan: 'e4',
        pvUci: ['e2e4', 'e7e5', 'g1f3'],
        pvSan: ['e4', 'e5', 'Nf3'],
        depth: 10,
      );

      expect(line.scoreString, equals('+1.2'));
      expect(line.formattedContinuation, equals('e5 Nf3'));
      expect(line.isMate, isFalse);

      const mateLine = EngineLine(
        multipv: 1,
        mateIn: 3,
        bestMoveUci: 'd1h5',
        bestMoveSan: 'Qh5',
        pvUci: ['d1h5', 'g7g6'],
        pvSan: ['Qh5', 'g6'],
        depth: 12,
      );

      expect(mateLine.scoreString, equals('+M3'));
      expect(mateLine.isMate, isTrue);
    });
  });

  group('EngineLinesPanel Widget Tests', () {
    testWidgets('renders top lines and triggers onSelectLine callback', (WidgetTester tester) async {
      const sampleLines = [
        EngineLine(
          multipv: 1,
          centipawns: 150,
          bestMoveUci: 'e2e4',
          bestMoveSan: 'e4',
          pvSan: ['e4', 'c5', 'Nf3'],
          depth: 10,
        ),
        EngineLine(
          multipv: 2,
          centipawns: 120,
          bestMoveUci: 'd2d4',
          bestMoveSan: 'd4',
          pvSan: ['d4', 'd5', 'c4'],
          depth: 10,
        ),
        EngineLine(
          multipv: 3,
          centipawns: 80,
          bestMoveUci: 'g1f3',
          bestMoveSan: 'Nf3',
          pvSan: ['Nf3', 'd5', 'g3'],
          depth: 10,
        ),
      ];

      EngineLine? selectedLine;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EngineLinesPanel(
              lines: sampleLines,
              onSelectLine: (line) {
                selectedLine = line;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header and Depth
      expect(find.text('Stockfish Engine'), findsOneWidget);
      expect(find.text('Depth 10'), findsOneWidget);

      // Verify the 3 lines are rendered with SAN moves
      expect(find.text('e4'), findsOneWidget);
      expect(find.text('d4'), findsOneWidget);
      expect(find.text('Nf3'), findsOneWidget);

      // Verify eval pills
      expect(find.text('+1.5'), findsOneWidget);
      expect(find.text('+1.2'), findsOneWidget);
      expect(find.text('+0.8'), findsOneWidget);

      // Tap on line 2 (d4)
      await tester.tap(find.text('d4'));
      await tester.pumpAndSettle();

      expect(selectedLine, isNotNull);
      expect(selectedLine!.bestMoveSan, equals('d4'));
    });
  });
}
