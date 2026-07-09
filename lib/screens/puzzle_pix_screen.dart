import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:here_with_you/main.dart';
import 'package:here_with_you/services/player_progress_service.dart';
import 'package:here_with_you/services/reward_service.dart';

class PuzzlePixScreen extends StatefulWidget {
  final List<Uint8List> imageBytes;

  const PuzzlePixScreen({super.key, required this.imageBytes});

  @override
  State<PuzzlePixScreen> createState() => _PuzzlePixScreenState();
}

class _PuzzlePixScreenState extends State<PuzzlePixScreen> {
  static const int _gridSize = 3;
  static const double _snapThreshold = 40.0;
  final Random _random = Random();

  List<_PuzzlePiece> _pieces = [];
  int? _draggingPieceIndex;
  Size? _lastCanvasSize;
  late Stopwatch _timer;
  int _moveCount = 0;
  late Timer _uiTimer;
  Timer? _breakCountdownTimer;
  bool _hasTriggeredHalfwayBreak = false;
  bool _isBreakActive = false;
  int _breakSecondsLeft = 30;
  bool _showBoardOverlay = false;
  Uint8List? _selectedImageBytes;
  bool _hasShownCompletionDialog = false;

  @override
  void initState() {
    super.initState();
    _timer = Stopwatch()..start();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });

    if (widget.imageBytes.isNotEmpty) {
      _selectedImageBytes =
          widget.imageBytes[_random.nextInt(widget.imageBytes.length)];
    }
  }

  @override
  void dispose() {
    _timer.stop();
    _uiTimer.cancel();
    _breakCountdownTimer?.cancel();
    super.dispose();
  }

  void _startExerciseBreak() {
    if (_isBreakActive) return;

    _hasTriggeredHalfwayBreak = true;
    _isBreakActive = true;
    _breakSecondsLeft = 30;
    _draggingPieceIndex = null;
    _timer.stop();

    _breakCountdownTimer?.cancel();

    _breakCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_breakSecondsLeft <= 1) {
        timer.cancel();
        _endExerciseBreak();
        return;
      }

      setState(() {
        _breakSecondsLeft -= 1;
      });
    });
  }

  void _endExerciseBreak() {
    _breakCountdownTimer?.cancel();
    _breakCountdownTimer = null;

    if (!mounted) return;
    setState(() {
      _isBreakActive = false;
      _breakSecondsLeft = 30;
    });
    _timer.start();
  }

  void _resetPuzzle() {
    if (_lastCanvasSize == null) return;

    _timer
      ..reset()
      ..start();

    _moveCount = 0;
    _draggingPieceIndex = null;
    _hasTriggeredHalfwayBreak = false;
    _isBreakActive = false;
    _breakSecondsLeft = 30;
    _hasShownCompletionDialog = false;
    _breakCountdownTimer?.cancel();
    _breakCountdownTimer = null;

    final boardSize = min(_lastCanvasSize!.width - 24, 300.0);
    _initializePieces(
      canvas: _lastCanvasSize!,
      boardLeft: ((_lastCanvasSize!.width) - boardSize) / 2,
      boardTop: 16.0,
      boardSize: boardSize,
    );
  }

  void _solvePuzzle() {
    setState(() {
      for (final piece in _pieces) {
        piece.currentOffset = piece.correctOffset;
        piece.cellIndex = piece.correctCellIndex;
        piece.isSnapped = true;
        piece.isOverBoard = false;
      }
      _draggingPieceIndex = null;
    });
  }

  Future<void> _showPreviewDialog() async {
    final previewImageBytes = _selectedImageBytes;

    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFFF5E9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Puzzle Preview',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _buildPuzzlePreviewImage(
                    imageBytes: previewImageBytes,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPuzzleSourceImage({BoxFit fit = BoxFit.cover}) {
    final bytes = _selectedImageBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFF6F3EE)),
      );
    }

    return const ColoredBox(color: Color(0xFFF6F3EE));
  }

  Widget _buildPuzzlePreviewImage({Uint8List? imageBytes}) {
    if (imageBytes != null && imageBytes.isNotEmpty) {
      return Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFF6F3EE)),
      );
    }

    return const ColoredBox(color: Color(0xFFF6F3EE));
  }

  Widget _buildBreaktimeOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: 360,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5E9),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFFFD7C9), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Breaktime',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF737FC0),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Side stretch (5 per side)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF737FC0),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F2EF),
                    borderRadius: BorderRadius.circular(115),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(36),
                    child: Center(
                      child: Image.asset(
                        'assets/images/person.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_breakSecondsLeft s',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _initializePieces({
    required Size canvas,
    required double boardLeft,
    required double boardTop,
    required double boardSize,
  }) {
    final tileSize = boardSize / _gridSize;
    final minY = boardTop + boardSize + 40;
    final maxY = max(minY, canvas.height - tileSize - 20);
    final padding = 12.0;

    final pieces = <_PuzzlePiece>[];
    for (int index = 0; index < _gridSize * _gridSize; index++) {
      final row = index ~/ _gridSize;
      final col = index % _gridSize;

      final topEdge = row == 0
          ? 0
          : -pieces[(row - 1) * _gridSize + col].bottomEdge;
      final leftEdge = col == 0 ? 0 : -pieces[index - 1].rightEdge;
      final bottomEdge = row == _gridSize - 1
          ? 0
          : _determineEdgeSign(row, col, forHorizontalEdge: true);
      final rightEdge = col == _gridSize - 1
          ? 0
          : _determineEdgeSign(row, col, forHorizontalEdge: false);

      final correctOffset = Offset(
        boardLeft + col * tileSize,
        boardTop + row * tileSize,
      );

      final x =
          padding +
          _random.nextDouble() * max(1, canvas.width - tileSize - 2 * padding);
      final y = minY + _random.nextDouble() * max(1, maxY - minY);

      pieces.add(
        _PuzzlePiece(
          index: index,
          row: row,
          col: col,
          currentOffset: Offset(x, y),
          correctOffset: correctOffset,
          correctCellIndex: index,
          topEdge: topEdge,
          rightEdge: rightEdge,
          bottomEdge: bottomEdge,
          leftEdge: leftEdge,
        ),
      );
    }

    _pieces = pieces;
  }

  int _determineEdgeSign(int row, int col, {required bool forHorizontalEdge}) {
    final parity = row + col + (forHorizontalEdge ? 1 : 0);
    return parity.isEven ? 1 : -1;
  }

  bool _isPuzzleComplete() {
    return _pieces.every((piece) => piece.cellIndex == piece.correctCellIndex);
  }

  Future<void> _goToPuzzleLevelsPage() async {
    await AppNavigationState.saveRoute('puzzle_game');

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const PuzzleGameScreen()),
    );
  }

  Future<void> _returnToHomeScreen() async {
    await AppNavigationState.saveTabIndex(0);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _showCompletionDialog() async {
    try {
      await PlayerProgressService().markLevelCompleted(1);
    } catch (_) {
      // Keep the completion flow responsive even if progress sync fails.
    }

    final minutes = _timer.elapsed.inMinutes;
    final seconds = _timer.elapsed.inSeconds % 60;
    final timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF5E9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '🧩 Puzzle Complete!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2E7D32),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              'Time: $timeStr',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Moves: $_moveCount',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _returnToHomeScreen();
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFF6B6B)),
              foregroundColor: const Color(0xFFFF6B6B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _claimRewardAndOpenRewards();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Claim Reward',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _claimRewardAndOpenRewards() async {
    try {
      await RewardService.instance.unlockRewardsForCurrentPlayerLevel(1);
    } catch (_) {
      // Keep navigation responsive even when unlock sync has a transient failure.
    }

    await AppNavigationState.saveTabIndex(2);
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const MainNavigationPage(initialIndex: 2),
      ),
      (route) => false,
    );
  }

  Widget _buildPieceTile({
    required _PuzzlePiece piece,
    required double tileSize,
    required double boardSize,
    required bool isDragging,
    Uint8List? imageBytes,
  }) {
    return SizedBox(
      width: tileSize,
      height: tileSize,
      child: Stack(
        children: [
          // ── Image slice (or solid colour fallback) clipped to puzzle shape ──
          ClipPath(
            clipper: _PuzzlePieceClipper(
              topEdge: piece.topEdge,
              rightEdge: piece.rightEdge,
              bottomEdge: piece.bottomEdge,
              leftEdge: piece.leftEdge,
            ),
            child: SizedBox(
              width: tileSize,
              height: tileSize,
              child: imageBytes != null && imageBytes.isNotEmpty
                  ? OverflowBox(
                      alignment: Alignment.topLeft,
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: Transform.translate(
                        // Shift the full image so only this piece's slice shows.
                        offset: Offset(
                          -piece.col * tileSize,
                          -piece.row * tileSize,
                        ),
                        child: SizedBox(
                          width: boardSize,
                          height: boardSize,
                          child: Image.memory(
                            imageBytes,
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) =>
                                const ColoredBox(color: Color(0xFFF6F3EE)),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: piece.isSnapped
                          ? const Color(0xFFF6F3EE)
                          : (isDragging
                                ? const Color(0xFFF3E8DE)
                                : Colors.white),
                    ),
            ),
          ),
          // ── Puzzle-piece outline drawn on top ──
          CustomPaint(
            size: Size(tileSize, tileSize),
            painter: _PuzzlePiecePainter(
              topEdge: piece.topEdge,
              rightEdge: piece.rightEdge,
              bottomEdge: piece.bottomEdge,
              leftEdge: piece.leftEdge,
              locked: piece.isSnapped,
              isDragging: isDragging,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goToPuzzleLevelsPage,
        ),
        title: const Text('Puzzle Pix'),
        backgroundColor: const Color(0xFFFF6B6B),
        foregroundColor: const Color(0xFF5B3E00),
        centerTitle: true,
        toolbarHeight: 64,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
              alignment: Alignment.center,
              child: Text(
                '9 card challenge with simple stretch breaks',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5B3E00),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFFFF5E9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final canvas = Size(constraints.maxWidth, constraints.maxHeight);
            final boardSize = min(canvas.width - 24, 300.0);
            final tileSize = boardSize / _gridSize;
            final boardLeft = (canvas.width - boardSize) / 2;
            final boardTop = 16.0;

            final shouldInit =
                _pieces.isEmpty ||
                _lastCanvasSize == null ||
                (_lastCanvasSize!.width - canvas.width).abs() > 1 ||
                (_lastCanvasSize!.height - canvas.height).abs() > 1;

            if (_selectedImageBytes == null) {
              return const Center(
                child: Text(
                  'No puzzle images available yet.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              );
            }

            if (shouldInit) {
              _lastCanvasSize = canvas;
              _initializePieces(
                canvas: canvas,
                boardLeft: boardLeft,
                boardTop: boardTop,
                boardSize: boardSize,
              );
            }

            // Ensure _pieces is never empty or null at this point
            if (_pieces.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final snappedCount = _pieces.where((p) => p.isSnapped).length;
            final complete = _isPuzzleComplete();

            final halfwayCount = _pieces.length ~/ 2;
            if (!_hasTriggeredHalfwayBreak &&
                !_isBreakActive &&
                !complete &&
                halfwayCount > 0 &&
                snappedCount == halfwayCount) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _isBreakActive || _hasTriggeredHalfwayBreak) {
                  return;
                }
                setState(() {
                  _startExerciseBreak();
                });
              });
            }

            if (complete && snappedCount == 9 && !_hasShownCompletionDialog) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _hasShownCompletionDialog = true;
                _showCompletionDialog();
              });
            }

            final orderedPieces = List<_PuzzlePiece>.from(_pieces);
            if (_draggingPieceIndex != null) {
              final dragged = orderedPieces.firstWhere(
                (p) => p.index == _draggingPieceIndex,
              );
              orderedPieces.removeWhere((p) => p.index == _draggingPieceIndex);
              orderedPieces.add(dragged);
            }

            final minutes = _timer.elapsed.inMinutes;
            final seconds = _timer.elapsed.inSeconds % 60;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TopActionButton(
                        label: 'Preview',
                        icon: Icons.visibility_rounded,
                        onTap: _showPreviewDialog,
                      ),
                      _TopActionButton(
                        label: _showBoardOverlay ? 'Overlay On' : 'Overlay',
                        icon: Icons.layers_rounded,
                        highlighted: _showBoardOverlay,
                        onTap: () {
                          setState(() {
                            _showBoardOverlay = !_showBoardOverlay;
                          });
                        },
                      ),
                      _TopActionButton(
                        label: 'Restart',
                        icon: Icons.restart_alt_rounded,
                        onTap: () {
                          setState(_resetPuzzle);
                        },
                      ),
                      _TopActionButton(
                        label: 'Solve',
                        icon: Icons.auto_fix_high_rounded,
                        onTap: _solvePuzzle,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          complete
                              ? 'Fantastic! All pieces placed!'
                              : 'Drag pieces into the grid.',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: complete
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFF5B3E00),
                              ),
                        ),
                      ),
                      Chip(
                        label: Text('$snappedCount/9'),
                        backgroundColor: complete
                            ? const Color(0xFFC8E6C9)
                            : const Color(0xFFFFE3DB),
                        side: BorderSide.none,
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          '$minutes:${seconds.toString().padLeft(2, '0')}',
                        ),
                        backgroundColor: const Color(0xFFE3F2FD),
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      // Grid outline background
                      Positioned(
                        left: boardLeft,
                        top: boardTop,
                        child: Container(
                          width: boardSize,
                          height: boardSize,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFD9CFC4),
                              width: 1.5,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              if (_showBoardOverlay)
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: 0.22,
                                    child: _buildPuzzleSourceImage(),
                                  ),
                                ),
                              for (int row = 0; row < _gridSize; row++)
                                for (int col = 0; col < _gridSize; col++)
                                  Positioned(
                                    left: col * tileSize,
                                    top: row * tileSize,
                                    child: Container(
                                      width: tileSize,
                                      height: tileSize,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFFD9CFC4),
                                          width: 1,
                                          strokeAlign:
                                              BorderSide.strokeAlignCenter,
                                        ),
                                      ),
                                      child:
                                          _pieces.any(
                                            (p) =>
                                                p.cellIndex ==
                                                    row * _gridSize + col &&
                                                p.isSnapped,
                                          )
                                          ? const Icon(
                                              Icons.check_circle,
                                              color: Color(0xFF2E7D32),
                                              size: 18,
                                            )
                                          : null,
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                      // Draggable pieces
                      IgnorePointer(
                        ignoring: _isBreakActive,
                        child: Stack(
                          children: [
                            for (final piece in orderedPieces)
                              Positioned(
                                left: piece.currentOffset.dx,
                                top: piece.currentOffset.dy,
                                child: GestureDetector(
                                  onPanStart: piece.isSnapped
                                      ? null
                                      : (_) {
                                          setState(
                                            () => _draggingPieceIndex =
                                                piece.index,
                                          );
                                        },
                                  onPanUpdate: piece.isSnapped
                                      ? null
                                      : (details) {
                                          final boardRight =
                                              boardLeft + boardSize;
                                          final boardBottom =
                                              boardTop + boardSize;

                                          setState(() {
                                            piece.currentOffset = Offset(
                                              (piece.currentOffset.dx +
                                                      details.delta.dx)
                                                  .clamp(
                                                    0,
                                                    canvas.width - tileSize,
                                                  ),
                                              (piece.currentOffset.dy +
                                                      details.delta.dy)
                                                  .clamp(
                                                    0,
                                                    canvas.height - tileSize,
                                                  ),
                                            );

                                            // Check if over board for visual feedback
                                            piece.isOverBoard =
                                                piece.currentOffset.dx >=
                                                    boardLeft &&
                                                piece.currentOffset.dx +
                                                        tileSize <=
                                                    boardRight &&
                                                piece.currentOffset.dy >=
                                                    boardTop &&
                                                piece.currentOffset.dy +
                                                        tileSize <=
                                                    boardBottom;
                                          });
                                        },
                                  onPanEnd: piece.isSnapped
                                      ? null
                                      : (_) {
                                          final targetOffset =
                                              piece.correctOffset;
                                          final distanceToTarget = sqrt(
                                            (piece.currentOffset.dx -
                                                        targetOffset.dx) *
                                                    (piece.currentOffset.dx -
                                                        targetOffset.dx) +
                                                (piece.currentOffset.dy -
                                                        targetOffset.dy) *
                                                    (piece.currentOffset.dy -
                                                        targetOffset.dy),
                                          );

                                          if (distanceToTarget <=
                                              _snapThreshold) {
                                            piece.currentOffset = targetOffset;
                                            piece.cellIndex =
                                                piece.correctCellIndex;
                                            piece.isSnapped = true;
                                          }

                                          piece.isOverBoard = false;
                                          _draggingPieceIndex = null;
                                          _moveCount += 1;

                                          setState(() {});
                                        },
                                  child: _buildPieceTile(
                                    piece: piece,
                                    tileSize: tileSize,
                                    boardSize: boardSize,
                                    isDragging:
                                        _draggingPieceIndex == piece.index,
                                    imageBytes: _selectedImageBytes,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_isBreakActive) _buildBreaktimeOverlay(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  const _TopActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: highlighted
            ? const Color(0xFFFF8A80)
            : const Color(0xFFFFE3DB),
        foregroundColor: const Color(0xFF5B3E00),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _PuzzlePiece {
  _PuzzlePiece({
    required this.index,
    required this.row,
    required this.col,
    required this.currentOffset,
    required this.correctOffset,
    required this.correctCellIndex,
    required this.topEdge,
    required this.rightEdge,
    required this.bottomEdge,
    required this.leftEdge,
  });

  final int index;
  final int row;
  final int col;
  Offset currentOffset;
  final Offset correctOffset;
  final int correctCellIndex;
  final int topEdge;
  final int rightEdge;
  final int bottomEdge;
  final int leftEdge;
  int cellIndex = -1;
  bool isSnapped = false;
  bool isOverBoard = false;
}

class _PuzzlePiecePainter extends CustomPainter {
  final int topEdge;
  final int rightEdge;
  final int bottomEdge;
  final int leftEdge;
  final bool locked;
  final bool isDragging;

  _PuzzlePiecePainter({
    required this.topEdge,
    required this.rightEdge,
    required this.bottomEdge,
    required this.leftEdge,
    required this.locked,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPiecePath(
      size,
      topEdge: topEdge,
      rightEdge: rightEdge,
      bottomEdge: bottomEdge,
      leftEdge: leftEdge,
    );

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDragging ? 0.22 : 0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final fillPaint = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isDragging
          ? const Color(0xFF9F978F)
          : (locked ? const Color(0xFF7F7870) : const Color(0xFFB2AAA2))
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = locked ? 1.9 : 1.6;

    canvas.drawPath(path.shift(const Offset(2, 3)), shadowPaint);
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(_PuzzlePiecePainter oldPainter) {
    return oldPainter.locked != locked || oldPainter.isDragging != isDragging;
  }
}

class _PuzzlePieceClipper extends CustomClipper<Path> {
  final int topEdge;
  final int rightEdge;
  final int bottomEdge;
  final int leftEdge;

  const _PuzzlePieceClipper({
    required this.topEdge,
    required this.rightEdge,
    required this.bottomEdge,
    required this.leftEdge,
  });

  @override
  Path getClip(Size size) {
    return _buildPiecePath(
      size,
      topEdge: topEdge,
      rightEdge: rightEdge,
      bottomEdge: bottomEdge,
      leftEdge: leftEdge,
    );
  }

  @override
  bool shouldReclip(_PuzzlePieceClipper oldClipper) {
    return oldClipper.topEdge != topEdge ||
        oldClipper.rightEdge != rightEdge ||
        oldClipper.bottomEdge != bottomEdge ||
        oldClipper.leftEdge != leftEdge;
  }
}

Path _buildPiecePath(
  Size size, {
  required int topEdge,
  required int rightEdge,
  required int bottomEdge,
  required int leftEdge,
}) {
  final w = size.width;
  final h = size.height;
  final tabDepth = min(w, h) * 0.18;
  final tabWidth = min(w, h) * 0.44;

  final path = Path();
  path.moveTo(0, 0);

  _drawTopEdge(path, w, tabDepth, tabWidth, topEdge);
  _drawRightEdge(path, w, h, tabDepth, tabWidth, rightEdge);
  _drawBottomEdge(path, w, h, tabDepth, tabWidth, bottomEdge);
  _drawLeftEdge(path, h, tabDepth, tabWidth, leftEdge);

  path.close();
  return path;
}

void _drawTopEdge(
  Path path,
  double w,
  double tabDepth,
  double tabWidth,
  int edge,
) {
  final connStart = (w - tabWidth) / 2;
  final connEnd = (w + tabWidth) / 2;
  final center = w / 2;
  final shoulder = tabWidth * 0.20;
  final neck = tabWidth * 0.32;

  path.lineTo(connStart, 0);
  if (edge != 0) {
    final bulge = -tabDepth * edge;
    path.cubicTo(
      connStart + shoulder,
      0,
      connStart + neck,
      bulge * 0.22,
      center - tabWidth * 0.16,
      bulge * 0.72,
    );
    path.cubicTo(
      center - tabWidth * 0.08,
      bulge,
      center + tabWidth * 0.08,
      bulge,
      center + tabWidth * 0.16,
      bulge * 0.72,
    );
    path.cubicTo(
      connEnd - neck,
      bulge * 0.22,
      connEnd - shoulder,
      0,
      connEnd,
      0,
    );
  } else {
    path.lineTo(connEnd, 0);
  }
  path.lineTo(w, 0);
}

void _drawRightEdge(
  Path path,
  double w,
  double h,
  double tabDepth,
  double tabWidth,
  int edge,
) {
  final connStart = (h - tabWidth) / 2;
  final connEnd = (h + tabWidth) / 2;
  final center = h / 2;
  final shoulder = tabWidth * 0.20;
  final neck = tabWidth * 0.32;

  path.lineTo(w, connStart);
  if (edge != 0) {
    final bulge = tabDepth * edge;
    path.cubicTo(
      w,
      connStart + shoulder,
      w + bulge * 0.22,
      connStart + neck,
      w + bulge * 0.72,
      center - tabWidth * 0.16,
    );
    path.cubicTo(
      w + bulge,
      center - tabWidth * 0.08,
      w + bulge,
      center + tabWidth * 0.08,
      w + bulge * 0.72,
      center + tabWidth * 0.16,
    );
    path.cubicTo(
      w + bulge * 0.22,
      connEnd - neck,
      w,
      connEnd - shoulder,
      w,
      connEnd,
    );
  } else {
    path.lineTo(w, connEnd);
  }
  path.lineTo(w, h);
}

void _drawBottomEdge(
  Path path,
  double w,
  double h,
  double tabDepth,
  double tabWidth,
  int edge,
) {
  final connStart = (w + tabWidth) / 2;
  final connEnd = (w - tabWidth) / 2;
  final center = w / 2;
  final shoulder = tabWidth * 0.20;
  final neck = tabWidth * 0.32;

  path.lineTo(connStart, h);
  if (edge != 0) {
    final bulge = tabDepth * edge;
    path.cubicTo(
      connStart - shoulder,
      h,
      connStart - neck,
      h + bulge * 0.22,
      center + tabWidth * 0.16,
      h + bulge * 0.72,
    );
    path.cubicTo(
      center + tabWidth * 0.08,
      h + bulge,
      center - tabWidth * 0.08,
      h + bulge,
      center - tabWidth * 0.16,
      h + bulge * 0.72,
    );
    path.cubicTo(
      connEnd + neck,
      h + bulge * 0.22,
      connEnd + shoulder,
      h,
      connEnd,
      h,
    );
  } else {
    path.lineTo(connEnd, h);
  }
  path.lineTo(0, h);
}

void _drawLeftEdge(
  Path path,
  double h,
  double tabDepth,
  double tabWidth,
  int edge,
) {
  final connStart = (h + tabWidth) / 2;
  final connEnd = (h - tabWidth) / 2;
  final center = h / 2;
  final shoulder = tabWidth * 0.20;
  final neck = tabWidth * 0.32;

  path.lineTo(0, connStart);
  if (edge != 0) {
    final bulge = -tabDepth * edge;
    path.cubicTo(
      0,
      connStart - shoulder,
      bulge * 0.22,
      connStart - neck,
      bulge * 0.72,
      center + tabWidth * 0.16,
    );
    path.cubicTo(
      bulge,
      center + tabWidth * 0.08,
      bulge,
      center - tabWidth * 0.08,
      bulge * 0.72,
      center - tabWidth * 0.16,
    );
    path.cubicTo(
      bulge * 0.22,
      connEnd + neck,
      0,
      connEnd + shoulder,
      0,
      connEnd,
    );
  } else {
    path.lineTo(0, connEnd);
  }
  path.lineTo(0, 0);
}
