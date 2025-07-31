import 'package:flutter/material.dart';
import 'youtube_music.dart';
import 'genie_music.dart';
import 'melon_music.dart';

class MusicPlatformSelectPage extends StatelessWidget {
  final List<Map<String, dynamic>> platforms = [
    {
      'name': 'YouTube Music',
      'icon': Icons.play_circle_fill,
      'route': 'youtube',
    },
    {'name': 'Melon', 'icon': Icons.music_note, 'route': 'melon'},
    {'name': 'Genie', 'icon': Icons.audiotrack, 'route': 'genie'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Music Platform')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        itemCount: platforms.length,
        itemBuilder: (context, index) {
          final platform = platforms[index];
          return GestureDetector(
            onTap: () {
              if (platform['route'] == 'youtube') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => YouTubeMusicPage()),
                );
              } else if (platform['route'] == 'melon') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MelonMusicPage()),
                );
              } else if (platform['route'] == 'genie') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GenieMusicPage()),
                );
              }
            },
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.green[100],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(platform['icon'], size: 60, color: Colors.green),
                  const SizedBox(height: 10),
                  Text(
                    platform['name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
