import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:here_with_you/screens/rewards_viewer_screen.dart';
import 'package:here_with_you/services/player_progress_service.dart';
import 'package:here_with_you/services/reward_service.dart';
import 'package:video_player/video_player.dart';

const Color _darkBrownText = Color(0xFF5B3E00);

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final RewardService _rewardService = RewardService.instance;
  final PlayerProgressService _progressService = PlayerProgressService();

  static const List<RewardType> _rewardTypeOrder = <RewardType>[
    RewardType.photo,
    RewardType.text,
    RewardType.voice,
    RewardType.video,
  ];

  bool _loading = true;
  int _highestCompletedLevel = 0;
  List<RewardRecord> _rewards = const <RewardRecord>[];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final highestCompletedLevel = await _progressService
          .fetchHighestCompletedLevel();
      final rewards = await _rewardService.fetchRewardsForCurrentPlayer();

      if (!mounted) {
        return;
      }

      setState(() {
        _highestCompletedLevel = highestCompletedLevel;
        _rewards = rewards;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = 'Unable to load rewards right now.';
      });
    }
  }

  RewardRecord? _representativeRewardForType(RewardType type) {
    final candidates = _rewards.where((reward) => reward.type == type).toList()
      ..sort((left, right) {
        final levelCompare = left.unlockLevel.compareTo(right.unlockLevel);
        if (levelCompare != 0) {
          return levelCompare;
        }
        return left.createdAt.compareTo(right.createdAt);
      });

    final unlocked = candidates
        .where((reward) => reward.unlocked)
        .toList(growable: false);

    final unlockedWithContent = unlocked
        .where((reward) => _hasDisplayContent(type, reward))
        .toList(growable: false);
    if (unlockedWithContent.isNotEmpty) {
      return unlockedWithContent.last;
    }

    if (unlocked.isNotEmpty) {
      return unlocked.last;
    }

    final withContent = candidates
        .where((reward) => _hasDisplayContent(type, reward))
        .toList(growable: false);
    if (withContent.isNotEmpty) {
      return withContent.last;
    }

    if (candidates.isNotEmpty) {
      return candidates.first;
    }

    return null;
  }

  bool _hasDisplayContent(RewardType type, RewardRecord reward) {
    switch (type) {
      case RewardType.photo:
      case RewardType.voice:
      case RewardType.video:
        final url = reward.url?.trim();
        return url != null && url.isNotEmpty;
      case RewardType.text:
        final note = reward.text?.trim();
        return note != null && note.isNotEmpty;
    }
  }

  int _defaultUnlockLevelForType(RewardType type) {
    switch (type) {
      case RewardType.photo:
        return 1;
      case RewardType.text:
        return 4;
      case RewardType.voice:
        return 5;
      case RewardType.video:
        return 7;
    }
  }

  void _showLockedRewardMessage(int requiredLevel) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'This reward is locked until level $requiredLevel is completed.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _openRewardsViewer(RewardRecord reward) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RewardsViewerScreen(
          rewards: <RewardsViewerReward>[
            RewardsViewerReward.fromRewardRecord(reward),
          ],
          initialIndex: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rewardCards = _rewardTypeOrder
        .map((type) {
          final reward = _representativeRewardForType(type);
          final isUnlocked = reward?.unlocked ?? false;
          final unlockLevel =
              reward?.unlockLevel ?? _defaultUnlockLevelForType(type);
          return _RewardCategoryCardData(
            type: type,
            reward: reward,
            unlocked: isUnlocked,
            unlockLevel: unlockLevel,
          );
        })
        .toList(growable: false);

    return Container(
      color: const Color(0xFFEFEEE9),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFFFF6B6B),
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customized Rewards',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _highestCompletedLevel == 0
                              ? 'Complete level 1 to unlock your first personalized reward.'
                              : 'Highest completed level: $_highestCompletedLevel',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFFFF5E9),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      height: 28,
                      width: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadRewards,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE7E4DC)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.workspace_premium_rounded,
                            color: Color(0xFFFF6B6B),
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Level progress: $_highestCompletedLevel',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _darkBrownText,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Rewards',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _darkBrownText,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_errorMessage != null)
                      _RewardsMessageCard(message: _errorMessage!)
                    else
                      GridView.builder(
                        itemCount: rewardCards.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.78,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemBuilder: (context, index) {
                          final card = rewardCards[index];
                          return _RewardCategoryCard(
                            data: card,
                            onTap: () {
                              if (!card.unlocked || card.reward == null) {
                                _showLockedRewardMessage(card.unlockLevel);
                                return;
                              }
                              _openRewardsViewer(card.reward!);
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardCategoryCardData {
  const _RewardCategoryCardData({
    required this.type,
    required this.reward,
    required this.unlocked,
    required this.unlockLevel,
  });

  final RewardType type;
  final RewardRecord? reward;
  final bool unlocked;
  final int unlockLevel;
}

class _RewardCategoryCard extends StatelessWidget {
  const _RewardCategoryCard({required this.data, required this.onTap});

  final _RewardCategoryCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = rewardTypeLabel(data.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFD5CE)),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _RewardThumbnail(type: data.type, reward: data.reward),
                      if (!data.unlocked || data.reward == null)
                        Positioned.fill(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                            child: Container(color: const Color(0x66000000)),
                          ),
                        ),
                      if (!data.unlocked || data.reward == null)
                        const Center(
                          child: Icon(
                            Icons.lock_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _darkBrownText,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.unlocked && data.reward != null
                    ? 'Unlocked'
                    : 'Unlocks at level ${data.unlockLevel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF7B756D),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardThumbnail extends StatelessWidget {
  const _RewardThumbnail({required this.type, required this.reward});

  final RewardType type;
  final RewardRecord? reward;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case RewardType.photo:
        final url = reward?.url;
        if (url == null || url.isEmpty) {
          return const ColoredBox(color: Color(0xFFFFE3DB));
        }
        return Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFFFE3DB)),
        );
      case RewardType.text:
        final note = reward?.text?.trim();
        return Container(
          color: const Color(0xFFFFEFD8),
          padding: const EdgeInsets.all(10),
          child: Center(
            child: Text(
              (note == null || note.isEmpty) ? 'Personalized note' : note,
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF7A4F00),
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.25,
              ),
            ),
          ),
        );
      case RewardType.voice:
        return Container(
          color: const Color(0xFFEFE3D1),
          alignment: Alignment.center,
          child: const Icon(
            Icons.mic_rounded,
            size: 40,
            color: Color(0xFFFF6B6B),
          ),
        );
      case RewardType.video:
        return Stack(
          fit: StackFit.expand,
          children: [
            _VideoThumbnail(url: reward?.url),
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 40,
                color: Color(0xFFFFFFFF),
              ),
            ),
          ],
        );
    }
  }
}

class _VideoThumbnail extends StatefulWidget {
  const _VideoThumbnail({required this.url});

  final String? url;

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  late final Future<void> _loadFuture;
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _loadFuture = _initialize();
  }

  Future<void> _initialize() async {
    final url = widget.url;
    if (url == null || url.isEmpty) {
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    await controller.initialize();
    await controller.pause();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        final controller = _controller;
        if (controller == null || !controller.value.isInitialized) {
          return const ColoredBox(color: Color(0xFFD9D3CE));
        }

        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        );
      },
    );
  }
}

class _RewardsMessageCard extends StatelessWidget {
  const _RewardsMessageCard({required this.message});

  final String message;

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
