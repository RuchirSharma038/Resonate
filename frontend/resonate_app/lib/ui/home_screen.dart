import 'package:flutter/material.dart';
import 'package:resonate_app/ui/join_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonate_app/providers/session_provider.dart';
import 'package:resonate_app/ui/audio_play.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(sessionProvider, (previous, next) {
      if ((previous == null || previous.sessionId.isEmpty) &&
          next.sessionId.isNotEmpty) {
        
        // Let the user know it succeeded
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Session Created: ${next.sessionId}")),
        );
        
        // Navigate to the audio room
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AudioPlay()),
        );
      }

      // Handle any socket errors
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });
    final sessionState = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text("Resonate"), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_note, size: 80, color: Colors.blue),

              const SizedBox(height: 20),

              const Text(
                "Welcome to Resonate",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              const Text(
                "Listen to music together in real time",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text("Join a Session"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => JoinSession()),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: sessionState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.add),
                  label: Text(
                    sessionState.isLoading ? "Creating..." : "Create a Session",
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: sessionState.isLoading
                      ? null
                      : () {
                          ref.read(sessionProvider.notifier).createSession();
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
