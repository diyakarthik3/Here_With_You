import 'dart:typed_data';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:here_with_you/services/admin_media_service.dart';

class MixAndMatchLevel1Screen extends StatefulWidget {
  const MixAndMatchLevel1Screen({super.key});

  @override
  State<MixAndMatchLevel1Screen> createState() =>
      _MixAndMatchLevel1ScreenState();
}

class _MixAndMatchLevel1ScreenState extends State<MixAndMatchLevel1Screen> {
  final AdminMediaService _mediaService = AdminMediaService.instance;

  List<_MixMatchItem> _items = const <_MixMatchItem>[];
  List<_MixMatchItem> _shuffledDescriptions = const <_MixMatchItem>[];
  final Set<String> _matchedIds = <String>{};
  final Set<String> _wrongTargetIds = <String>{};

  Future<void> _loadItems() async {
    final pairs = await _mediaService.fetchMixAndMatchPairsForLinkedAdmin();
    final usablePairs = pairs
        .where(
          (pair) =>
              pair.imageBytes.isNotEmpty ||
              (pair.imageUrl?.isNotEmpty ?? false),
        )
        .take(4)
        .toList();

    final items = usablePairs
        .map(
          (pair) => _MixMatchItem(
            id: pair.id,
            imageBytes: pair.imageBytes.isNotEmpty ? pair.imageBytes : null,
            imageUrl: pair.imageUrl,
            description: pair.description.trim().isEmpty
                ? 'No description added yet.'
                : pair.description.trim(),
          ),
        )
        .toList();

    final random = Random();
    final shuffled = List<_MixMatchItem>.from(items)..shuffle(random);

    if (!mounted) {
      return;
    }

    setState(() {
      _items = items;
      _shuffledDescriptions = shuffled;
      _matchedIds.clear();
      _wrongTargetIds.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _onDroppedOnTarget({
    required String draggedId,
    required String targetId,
  }) {
    if (draggedId == targetId) {
      setState(() {
        _matchedIds.add(targetId);
        _wrongTargetIds.remove(targetId);
      });
      return;
    }

    setState(() {
      _wrongTargetIds.add(targetId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Not quite. Try another description card.'),
        backgroundColor: Color(0xFFFF6B6B),
      ),
    );

    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _wrongTargetIds.remove(targetId);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEEE9),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFFFF6B6B),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: const Color(0xFF5B3E00),
                      ),
                      const Expanded(
                        child: Text(
                          'Mix & Match',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF5B3E00),
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '8 card challenge with simple stretch breaks.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF5B3E00),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<void>(
                future: Future<void>.value(),
                builder: (context, _) {
                  if (_items.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _loadItems,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: const [
                          SizedBox(height: 24),
                          _EmptyMixMatchCard(
                            message:
                                'No Mix & Match level 1 cards yet. Ask your admin to add at least 4 pairs with photos and descriptions.',
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _loadItems,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _items.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1,
                              ),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final isMatched = _matchedIds.contains(item.id);

                            if (isMatched) {
                              return _PhotoMatchedCard(item: item);
                            }

                            return Draggable<String>(
                              data: item.id,
                              feedback: Material(
                                color: Colors.transparent,
                                child: SizedBox(
                                  width: 140,
                                  height: 140,
                                  child: _PhotoCard(item: item),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.35,
                                child: _PhotoCard(item: item),
                              ),
                              child: _PhotoCard(item: item),
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        ..._shuffledDescriptions.map((item) {
                          final isMatched = _matchedIds.contains(item.id);
                          final isWrong = _wrongTargetIds.contains(item.id);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DragTarget<String>(
                              onWillAcceptWithDetails: (_) => !isMatched,
                              onAcceptWithDetails: (details) {
                                _onDroppedOnTarget(
                                  draggedId: details.data,
                                  targetId: item.id,
                                );
                              },
                              builder: (context, candidateData, rejectedData) {
                                return _DescriptionCard(
                                  description: item.description,
                                  isMatched: isMatched,
                                  isWrong: isWrong,
                                  isHovering: candidateData.isNotEmpty,
                                );
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MixMatchItem {
  final String id;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final String description;

  const _MixMatchItem({
    required this.id,
    this.imageBytes,
    this.imageUrl,
    required this.description,
  });
}

class _PhotoCard extends StatelessWidget {
  final _MixMatchItem item;

  const _PhotoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E4DC)),
      ),
      clipBehavior: Clip.antiAlias,
      child: item.imageBytes != null && item.imageBytes!.isNotEmpty
          ? Image.memory(item.imageBytes!, fit: BoxFit.cover)
          : (item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFFFFE3DB),
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined),
                    ),
                  )
                : Container(
                    color: const Color(0xFFFFE3DB),
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_outlined),
                  )),
    );
  }
}

class _PhotoMatchedCard extends StatelessWidget {
  final _MixMatchItem item;

  const _PhotoMatchedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _PhotoCard(item: item),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2E7D32), width: 3),
              color: const Color(0x332E7D32),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF2E7D32),
              size: 36,
            ),
          ),
        ),
      ],
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  final String description;
  final bool isMatched;
  final bool isWrong;
  final bool isHovering;

  const _DescriptionCard({
    required this.description,
    required this.isMatched,
    required this.isWrong,
    required this.isHovering,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isMatched
        ? const Color(0xFF2E7D32)
        : isWrong
        ? const Color(0xFFB3261E)
        : isHovering
        ? const Color(0xFFFF6B6B)
        : const Color(0xFFE7E4DC);

    final backgroundColor = isMatched
        ? const Color(0xFFE8F5E9)
        : isWrong
        ? const Color(0xFFFFEBEE)
        : isHovering
        ? const Color(0xFFFFF1EC)
        : Colors.white;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isMatched ? 2.5 : 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                color: Color(0xFF5B3E00),
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isMatched)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32)),
        ],
      ),
    );
  }
}

class _EmptyMixMatchCard extends StatelessWidget {
  final String message;

  const _EmptyMixMatchCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E4DC)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF6F6960), height: 1.4),
      ),
    );
  }
}
