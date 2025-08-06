import 'dart:convert';
import 'package:flutter/material.dart';
import '../../sidebar_menu.dart';
import '../../../main.dart';
import 'timer.dart';
import 'board.dart';
import 'music/music.dart';
import 'agenda.dart';
import 'ai/ai.dart';
import 'debate.dart';
import 'reward.dart';
import 'feedback.dart';

class PresenterToolsPage extends StatelessWidget {
  final List<Map<String, dynamic>> tools = [
    {'icon': Icons.timer, 'label': 'Timer', 'page': TimerPage()},
    {'icon': Icons.brush, 'label': 'Board', 'page': BoardPage()},
    {'icon': Icons.music_note,'label': 'Music','page': null,},
    {'icon': Icons.campaign, 'label': 'Agenda', 'page': AgendaPage()},
    {'icon': Icons.smart_toy, 'label': 'AI', 'page': AIPage()},
    {'icon': Icons.chat_rounded, 'label': 'Debate', 'page': DebatePage()},
    {'icon': Icons.water_drop, 'label': 'Reward', 'page': null},
    {'icon': Icons.feedback, 'label': 'Feedback', 'page': null},
  ];

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      channel.postMessage(jsonEncode({'type': 'tool_mode', 'mode': 'none'}));
    });

    return AppScaffold(
      selectedIndex: 3,
      body: Scaffold(
        appBar: AppBar(title: const Text('Class Tools')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1,
            ),
            itemCount: tools.length,
            itemBuilder: (context, index) {
              final tool = tools[index];
              return GestureDetector(
                onTap: () {
                  channel.postMessage(jsonEncode({
                    'type': 'tool_mode',
                    'mode': tool['mode'],
                  }));
                  
                  if (tool['page'] != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => tool['page'] as Widget),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${tool['label']} 기능은 준비 중입니다.')),
                    );
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, 149, 179, 238),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        tool['icon'],
                        size: 48,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tool['label'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
