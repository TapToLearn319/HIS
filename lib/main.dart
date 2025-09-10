
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:project/pages/ai_chat/presenter_ai_char.dart';
import 'package:project/pages/profile/class_score_detail.dart';
import 'package:project/pages/profile/student_score_detail.dart';
import 'package:project/pages/random_seat/display_random_seat.dart';
import 'package:project/pages/random_seat/presenter_random_seat.dart';
import 'package:project/pages/tools/groupMaking/display_group_page.dart';
import 'package:project/pages/tools/groupMaking/presenter_group_page.dart';
import 'package:project/pages/tools/timer/display_timer.dart';
import 'package:project/pages/tools/vote/display_vote.dart';
import 'package:project/pages/tools/vote/presenter_vote.dart';
import 'package:project/provider/all_logs_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:project/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'provider/app_settings_provider.dart';


import 'pages/profile/presenter_student_log_page.dart';
import 'pages/profile/presenter_class.dart';

import 'l10n/app_localizations.dart';
import 'login.dart';
import 'pages/profile/presenter_profile.dart';
import 'pages/home/presenter_home_page.dart';
import 'pages/home/display_home_page.dart';
import 'pages/quiz/presenter_quiz_page.dart';
import 'pages/quiz/display_quiz_page.dart';
import 'pages/game/presenter_game_page.dart';
import 'pages/game/display_game_page.dart';
import 'pages/tools/presenter_tools_page.dart';
import 'pages/tools/display_tools_page.dart';
import 'pages/setting/presenter_setting_page.dart';
import 'pages/setting/display_setting_page.dart';
import 'pages/ai_chat/display_ai_chat.dart';
import 'pages/tools/timer/presenter_timer.dart';
import 'pages/display_standby.dart';

import 'pages/tools/debate.dart';
import 'pages/tools/vote/vote_manager.dart';

// import 'provider/button_provider.dart';
// import 'provider/logs_provider.dart';
// import 'provider/seat_provider.dart';
import 'provider/session_provider.dart';
import 'provider/student_stats_provider.dart';
import 'provider/students_provider.dart';
import 'provider/total_stats_provider.dart';
import 'provider/seat_map_provider.dart';
import 'provider/debug_events_provider.dart';
import 'provider/device_overrides.provider.dart';

final bool isDisplay = Uri.base.queryParameters['view'] == 'display';
final String initialRoute = Uri.base.queryParameters['route'] ?? '/login';
final html.BroadcastChannel channel = html.BroadcastChannel('presentation');
final ValueNotifier<int> slideIndex = ValueNotifier<int>(0);

final ValueNotifier<Locale?> _localeNotifier = ValueNotifier(const Locale('en'));

void setLocale(Locale locale) {
  _localeNotifier.value = locale;
}

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

Future<void> main() async {
  print('🛠️ main() 시작');
  WidgetsFlutterBinding.ensureInitialized();
  final app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('🔥 Firebase projectId: ${app.options.projectId}');
  print('🔥 firestore.settings: ${FirebaseFirestore.instance.settings}');
  final snap = await FirebaseFirestore.instance.collection('buttons').get();
  print('🔥 [GET] buttons docs.length = ${snap.docs.length}');
  for (var doc in snap.docs) {
    print('   • ${doc.id} → ${doc.data()}');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(
        create: (_) => StudentStatsProvider(FirebaseFirestore.instance),
      ),
      ChangeNotifierProvider(
        create: (_) => TotalStatsProvider(FirebaseFirestore.instance),
      ),
      ChangeNotifierProvider(
        create: (_) => SeatMapProvider(FirebaseFirestore.instance),
      ),
      ChangeNotifierProvider(
        create: (_) => DeviceOverridesProvider(FirebaseFirestore.instance),
      ),
      ChangeNotifierProvider(
        create: (_) => DebugEventsProvider(FirebaseFirestore.instance),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            StudentsProvider(FirebaseFirestore.instance)..listenAll(),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            AppSettingsProvider()),
      ],
      child: isDisplay ? DisplayApp() : PresenterApp(),
    ),
  );
  print('🛠️ runApp 호출 완료');
}

class PresenterApp extends StatelessWidget {
  final _observer = PresenterRouteObserver();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>(); // <- 추가

    return MaterialApp(
      title: 'Presenter',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.kanitTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF6FAFF),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.kanitTextTheme(ThemeData.dark().textTheme),
      ),
      themeMode: settings.themeMode,

      // ▼ l10n 적용
      locale: settings.locale,                     // <- Provider에서 읽음
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ko'),
      ],

      initialRoute: initialRoute,
      navigatorObservers: [_observer],
      routes: {
        '/login': (_) => LoginPage(),
        '/home': (_) => PresenterHomePage(),
        '/tools/quiz': (_) => PresenterQuizPage(),
        '/game': (_) => PresenterGamePage(),
        '/tools': (_) => PresenterToolsPage(),
        '/AI': (_) => PresenterAIChatPage(),
        '/setting': (_) => PresenterSettingPage(),
        '/profile': (_) => PresenterMainPage(),
        '/profile/student': (_) => const PresenterStudentPage(),
        '/profile/class': (_) => const PresenterClassPage(),
        '/tools/timer': (_) =>  TimerPage(),
        '/tools/grouping': (_) =>  PresenterGroupPage(),
        '/tools/voting': (_) =>  PresenterVotePage(),
        '/tools/attendance': (_) =>  PresenterHomePage(),
        '/tools/random_seat': (_) =>  RandomSeatPage(),
        '/profile/student/details': (_) => const StudentScoreDetailsPage(),
        '/profile/class/details': (_) => const ClassScoreDetailsPage(),
      },
    );
  }
}

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
          navigatorKey.currentState?.pushReplacementNamed(route);
        }
        slideIndex.value = data['slide'] as int;
      } else if (data['type'] == 'slide') {
        slideIndex.value = data['slide'] as int;
      }
    });
  }

  @override
Widget build(BuildContext context) {
  final settings = context.watch<AppSettingsProvider>(); // <- 추가

  return MaterialApp(
    title: 'Display',
    debugShowCheckedModeBanner: false,
    navigatorKey: navigatorKey,

    // ▼ 테마
    theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.kanitTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF6FAFF),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.kanitTextTheme(ThemeData.dark().textTheme),
      ),
      themeMode: settings.themeMode,

    // ▼ l10n
    locale: settings.locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('en'),
      Locale('ko'),
    ],

    initialRoute: initialRoute,
    routes: {
      '/login': (_) => DisplayHomePage(),
      '/tools/attendance': (_) => DisplayHomePage(),
      '/tools/quiz': (_) => DisplayQuizPage(),
      '/game': (_) => DisplayGamePage(),
      '/tools': (_) => DisplayStandByPage(),
      '/AI': (_) => AIPage(),
      '/setting': (_) => DisplayStandByPage(),
      '/profile': (_) => DisplayStandByPage(),
      '/tools/timer': (_) =>  DisplayTimerPage(),
      '/tools/voting': (_) =>  DisplayVotePage(),
      '/tools/grouping': (_) =>  GroupDisplayPage(),
      '/tools/random_seat': (_) =>  DisplayRandomSeatPage(),
      '/profile/student': (_) => const DisplayStandByPage(),
      '/profile/class': (_) => const DisplayStandByPage(),
    },
  );
}
}
