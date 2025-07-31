import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../main.dart';

class MelonMusicPage extends StatefulWidget {
  @override
  _MelonMusicPageState createState() => _MelonMusicPageState();
}

class _MelonMusicPageState extends State<MelonMusicPage> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();

    channel.postMessage(jsonEncode({
      'type': 'tool_mode',
      'mode': 'music',
      'platform': 'melon',
    }));

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('https://www.melon.com/'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Melon Player')),
      body: WebViewWidget(controller: _controller),
    );
  }
}