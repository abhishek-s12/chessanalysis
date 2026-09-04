import 'package:flutter/material.dart';
import '../models/chess_game.dart';
import '../models/move_analysis.dart';
import '../services/analysis_cache_service.dart';
import '../services/chess_com_service.dart';
import '../services/game_analyzer.dart';
import '../widgets/game_card.dart';
import 'review_screen.dart';

class HomeScreen extends StatefulWidget {
  final ChessComService? chessComService;
  final GameAnalyzer? gameAnalyzer;
  final AnalysisCacheService? cacheService;

  const HomeScreen({
    super.key,
    this.chessComService,
    this.gameAnalyzer,
    this.cacheService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ChessComService _service;
  late final GameAnalyzer _analyzer;
  late final AnalysisCacheService _cacheService;

  final TextEditingController _usernameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;
  List<ChessGame>? _games;
  String _activeUsername = '';

  // Analysis state
  String? _analyzingUrl;
  int _analyzedMoves = 0;
  int _totalMoves = 0;
  final Map<String, GameAnalysisResult> _cachedAnalyses = {};

  final List<String> _popularPlayers = [
    'hikaru',
    'magnuscarlsen',
    'GothamChess',
    'FabianoCaruana',
  ];

  @override
  void initState() {
    super.initState();
    _service = widget.chessComService ?? ChessComService();
    _analyzer = widget.gameAnalyzer ?? GameAnalyzer();
    _cacheService = widget.cacheService ?? AnalysisCacheService();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchGames([String? usernameOverride]) async {
    final username = (usernameOverride ?? _usernameController.text).trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a Chess.com username'),
          backgroundColor: Color(0xFFE05344),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (usernameOverride != null) {
      _usernameController.text = usernameOverride;
    }

    _focusNode.unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _activeUsername = username;
    });

    try {
      final games = await _service.fetchRecentGames(username);
      setState(() {
        _games = games;
        _isLoading = false;
      });

      // Load any previously cached analyses for these games
      _loadCachedAnalyses(games);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCachedAnalyses(List<ChessGame> games) async {
    for (final game in games) {
      final url = game.url ?? '';
      if (url.isNotEmpty && !_cachedAnalyses.containsKey(url)) {
        final cached = await _cacheService.getAnalysis(url);
        if (cached != null && mounted) {
          setState(() {
            _cachedAnalyses[url] = cached;
          });
        }
      }
    }
  }

  Future<void> _analyzeGame(ChessGame game) async {
    final url = game.url ?? game.endTime.millisecondsSinceEpoch.toString();

    setState(() {
      _analyzingUrl = url;
      _analyzedMoves = 0;
      _totalMoves = 0;
    });

    try {
      final result = await _analyzer.analyzeGame(
        pgn: game.pgn,
        gameUrl: url,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _analyzedMoves = current;
              _totalMoves = total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _cachedAnalyses[url] = result;
          _analyzingUrl = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF262421),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF81B64C), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Analysis complete! White: ${result.whiteAccuracy}%, Black: ${result.blackAccuracy}%',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Review',
              textColor: const Color(0xFF81B64C),
              onPressed: () => _openReview(game, result),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analyzingUrl = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: const Color(0xFFE05344),
          ),
        );
      }
    }
  }

  void _openReview(ChessGame game, GameAnalysisResult analysis) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          game: game,
          analysis: analysis,
          searchedUsername: _activeUsername,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161512),
      appBar: AppBar(
        backgroundColor: const Color(0xFF262421),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0x2681B64C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.sports_esports,
                color: Color(0xFF81B64C),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Chess Analyzer',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          if (_games != null && !_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh games',
              onPressed: () => _fetchGames(_activeUsername),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                // Top Search & Quick Chips Area
                _buildSearchHeader(),

                // Main Content (Loading, Error, Empty, or Games List)
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF262421),
        border: Border(
          bottom: BorderSide(color: Color(0xFF36322C), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input row with Text Field & Fetch Button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usernameController,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _fetchGames(),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Enter Chess.com username (e.g. hikaru)...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                    prefixIcon: const Icon(Icons.person_search_rounded, color: Colors.white54),
                    suffixIcon: _usernameController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                            onPressed: () {
                              _usernameController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1E1C18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF36322C)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF81B64C), width: 1.5),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _fetchGames(),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 20),
                  label: const Text(
                    'Fetch Games',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81B64C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Quick pick suggestions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  'Popular: ',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(width: 6),
                for (final player in _popularPlayers) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _fetchGames(player),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _activeUsername.toLowerCase() == player.toLowerCase()
                              ? const Color(0xFF81B64C).withAlpha(50)
                              : const Color(0xFF1E1C18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _activeUsername.toLowerCase() == player.toLowerCase()
                                ? const Color(0xFF81B64C)
                                : const Color(0xFF36322C),
                          ),
                        ),
                        child: Text(
                          player,
                          style: TextStyle(
                            fontSize: 12,
                            color: _activeUsername.toLowerCase() == player.toLowerCase()
                                ? const Color(0xFF81B64C)
                                : Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF81B64C),
              strokeWidth: 3,
            ),
            const SizedBox(height: 18),
            Text(
              'Fetching recent games for $_activeUsername...',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Retrieving monthly archive from Chess.com public API',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF262421),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE05344).withAlpha(80)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE05344).withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFE05344),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Could Not Fetch Games',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _fetchGames(_activeUsername),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF36322C),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_games == null) {
      // Initial Welcome State
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF262421),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF36322C)),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  size: 46,
                  color: Color(0xFF81B64C),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Explore Chess.com Games',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter a username above or choose a suggested player\nto fetch and view their most recent games archive.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_games!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.folder_off_outlined,
                size: 48,
                color: Colors.white38,
              ),
              const SizedBox(height: 16),
              Text(
                'No recent games found for "$_activeUsername"',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This player might not have played any live games this month.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Games List
    return Column(
      children: [
        // Results stats header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: const Color(0xFF1E1C18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: Color(0xFF81B64C),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_activeUsername\'s Latest Archive',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF36322C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_games!.length} games',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // List view
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            itemCount: _games!.length,
            itemBuilder: (context, index) {
              final game = _games![index];
              final url = game.url ?? game.endTime.millisecondsSinceEpoch.toString();
              final isThisAnalyzing = _analyzingUrl == url;
              final cachedResult = _cachedAnalyses[url];

              return GameCard(
                game: game,
                searchedUsername: _activeUsername,
                isAnalyzing: isThisAnalyzing,
                analyzedMoves: _analyzedMoves,
                totalMoves: _totalMoves,
                cachedAnalysis: cachedResult,
                onAnalyze: _analyzingUrl != null ? null : () => _analyzeGame(game),
                onReview: cachedResult != null ? () => _openReview(game, cachedResult) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
