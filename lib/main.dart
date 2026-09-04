import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const ChessAnalyzerApp());
}

class ChessAnalyzerApp extends StatelessWidget {
  const ChessAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF161512),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF81B64C),
          secondary: Color(0xFF588235),
          surface: Color(0xFF262421),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
