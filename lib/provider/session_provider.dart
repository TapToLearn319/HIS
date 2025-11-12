import 'package:flutter/foundation.dart';

/// 세션 스코프 전용
class SessionProvider extends ChangeNotifier {
  String? _sessionId;

  String? get sessionId => _sessionId;

  void setSession(String sessionId) {
    if (_sessionId == sessionId) return;
    _sessionId = sessionId;
    notifyListeners();
  }

  void clear() {
    if (_sessionId == null) return;
    _sessionId = null;
    notifyListeners();
  }
}