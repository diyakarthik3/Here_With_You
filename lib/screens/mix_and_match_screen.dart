import 'package:flutter/material.dart';
import 'package:here_with_you/screens/mix_and_match_level1_screen.dart';

class MixAndMatchScreen extends StatefulWidget {
  const MixAndMatchScreen({super.key});

  @override
  State<MixAndMatchScreen> createState() => _MixAndMatchScreenState();
}

class _MixAndMatchScreenState extends State<MixAndMatchScreen> {
  int _selectedLevel = 0;

  final List<_MixAndMatchLevel> _levels = const [
    _MixAndMatchLevel(
      title: 'Level 1',
      pieceCount: 8,
      exerciseName: 'Stretch breaks',
      exerciseHint: 'Gentle seated stretches for shoulders and back.',
      exerciseIcon: Icons.self_improvement,
    ),
    _MixAndMatchLevel(
      title: 'Level 2',
      pieceCount: 12,
      exerciseName: 'Cardio breaks',
      exerciseHint: 'Light marching in place to raise heart rate.',
      exerciseIcon: Icons.directions_run,
    ),
    _MixAndMatchLevel(
      title: 'Level 3',
      pieceCount: 16,
      exerciseName: 'Strength breaks',
      exerciseHint: 'Low-impact arm and leg strengthening drills.',
      exerciseIcon: Icons.fitness_center,
    ),
  ];

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF6B6B),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted
                  ? const Color(0xFFFF6B6B)
                  : const Color(0xFFE7E4DC),
              width: highlighted ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 48, color: const Color(0xFFFF6B6B)),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5B3E00),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6F6960), height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelSection(int index) {
    final level = _levels[index];
    final isSelected = index == _selectedLevel;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? const Color(0xFFFF6B6B) : const Color(0xFFE7E4DC),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                level.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5B3E00),
                ),
              ),
              const Spacer(),
              if (isSelected)
                const Chip(
                  label: Text('Selected'),
                  backgroundColor: Color(0xFFFFE3DB),
                  side: BorderSide.none,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoCard(
                icon: Icons.extension,
                title: '${level.pieceCount} pieces',
                subtitle: 'Less pieces means easier play',
                highlighted: isSelected,
                onTap: () {
                  setState(() => _selectedLevel = index);
                  _showMessage(
                    'Selected ${level.title}: ${level.pieceCount} pieces',
                  );
                },
              ),
              const SizedBox(width: 12),
              _infoCard(
                icon: level.exerciseIcon,
                title: level.exerciseName,
                subtitle: level.exerciseHint,
                highlighted: isSelected,
                onTap: () {
                  setState(() => _selectedLevel = index);
                  _showMessage('${level.title} exercise: ${level.exerciseName}');
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() => _selectedLevel = index);
                if (index == 0) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MixAndMatchLevel1Screen(),
                    ),
                  );
                  return;
                }
                _showMessage('Coming soon: ${level.title}');
              },
              icon: const Icon(Icons.play_arrow),
              label: Text('Play ${level.title}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
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
        title: const Text('Mix & Match'),
        backgroundColor: const Color(0xFFFF6B6B),
      ),
      body: Container(
        color: const Color(0xFFEFEEE9),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFFFF6B6B),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Text(
                  'Pick a level and matched exercise before you start.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (var i = 0; i < _levels.length; i++) _levelSection(i),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MixAndMatchLevel {
  final String title;
  final int pieceCount;
  final String exerciseName;
  final String exerciseHint;
  final IconData exerciseIcon;

  const _MixAndMatchLevel({
    required this.title,
    required this.pieceCount,
    required this.exerciseName,
    required this.exerciseHint,
    required this.exerciseIcon,
  });
}