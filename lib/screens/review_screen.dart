import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_pkg;
import 'package:simple_chess_board/simple_chess_board.dart';
import '../models/chess_game.dart';
import '../models/move_analysis.dart';
import '../widgets/eval_bar.dart';
import '../widgets/advantage_graph.dart';

class ReviewScreen extends StatefulWidget {
  final ChessGame game;
  final GameAnalysisResult analysis;
  final String searchedUsername;
  final Widget Function(BuildContext context, String fen, bool isFlipped, List<BoardArrow> arrows)? boardBuilder;

  const ReviewScreen({
    super.key,
    required this.game,
    required this.analysis,
    required this.searchedUsername,
    this.boardBuilder,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late int _selectedPlyIndex;
  late bool _isFlipped;
  bool _isPlaying = false;
  Timer? _playTimer;
  final ScrollController _scrollController = ScrollController();
  bool _showStats = false;

  @override
  void initState() {
    super.initState();
    // Default to the first move, or -1 if empty
    _selectedPlyIndex = widget.analysis.moves.isNotEmpty ? 0 : -1;
    // Default orientation: if user was Black, put Black on bottom
    _isFlipped = !widget.game.isUserWhite(widget.searchedUsername);
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _selectPly(int index) {
    if (index < -1 || index >= widget.analysis.moves.length) return;
    setState(() {
      _selectedPlyIndex = index;
    });
    _scrollToActiveMove();
  }

  void _nextMove() {
    if (_selectedPlyIndex < widget.analysis.moves.length - 1) {
      _selectPly(_selectedPlyIndex + 1);
    } else if (_isPlaying) {
      _togglePlay();
    }
  }

  void _prevMove() {
    if (_selectedPlyIndex > -1) {
      _selectPly(_selectedPlyIndex - 1);
    }
  }

  void _firstMove() {
    _selectPly(-1);
  }

  void _lastMove() {
    if (widget.analysis.moves.isNotEmpty) {
      _selectPly(widget.analysis.moves.length - 1);
    }
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _playTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
          _nextMove();
        });
      } else {
        _playTimer?.cancel();
      }
    });
  }

  void _scrollToActiveMove() {
    if (_selectedPlyIndex >= 0 && _scrollController.hasClients) {
      final targetOffset = (_selectedPlyIndex ~/ 2) * 52.0;
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String get _currentFen {
    if (_selectedPlyIndex == -1) {
      return widget.analysis.moves.isNotEmpty
          ? widget.analysis.moves.first.fenBefore
          : chess_pkg.Chess.DEFAULT_POSITION;
    }
    return widget.analysis.moves[_selectedPlyIndex].fenAfter;
  }

  List<BoardArrow> get _currentArrows {
    if (_selectedPlyIndex < 0 || _selectedPlyIndex >= widget.analysis.moves.length) {
      return const [];
    }

    final move = widget.analysis.moves[_selectedPlyIndex];
    final best = move.bestMove.trim().toLowerCase();
    if (best.length >= 4) {
      final from = best.substring(0, 2);
      final to = best.substring(2, 4);
      return [
        BoardArrow(
          from: from,
          to: to,
          color: const Color(0xFF81B64C),
        ),
      ];
    }
    return const [];
  }

  MoveAnalysis? get _currentMove {
    if (_selectedPlyIndex >= 0 && _selectedPlyIndex < widget.analysis.moves.length) {
      return widget.analysis.moves[_selectedPlyIndex];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161512),
      appBar: AppBar(
        backgroundColor: const Color(0xFF262421),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Game Review',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(_showStats ? Icons.bar_chart_rounded : Icons.insert_chart_outlined_rounded),
            tooltip: 'Toggle classification stats',
            onPressed: () => setState(() => _showStats = !_showStats),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android_rounded),
            tooltip: 'Flip board',
            onPressed: () => setState(() => _isFlipped = !_isFlipped),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Chess.com Style Accuracy Header
            _buildAccuracyHeader(),

            // Opening Header Banner
            _buildOpeningBanner(),

            if (_showStats) _buildClassificationStatsCard(),

            // Main Content Area: Responsive side-by-side or vertical layout
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 720;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left: Board, Eval, Navigation & Move Explainer
                        Expanded(
                          flex: 6,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildBoardWithEval(),
                                const SizedBox(height: 12),
                                _buildNavigationControls(),
                                const SizedBox(height: 8),
                                _buildAdvantageGraph(),
                                const SizedBox(height: 12),
                                _buildMoveExplainerCard(),
                              ],
                            ),
                          ),
                        ),
                        // Divider
                        const VerticalDivider(color: Color(0xFF36322C), width: 1),
                        // Right: Scrollable Move List
                        Expanded(
                          flex: 4,
                          child: _buildMoveList(),
                        ),
                      ],
                    );
                  } else {
                    // Mobile stacked layout
                    return Column(
                      children: [
                        _buildBoardWithEval(),
                        _buildNavigationControls(),
                        _buildAdvantageGraph(),
                        _buildMoveExplainerCard(),
                        const Divider(color: Color(0xFF36322C), height: 1),
                        Expanded(child: _buildMoveList()),
                      ],
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccuracyHeader() {
    final whiteAccuracy = widget.analysis.whiteAccuracy;
    final blackAccuracy = widget.analysis.blackAccuracy;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF262421),
        border: Border(
          bottom: BorderSide(color: Color(0xFF36322C), width: 1),
        ),
      ),
      child: Row(
        children: [
          // White Player Info & Accuracy
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.circle, color: Colors.white, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.game.white.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.game.white.rating != null)
                        Text(
                          '${widget.game.white.rating}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF81B64C).withAlpha(35),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF81B64C).withAlpha(90)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$whiteAccuracy%',
                        style: const TextStyle(
                          color: Color(0xFF81B64C),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (widget.analysis.estimatedWhiteElo != null)
                        Text(
                          'Est. ${widget.analysis.estimatedWhiteElo}',
                          style: const TextStyle(
                            color: Color(0xFF9ECE6A),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // VS Center Label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'VS',
              style: TextStyle(
                color: Colors.white.withAlpha(80),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),

          // Black Player Info & Accuracy
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF81B64C).withAlpha(35),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF81B64C).withAlpha(90)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$blackAccuracy%',
                        style: const TextStyle(
                          color: Color(0xFF81B64C),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (widget.analysis.estimatedBlackElo != null)
                        Text(
                          'Est. ${widget.analysis.estimatedBlackElo}',
                          style: const TextStyle(
                            color: Color(0xFF9ECE6A),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.game.black.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.game.black.rating != null)
                        Text(
                          '${widget.game.black.rating}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.circle_outlined, color: Colors.white70, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpeningBanner() {
    final eco = widget.analysis.ecoCode ?? widget.game.eco;
    final name = widget.analysis.openingName ?? widget.game.openingName;

    if ((eco == null || eco.isEmpty) && (name == null || name.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1D1A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF36322C), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF5C8BB0).withAlpha(40),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF5C8BB0).withAlpha(90)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_book_rounded, size: 12, color: Color(0xFF7AA2C2)),
                if (eco != null && eco.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    eco,
                    style: const TextStyle(
                      color: Color(0xFF8BB3D6),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name ?? 'Theoretical Opening Line',
              style: const TextStyle(
                color: Color(0xFFDDD5C7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationStatsCard() {
    final categories = [
      MoveClassification.brilliant,
      MoveClassification.great,
      MoveClassification.best,
      MoveClassification.excellent,
      MoveClassification.good,
      MoveClassification.book,
      MoveClassification.inaccuracy,
      MoveClassification.mistake,
      MoveClassification.blunder,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFF1E1C18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Move Quality Breakdown',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: categories.map((cat) {
              final whiteCount = widget.analysis.countClassificationForWhite(cat);
              final blackCount = widget.analysis.countClassificationForBlack(cat);
              if (whiteCount == 0 && blackCount == 0) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF262421),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cat.color.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat.icon, color: cat.color, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      cat.displayLabel,
                      style: TextStyle(color: cat.color, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$whiteCount : $blackCount',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardWithEval() {
    final move = _currentMove;
    final centipawns = move?.scoreAfter;
    final mateIn = move?.mateAfter;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 460),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vertical Eval Bar
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: EvalBar(
                  centipawns: centipawns,
                  mateIn: mateIn,
                  isFlipped: _isFlipped,
                ),
              ),

              // Chessboard
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.boardBuilder != null
                      ? widget.boardBuilder!(context, _currentFen, _isFlipped, _currentArrows)
                      : SimpleChessBoard(
                          fen: _currentFen,
                          blackSideAtBottom: _isFlipped,
                          whitePlayerType: PlayerType.computer,
                          blackPlayerType: PlayerType.computer,
                          chessBoardColors: ChessBoardColors()
                            ..lightSquaresColor = const Color(0xFFEBECD0)
                            ..darkSquaresColor = const Color(0xFF779556)
                            ..coordinatesColor = Colors.white70,
                          highlightingArrows: _currentArrows,
                          showCoordinatesZone: true,
                          isInteractive: false,
                          playSounds: false,
                          onMove: ({required ShortMove move}) {},
                          onPromote: () async => PieceType.queen,
                          onPromotionCommited: ({required PieceType pieceType, required ShortMove moveDone}) {},
                          onTap: ({required String cellCoordinate}) {},
                          cellHighlights: const {},
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF262421),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF36322C)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page_rounded),
            tooltip: 'Initial position',
            color: Colors.white70,
            onPressed: _selectedPlyIndex > -1 ? _firstMove : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous move',
            color: Colors.white70,
            onPressed: _selectedPlyIndex > -1 ? _prevMove : null,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded),
            iconSize: 36,
            color: const Color(0xFF81B64C),
            tooltip: _isPlaying ? 'Pause' : 'Play',
            onPressed: _togglePlay,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next move',
            color: Colors.white70,
            onPressed: _selectedPlyIndex < widget.analysis.moves.length - 1 ? _nextMove : null,
          ),
          IconButton(
            icon: const Icon(Icons.last_page_rounded),
            tooltip: 'Final move',
            color: Colors.white70,
            onPressed: _selectedPlyIndex < widget.analysis.moves.length - 1 ? _lastMove : null,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvantageGraph() {
    return AdvantageGraph(
      moves: widget.analysis.moves,
      selectedPlyIndex: _selectedPlyIndex,
      onSelectPly: _selectPly,
      isFlipped: _isFlipped,
    );
  }

  Widget _buildMoveExplainerCard() {
    final move = _currentMove;

    if (move == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF262421),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF36322C)),
        ),
        child: const Center(
          child: Text(
            'Starting Position (Move 1 to begin)',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
      );
    }

    final cat = move.classification;
    final delta = move.winProbabilityDelta;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF262421),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cat.color.withAlpha(90), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cat.color.withAlpha(35),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat.icon, color: cat.color, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      cat.displayLabel,
                      style: TextStyle(color: cat.color, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${move.moveNumber}${move.isWhite ? "." : "..."} ${move.san}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (delta > 0.5)
                Text(
                  '-${delta.toStringAsFixed(1)}% win chance',
                  style: TextStyle(
                    color: delta > 15.0 ? const Color(0xFFE05344) : const Color(0xFFECC440),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (cat == MoveClassification.book)
            Row(
              children: [
                const Icon(Icons.menu_book_rounded, size: 14, color: Color(0xFFA88865)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Standard move according to opening theory.',
                    style: TextStyle(color: Color(0xFFDDD5C7), fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
                Text(
                  'Eval: ${_formatEvalText(move.scoreAfter, move.mateAfter)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            )
          else
            Row(
              children: [
                const Icon(Icons.assistant_direction_rounded, size: 14, color: Color(0xFF81B64C)),
                const SizedBox(width: 6),
                const Text(
                  'Best Engine Move: ',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  move.bestMove,
                  style: const TextStyle(
                    color: Color(0xFF81B64C),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  'Eval: ${_formatEvalText(move.scoreAfter, move.mateAfter)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatEvalText(int? cp, int? mate) {
    if (mate != null) {
      return mate > 0 ? '+M$mate' : '-M${mate.abs()}';
    }
    if (cp == null) return '0.0';
    final score = cp / 100.0;
    return score >= 0 ? '+${score.toStringAsFixed(1)}' : score.toStringAsFixed(1);
  }

  Widget _buildMoveList() {
    final totalTurns = (widget.analysis.moves.length / 2).ceil();

    return Container(
      color: const Color(0xFF1E1C18),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: totalTurns,
        itemBuilder: (context, turnIndex) {
          final moveNumber = turnIndex + 1;
          final whitePlyIndex = turnIndex * 2;
          final blackPlyIndex = whitePlyIndex + 1;

          final whiteMove = whitePlyIndex < widget.analysis.moves.length
              ? widget.analysis.moves[whitePlyIndex]
              : null;
          final blackMove = blackPlyIndex < widget.analysis.moves.length
              ? widget.analysis.moves[blackPlyIndex]
              : null;

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: turnIndex.isEven ? const Color(0xFF262421).withAlpha(80) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                // Move turn number
                SizedBox(
                  width: 38,
                  child: Center(
                    child: Text(
                      '$moveNumber.',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                // White Move
                Expanded(
                  child: whiteMove != null
                      ? _buildMoveButton(
                          move: whiteMove,
                          plyIndex: whitePlyIndex,
                        )
                      : const SizedBox.shrink(),
                ),

                const SizedBox(width: 6),

                // Black Move
                Expanded(
                  child: blackMove != null
                      ? _buildMoveButton(
                          move: blackMove,
                          plyIndex: blackPlyIndex,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMoveButton({
    required MoveAnalysis move,
    required int plyIndex,
  }) {
    final isSelected = _selectedPlyIndex == plyIndex;
    final cat = move.classification;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _selectPly(plyIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF36322C) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? const Color(0xFF81B64C) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(cat.icon, color: cat.color, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  move.san,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
