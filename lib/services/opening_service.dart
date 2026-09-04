import 'dart:convert';
import 'package:http/http.dart' as http;

/// Metadata regarding a chess opening and theoretical book line.
class OpeningInfo {
  /// The Encyclopaedia of Chess Openings (ECO) code (e.g. "B15", "C65", "A46").
  final String? eco;

  /// Human-readable opening name (e.g. "Caro-Kann Defense: Gurgenidze System").
  final String? name;

  /// Canonical URL for the opening.
  final String? url;

  /// Number of plies (half-moves) that belong to this theoretical opening line.
  final int bookPlyCount;

  const OpeningInfo({
    this.eco,
    this.name,
    this.url,
    this.bookPlyCount = 0,
  });

  bool get hasOpening => (name != null && name!.isNotEmpty) || (eco != null && eco!.isNotEmpty);

  @override
  String toString() {
    if (eco != null && name != null) {
      return '$eco - $name';
    }
    return name ?? eco ?? 'Unknown Opening';
  }
}

/// Service to detect chess openings and book moves from PGN / Chess.com data,
/// with optional Lichess Opening Explorer queries.
class OpeningService {
  final http.Client _httpClient;

  OpeningService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  /// Detects the opening from PGN headers and/or Chess.com eco data.
  OpeningInfo detectFromPgnOrUrl({
    String? pgn,
    String? rawEco,
    String? rawEcoUrl,
  }) {
    String? eco = rawEco;
    String? ecoUrl = rawEcoUrl;

    // 1. If rawEco is actually a URL (Chess.com sometimes returns the URL in the 'eco' field)
    if (eco != null && eco.startsWith('http')) {
      ecoUrl = eco;
      eco = null;
    }

    // 2. Extract from PGN headers if not already present
    if (pgn != null && pgn.isNotEmpty) {
      if (eco == null || eco.isEmpty) {
        final ecoMatch = RegExp(r'\[ECO\s+"([^"]+)"\]', caseSensitive: false).firstMatch(pgn);
        if (ecoMatch != null) {
          eco = ecoMatch.group(1)?.trim();
        }
      }

      if (ecoUrl == null || ecoUrl.isEmpty) {
        final urlMatch = RegExp(r'\[ECOUrl\s+"([^"]+)"\]', caseSensitive: false).firstMatch(pgn);
        if (urlMatch != null) {
          ecoUrl = urlMatch.group(1)?.trim();
        }
      }
    }

    // 3. Format opening name and determine book plies
    String? name;
    int bookPlies = 0;

    if (ecoUrl != null && ecoUrl.isNotEmpty) {
      name = parseOpeningNameFromUrl(ecoUrl);
      bookPlies = parseBookPliesFromUrl(ecoUrl);
    }

    // Fallback: if we have an ECO code but bookPlies wasn't extracted from URL, default to at least 4 plies
    if (eco != null && eco.isNotEmpty && bookPlies == 0) {
      bookPlies = 4;
    }

    return OpeningInfo(
      eco: eco,
      name: name,
      url: ecoUrl,
      bookPlyCount: bookPlies,
    );
  }

  /// Parses a human-readable opening name from a Chess.com opening URL.
  /// Example:
  /// `https://www.chess.com/openings/Caro-Kann-Defense-Gurgenidze-System-4.h3-Bg7`
  /// -> `Caro-Kann Defense: Gurgenidze System`
  static String parseOpeningNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isEmpty) return '';

      String slug = segments.last;

      // Strip out the move line portion if present (indicated by digits with dots e.g. "...4.Nxd4" or "-2...g6")
      final moveIdx = slug.indexOf(RegExp(r'(\.\.\.|\d+\.)'));
      if (moveIdx != -1) {
        slug = slug.substring(0, moveIdx);
      }

      // Trim trailing hyphens or dots
      slug = slug.replaceAll(RegExp(r'[-_.]+$'), '');

      // Replace hyphens with spaces while preserving hyphenated defenses like "Caro-Kann"
      final parts = slug.split('-');
      final List<String> formattedWords = [];

      for (int i = 0; i < parts.length; i++) {
        final word = parts[i];
        if (word.isEmpty) continue;

        // Check common chess compound terms
        if (word.toLowerCase() == 'defense' ||
            word.toLowerCase() == 'opening' ||
            word.toLowerCase() == 'game' ||
            word.toLowerCase() == 'gambit' ||
            word.toLowerCase() == 'system' ||
            word.toLowerCase() == 'attack') {
          formattedWords.add(_capitalize(word));
          // If followed by variation words, add colon separator if appropriate
          if (i + 1 < parts.length && !parts[i + 1].toLowerCase().startsWith('variation')) {
            formattedWords.add(':');
          }
        } else {
          formattedWords.add(_capitalize(word));
        }
      }

      String result = formattedWords.join(' ');
      // Clean up spacing around colons: "Defense : Gurgenidze" -> "Defense: Gurgenidze"
      result = result.replaceAll(' :', ':').replaceAll(RegExp(r'\s+'), ' ').trim();

      // Ensure proper capitalization for known names
      result = result
          .replaceAll('Caro Kann', 'Caro-Kann')
          .replaceAll('Nimzo Larsen', 'Nimzo-Larsen')
          .replaceAll('Nimzo Indian', 'Nimzo-Indian')
          .replaceAll('Queen S', "Queen's")
          .replaceAll('King S', "King's");

      return result.isNotEmpty ? result : slug;
    } catch (_) {
      return '';
    }
  }

  /// Calculates book ply count based on moves listed in the opening URL.
  /// Example: `...4.Nxd4-d5-5.Bg2-e5` -> move 5 black = 10 plies.
  static int parseBookPliesFromUrl(String url) {
    try {
      int maxPly = 4;

      // 1. Matches patterns like "5.Bg2-e5" or "4.d4"
      final moveMatches = RegExp(r'(\d+)\.([a-zA-Z0-9+=#]+)(?:-([a-zA-Z0-9+=#]+))?').allMatches(url);
      for (final m in moveMatches) {
        final moveNum = int.tryParse(m.group(1) ?? '0') ?? 0;
        final hasBlackMove = m.group(3) != null && m.group(3)!.isNotEmpty;
        final ply = (moveNum * 2) - (hasBlackMove ? 0 : 1);
        if (ply > maxPly) {
          maxPly = ply;
        }
      }

      // 2. Matches patterns like "2...g6"
      final blackMatches = RegExp(r'(\d+)\.\.\.([a-zA-Z0-9+=#]+)').allMatches(url);
      for (final m in blackMatches) {
        final moveNum = int.tryParse(m.group(1) ?? '0') ?? 0;
        final ply = moveNum * 2;
        if (ply > maxPly) {
          maxPly = ply;
        }
      }

      return maxPly.clamp(2, 24);
    } catch (_) {
      return 4;
    }
  }

  /// Queries the Lichess Opening Explorer for masters games matching [fen].
  /// Requires [authToken] if querying Lichess endpoints that mandate OAuth authorization.
  Future<OpeningInfo?> queryLichessExplorer(
    String fen, {
    String? authToken,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final encodedFen = Uri.encodeComponent(fen);
      final uri = Uri.parse('https://explorer.lichess.ovh/masters?fen=$encodedFen');

      final headers = <String, String>{
        'User-Agent': 'ChessComAnalysisApp/1.0',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await _httpClient.get(uri, headers: headers).timeout(timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final openingData = data['opening'] as Map<String, dynamic>?;
        if (openingData != null) {
          final eco = openingData['eco'] as String?;
          final name = openingData['name'] as String?;
          return OpeningInfo(eco: eco, name: name, bookPlyCount: 4);
        }
      }
    } catch (_) {
      // Graceful fallback on network or authorization errors
    }
    return null;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
