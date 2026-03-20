import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonate_app/providers/session_provider.dart';

class AudioPlay extends ConsumerStatefulWidget {
  const AudioPlay({super.key});

  @override
  ConsumerState<AudioPlay> createState() => _AudioPlayState();
}

class _AudioPlayState extends ConsumerState<AudioPlay> {
  final TextEditingController urlcontroller = TextEditingController();

  @override
  void dispose() {
    urlcontroller.dispose();
    super.dispose();
  }

  Color getStatusColor(String state) {
    switch (state.toLowerCase()) {
      case "playing":
        return Colors.green;
      case "paused":
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final hasSession = session.sessionId.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resonate Player'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1E2C), Color(0xFF2D2D44)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ICON
              const CircleAvatar(
                radius: 45,
                backgroundColor: Colors.white24,
                child: Icon(Icons.music_note, size: 50, color: Colors.white),
              ),

              const SizedBox(height: 20),

              //  SESSION CARD
              Card(
                color: Colors.white10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Session",
                            style: TextStyle(color: Colors.white70),
                          ),
                          Text(
                            session.sessionId.isEmpty
                                ? "Not joined"
                                : session.sessionId,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "State",
                            style: TextStyle(color: Colors.white70),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: getStatusColor(
                                    session.playbackState.toString(),
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                session.playbackState.toString(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Users",
                            style: TextStyle(color: Colors.white70),
                          ),
                          Text(
                            session.participants.length.toString(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              //  URL INPUT
              TextField(
                controller: urlcontroller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter song URL',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.link, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              //  LOAD BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: hasSession
                      ? () {
                          final url = urlcontroller.text.trim();
                          if (url.isEmpty) return;
                          ref.read(sessionProvider.notifier).setUrl(url);
                        }
                      : null,
                  child: const Text("Load Track"),
                ),
              ),

              const Spacer(),

              //  CONTROLS
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      iconSize: 36,
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      onPressed: hasSession
                          ? () {
                              ref.read(sessionProvider.notifier).play();
                            }
                          : null,
                    ),
                    IconButton(
                      iconSize: 36,
                      icon: const Icon(Icons.pause, color: Colors.white),
                      onPressed: hasSession
                          ? () {
                              ref.read(sessionProvider.notifier).pause();
                            }
                          : null,
                    ),
                    IconButton(
                      iconSize: 36,
                      icon: const Icon(Icons.stop, color: Colors.white),
                      onPressed: () {
                        ref.read(sessionProvider.notifier).stop();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
