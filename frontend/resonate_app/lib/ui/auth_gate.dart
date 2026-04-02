import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonate_app/providers/auth_provider.dart';
import 'package:resonate_app/ui/auth_screen.dart';
import 'package:resonate_app/ui/home_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      // DATA STATE: Firebase has an answer
      data: (user) {
        if (user == null) {
          // No user found, show the Login/Signup screen
          return const AuthScreen();
        }
        // User is logged in, show the main app!
        return const HomeScreen();
      },
      loading: () => const Scaffold(
        body: _ResonateSplashScreen(
          child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
        ),
      ),

      // ERROR STATE: Something went fundamentally wrong with Firebase
      error: (error, stackTrace) => Scaffold(
        body: _ResonateSplashScreen(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  "Authentication Error\n$error",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A private helper widget to ensure the background and logo are perfectly
/// consistent across the Loading and Error states, matching the AuthScreen.
class _ResonateSplashScreen extends StatelessWidget {
  final Widget child;

  const _ResonateSplashScreen({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1E2C), Color(0xFF12121A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            const Icon(
              Icons.graphic_eq_rounded,
              size: 80,
              color: Colors.deepPurpleAccent,
            ),
            const SizedBox(height: 16),
            // App Title
            const Text(
              'RESONATE',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 4.0,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 48),
            // The injected child (Spinner or Error Text)
            child,
          ],
        ),
      ),
    );
  }
}
