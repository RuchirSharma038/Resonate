import 'package:flutter/material.dart';
import 'package:resonate_app/controllers/audio_controller.dart';

class AudioPlay extends StatefulWidget {
  const AudioPlay({super.key});

  @override
  State<AudioPlay> createState() => _AudioPlayState();
}

class _AudioPlayState extends State<AudioPlay> {
  final TextEditingController urlcontroller = TextEditingController();
  late AudioController audiocontroller = AudioController();

  @override
  void dispose() {
    urlcontroller.dispose();
    audiocontroller.dispose();
    super.dispose();
  }

  void loadTrack() {
    if (urlcontroller.text.trim().isEmpty) return;
    audiocontroller.loadTrack(urlcontroller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resonate Player'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 100, color: Colors.blue),

            const SizedBox(height: 20),

            const Text(
              "Play Music from URL",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 25),

            TextField(
              controller: urlcontroller,
              decoration: InputDecoration(
                hintText: 'Enter song URL',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text("Load Track"),
                onPressed: loadTrack,
              ),
            ),

            const SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () {
                    if (audiocontroller.isLoaded) {
                      audiocontroller.playTrack();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Audio cannot be loaded')),
                      );
                    }
                  },
                ),

                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.pause),
                  onPressed: () {
                    audiocontroller.pauseTrack();
                  },
                ),

                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.stop),
                  onPressed: () {
                    audiocontroller.stopTrack();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
