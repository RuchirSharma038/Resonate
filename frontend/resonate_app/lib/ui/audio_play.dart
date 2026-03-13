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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Resonate App Audio Screen')),
      body: Center(
        child: Column(
          children: [
            TextField(
              controller: urlcontroller,
              decoration: InputDecoration(
                hintText: 'Enter the url of song',
                border: OutlineInputBorder(),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                audiocontroller.loadTrack(urlcontroller.text);
              },
              child: Text('Submit url'),
            ),
            ElevatedButton(
              onPressed: () {
                if (audiocontroller.isLoaded) {
                  audiocontroller.playTrack();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Audio cannot be loaded')),
                  );
                }
              },
              child: Text('Play'),
            ),
            ElevatedButton(
              onPressed: () {
                audiocontroller.pauseTrack();
              },
              child: Text('Pause'),
            ),
            ElevatedButton(
              onPressed: () {
                audiocontroller.stopTrack();
              },
              child: Text('Stop'),
            ),
          ],
        ),
      ),
    );
  }
}
