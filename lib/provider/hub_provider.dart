import 'package:flutter/foundation.dart';

/// 앱 전역 허브 스코프
class HubProvider extends ChangeNotifier {
  String? _hubId;

  String? get hubId => _hubId;

  /// 허브 설정 (로그인/허브 선택 시 호출)
  void setHub(String hubId) {
    if (_hubId == hubId) return;
    _hubId = hubId;
    notifyListeners();
  }

  /// 허브 초기화 (세션도 자연히 무효가 되도록, 외부에서 세션도 함께 clear해 주세요)
  void clear() {
    if (_hubId == null) return;
    _hubId = null;
    notifyListeners();
  }

  // ===== 편의 경로(옵셔널) =====
  String? get hubDocPath => (_hubId != null) ? 'hubs/$_hubId' : null;
  String? get studentsColPath =>
      hubDocPath == null ? null : '$hubDocPath/students';
  String? get liveByDeviceColPath =>
      hubDocPath == null ? null : '$hubDocPath/liveByDevice';

  /// 세션 문서 경로(허브가 있어야 계산 가능)
  String? sessionDocPath(String sessionId) =>
      hubDocPath == null ? null : '$hubDocPath/sessions/$sessionId';

  /// 세션 서브컬렉션 헬퍼
  String? eventsColPath(String sessionId) =>
      sessionDocPath(sessionId) == null ? null : '${sessionDocPath(sessionId)}/events';
  String? seatMapColPath(String sessionId) =>
      sessionDocPath(sessionId) == null ? null : '${sessionDocPath(sessionId)}/seatMap';
  String? studentStatsColPath(String sessionId) =>
      sessionDocPath(sessionId) == null ? null : '${sessionDocPath(sessionId)}/studentStats';
  String? statsColPath(String sessionId) =>
      sessionDocPath(sessionId) == null ? null : '${sessionDocPath(sessionId)}/stats';
}
