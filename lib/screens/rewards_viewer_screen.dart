import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:here_with_you/services/reward_service.dart';
import 'package:video_player/video_player.dart';

const Color _viewerOverlayColor = Color(0xCC111111);

class RewardsViewerReward {
  final RewardType type;
  final String name;
  final String? url;
  final String? text;

  const RewardsViewerReward({
    required this.type,
    required this.name,
    this.url,
    this.text,
  });

  factory RewardsViewerReward.fromRewardRecord(RewardRecord reward) {
    return RewardsViewerReward(
      type: reward.type,
      name: reward.fileName,
      url: reward.url,
      text: reward.text,
    );
  }
}

class RewardsViewerScreen extends StatefulWidget {
  const RewardsViewerScreen({
    super.key,
    required this.rewards,
    required this.initialIndex,
  });

  final List<RewardsViewerReward> rewards;
  final int initialIndex;

  @override
  State<RewardsViewerScreen> createState() => _RewardsViewerScreenState();
}

class _RewardsViewerScreenState extends State<RewardsViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final safeIndex = widget.initialIndex
        .clamp(0, math.max(widget.rewards.length - 1, 0))
        .toInt();
    _currentIndex = safeIndex;
    _pageController = PageController(initialPage: safeIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rewards.isEmpty) {
      return const Scaffold(
        body: SafeArea(child: Center(child: Text('No rewards available.'))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.rewards.length,
            onPageChanged: (value) {
              if (!mounted) {
                return;
              }
              setState(() {
                _currentIndex = value;
              });
            },
            itemBuilder: (context, index) {
              final reward = widget.rewards[index];
              return _RewardViewerPage(
                reward: reward,
                isActive: index == _currentIndex,
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _viewerOverlayColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.rewards.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: _viewerOverlayColor,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardViewerPage extends StatelessWidget {
  const _RewardViewerPage({required this.reward, required this.isActive});

  final RewardsViewerReward reward;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    switch (reward.type) {
      case RewardType.photo:
        return _PhotoRewardPage(reward: reward);
      case RewardType.text:
        return _NoteRewardPage(reward: reward);
      case RewardType.voice:
        return _VoiceRewardPage(reward: reward, isActive: isActive);
      case RewardType.video:
        return _VideoRewardPage(reward: reward, isActive: isActive);
    }
  }
}

class _PhotoRewardPage extends StatelessWidget {
  const _PhotoRewardPage({required this.reward});

  final RewardsViewerReward reward;

  @override
  Widget build(BuildContext context) {
    final url = reward.url;

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Column(
        children: [
          const Spacer(),
          Expanded(
            flex: 8,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: (url == null || url.isEmpty)
                    ? const Text(
                        'Photo unavailable.',
                        style: TextStyle(color: Colors.white70),
                      )
                    : Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Text(
                          'Photo unavailable.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ViewerRewardTitle(name: reward.name),
          const SizedBox(height: 26),
        ],
      ),
    );
  }
}

class _NoteRewardPage extends StatelessWidget {
  const _NoteRewardPage({required this.reward});

  final RewardsViewerReward reward;

  @override
  Widget build(BuildContext context) {
    final note = reward.text?.trim();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF4E6), Color(0xFFFFE7D1)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFFD8B3)),
                ),
                child: Text(
                  (note == null || note.isEmpty)
                      ? 'No note available yet.'
                      : note,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF5B3E00),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _ViewerRewardTitle(name: reward.name, darkText: true),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoRewardPage extends StatefulWidget {
  const _VideoRewardPage({required this.reward, required this.isActive});

  final RewardsViewerReward reward;
  final bool isActive;

  @override
  State<_VideoRewardPage> createState() => _VideoRewardPageState();
}

class _VideoRewardPageState extends State<_VideoRewardPage> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _VideoRewardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _showControls();
      _controller?.play();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller?.pause();
    }
  }

  Future<void> _initialize() async {
    final url = widget.reward.url;
    if (url == null || url.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await controller.initialize();
    await controller.setLooping(false);
    controller.addListener(_videoListener);

    if (!mounted) {
      controller.removeListener(_videoListener);
      await controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
      _loading = false;
    });

    if (widget.isActive) {
      await controller.play();
      _showControls();
    }
  }

  void _videoListener() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _showControls() {
    _hideControlsTimer?.cancel();
    setState(() {
      _controlsVisible = true;
    });
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _controlsVisible = false;
      });
    });
  }

  Future<void> _togglePlayPause() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    _showControls();
  }

  Future<void> _seekTo(Duration value) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.seekTo(value);
    _showControls();
  }

  Future<void> _skipBy(Duration delta) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final duration = controller.value.duration;
    final position = controller.value.position;
    final next = position + delta;
    final clamped = next < Duration.zero
        ? Duration.zero
        : (next > duration ? duration : next);

    await controller.seekTo(clamped);
    _showControls();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady = controller != null && controller.value.isInitialized;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showControls,
      onPanDown: (_) => _showControls(),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : !isReady
                  ? const Text(
                      'Video unavailable.',
                      style: TextStyle(color: Colors.white70),
                    )
                  : FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 28,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _controlsVisible ? 1 : 0,
              child: _MediaPlaybackControls(
                visible: _controlsVisible,
                name: widget.reward.name,
                isPlaying: controller?.value.isPlaying ?? false,
                position: controller?.value.position ?? Duration.zero,
                duration: controller?.value.duration ?? Duration.zero,
                onTogglePlayPause: _togglePlayPause,
                onSeek: _seekTo,
                onRewind10: () => _skipBy(const Duration(seconds: -10)),
                onForward10: () => _skipBy(const Duration(seconds: 10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceRewardPage extends StatefulWidget {
  const _VoiceRewardPage({required this.reward, required this.isActive});

  final RewardsViewerReward reward;
  final bool isActive;

  @override
  State<_VoiceRewardPage> createState() => _VoiceRewardPageState();
}

class _VoiceRewardPageState extends State<_VoiceRewardPage> {
  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  bool _loading = false;
  bool _controlsVisible = true;
  bool _sourceReady = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _setupPlayer();
  }

  @override
  void didUpdateWidget(covariant _VoiceRewardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive) {
      _pause();
    }
  }

  Future<void> _setupPlayer() async {
    _player.onPositionChanged.listen((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _position = value;
      });
    });

    _player.onDurationChanged.listen((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _duration = value;
      });
    });

    _player.onPlayerStateChanged.listen((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = value == PlayerState.playing;
      });
    });

    final url = widget.reward.url;
    if (url == null || url.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
    });

    await _player.setSourceUrl(url);
    final duration = await _player.getDuration();

    if (!mounted) {
      return;
    }

    setState(() {
      _duration = duration ?? Duration.zero;
      _sourceReady = true;
      _loading = false;
    });
  }

  void _showControls() {
    _hideControlsTimer?.cancel();
    setState(() {
      _controlsVisible = true;
    });
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _controlsVisible = false;
      });
    });
  }

  Future<void> _pause() async {
    if (_isPlaying) {
      await _player.pause();
    }
  }

  Future<void> _togglePlayPause() async {
    if (!_sourceReady) {
      return;
    }

    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
    _showControls();
  }

  Future<void> _seekTo(Duration target) async {
    if (!_sourceReady) {
      return;
    }

    await _player.seek(target);
    _showControls();
  }

  Future<void> _skipBy(Duration delta) async {
    if (!_sourceReady) {
      return;
    }

    final next = _position + delta;
    final clamped = next < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && next > _duration ? _duration : next);
    await _player.seek(clamped);
    _showControls();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showControls,
      onPanDown: (_) => _showControls(),
      child: Container(
        color: const Color(0xFF101010),
        child: Stack(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF3A3A3A)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.mic_rounded,
                      color: Color(0xFFFFB86C),
                      size: 36,
                    ),
                    const SizedBox(height: 14),
                    const _WaveformPlaceholder(),
                    const SizedBox(height: 14),
                    Text(
                      _loading
                          ? 'Loading voice memo...'
                          : (_sourceReady
                                ? 'Voice memo ready'
                                : 'Voice memo unavailable'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 28,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _controlsVisible ? 1 : 0,
                child: _MediaPlaybackControls(
                  visible: _controlsVisible,
                  name: widget.reward.name,
                  isPlaying: _isPlaying,
                  position: _position,
                  duration: _duration,
                  onTogglePlayPause: _togglePlayPause,
                  onSeek: _seekTo,
                  onRewind10: () => _skipBy(const Duration(seconds: -10)),
                  onForward10: () => _skipBy(const Duration(seconds: 10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformPlaceholder extends StatelessWidget {
  const _WaveformPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(28, (index) {
          final heights = <double>[10, 22, 16, 28, 14, 24, 18, 30];
          final barHeight = heights[index % heights.length];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              width: 4,
              height: barHeight,
              decoration: BoxDecoration(
                color: index.isEven
                    ? const Color(0xFFFFA55A)
                    : const Color(0xFFF0C38C),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MediaPlaybackControls extends StatelessWidget {
  const _MediaPlaybackControls({
    required this.visible,
    required this.name,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onTogglePlayPause,
    required this.onSeek,
    required this.onRewind10,
    required this.onForward10,
  });

  final bool visible;
  final String name;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final Future<void> Function() onTogglePlayPause;
  final Future<void> Function(Duration value) onSeek;
  final Future<void> Function() onRewind10;
  final Future<void> Function() onForward10;

  String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final hasDuration = duration > Duration.zero;
    final sliderMax = hasDuration ? duration.inMilliseconds.toDouble() : 1.0;
    final sliderValue = hasDuration
        ? position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble()
        : 0.0;

    return IgnorePointer(
      ignoring: !visible,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: _viewerOverlayColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x55FFFFFF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: const Color(0xFFFFB86C),
                inactiveTrackColor: Colors.white24,
                thumbColor: const Color(0xFFFFD7A8),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: sliderValue,
                min: 0,
                max: sliderMax,
                onChanged: hasDuration
                    ? (value) => onSeek(Duration(milliseconds: value.round()))
                    : null,
              ),
            ),
            Row(
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: onRewind10,
                  icon: const Icon(
                    Icons.replay_10_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Ink(
                  decoration: const ShapeDecoration(
                    color: Color(0x33FFFFFF),
                    shape: CircleBorder(),
                  ),
                  child: IconButton(
                    onPressed: onTogglePlayPause,
                    iconSize: 34,
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onForward10,
                  icon: const Icon(
                    Icons.forward_10_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerRewardTitle extends StatelessWidget {
  const _ViewerRewardTitle({required this.name, this.darkText = false});

  final String name;
  final bool darkText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        name,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: darkText ? const Color(0xFF5B3E00) : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
    );
  }
}
