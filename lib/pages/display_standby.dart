import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../provider/hub_provider.dart';

class DisplayStandByPage extends StatefulWidget {
  const DisplayStandByPage({super.key});
  @override
  State<DisplayStandByPage> createState() => _DisplayStandByPageState();
}

class _DisplayStandByPageState extends State<DisplayStandByPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markReady());
  }

  Future<void> _markReady() async {
    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null) return;
    final fs = FirebaseFirestore.instance;

    // ✅ Display ID는 각 창에 고유하게 부여 가능
    const displayId = 'display-main';

    await fs
        .doc('hubs/$hubId/displayStatus/$displayId')
        .set({
          'ready': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    debugPrint('🟢 Display $displayId marked as ready');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF6FAFF),
      body: Center(child: Image(image: AssetImage('assets/logo_bird_standby.png'))),
    );
  }
}
