import 'package:flutter/material.dart';
import 'package:here_with_you/services/linked_player_service.dart';

class ManageUserProfileScreen extends StatefulWidget {
  const ManageUserProfileScreen({super.key});

  @override
  State<ManageUserProfileScreen> createState() => _ManageUserProfileScreenState();
}

class _ManageUserProfileScreenState extends State<ManageUserProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage user profile'),
        backgroundColor: const Color(0xFFFF6B6B),
        foregroundColor: const Color(0xFF5B3E00),
        centerTitle: true,
      ),
      body: const ManageUserProfileTabContent(),
    );
  }
}

class ManageUserProfileTabContent extends StatefulWidget {
  const ManageUserProfileTabContent({super.key});

  @override
  State<ManageUserProfileTabContent> createState() => _ManageUserProfileTabContentState();
}

class _ManageUserProfileTabContentState extends State<ManageUserProfileTabContent> {
  final LinkedPlayerService _linkedPlayerService = LinkedPlayerService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveLinkedPlayer() async {
    if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both name and email.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _linkedPlayerService.addLinkedPlayer(
        name: _nameController.text,
        email: _emailController.text,
      );

      if (!mounted) return;

      _nameController.clear();
      _emailController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Linked player saved to Firestore.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save linked player: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFEEE9),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE7E4DC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Link a player to your feed',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF5B3E00),
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add the player name and email so only this admin\'s published assets are available to that player.',
                    style: TextStyle(color: Color(0xFF6F6960), height: 1.35),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Player name',
                      filled: true,
                      fillColor: const Color(0xFFF8F8F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Player email',
                      filled: true,
                      fillColor: const Color(0xFFF8F8F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveLinkedPlayer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B6B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save linked player'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Linked player feed',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5B3E00),
                  ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<LinkedPlayerRecord>>(
              stream: _linkedPlayerService.linkedPlayersForCurrentAdmin(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final players = snapshot.data ?? const <LinkedPlayerRecord>[];
                if (players.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE7E4DC)),
                    ),
                    child: const Text(
                      'No linked players yet.',
                      style: TextStyle(color: Color(0xFF6F6960)),
                    ),
                  );
                }

                return Column(
                  children: players
                      .map(
                        (player) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFFFD7CC)),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFFFFE3DB),
                                child: Icon(Icons.person, color: Color(0xFF5B3E00)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      player.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      player.email,
                                      style: const TextStyle(color: Color(0xFF6F6960)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}