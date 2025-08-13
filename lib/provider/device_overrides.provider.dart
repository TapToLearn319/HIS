// device_overrides_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceOverride {
  final String deviceId;
  final String? studentId;
  final String? slotIndex; // "1" | "2"
  final Timestamp? expiresAt;
  DeviceOverride({
    required this.deviceId,
    this.studentId,
    this.slotIndex,
    this.expiresAt,
  });

  factory DeviceOverride.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data() ?? {};
    return DeviceOverride(
      deviceId: d.id,
      studentId: x['studentId'] as String?,
      slotIndex: x['slotIndex'] as String?,
      expiresAt: x['expiresAt'] as Timestamp?,
    );
    }
}

class DeviceOverridesProvider extends ChangeNotifier {
  final FirebaseFirestore _fs;
  String? _sessionId;
  StreamSubscription? _sub;

  // deviceId -> override
  Map<String, DeviceOverride> _overrides = {};
  Map<String, DeviceOverride> get overrides => _overrides;

  DeviceOverridesProvider(this._fs);

  void bindSession(String? sessionId) {
    if (_sessionId == sessionId) return;
    _sessionId = sessionId;
    _listen();
  }

  void _listen() {
    _sub?.cancel();
    _overrides = {};
    notifyListeners();

    if (_sessionId == null) return;

    _sub = _fs
        .collection('sessions/${_sessionId}/deviceOverrides')
        .snapshots()
        .listen((snap) {
      final m = <String, DeviceOverride>{};
      for (final d in snap.docs) {
        m[d.id] = DeviceOverride.fromDoc(d as DocumentSnapshot<Map<String, dynamic>>);
      }
      _overrides = m;
      notifyListeners();
    });
  }

  Future<void> setOverride({
    required String deviceId,
    required String studentId,
    required String slotIndex, // "1" | "2"
    Timestamp? expiresAt,
  }) async {
    if (_sessionId == null) return;
    await _fs
        .doc('sessions/${_sessionId}/deviceOverrides/$deviceId')
        .set({'studentId': studentId, 'slotIndex': slotIndex, 'expiresAt': expiresAt},
            SetOptions(merge: true));
  }

  Future<void> clearOverride(String deviceId) async {
    if (_sessionId == null) return;
    await _fs.doc('sessions/${_sessionId}/deviceOverrides/$deviceId').delete();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
