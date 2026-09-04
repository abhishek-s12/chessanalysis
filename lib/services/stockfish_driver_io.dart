import 'dart:async';
import 'dart:io';
import 'package:stockfish/stockfish.dart' as sf;
import 'stockfish_engine.dart';

/// Creates the platform-appropriate Stockfish driver for native IO environments.
/// On Android and iOS, native Stockfish 18 C++ binaries run via FFI.
/// On desktop and headless test environments, [FallbackStockfishDriver] is used.
IStockfishDriver createPlatformStockfishDriver() {
  if (Platform.isAndroid || Platform.isIOS) {
    return LiveStockfishDriver();
  }
  return FallbackStockfishDriver();
}

/// Production driver interfacing with `package:stockfish` (for Android & iOS).
class LiveStockfishDriver implements IStockfishDriver {
  sf.Stockfish? _engine;
  final StreamController<String> _stdoutController = StreamController<String>.broadcast();
  StreamSubscription<String>? _stdoutSub;
  bool _isReady = false;

  @override
  Stream<String> get stdout => _stdoutController.stream;

  @override
  bool get isReady => _isReady;

  @override
  Future<void> init() async {
    final completer = Completer<void>();

    try {
      _engine = sf.Stockfish();
    } catch (e) {
      throw StateError('Could not initialize Stockfish native engine: $e');
    }

    final engine = _engine!;

    // Note: package:stockfish state is a ValueListenable<StockfishState>, NOT a Stream.
    void stateListener() {
      final state = engine.state.value;
      if (state == sf.StockfishState.ready && !completer.isCompleted) {
        _isReady = true;
        completer.complete();
      } else if (state == sf.StockfishState.error && !completer.isCompleted) {
        completer.completeError(StateError('Stockfish engine encountered an error state.'));
      }
    }

    if (engine.state.value == sf.StockfishState.ready) {
      _isReady = true;
      completer.complete();
    } else {
      engine.state.addListener(stateListener);
    }

    _stdoutSub = engine.stdout.listen((line) {
      _stdoutController.add(line);
    });

    await completer.future.timeout(const Duration(seconds: 5));
  }

  @override
  void sendCommand(String command) {
    if (_engine == null) {
      throw StateError('Stockfish engine is not initialized.');
    }
    // Note: package:stockfish has NO sendCommand method; it uses the `stdin = ...` setter.
    _engine!.stdin = command;
  }

  @override
  void dispose() {
    _stdoutSub?.cancel();
    _stdoutController.close();
    try {
      _engine?.dispose();
    } catch (_) {}
    _engine = null;
    _isReady = false;
  }
}
