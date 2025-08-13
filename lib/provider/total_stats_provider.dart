import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TotalStatsProvider extends ChangeNotifier {
  final FirebaseFirestore _fs;
  TotalStatsProvider(this._fs);

  String? _sessionId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  int total = 0;

  Future<void> bindSession(String? sid) async {
    if (_sessionId == sid) return;

    final prev = _sub;
    _sub = null;
    if (prev != null) {
      try { await prev.cancel(); } catch (_) {}
    }

    _sessionId = sid;
    total = 0;
    notifyListeners();

    if (sid == null) return;

    await Future<void>.delayed(Duration.zero);

    final doc = _fs.doc('sessions/$sid/stats/summary');
    _sub = doc.snapshots().listen((snap) {
      final data = snap.data() ?? {};
      total = (data['total'] as num?)?.toInt() ?? 0;
      notifyListeners();
    }, onError: (e, st) {
      debugPrint('TotalStatsProvider snapshots error: $e');
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
