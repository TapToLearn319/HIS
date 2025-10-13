// tools/draw/display_random_draw.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../provider/hub_provider.dart';

class DisplayRandomDrawPage extends StatelessWidget {
  const DisplayRandomDrawPage({super.key});

  @override
  Widget build(BuildContext context) {
    final hubId = context.watch<HubProvider>().hubId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: (hubId == null)
              ? const Text('No hub', style: TextStyle(color: Colors.white))
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .doc('hubs/$hubId/draw/display')
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData || !snap.data!.exists) {
                      return const Text('Waiting…',
                          style: TextStyle(color: Colors.white, fontSize: 36));
                    }
                    final data = snap.data!.data()!;
                    final show = (data['show'] as bool?) ?? false;
                    final mode = (data['mode'] as String?) ?? 'lots';
                    final title = (data['title'] as String?) ?? '';
                    final names = (data['names'] as List?)?.cast<String>() ?? const [];

                    if (!show || names.isEmpty) {
                      return const Text('Waiting…',
                          style: TextStyle(color: Colors.white, fontSize: 36));
                    }

                    // 렌더
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (title.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        // lots: 이름만, ordering: 번호 + 이름
                        for (int i = 0; i < names.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              mode == 'ordering' ? '${i + 1}. ${names[i]}' : names[i],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/* -------------------- Waiting View -------------------- */

class _WaitingView extends StatelessWidget {
  const _WaitingView({this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (title != null && title!.isNotEmpty) ...[
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 42, fontWeight: FontWeight.w800, color: Color(0xFF001A36),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              const Icon(Icons.hourglass_empty, size: 96, color: Colors.black54),
              const SizedBox(height: 16),
              const Text(
                'Waiting for presenter…',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'The screen will update automatically when the presenter presses SHOW.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------- Drawing lots View -------------------- */

class _DrawingLotsView extends StatelessWidget {
  const _DrawingLotsView({super.key, this.title, required this.winners});

  final String? title;
  final List<String> winners;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxCols = size.width ~/ 320;
    final crossAxisCount = maxCols.clamp(1, 5);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (title != null && title!.isNotEmpty) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 42, fontWeight: FontWeight.w800, color: Color(0xFF001A36),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Winners',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 4 / 2,
              ),
              itemCount: winners.length,
              itemBuilder: (_, i) => _NameCard(title: winners[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------- Ordering View -------------------- */

class _OrderingView extends StatelessWidget {
  const _OrderingView({super.key, this.title, required this.ordered});

  final String? title;
  final List<String> ordered;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxCols = size.width ~/ 460;
    final crossAxisCount = maxCols.clamp(1, 3);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (title != null && title!.isNotEmpty) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 42, fontWeight: FontWeight.w800, color: Color(0xFF001A36),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Order',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 16 / 3.5,
              ),
              itemCount: ordered.length,
              itemBuilder: (_, i) => _OrderRow(index: i + 1, name: ordered[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------- Small UI Parts -------------------- */

class _NameCard extends StatelessWidget {
  const _NameCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD2D2D2), width: 1),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            title,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF0B1324),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.index, required this.name});

  final int index;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD2D2D2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$index',
                style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0B1324),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(fontSize: 20, color: Colors.black54),
      ),
    );
  }
}
