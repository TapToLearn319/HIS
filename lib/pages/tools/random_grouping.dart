import 'package:flutter/material.dart';

class RandomGroupingPage extends StatelessWidget {
  const RandomGroupingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: const Text(''),
        elevation: 0,
      ),
      body: const Center(
        child: Text(''),
      ),
    );
  }
}