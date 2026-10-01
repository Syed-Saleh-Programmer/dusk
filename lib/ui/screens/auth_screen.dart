import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/app_state.dart';
import '../../services/supabase_service.dart';
import '../widgets/dusk_logo.dart';
import '../widgets/dusk_ui_components.dart';
import '../navigation/dusk_navigation.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '800823333611-qt1o5i485e5nsm23bpl5p9jq3taesa9f.apps.googleusercontent.com',
  );
  static const String googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  StreamSubscription<AuthState>? _authSubscription;
  bool _isLoading = false;
  bool _isLogin = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Listen for OAuth deep link callbacks (e.g. Google OAuth redirecting back to dusk://login-callback)
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null && mounted) {
        await context.read<AppState>().onAuthSessionChanged();
        final needsSetup = await _needsProfileSetup();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          DuskPageRoute.flowProgression(
            builder: (_) =>
                needsSetup ? const ProfileSetupScreen() : const HomeScreen(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _needsProfileSetup() async {
    final user = _supabaseService.currentUser;
    if (user == null) return false;
    final meta = user.userMetadata ?? {};
    if (meta['profile_setup_completed'] == true) return false;
    if (meta['preferred_name'] != null &&
        meta['preferred_name'].toString().trim().isNotEmpty) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final completedLocally =
        prefs.getBool('profile_setup_completed_${user.id}') ?? false;
    return !completedLocally;
  }

  String _formatAuthError(Object error) {
    if (error is AuthException) {
      final msg = error.message.trim();
      final lower = msg.toLowerCase();
      if (lower.contains('invalid login credentials')) {
        return 'Incorrect email or password. If you are new, switch to "First Sign Up".';
      }
      if (lower.contains('user already registered') ||
          lower.contains('already exists')) {
        return 'An account with this email already exists. Please switch to "Log In".';
      }
      if (lower.contains('email not confirmed')) {
        return 'Your email address is not confirmed yet. Please check your inbox or try signing in again.';
      }
      return msg;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _submitGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      // 1. If Web Client ID is supplied via --dart-define, attempt native Play Services sign in
      if (googleWebClientId.isNotEmpty) {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          serverClientId: googleWebClientId,
          clientId: googleIosClientId.isNotEmpty ? googleIosClientId : null,
        );
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          // User canceled the account picker
          return;
        }

        final googleAuth = await googleUser.authentication;
        if (googleAuth.idToken != null) {
          if (_supabaseService.currentUser != null) {
            await _supabaseService.signOut();
          }
          await Supabase.instance.client.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: googleAuth.idToken!,
            accessToken: googleAuth.accessToken,
          );
          if (!mounted) return;
          await context.read<AppState>().onAuthSessionChanged();
          final needsSetup = await _needsProfileSetup();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            DuskPageRoute.flowProgression(
              builder: (_) =>
                  needsSetup ? const ProfileSetupScreen() : const HomeScreen(),
            ),
          );
          return;
        }
      }

      // 2. Browser/Custom Tab OAuth flow (uses the Google Client ID & Secret configured in Supabase Dashboard)
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'dusk://login-callback',
      );
    } catch (e) {
      if (mounted) {
        final errText = _formatAuthError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errText.contains('developer') || errText.contains('10')
                  ? 'Google credentials unconfigured. Please configure your Google Client ID or use Email sign in.'
                  : 'Google Sign-In: $errText',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password.')),
      );
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }
    if (!_isLogin && password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters long.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Clear any previous user's state before authenticating a new session
      await context.read<AppState>().resetStateForSignOut();

      if (_isLogin) {
        await _supabaseService.signIn(email, password);
      } else {
        await _supabaseService.signUp(email, password);
      }
      if (!mounted) return;

      // Load profile & local/remote dumps strictly for the newly authenticated user
      await context.read<AppState>().onAuthSessionChanged();

      if (!mounted) return;
      if (_isLogin) {
        final needsSetup = await _needsProfileSetup();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          DuskPageRoute.flowProgression(
            builder: (_) =>
                needsSetup ? const ProfileSetupScreen() : const HomeScreen(),
          ),
        );
      } else {
        // First signup -> go to ProfileSetupScreen ("What should I call you?")
        Navigator.of(context).pushReplacement(
          DuskPageRoute.flowProgression(builder: (_) => const ProfileSetupScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_formatAuthError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: DuskAmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 26.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Center(
                  child: DuskLogo(
                    size: 92,
                    showBadgeContainer: true,
                  ),
                ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.12),
                const SizedBox(height: 18),
                Text(
                  _isLogin ? 'Welcome back to Dusk' : 'Create your sanctuary',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1A19),
                    letterSpacing: -0.6,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.08),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? 'Sign in to continue your reflection.'
                      : 'A quiet, private space for your daily thoughts and insights.',
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF88827A),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.08),
                const SizedBox(height: 28),

                // Mode Switcher Pill (Log In / Sign Up)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EBE1),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isLogin = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: _isLogin ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: _isLogin
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              'Log In',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    _isLogin ? FontWeight.w800 : FontWeight.w600,
                                color: _isLogin
                                    ? const Color(0xFF1B1A19)
                                    : const Color(0xFF88827A),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isLogin = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: !_isLogin ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: !_isLogin
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              'First Sign Up',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    !_isLogin ? FontWeight.w800 : FontWeight.w600,
                                color: !_isLogin
                                    ? const Color(0xFF1B1A19)
                                    : const Color(0xFF88827A),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 280.ms),

                const SizedBox(height: 22),

                // Main Auth Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFFEFE8DE)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          fillColor: Color(0xFFFAF7F2),
                          prefixIcon: Icon(
                            Icons.mail_outline_rounded,
                            color: Color(0xFFFF7A1A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          fillColor: const Color(0xFFFAF7F2),
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: Color(0xFFFF7A1A),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 19,
                              color: const Color(0xFFA59F95),
                            ),
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DuskPrimaryButton(
                        label: _isLogin ? 'Log In' : 'Create Account',
                        icon: Icons.arrow_forward_rounded,
                        isLoading: _isLoading,
                        onPressed: _submitEmail,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.05),

                const SizedBox(height: 22),

                const Row(
                  children: [
                    Expanded(child: Divider(color: Color(0xFFE8E2D8))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'OR CONTINUE WITH',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Color(0xFF9C958B),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Color(0xFFE8E2D8))),
                  ],
                ).animate().fadeIn(delay: 420.ms),

                const SizedBox(height: 20),

                // Google Sign In Button
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _submitGoogleSignIn,
                  icon: const Icon(
                    Icons.g_mobiledata_rounded,
                    size: 28,
                    color: Color(0xFF1B1A19),
                  ),
                  label: const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B1A19),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE6DFD3), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ).animate().fadeIn(delay: 480.ms).slideY(begin: 0.05),

                const SizedBox(height: 14),

                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin
                        ? 'New to Dusk? Tap to create an account'
                        : 'Already have an account? Log in',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6E6862),
                    ),
                  ),
                ).animate().fadeIn(delay: 540.ms),

                const SizedBox(height: 12),
                const Divider(color: Color(0xFFE8E2D8)),
                const SizedBox(height: 12),

                // Continue without Account (Free Users)
                TextButton.icon(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('hasSeenOnboarding', true);
                    await prefs.setBool('hasChosenGuestMode', true);
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacement(
                      DuskPageRoute.flowProgression(
                        builder: (_) => const HomeScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFFFF7A1A),
                    size: 18,
                  ),
                  label: const Text(
                    'Continue without an Account (Free Users)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B1A19),
                    ),
                  ),
                ).animate().fadeIn(delay: 580.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
