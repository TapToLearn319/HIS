import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../../../main.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  final TextEditingController _agendaController = TextEditingController();

  @override
  void initState() {
    super.initState();

    channel.postMessage(jsonEncode({
      'type': 'tool_mode',
      'mode': 'agenda',
    }));

    _agendaController.addListener(() {
      channel.postMessage(jsonEncode({
        'type': 'agenda',
        'date': DateFormat('yyyy.MM.dd').format(DateTime.now()),
        'text': _agendaController.text,
      }));
    });
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('M월 d일').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F0),
      appBar: AppBar(title: const Text('수업 도구 - AGENDA')),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            '$formattedDate 알 림 장',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 1200,
              height: 700,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green[700],
                border: Border.all(color: Colors.brown, width: 12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _agendaController,
                maxLines: null,
                style: const TextStyle(color: Colors.white, fontSize: 50),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter the notice...',
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                keyboardType: TextInputType.multiline,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
