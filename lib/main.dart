// lib/main.dart
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:project/pages/game/presenter_game_page.dart';

import 'login.dart';
import 'pages/home/presenter_home_page.dart';
import 'pages/home/display_home_page.dart';
import 'pages/quiz/presenter_quiz_page.dart';
import 'pages/quiz/display_quiz_page.dart';
import 'pages/game/display_game_page.dart';
import 'pages/game/presenter_game_page.dart';
import 'pages/tools/presenter_tools_page.dart';
import 'pages/tools/display_tools_page.dart';
import 'pages/setting/display_setting_page.dart';
import 'pages/setting/presenter_setting_page.dart';
// … (other imports: class, choice, ox, timer, setting)

/// ─── 전역 설정 ────────────────────────────────────────
final bool isDisplay =
    Uri.base.queryParameters['view'] == 'display';
final String initialRoute =
    Uri.base.queryParameters['route'] ?? '/login';
final html.BroadcastChannel channel =
    html.BroadcastChannel('presentation');
final ValueNotifier<int> slideIndex = ValueNotifier<int>(0);

/// ─── Presenter 전용 RouteObserver ────────────────────
class PresenterRouteObserver extends RouteObserver<ModalRoute<void>> {
  void _broadcast(String? route) {
    channel.postMessage(jsonEncode({
      'type': 'route',
      'route': route,
      'slide': slideIndex.value,
    }));
  }

  @override
  void didPush(Route route, Route? previous) {
    super.didPush(route, previous);
    _broadcast(route.settings.name);
  }

  @override
  void didPop(Route route, Route? previous) {
    super.didPop(route, previous);
    _broadcast(previous?.settings.name);
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(isDisplay ? DisplayApp() : PresenterApp());
}

/// ─── PresenterApp ────────────────────────────────────
class PresenterApp extends StatelessWidget {
  final _observer = PresenterRouteObserver();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Presenter',
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      navigatorObservers: [ _observer ],
      routes: {
        '/login': (_) => LoginPage(),
        '/home' : (_) => PresenterHomePage(),
        '/quiz' : (_) => PresenterQuizPage(),
        '/game' : (_) => PresenterGamePage(),
        '/tools' : (_) => PresenterToolsPage(),
        '/setting': (_) =>  PresenterSettingPage(),
        // … other presenter routes …
      },
    );
  }
}

/// ─── DisplayApp ──────────────────────────────────────
class DisplayApp extends StatefulWidget {
  @override
  _DisplayAppState createState() => _DisplayAppState();
}

class _DisplayAppState extends State<DisplayApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    channel.onMessage.listen((event) {
      final data = jsonDecode(event.data as String);
      if (data['type'] == 'route') {
        final route = data['route'] as String?;
        if (route != null) {
          navigatorKey.currentState
              ?.pushReplacementNamed(route);
        }
        slideIndex.value = data['slide'] as int;
      } else if (data['type'] == 'slide') {
        slideIndex.value = data['slide'] as int;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Display',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      initialRoute: initialRoute,
      routes: {
        '/login': (_) =>  DisplayHomePage(),
        '/home' : (_) =>  DisplayHomePage(),
        '/quiz' : (_) =>  DisplayQuizPage(),
        '/game' : (_) =>  DisplayGamePage(),
        '/tools': (_) =>  DisplayToolsPage(),
        '/setting': (_) =>  DisplaySettingPage(),
        // … other display routes …
      },
    );
  }
}
