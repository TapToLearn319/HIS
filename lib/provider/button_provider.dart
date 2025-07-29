import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ButtonsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  List<String> _serials = [];
  List<String> get serials => _serials;

  ButtonsProvider() {
    // 1) 생성자 호출 확인
    print('🔔 ButtonsProvider 생성자 호출');

    // 2) 일회성 GET 으로 컬렉션 데이터 확인
    _checkOnce();

    // 3) 실시간 스냅샷 구독 시작
    _sub = _firestore
        .collection('buttons')
        .snapshots()
        .listen(
          (snap) => _onSnapshot(snap),
          onError: (e) => print('🔴 Buttons snapshot 에러: $e'),
        );
  }

  Future<void> _checkOnce() async {
    try {
      final snap = await _firestore.collection('buttons').get();
      print('🔔 [일회성 GET] buttons docs: ${snap.docs.length}');
      for (var doc in snap.docs) {
        print('   • ${doc.id} → ${doc.data()}');
      }
    } catch (e) {
      print('🔴 [일회성 GET] 에러: $e');
    }
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    print('🔔 [실시간 SNAPSHOT] buttons docs: ${snap.docs.length}');
    for (var doc in snap.docs) {
      print('   • ${doc.id} → ${doc.data()}');
    }
    _serials = snap.docs.map((d) => d.id).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
