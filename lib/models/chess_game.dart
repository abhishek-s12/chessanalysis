enum GameOutcome { win, loss, draw }

class ChessPlayerInfo {
  final String username;
  final String result;
  final int? rating;

  const ChessPlayerInfo({
    required this.username,
    required this.result,
    this.rating,
  });

  factory ChessPlayerInfo.fromJson(Map<String, dynamic> json) {
    return ChessPlayerInfo(
      username: (json['username'] as String?) ?? '',
      result: (json['result'] as String?) ?? 'unknown',
      rating: json['rating'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'result': result,
      'rating': rating,
    };
  }
}

class ChessGame {
  final String? url;
  final String pgn;
  final String timeControl;
  final DateTime endTime;
  final bool rated;
  final String? timeClass;
  final ChessPlayerInfo white;
  final ChessPlayerInfo black;
  final String? eco;
  final String? ecoUrl;

  const ChessGame({
    this.url,
    required this.pgn,
    required this.timeControl,
    required this.endTime,
    required this.rated,
    this.timeClass,
    required this.white,
    required this.black,
    this.eco,
    this.ecoUrl,
  });

  factory ChessGame.fromJson(Map<String, dynamic> json) {
    final int endTimeSeconds = (json['end_time'] as int?) ?? 0;
    final pgnText = (json['pgn'] as String?) ?? '';

    // Extract ECO and ECOUrl from JSON or fallback to PGN headers
    String? eco = json['eco'] as String?;
    String? ecoUrl;

    if (eco != null && eco.startsWith('http')) {
      ecoUrl = eco;
      eco = null;
    }

    if (eco == null || eco.isEmpty) {
      final ecoMatch = RegExp(r'\[ECO\s+"([^"]+)"\]', caseSensitive: false).firstMatch(pgnText);
      if (ecoMatch != null) eco = ecoMatch.group(1)?.trim();
    }

    if (ecoUrl == null || ecoUrl.isEmpty) {
      final urlMatch = RegExp(r'\[ECOUrl\s+"([^"]+)"\]', caseSensitive: false).firstMatch(pgnText);
      if (urlMatch != null) ecoUrl = urlMatch.group(1)?.trim();
    }

    return ChessGame(
      url: json['url'] as String?,
      pgn: pgnText,
      timeControl: (json['time_control'] as String?) ?? 'Unknown',
      endTime: DateTime.fromMillisecondsSinceEpoch(endTimeSeconds * 1000),
      rated: (json['rated'] as bool?) ?? false,
      timeClass: json['time_class'] as String?,
      white: ChessPlayerInfo.fromJson(
        (json['white'] as Map<String, dynamic>?) ?? {},
      ),
      black: ChessPlayerInfo.fromJson(
        (json['black'] as Map<String, dynamic>?) ?? {},
      ),
      eco: eco,
      ecoUrl: ecoUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'pgn': pgn,
      'time_control': timeControl,
      'end_time': endTime.millisecondsSinceEpoch ~/ 1000,
      'rated': rated,
      'time_class': timeClass,
      'white': white.toJson(),
      'black': black.toJson(),
      'eco': eco,
      'ecoUrl': ecoUrl,
    };
  }

  /// Extracts readable opening name from the opening URL or ECO code.
  String? get openingName {
    if (ecoUrl == null || ecoUrl!.isEmpty) return null;
    try {
      final uri = Uri.parse(ecoUrl!);
      final slug = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      final moveIdx = slug.indexOf(RegExp(r'(\.\.\.|\d+\.)'));
      final clean = moveIdx != -1 ? slug.substring(0, moveIdx) : slug;
      final formatted = clean
          .replaceAll(RegExp(r'[-_.]+$'), '')
          .split('-')
          .where((s) => s.isNotEmpty)
          .map((s) => s[0].toUpperCase() + s.substring(1))
          .join(' ')
          .replaceAll('Caro Kann', 'Caro-Kann')
          .replaceAll('Nimzo Larsen', 'Nimzo-Larsen')
          .replaceAll('Nimzo Indian', 'Nimzo-Indian');
      return formatted.isNotEmpty ? formatted : null;
    } catch (_) {
      return null;
    }
  }

  bool isUserWhite(String currentUsername) {
    return white.username.toLowerCase() == currentUsername.toLowerCase();
  }

  ChessPlayerInfo getUser(String currentUsername) {
    return isUserWhite(currentUsername) ? white : black;
  }

  ChessPlayerInfo getOpponent(String currentUsername) {
    return isUserWhite(currentUsername) ? black : white;
  }

  GameOutcome getUserOutcome(String currentUsername) {
    final userResult = getUser(currentUsername).result.toLowerCase();
    if (userResult == 'win') {
      return GameOutcome.win;
    } else if (const [
      'agreed',
      'repetition',
      'stalemate',
      'insufficient',
      '50move',
      'timevsinsufficient',
    ].contains(userResult)) {
      return GameOutcome.draw;
    } else {
      return GameOutcome.loss;
    }
  }

  String getOutcomeDescription(String currentUsername) {
    final isWhite = isUserWhite(currentUsername);
    final user = isWhite ? white : black;
    final opponent = isWhite ? black : white;

    final userRes = user.result.toLowerCase();
    final oppRes = opponent.result.toLowerCase();

    if (userRes == 'win') {
      switch (oppRes) {
        case 'checkmated':
          return 'Won by checkmate';
        case 'resigned':
          return 'Won by resignation';
        case 'timeout':
          return 'Won on time';
        case 'abandoned':
          return 'Won by abandonment';
        default:
          return 'Won';
      }
    }

    switch (userRes) {
      case 'checkmated':
        return 'Lost by checkmate';
      case 'resigned':
        return 'Lost by resignation';
      case 'timeout':
        return 'Lost on time';
      case 'abandoned':
        return 'Lost by abandonment';
      case 'agreed':
        return 'Draw by agreement';
      case 'repetition':
        return 'Draw by repetition';
      case 'stalemate':
        return 'Draw by stalemate';
      case 'insufficient':
        return 'Draw by insufficient material';
      case '50move':
        return 'Draw by 50-move rule';
      case 'timevsinsufficient':
        return 'Draw by timeout vs insufficient';
      default:
        return userRes;
    }
  }

  String get formattedTimeControl {
    final tc = timeControl;
    final tcClass = timeClass != null ? ' • ${timeClass![0].toUpperCase()}${timeClass!.substring(1)}' : '';

    if (tc.contains('+')) {
      final parts = tc.split('+');
      final baseSeconds = int.tryParse(parts[0]) ?? 0;
      final incSeconds = parts[1];
      final minutes = (baseSeconds / 60).toStringAsFixed(baseSeconds % 60 == 0 ? 0 : 1);
      return '$minutes+$incSeconds$tcClass';
    } else if (int.tryParse(tc) != null) {
      final seconds = int.parse(tc);
      final minutes = (seconds / 60).toStringAsFixed(seconds % 60 == 0 ? 0 : 1);
      return '$minutes min$tcClass';
    }
    return '$tc$tcClass';
  }

  String get formattedDate {
    final year = endTime.year;
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = monthNames[endTime.month - 1];
    final day = endTime.day.toString().padLeft(2, '0');
    final hour = endTime.hour.toString().padLeft(2, '0');
    final minute = endTime.minute.toString().padLeft(2, '0');
    return '$month $day, $year  $hour:$minute';
  }
}
