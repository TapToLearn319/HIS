import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../../main.dart';

class YouTubeMusicPage extends StatefulWidget {
  @override
  _YouTubeMusicPageState createState() => _YouTubeMusicPageState();
}

class _YouTubeMusicPageState extends State<YouTubeMusicPage> {
  late YoutubePlayerController _controller;
  String currentTrack = 'kh7GqO-2yoc'; // 기본 영상 ID
  String status = 'stopped';
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Display에 플랫폼 모드 전송
    channel.postMessage(
      jsonEncode({'type': 'tool_mode', 'mode': 'music', 'platform': 'youtube'}),
    );

    _controller = YoutubePlayerController.fromVideoId(
      videoId: currentTrack,
      autoPlay: false,
      params: const YoutubePlayerParams(showFullscreenButton: true),
    );

    _controller.listen((event) {
      if (event.playerState == PlayerState.playing && status != 'playing') {
        setState(() => status = 'playing');
        _broadcastStatus();
      } else if (event.playerState == PlayerState.paused &&
          status != 'paused') {
        setState(() => status = 'paused');
        _broadcastStatus();
      }
    });
  }

  void _broadcastStatus() {
    final metadata = _controller.metadata;
    channel.postMessage(
      jsonEncode({
        'type': 'music',
        'platform': 'youtube',
        'track': 'https://www.youtube.com/watch?v=$currentTrack',
        'title': metadata.title,
        'status': status,
      }),
    );
  }

  void _changeVideo(String videoId) {
    _controller.loadVideoById(videoId: videoId);
    setState(() {
      currentTrack = videoId;
      status = 'paused'; // ✅ 기본 상태 초기화
    });
    _broadcastStatus();
  }

  void _loadFromUrl() {
    final url = _urlController.text.trim();
    final videoId = YoutubePlayerController.convertUrlToId(url);
    if (videoId != null) {
      _changeVideo(videoId);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid YouTube URL')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YouTube Music Player')),
      body: Column(
        children: [
          Expanded(child: YoutubePlayer(controller: _controller)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Enter YouTube URL',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: _loadFromUrl,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => _changeVideo('5qap5aO4i9A'), // Lo-fi Beats 영상
            child: const Text('Play Lo-fi Beats'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
