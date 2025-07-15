// lib/pages/display_home_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../main.dart'; // channel, slideIndex 전역 참조
import 'package:project/sidebar_menu.dart';

class DisplayHomePage extends StatefulWidget {
  @override
  _DisplayHomePageState createState() =>
      _DisplayHomePageState();
}

class _DisplayHomePageState extends State<DisplayHomePage> {
  @override
  void initState() {
    super.initState();
    // Presenter 쪽의 라우트/슬라이드 메시지 구독
    channel.onMessage.listen((msg) {
      final data = jsonDecode(msg.data as String);
      if (data['type'] == 'route') {
        final route = data['route'] as String?;
        if (route != null &&
            route !=
                ModalRoute.of(context)!
                    .settings
                    .name) {
          Navigator.pushReplacementNamed(
              context, route);
        }
        slideIndex.value = data['slide'] as int;
      } else if (data['type'] == 'slide') {
        slideIndex.value = data['slide'] as int;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ValueListenableBuilder<int>(
          valueListenable: slideIndex,
          builder: (_, idx, __) {
            return Text(
              '🔹 Display 화면\n슬라이드 ${idx + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 48),
            );
          },
        ),
      ),
    );
  }
}
