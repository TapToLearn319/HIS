// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:webview_flutter/webview_flutter.dart';

// import '../../../main.dart';

// class GenieMusicPage extends StatefulWidget {
//   @override
//   _GenieMusicPageState createState() => _GenieMusicPageState();
// }

// class _GenieMusicPageState extends State<GenieMusicPage> {
//   late WebViewController _controller;

//   @override
//   void initState() {
//     super.initState();

//     channel.postMessage(jsonEncode({
//       'type': 'tool_mode',
//       'mode': 'music',
//       'platform': 'genie',
//     }));

//     _controller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..loadRequest(Uri.parse('https://www.genie.co.kr/'));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Genie Player')),
//       body: WebViewWidget(controller: _controller),
//     );
//   }
// }
