import 'package:flutter/material.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final TextEditingController _checkInController = TextEditingController();

  final List<String> _moodEmojis = const [
    '😊',
    '🙂',
    '😐',
    '🙁',
    '😢',
    '😣',
    '😴',
    '😌',
  ];

  @override
  void dispose() {
    _checkInController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFEEE9),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFFF6B6B),
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Health',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'A check in for your mind and body.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
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
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 8),
                const Text(
                  'How are you feeling?',
                  style: TextStyle(
                    color: Color(0xFF5B3E00),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Scrollbar(
                  thumbVisibility: true,
                  child: SizedBox(
                    height: 112,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _moodEmojis.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 2),
                      itemBuilder: (context, index) {
                        return SizedBox(
                          width: 102,
                          height: 102,
                          child: Center(
                            child: Text(
                              _moodEmojis[index],
                              style: const TextStyle(fontSize: 64),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Or let us know below:',
                  style: TextStyle(
                    color: Color(0xFF5B3E00),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F6F6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: TextField(
                    controller: _checkInController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Type how you are feeling...',
                    ),
                  ),
                ),
                const SizedBox(height: 42),
                const Text(
                  'Health tracker',
                  style: TextStyle(
                    color: Color(0xFF5B3E00),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _MetricTrackerCard(
                  title: 'Step Tracker',
                  valueText: '1200/8000 steps',
                  progress: 0.15,
                  barColor: const Color(0xFF4D67E8),
                ),
                const SizedBox(height: 12),
                _DistanceTrackerCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTrackerCard extends StatelessWidget {
  final String title;
  final String valueText;
  final double progress;
  final Color barColor;

  const _MetricTrackerCard({
    required this.title,
    required this.valueText,
    required this.progress,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                valueText,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: barColor.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _DistanceTrackerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distance Tracker',
            style: TextStyle(
              color: Color(0xFF555555),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const _DistanceRow(
            label: 'Walking',
            value: '2.1 / 5.0 km',
            progress: 0.42,
            barColor: Color(0xFF00B8C7),
          ),
          const SizedBox(height: 12),
          const _DistanceRow(
            label: 'Running',
            value: '1.3 / 3.0 km',
            progress: 0.43,
            barColor: Color(0xFFFF59B6),
          ),
        ],
      ),
    );
  }
}

class _DistanceRow extends StatelessWidget {
  final String label;
  final String value;
  final double progress;
  final Color barColor;

  const _DistanceRow({
    required this.label,
    required this.value,
    required this.progress,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: barColor.withValues(alpha: 0.25),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}
