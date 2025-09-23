// lib/provider/device_overrides_provider.dart
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
    final x = d.data() ?? const <String, dynamic>{};
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
  DeviceOverridesProvider(this._fs);

  String? _hubId;
  String? _sessionId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  // deviceId -> override
  Map<String, DeviceOverride> _overrides = {};
  Map<String, DeviceOverride> get overrides => _overrides;

  String? get hubId => _hubId;
  String? get sessionId => _sessionId;

  String? get _collectionPath {
    if (_hubId == null || _sessionId == null) return null;
    return 'hubs/$_hubId/sessions/$_sessionId/deviceOverrides';
  }

  /// 허브/세션 바인딩
  void bindHubSession({required String hubId, required String? sessionId}) {
    final same = (_hubId == hubId) && (_sessionId == sessionId);
    if (same) return;

    _hubId = hubId;
    _sessionId = sessionId;
    _listen();
  }

  /// (하위 호환) 예전 API: 세션만 받는 버전.
  @Deprecated('Use bindHubSession(hubId: ..., sessionId: ...) instead.')
  void bindSession(String? sessionId) {
    bindHubSession(hubId: _hubId ?? 'hub-001', sessionId: sessionId);
  }

  void _listen() {
    _sub?.cancel();
    _sub = null;
    _overrides = {};
    notifyListeners();

    final path = _collectionPath;
    if (path == null) return;

    _sub = _fs
        .collection(path)
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snap) {
      final m = <String, DeviceOverride>{};
      for (final d in snap.docs) {
        m[d.id] = DeviceOverride.fromDoc(d);
      }
      _overrides = m;
      notifyListeners();
    }, onError: (e, st) {
      debugPrint('DeviceOverridesProvider snapshots error: $e');
    });
  }

  Future<void> setOverride({
    required String deviceId,
    required String studentId,
    required String slotIndex, // "1" | "2"
    Timestamp? expiresAt,
  }) async {
    final path = _collectionPath;
    if (path == null) return;

    await _fs.doc('$path/$deviceId').set(
      {
        'studentId': studentId,
        'slotIndex': slotIndex,
        'expiresAt': expiresAt,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> clearOverride(String deviceId) async {
    final path = _collectionPath;
    if (path == null) return;

    await _fs.doc('$path/$deviceId').delete();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
