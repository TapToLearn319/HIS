import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// hubs/{hubId}/devices 기준으로 버튼(디바이스) 목록을 읽어오는 Provider
class ButtonsProvider extends ChangeNotifier {
  final FirebaseFirestore _fs;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  String? _hubId;

  /// deviceId 리스트 (= 문서 id)
  List<String> _deviceIds = [];
  List<String> get serials => _deviceIds; // 기존 API 호환용

  ButtonsProvider(this._fs, {String? initialHubId}) {
    if (initialHubId != null) listenHub(initialHubId);
  }

  /// 허브 변경 시 재구독
  void listenHub(String hubId) {
    if (_hubId == hubId) return;
    _hubId = hubId;

    print('🔔 ButtonsProvider.listenHub → $hubId');

    _sub?.cancel();
    _deviceIds = [];
    notifyListeners();

    _checkOnce(); // 일회성 GET (디버깅용)

    _sub = _fs
        .collection('hubs')
        .doc(hubId)
        .collection('devices')
        .snapshots()
        .listen(
          _onSnapshot,
          onError: (e) => print('🔴 devices snapshot 에러: $e'),
        );
  }

  Future<void> _checkOnce() async {
    final hubId = _hubId;
    if (hubId == null) return;

    try {
      final snap = await _fs
          .collection('hubs')
          .doc(hubId)
          .collection('devices')
          .get();
      print('🔔 [일회성 GET] hubs/$hubId/devices docs: ${snap.docs.length}');
      for (var doc in snap.docs) {
        print('   • ${doc.id} → ${doc.data()}');
      }
    } catch (e) {
      print('🔴 [일회성 GET] 에러: $e');
    }
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    print('🔔 [실시간 SNAPSHOT] hubs/$_hubId/devices docs: ${snap.docs.length}');
    for (var doc in snap.docs) {
      print('   • ${doc.id} → ${doc.data()}');
    }
    _deviceIds = snap.docs.map((d) => d.id).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
