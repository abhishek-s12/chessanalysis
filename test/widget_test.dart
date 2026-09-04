import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_analyzer/main.dart';

void main() {
  testWidgets('Chess Analyzer home screen UI smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ChessAnalyzerApp());

    // Verify AppBar title
    expect(find.text('Chess Analyzer'), findsOneWidget);

    // Verify Search Input & Button
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Fetch Games'), findsOneWidget);

    // Verify Quick Pick Chips
    expect(find.text('hikaru'), findsOneWidget);
    expect(find.text('magnuscarlsen'), findsOneWidget);

    // Verify Welcome State
    expect(find.text('Explore Chess.com Games'), findsOneWidget);
  });
}
