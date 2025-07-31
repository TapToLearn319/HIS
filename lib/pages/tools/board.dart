import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../main.dart';

class DrawnLine {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DrawnLine({required this.points, required this.color, required this.strokeWidth});
}

class BoardPage extends StatefulWidget {
  @override
  _BoardPageState createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  List<DrawnLine> lines = [];
  DrawnLine? currentLine;
  Color selectedColor = Colors.black;
  double strokeWidth = 4.0;

  @override
  void initState() {
    super.initState();
    channel.postMessage(jsonEncode({
      'type': 'tool_mode',
      'mode': 'board',
    }));
  }

  void _broadcastBoard() {
    channel.postMessage(jsonEncode({
      'type': 'board',
      'lines': lines.map((line) => {
            'points': line.points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
            'color': line.color.value,
            'strokeWidth': line.strokeWidth,
          }).toList(),
    }));
  }

  void _clearBoard() {
    setState(() => lines.clear());
    _broadcastBoard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Board'),
        actions: [
          IconButton(icon: const Icon(Icons.clear), onPressed: _clearBoard),
        ],
      ),
      body: Stack(
        children: [
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              setState(() {
                currentLine = DrawnLine(points: [event.localPosition], color: selectedColor, strokeWidth: strokeWidth);
                lines.add(currentLine!);
              });
              _broadcastBoard();
            },
            onPointerMove: (event) {
              setState(() {
                currentLine?.points.add(event.localPosition);
              });
              _broadcastBoard();
            },
            onPointerUp: (_) {
              setState(() => currentLine = null);
              _broadcastBoard();
            },
            child: SizedBox.expand(
              child: CustomPaint(
                painter: BoardPainter(lines),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _colorButton(Colors.black),
                  _colorButton(Colors.red),
                  _colorButton(Colors.blue),
                  _colorButton(Colors.green),
                  Expanded(
                    child: Slider(
                      value: strokeWidth,
                      min: 2.0,
                      max: 10.0,
                      onChanged: (val) {
                        setState(() => strokeWidth = val);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorButton(Color color) {
    return GestureDetector(
      onTap: () => setState(() => selectedColor = color),
      child: CircleAvatar(backgroundColor: color),
    );
  }
}

class BoardPainter extends CustomPainter {
  final List<DrawnLine> lines;

  BoardPainter(this.lines);

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in lines) {
      final paint = Paint()
        ..color = line.color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = line.strokeWidth;
      for (int i = 0; i < line.points.length - 1; i++) {
        canvas.drawLine(line.points[i], line.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) => true;
}