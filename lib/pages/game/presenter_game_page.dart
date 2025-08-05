import 'dart:convert';

import 'package:flutter/material.dart';
import '../../sidebar_menu.dart';
import '../../../main.dart';

/// Presenter 모드일 때 보여줄 화면
class PresenterGamePage extends StatelessWidget {
  final List<Map<String, dynamic>> games = [
    {'icon': Icons.question_mark, 'label': 'Card Choice', 'page': null},
    {'icon': Icons.casino, 'label': 'Roulette', 'page': null},
    {'icon': Icons.format_list_numbered, 'label': 'FCFS', 'page': null},
    {
      'icon': Icons.sports_baseball_outlined,
      'label': 'Ball Draw',
      'page': null,
    },
    {'label': 'Bomb', 'page': null},
  ];

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      channel.postMessage(jsonEncode({'type': 'game_mode', 'mode': 'none'}));
    });

    return AppScaffold(
      selectedIndex: 2,
      body: Scaffold(
        appBar: AppBar(title: const Text('Game')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1,
            ),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              return GestureDetector(
                onTap: () {
                  channel.postMessage(
                    jsonEncode({'type': 'game_mode', 'mode': game['mode']}),
                  );

                  if (game['page'] != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => game['page'] as Widget),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${game['label']} 기능은 준비 중입니다.')),
                    );
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.lightGreen[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        game['icon'],
                        size: 48,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      game['label'],
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