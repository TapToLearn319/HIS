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
// import 'pages/game/presenter_game_page.dart';
// import 'pages/game/display_game_page.dart';
import 'pages/tools/presenter_tools_page.dart';
import 'pages/tools/display_tools_page.dart';
import 'pages/setting/presenter_setting_page.dart';
import 'pages/setting/display_setting_page.dart';
import 'pages/ai_chat/display_ai_chat.dart';
import 'pages/tools/timer/presenter_timer.dart';
import 'pages/display_standby.dart';

import 'pages/tools/vote/vote_manager.dart';
import 'pages/tools/presenter_button_test_page.dart';
import 'pages/tools/display_button_test_page.dart';

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
import 'provider/hub_provider.dart';

// ——— ADD: theme factory ———
ThemeData buildAppTheme({required Brightness brightness}) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B82F6), // 브랜드 기본색(원하면 변경 가능)
      brightness: brightness,
    ),
  );

  final cs = base.colorScheme;

  return base.copyWith(
    // Kanit 전역 폰트
    textTheme: GoogleFonts.kanitTextTheme(base.textTheme),

    // 라이트에만 기존 앱 배경색 유지, 다크는 시스템 기본 사용
    scaffoldBackgroundColor:
        brightness == Brightness.light ? const Color(0xFFF6FAFF) : null,

    // 카드/보더/인풋 등 공통 컴포넌트 색을 스킴 기반으로 통일
    cardTheme: CardThemeData(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cs.outlineVariant, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: cs.primary, width: 1.2),
      ),
      labelStyle: TextStyle(color: cs.onSurface),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.disabled) ? cs.surfaceVariant : cs.surface,
        ),
        foregroundColor: WidgetStatePropertyAll(cs.onSurface),
        side: WidgetStatePropertyAll(BorderSide(color: cs.outlineVariant)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected)
                ? cs
                    .onSurface // “검은색 느낌” 트랙
                : cs.outlineVariant,
      ),
      thumbColor: WidgetStatePropertyAll(cs.surface), // 라이트/다크 자동
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStatePropertyAll(cs.onSurface),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
    ),
    dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1),
    listTileTheme: ListTileThemeData(
      iconColor: cs.onSurfaceVariant,
      textColor: cs.onSurface,
    ),
  );
}

final bool isDisplay = Uri.base.queryParameters['view'] == 'display';
final String initialRoute = Uri.base.queryParameters['route'] ?? '/login';
final html.BroadcastChannel channel = html.BroadcastChannel('presentation');
final ValueNotifier<int> slideIndex = ValueNotifier<int>(0);

// // final ValueNotifier<Locale?> _localeNotifier = ValueNotifier(
// //   const Locale('en'),
// // );
//
// void setLocale(Locale locale) {
//   _localeNotifier.value = locale;
// }

class PresenterRouteObserver extends RouteObserver<ModalRoute<void>> {
  void _broadcast(String? route) {
    channel.postMessage(
      jsonEncode({'type': 'route', 'route': route, 'slide': slideIndex.value}),
    );
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

  // ▼ 허브 선택값 주입: URL > localStorage > 기본값
  final String? hubFromUrl = Uri.base.queryParameters['hub'];
  final String? hubFromStorage = html.window.localStorage['hubId'];
  final String hubId = hubFromUrl ?? hubFromStorage ?? 'hub-001';
  print('🔧 hubId resolved: $hubId (url=$hubFromUrl, storage=$hubFromStorage)');

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
              StudentsProvider(FirebaseFirestore.instance)..listenHub(hubId),
        ),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        // ★ HubProvider 초기값을 세팅 + 이후 변경은 브로드캐스트로 전파
        ChangeNotifierProvider(create: (_) => HubProvider()..setHub(hubId)),
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

      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: settings.themeMode,

      // ▼ l10n 적용
      locale: settings.locale, // <- Provider에서 읽음
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ko')],

      initialRoute: initialRoute,
      navigatorObservers: [_observer],
      // ★ 허브 변경 시 디스플레이로 브로드캐스트
      builder: (context, child) => HubChannelEmitter(child: child),
      routes: {
        '/login': (_) => LoginPage(),
        '/home': (_) => PresenterHomePage(),
        '/tools/quiz': (_) => PresenterQuizPage(),
        // '/game': (_) => PresenterGamePage(),
        '/tools': (_) => PresenterToolsPage(),
        '/AI': (_) => PresenterAIChatPage(),
        '/setting': (_) => PresenterSettingPage(),
        '/profile': (_) => PresenterMainPage(),
        '/profile/student': (_) => const PresenterStudentPage(),
        '/profile/class': (_) => const PresenterClassPage(),
        '/tools/timer': (_) => TimerPage(),
        '/tools/grouping': (_) => PresenterGroupPage(),
        '/tools/voting': (_) => PresenterVotePage(),
        '/tools/attendance': (_) => PresenterHomePage(),
        '/tools/random_seat': (_) => RandomSeatPage(),
        '/tools/button_test': (_) => ButtonTestPage(),
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
      // ★ 허브 동기화 수신 → Display의 HubProvider 갱신
      else if (data['type'] == 'hub') {
        final hubId = data['hubId'] as String?;
        if (hubId != null && hubId.isNotEmpty) {
          // 컨텍스트가 안전할 때 한 프레임 뒤에 적용
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.read<HubProvider>().setHub(hubId);
              // 디버그 로그
              // print('📡 [Display] Hub set from broadcast: $hubId');
            }
          });
        }
      }
    });

    // (선택) Display가 먼저 열렸을 때 초기값을 못 받는 경우가 있다면
    // 아래처럼 Presenter에 허브 브로드캐스트를 요청하는 메시지를 보낼 수도 있음:
    // channel.postMessage(jsonEncode({'type':'hub:request'}));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>(); // <- 추가

    return MaterialApp(
      title: 'Display',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,

      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: settings.themeMode,

      // ▼ l10n
      locale: settings.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ko')],

      initialRoute: initialRoute,
      // ★ Display 쪽도 현재 허브를 한 번 브로드캐스트(디버그/동기화용, 필요시 유지)
      builder: (context, child) => HubChannelEmitter(child: child),
      routes: {
        '/login': (_) => DisplayHomePage(),
        '/tools/attendance': (_) => DisplayHomePage(),
        '/tools/quiz': (_) => DisplayQuizPage(),
        // '/game': (_) => DisplayGamePage(),
        '/tools': (_) => DisplayStandByPage(),
        '/AI': (_) => AIPage(),
        '/setting': (_) => DisplayStandByPage(),
        '/profile': (_) => DisplayStandByPage(),
        '/tools/timer': (_) => DisplayTimerPage(),
        '/tools/voting': (_) => DisplayVotePage(),
        '/tools/grouping': (_) => GroupDisplayPage(),
        '/tools/random_seat': (_) => DisplayRandomSeatPage(),
        '/tools/button_test': (_) => ButtonTestDisplayPage(),
        '/profile/student': (_) => const DisplayStandByPage(),
        '/profile/class': (_) => const DisplayStandByPage(),
      },
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// HubChannelEmitter
/// - HubProvider의 hubId가 바뀔 때마다 BroadcastChannel로 내보냄
/// - Presenter/Display 양쪽 MaterialApp.builder에 삽입됨
/// ─────────────────────────────────────────────────────────
class HubChannelEmitter extends StatefulWidget {
  const HubChannelEmitter({required this.child});
  final Widget? child;

  @override
  State<HubChannelEmitter> createState() => _HubChannelEmitterState();
}

class _HubChannelEmitterState extends State<HubChannelEmitter> {
  String? _lastSent;

  void _postIfChanged(String? hubId) {
    if (hubId == null || hubId.isEmpty) return;
    if (_lastSent == hubId) return;
    _lastSent = hubId;
    channel.postMessage(jsonEncode({'type': 'hub', 'hubId': hubId}));
    // 디버그 로그:
    // print('📡 [Broadcast] hub=$hubId');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final hubId = context.read<HubProvider>().hubId;
    // 첫 빌드 이후 한 프레임에 초기 허브 브로드캐스트
    WidgetsBinding.instance.addPostFrameCallback((_) => _postIfChanged(hubId));
  }

  @override
  Widget build(BuildContext context) {
    // watch로 허브 변경을 구독 → 바뀔 때마다 프레임 뒤에 브로드캐스트
    final hubId = context.watch<HubProvider>().hubId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _postIfChanged(hubId));
    return widget.child ?? const SizedBox.shrink();
  }
}
