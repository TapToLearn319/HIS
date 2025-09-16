// session_provider.dart
import 'package:flutter/foundation.dart';

class SessionProvider extends ChangeNotifier {
  String? _sessionId;
  String? get sessionId => _sessionId;

  void setSession(String sessionId) {
    if (_sessionId == sessionId) return;
    _sessionId = sessionId;
    notifyListeners();
  }

  void clearSession() {
    _sessionId = null;
    notifyListeners();
  }
  void clear() {
    if (_sessionId != null) {
      _sessionId = null;
      notifyListeners();
    }
  }
}
