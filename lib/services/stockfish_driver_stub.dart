import 'stockfish_engine.dart';

/// Creates the platform-appropriate Stockfish driver for Web.
/// Since Web does not support native C++ FFI (`dart:ffi`),
/// this returns [FallbackStockfishDriver].
IStockfishDriver createPlatformStockfishDriver() {
  return FallbackStockfishDriver();
}

/// Fallback stub for [LiveStockfishDriver] on Web platforms.
class LiveStockfishDriver extends FallbackStockfishDriver {}
