import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:here_with_you/firebase_options.dart';
import 'package:here_with_you/screens/admin_dashboard_screen.dart';
import 'package:here_with_you/screens/health_screen.dart';
import 'package:here_with_you/screens/memory_match_screen.dart';
import 'package:here_with_you/screens/mix_and_match_screen.dart';
import 'package:here_with_you/screens/puzzle_pix_screen.dart';
import 'package:here_with_you/screens/rewards_screen.dart';
import 'package:here_with_you/services/auth_service.dart';
import 'package:here_with_you/services/admin_media_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static String? name;
}

class AppNavigationState {
  static const String _routeKey = 'last_route';
  static const String _tabKey = 'last_tab_index';

  static Future<void> saveRoute(String route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_routeKey, route);
  }

  static Future<void> saveTabIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_routeKey, 'main');
    await prefs.setInt(_tabKey, index);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_routeKey);
    await prefs.remove(_tabKey);
  }

  static Future<String?> loadRoute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_routeKey);
  }

  static Future<int> loadTabIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_tabKey) ?? 0;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Here with You',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B6B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<DocumentSnapshot<Map<String, dynamic>>?> _resolveUserDoc(String uid) async {
    try {
      return await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
          future: _resolveUserDoc(user.uid),
          builder: (context, userDocSnapshot) {
            if (userDocSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final userDoc = userDocSnapshot.data;
            final userData = userDoc?.data();
            final role = (userData?['role'] as String?) ?? 'user';
            final name = (userData?['name'] as String?) ?? user.displayName ?? 'User';
            UserSession.name = name;

            return FutureBuilder<String?>(
              future: AppNavigationState.loadRoute(),
              builder: (context, routeSnapshot) {
                if (routeSnapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final route = routeSnapshot.data;

                if (role == 'admin') {
                  return const AdminDashboard();
                }

                if (route == 'puzzle_pix') {
                  return FutureBuilder<List<Uint8List>>(
                    future: AdminMediaService.instance
                        .fetchPuzzleImagesForLinkedAdmin()
                        .then((files) => files.map((f) => f.bytes!).toList()),
                    builder: (context, puzzleSnapshot) {
                      if (puzzleSnapshot.connectionState != ConnectionState.done) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final imageBytes = puzzleSnapshot.data ?? const <Uint8List>[];
                      return PuzzlePixScreen(imageBytes: imageBytes);
                    },
                  );
                }

                if (route == 'puzzle_game') {
                  return const PuzzleGameScreen();
                }

                return FutureBuilder<int>(
                  future: AppNavigationState.loadTabIndex(),
                  builder: (context, tabSnapshot) {
                    if (tabSnapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    return MainNavigationPage(initialIndex: tabSnapshot.data ?? 0);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _goToDestination(Widget destination) {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => destination),
      (route) => false,
    );
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        // User is logged in, fetch their role from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get()
            .timeout(const Duration(seconds: 4));
        final userData = userDoc.data();
        final role = (userData?['role'] as String?) ?? 'user';
        final name = (userData?['name'] as String?) ?? 'User';

        if (!mounted) return;

        UserSession.name = name;

        final destination = role == 'admin' ? const AdminDashboard() : const MainNavigationPage();

        _goToDestination(destination);
      } else {
        // No user logged in, show login screen
        _goToLogin();
      }
    } on TimeoutException {
      // Do not force logout on transient startup/network issues.
      _goToLogin();
    } catch (e) {
      // Error fetching user data, show login
      _goToLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topHeight = constraints.maxHeight * 0.35;
            const logoSize = 190.0;

            return Stack(
              children: [
                Column(
                  children: [
                    Container(
                      height: topHeight,
                      width: double.infinity,
                      color: const Color(0xFFFF6B6B),
                      child: Align(
                        alignment: const Alignment(0, 0.22),
                        child: Text(
                          'Here with You',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.chewy(
                            fontSize: 48,
                            color: const Color(0xFFFFF0E6),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: const Color(0xFFFFF5E9),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 92, 24, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6B6B),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LoginFormScreen(userType: 'user'),
                                      ),
                                    );
                                  },
                                  child: Text('Login as User', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 56,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFFF6B6B), width: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    foregroundColor: const Color(0xFFFF6B6B),
                                    backgroundColor: Colors.transparent,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LoginFormScreen(userType: 'admin'),
                                      ),
                                    );
                                  },
                                  child: Text('Login as Admin', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFFFF6B6B))),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('New user? ', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700)),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const SignupFormScreen()),
                                      );
                                    },
                                    child: Text('Sign up', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFFFF6B6B))),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: topHeight - (logoSize / 2) - 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      height: logoSize,
                      width: logoSize,
                      fit: BoxFit.contain,
                    ),
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

class LoginFormScreen extends StatefulWidget {
  final String userType;
  const LoginFormScreen({super.key, required this.userType});

  @override
  State<LoginFormScreen> createState() => _LoginFormScreenState();
}

class _LoginFormScreenState extends State<LoginFormScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields')));
      return;
    }

    setState(() => _loading = true);

    try {
      final authUser = await _authService.loginWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      UserSession.name = authUser.name;

      final destination =
          widget.userType == 'admin'
            ? const AdminDashboard()
              : const MainNavigationPage();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => destination),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed. Please try again.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Could not load user profile.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.userType == 'admin' ? 'Admin Login' : 'User Login';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFFFF6B6B),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B)),
                child: _loading ? const CircularProgressIndicator() : const Text('Log in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignupFormScreen extends StatefulWidget {
  const SignupFormScreen({super.key});

  @override
  State<SignupFormScreen> createState() => _SignupFormScreenState();
}

class _SignupFormScreenState extends State<SignupFormScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedRole = 'user';
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields')));
      return;
    }

    setState(() => _loading = true);

    try {
      final authUser = await _authService.signUpWithEmail(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
      );

      if (!mounted) return;

      UserSession.name = authUser.name;

      final destination =
          authUser.role == 'admin'
            ? const AdminDashboard()
              : const MainNavigationPage();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => destination),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Signup failed. Please try again.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Could not create user profile.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign up'), backgroundColor: const Color(0xFFFF6B6B)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 12),
            TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              items: const [
                DropdownMenuItem(value: 'user', child: Text('User')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedRole = value);
              },
              decoration: const InputDecoration(labelText: 'Role'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _signup,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B)),
                child: _loading ? const CircularProgressIndicator() : const Text('Sign up'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  late int _selectedIndex;

  static const List<Widget> _screens = <Widget>[
    HomeScreen(),
    HealthScreen(),
    RewardsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  Future<void> _onItemTapped(int index) async {
    setState(() {
      _selectedIndex = index;
    });
    await AppNavigationState.saveTabIndex(index);
  }

  // Exposed helper so child screens can switch tabs
  void switchToTab(int index) {
    _onItemTapped(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _screens[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFFF6B6B),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.health_and_safety), label: 'Health'),
          BottomNavigationBarItem(icon: Icon(Icons.redeem), label: 'Rewards'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOpeningPuzzlePix = false;

  void _goToRewards(BuildContext context) {
    final navState = context.findAncestorStateOfType<_MainNavigationPageState>();
    if (navState != null) navState.switchToTab(2);
  }

  Future<void> _openPuzzlePix() async {
    if (_isOpeningPuzzlePix) return;
    setState(() => _isOpeningPuzzlePix = true);

    try {
      await AppNavigationState.saveRoute('puzzle_game');
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PuzzleGameScreen(),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open Puzzle Pix levels right now.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningPuzzlePix = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = UserSession.name ?? 'User';

    return Padding(
      padding: const EdgeInsets.only(top: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: const Color(0xFFFF6B6B),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $displayName',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ready for today’s wellness games?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFFFF5E9),
                  child: Image.asset('assets/images/app_logo.png', height: 28, width: 28, fit: BoxFit.contain),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Choose a game', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryCard(
                  imageAsset: 'assets/images/puzzle.png',
                  title: _isOpeningPuzzlePix ? 'Loading...' : 'Puzzle Pix',
                  onTap: _openPuzzlePix,
                ),
                const SizedBox(width: 12),
                _CategoryCard(
                  imageAsset: 'assets/images/memory_match.png',
                  title: 'Memory Match',
                  imageFit: BoxFit.contain,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MemoryMatchScreen()),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _CategoryCard(
                  imageAsset: 'assets/images/mix&match.png',
                  title: 'Mix & Match',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MixAndMatchScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Top Rewards', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => _goToRewards(context),
                  child: const Text('View all'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _RewardButton(
                      title: 'Photo Memory',
                      subtitle: 'A favorite family photo unlocked after you complete a level.',
                      onTap: () => _goToRewards(context),
                    ),
                    const SizedBox(height: 12),
                    _RewardButton(
                      title: 'Personalized Note',
                      subtitle: 'A loving message written just for you to read anytime.',
                      onTap: () => _goToRewards(context),
                    ),
                    const SizedBox(height: 12),
                    _RewardButton(
                      title: 'Voice Memo',
                      subtitle: 'A recorded voice message from family that you can unlock and replay.',
                      onTap: () => _goToRewards(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String imageAsset;
  final String title;
  final BoxFit imageFit;
  final VoidCallback onTap;
  const _CategoryCard({
    required this.imageAsset,
    required this.title,
    required this.onTap,
    this.imageFit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(imageAsset, width: double.infinity, fit: imageFit),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text('Tap to explore', style: TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _RewardButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _RewardButton({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6B6B), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF333333),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF6F6960),
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Icon(Icons.chevron_right, color: Color(0xFFFF6B6B)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PuzzleGameScreen extends StatefulWidget {
  const PuzzleGameScreen({super.key});

  @override
  State<PuzzleGameScreen> createState() => _PuzzleGameScreenState();
}

class _PuzzleGameScreenState extends State<PuzzleGameScreen> {
  int _selectedLevel = 0;

  final List<_PuzzleLevel> _levels = const [
    _PuzzleLevel(
      title: 'Level 1',
      puzzlePieces: 9,
      exerciseName: 'Stretch breaks',
      exerciseHint: 'Gentle seated stretches for shoulders and back.',
      exerciseIcon: Icons.self_improvement,
    ),
    _PuzzleLevel(
      title: 'Level 2',
      puzzlePieces: 16,
      exerciseName: 'Cardio breaks',
      exerciseHint: 'Light marching in place to raise heart rate.',
      exerciseIcon: Icons.directions_run,
    ),
    _PuzzleLevel(
      title: 'Level 3',
      puzzlePieces: 25,
      exerciseName: 'Strength breaks',
      exerciseHint: 'Low-impact arm and leg strengthening drills.',
      exerciseIcon: Icons.fitness_center,
    ),
  ];

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFFF6B6B)),
    );
  }

  Future<void> _goBackToHomePage() async {
    await AppNavigationState.saveTabIndex(0);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MainNavigationPage(initialIndex: 0),
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
              color: highlighted ? const Color(0xFFFF6B6B) : const Color(0xFFE7E4DC),
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
                title: '${level.puzzlePieces} pieces',
                subtitle: 'Less pieces means easier play',
                highlighted: isSelected,
                onTap: () {
                  setState(() => _selectedLevel = index);
                  _showMessage('Selected ${level.title}: ${level.puzzlePieces} pieces');
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
                  _openLevelOnePuzzlePix();
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goBackToHomePage,
        ),
        title: const Text('Puzzle Pix'),
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

  Future<void> _openLevelOnePuzzlePix() async {
    try {
      final files = await AdminMediaService.instance.fetchPuzzleImagesForLinkedAdmin();
      final imageBytes = files.map((f) => f.bytes!).toList();
      if (!mounted) return;

      if (imageBytes.isEmpty) {
        _showMessage('No images found. Ask your admin to upload images and link your account.');
        return;
      }

      await AppNavigationState.saveRoute('puzzle_pix');
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PuzzlePixScreen(imageBytes: imageBytes),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to load puzzle images right now.');
    }
  }
}

class _PuzzleLevel {
  final String title;
  final int puzzlePieces;
  final String exerciseName;
  final String exerciseHint;
  final IconData exerciseIcon;

  const _PuzzleLevel({
    required this.title,
    required this.puzzlePieces,
    required this.exerciseName,
    required this.exerciseHint,
    required this.exerciseIcon,
  });
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await AuthService().signOut();
    await AppNavigationState.clear();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: const Color(0xFFFF6B6B), fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () async => _signOut(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B)),
              child: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}
