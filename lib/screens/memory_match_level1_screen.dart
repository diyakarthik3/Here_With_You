import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:here_with_you/services/admin_media_service.dart';

class MemoryMatchLevel1Screen extends StatefulWidget {
  const MemoryMatchLevel1Screen({super.key});

  @override
  State<MemoryMatchLevel1Screen> createState() =>
      _MemoryMatchLevel1ScreenState();
}

class _MemoryMatchLevel1ScreenState extends State<MemoryMatchLevel1Screen> {
  static const int _totalCards = 8;
  static const int _columns = 4;

  final List<_MemoryCardData> _cards = [];
  final AdminMediaService _mediaService = AdminMediaService.instance;

  late Stopwatch _timer;
  late Timer _uiTimer;
  Timer? _breakTimer;

  int? _firstSelectedIndex;
  bool _isCheckingPair = false;
  bool _hasTriggeredHalfwayBreak = false;
  bool _isBreakActive = false;
  int _breakSecondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _timer = Stopwatch()..start();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
    _mediaService.uploadedFiles.addListener(_handleMediaChanged);
    _setupCards();
  }

  @override
  void dispose() {
    _uiTimer.cancel();
    _breakTimer?.cancel();
    _mediaService.uploadedFiles.removeListener(_handleMediaChanged);
    _timer.stop();
    super.dispose();
  }

  void _handleMediaChanged() {
    if (!mounted) return;
    setState(_setupCards);
  }

  void _setupCards() {
    _cards.clear();

    final availablePhotos = _mediaService.uploadedFiles.value
        .where(
          (file) =>
              (file.bytes?.isNotEmpty ?? false) ||
              (file.downloadUrl?.isNotEmpty ?? false),
        )
        .toList();
    final uniquePhotos = availablePhotos.take(_totalCards ~/ 2).toList()
      ..shuffle(Random());

    if (uniquePhotos.length < _totalCards ~/ 2) {
      final fallbackColors = <Color>[
        const Color(0xFFFF8A80),
        const Color(0xFF81C784),
        const Color(0xFF64B5F6),
        const Color(0xFFFFD54F),
      ];
      final pairColors = [...fallbackColors, ...fallbackColors]
        ..shuffle(Random());

      for (int i = 0; i < _totalCards; i++) {
        _cards.add(
          _MemoryCardData(id: i, pairKey: 'color_$i', color: pairColors[i]),
        );
      }
      return;
    }

    final cardPhotos = <_MemoryCardData>[];
    for (final photo in uniquePhotos) {
      cardPhotos.add(
        _MemoryCardData(
          id: cardPhotos.length,
          pairKey: photo.id,
          imageBytes: photo.bytes,
          imageUrl: photo.downloadUrl,
          label: photo.fileName,
          color: const Color(0xFFFFE3DB),
        ),
      );
      cardPhotos.add(
        _MemoryCardData(
          id: cardPhotos.length,
          pairKey: photo.id,
          imageBytes: photo.bytes,
          imageUrl: photo.downloadUrl,
          label: photo.fileName,
          color: const Color(0xFFFFD7C9),
        ),
      );
    }

    cardPhotos.shuffle(Random());
    _cards.addAll(cardPhotos);

    if (_cards.length != _totalCards) {
      _cards.clear();
      final pairColors = [
        const Color(0xFFFF8A80),
        const Color(0xFF81C784),
        const Color(0xFF64B5F6),
        const Color(0xFFFFD54F),
        const Color(0xFFFF8A80),
        const Color(0xFF81C784),
        const Color(0xFF64B5F6),
        const Color(0xFFFFD54F),
      ]..shuffle(Random());

      for (int i = 0; i < _totalCards; i++) {
        _cards.add(
          _MemoryCardData(
            id: i,
            pairKey: 'color_${pairColors[i].toARGB32()}_$i',
            color: pairColors[i],
          ),
        );
      }
    }
  }

  int get _matchedCardsCount => _cards.where((c) => c.isMatched).length;

  Future<void> _onCardTap(int index) async {
    if (_isBreakActive || _isCheckingPair) return;

    final card = _cards[index];
    if (card.isMatched || card.isFaceUp) return;

    setState(() {
      card.isFaceUp = true;
    });

    if (_firstSelectedIndex == null) {
      _firstSelectedIndex = index;
      return;
    }

    _isCheckingPair = true;
    final firstIndex = _firstSelectedIndex!;
    final first = _cards[firstIndex];
    final second = _cards[index];

    await Future<void>.delayed(const Duration(milliseconds: 420));

    if (!mounted) return;

    if (first.pairKey == second.pairKey) {
      setState(() {
        first.isMatched = true;
        second.isMatched = true;
      });

      if (!_hasTriggeredHalfwayBreak &&
          _matchedCardsCount >= _totalCards ~/ 2) {
        _startBreakPopup();
      }
    } else {
      setState(() {
        first.isFaceUp = false;
        second.isFaceUp = false;
      });
    }

    _firstSelectedIndex = null;
    _isCheckingPair = false;
  }

  void _startBreakPopup() {
    _hasTriggeredHalfwayBreak = true;
    _isBreakActive = true;
    _breakSecondsLeft = 60;
    _timer.stop();

    _breakTimer?.cancel();
    _breakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_breakSecondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _isBreakActive = false;
          _breakSecondsLeft = 60;
        });
        _timer.start();
        return;
      }

      setState(() {
        _breakSecondsLeft -= 1;
      });
    });
  }

  void _restartGame() {
    setState(() {
      _firstSelectedIndex = null;
      _isCheckingPair = false;
      _hasTriggeredHalfwayBreak = false;
      _isBreakActive = false;
      _breakSecondsLeft = 60;
      _breakTimer?.cancel();
      _breakTimer = null;
      _setupCards();
      _timer
        ..reset()
        ..start();
    });
  }

  void _solveGame() {
    setState(() {
      for (final card in _cards) {
        card.isFaceUp = true;
        card.isMatched = true;
      }
      _firstSelectedIndex = null;
      _isCheckingPair = false;
      _isBreakActive = false;
      _breakTimer?.cancel();
      _breakTimer = null;
      _timer.stop();
    });
  }

  Widget _buildBreakOverlay() {
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
                    fontSize: 16,
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
                    padding: const EdgeInsets.all(10),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/person.png',
                        fit: BoxFit.cover,
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

  @override
  Widget build(BuildContext context) {
    final minutes = _timer.elapsed.inMinutes;
    final seconds = _timer.elapsed.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6B6B),
        foregroundColor: const Color(0xFF5B3E00),
        centerTitle: true,
        title: const Text('Memory Match'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(34),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '8 card challenge with simple stretch breaks',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5B3E00),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFFFF5E9),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      Chip(
                        label: Text('$_matchedCardsCount/$_totalCards'),
                        backgroundColor: const Color(0xFFFFE3DB),
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _restartGame,
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Restart'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFE3DB),
                            foregroundColor: const Color(0xFF5B3E00),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _solveGame,
                          icon: const Icon(Icons.auto_fix_high_rounded),
                          label: const Text('Solve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFE3DB),
                            foregroundColor: const Color(0xFF5B3E00),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: IgnorePointer(
                      ignoring: _isBreakActive,
                      child: GridView.builder(
                        itemCount: _cards.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _columns,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.72,
                            ),
                        itemBuilder: (context, index) {
                          final card = _cards[index];
                          return _MemoryMatchCard(
                            card: card,
                            onTap: () => _onCardTap(index),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isBreakActive) _buildBreakOverlay(),
          ],
        ),
      ),
    );
  }
}

class _MemoryMatchCard extends StatelessWidget {
  final _MemoryCardData card;
  final VoidCallback onTap;

  const _MemoryMatchCard({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final reveal = card.isFaceUp || card.isMatched;
    final hasPhoto =
        (card.imageBytes != null && card.imageBytes!.isNotEmpty) ||
        (card.imageUrl != null && card.imageUrl!.isNotEmpty);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: reveal ? (hasPhoto ? Colors.white : card.color) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: card.isMatched
                ? const Color(0xFF2E7D32)
                : const Color(0xFFE5DFD5),
            width: card.isMatched ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (reveal && hasPhoto)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: card.imageBytes != null && card.imageBytes!.isNotEmpty
                    ? Image.memory(
                        card.imageBytes!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : Image.network(
                        card.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: Color(0xFFF6F3EE)),
                      ),
              )
            else if (reveal)
              Center(
                child: Icon(
                  Icons.palette_rounded,
                  color: Colors.white.withValues(alpha: 0.78),
                  size: 28,
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFF4E9),
                      const Color(0xFFFFE3DB).withValues(alpha: 0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFFFF6B6B),
                    size: 26,
                  ),
                ),
              ),
            if (reveal && hasPhoto)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    card.label ?? 'Photo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MemoryCardData {
  final int id;
  final String pairKey;
  final Color color;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final String? label;
  bool isFaceUp = false;
  bool isMatched = false;

  _MemoryCardData({
    required this.id,
    required this.pairKey,
    required this.color,
    this.imageBytes,
    this.imageUrl,
    this.label,
  });
}
