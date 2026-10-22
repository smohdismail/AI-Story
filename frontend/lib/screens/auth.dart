import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<bool> _verifyAgeConsent() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('is_age_verified_18') == true) {
      return true;
    }

    if (!mounted) return false;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1228),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFFF2D55), width: 1.5),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D55).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Text('🔞', style: TextStyle(fontSize: 32)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Age Verification (18+)',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Mature & Romantic Content Warning',
              style: TextStyle(
                color: Color(0xFFFF2D55),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: const Text(
                'AI Story contains deep emotional roleplay, passionate romantic themes, intimate conversations, and adult character interactions.\n\nThis application is strictly intended for individuals 18 years of age or older.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Are you 18 years of age or older?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2D55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Yes, I am 18 or Older',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white60,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No, I am Under 18 (Exit)', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await prefs.setBool('is_age_verified_18', true);
      return true;
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: const Color(0xFF1E1228),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.block, color: Colors.redAccent),
                SizedBox(width: 10),
                Text('Access Restricted', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'You must be at least 18 years old to access AI Story. Access has been restricted.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Understood', style: TextStyle(color: Colors.pinkAccent)),
              ),
            ],
          ),
        );
      }
      return false;
    }
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final email = _emailController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both your username and password.')),
      );
      return;
    }
    if (!_isLogin && email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email to register.')),
      );
      return;
    }

    final isAdult = await _verifyAgeConsent();
    if (!isAdult) return;

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        final data = await ApiService.login(username, password);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['access_token']);
        if (mounted) context.go('/');
      } else {
        await ApiService.register(username, email, password);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful! Please log in with your credentials.'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() => _isLogin = true);
        }
      }
    } catch (e) {
      if (mounted) {
        final rawMsg = e.toString().replaceFirst('Exception: ', '');
        if (rawMsg.contains('User account not found')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Account not found. Would you like to register?'),
              backgroundColor: Colors.orange.shade800,
              action: SnackBarAction(
                label: 'Register',
                textColor: Colors.white,
                onPressed: () => setState(() => _isLogin = false),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(rawMsg),
              backgroundColor: Colors.redAccent.shade700,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final isAdult = await _verifyAgeConsent();
    if (!isAdult) return;

    setState(() => _isLoading = true);
    try {
      // NOTE: serverClientId must be replaced with the user's actual Google OAuth Web Client ID.
      // We pass it to the backend so the backend can verify the token.
      const String serverClientId = "352946680628-e28emiglvp3dvanfo256eg9sea2rc3fp.apps.googleusercontent.com";
      final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: serverClientId);
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User canceled
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken != null) {
        final data = await ApiService.loginWithGoogle(idToken);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['access_token']);
        if (mounted) context.go('/');
      } else {
        throw Exception("Failed to get Google ID token");
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Sign-In Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Login' : 'Register'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Server Settings',
            onPressed: () async {
              await context.push('/settings');
              setState(() {});
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.auto_stories, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 32),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                ),
                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(_isLogin ? 'Login' : 'Register'),
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Connecting to server...\n(If server was asleep, Render free tier takes ~30s on first request)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin ? 'Need an account? Register' : 'Have an account? Login'),
                ),
                const SizedBox(height: 24),
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
