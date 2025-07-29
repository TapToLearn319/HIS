import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SeatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<int, String> _seatAssignments = {};
  Map<int, String> get seatAssignments => _seatAssignments;

  SeatProvider() {
    loadAssignments();
  }

  // 좌석 이름 저장 (Firestore 반영)
  Future<void> assignSeat(int index, String name) async {
    _seatAssignments[index] = name;
    notifyListeners();

    await _firestore.collection('seatAssignments').doc('seat_$index').set({
      'name': name,
    });
  }

  // Firestore에서 좌석 데이터 불러오기
  Future<void> loadAssignments() async {
    final snapshot = await _firestore.collection('seatAssignments').get();
    for (var doc in snapshot.docs) {
      final seatIndex = int.parse(doc.id.replaceAll('seat_', ''));
      final name = doc['name'] as String;
      _seatAssignments[seatIndex] = name;
    }
    notifyListeners();
  }
}
