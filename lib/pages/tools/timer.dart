import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../main.dart';

class TimerPage extends StatefulWidget {
  @override
  _TimerPageState createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  int minutes = 0;
  int seconds = 0;
  bool isRunning = false;
  int _initialTotalSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    channel.postMessage(jsonEncode({
      'type': 'tool_mode',
      'mode': 'timer',
    }));
  }

  void _broadcastTimerState() {
    channel.postMessage(jsonEncode({
      'type': 'timer',
      'minutes': minutes,
      'seconds': seconds,
      'isRunning': isRunning,
      'totalSeconds': _initialTotalSeconds,
    }));
  }

  void _startTimer() {
    if (minutes == 0 && seconds == 0) return;
    setState(() => isRunning = true);
    _broadcastTimerState();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (minutes == 0 && seconds == 0) {
        _stopTimer();
      } else {
        setState(() {
          if (seconds > 0) {
            seconds--;
          } else {
            minutes--;
            seconds = 59;
          }
        });
        _broadcastTimerState();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => isRunning = false);
    _broadcastTimerState();
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      isRunning = false;
      minutes = 0;
      seconds = 0;
    });
    _broadcastTimerState();
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => isRunning = false);
    _broadcastTimerState();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Time is up!')),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _presetButton(int sec) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          minutes = sec ~/ 60;
          seconds = sec % 60;
          _initialTotalSeconds = sec;
        });
        _broadcastTimerState();
      },
      child: Text('${sec >= 60 ? sec ~/ 60 : sec} ${sec >= 60 ? 'min' : 'sec'}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Timer')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeBox(minutes),
                const Text(':', style: TextStyle(fontSize: 50)),
                _buildTimeBox(seconds),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: isRunning ? null : _startTimer, child: const Text('Start')),
                const SizedBox(width: 10),
                ElevatedButton(onPressed: isRunning ? _pauseTimer : null, child: const Text('Pause')),
                const SizedBox(width: 10),
                ElevatedButton(onPressed: _resetTimer, child: const Text('Reset')),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: [
                _presetButton(30),
                _presetButton(60),
                _presetButton(300),
                _presetButton(600),
                _presetButton(1800),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBox(int value) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value.toString().padLeft(2, '0'),
        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
      ),
    );
  }
}