// lib/pages/quiz/create_topic_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/hub_provider.dart';

class CreateTopicPage extends StatefulWidget {
  const CreateTopicPage({super.key});

  @override
  State<CreateTopicPage> createState() => _CreateTopicPageState();
}

class _CreateTopicPageState extends State<CreateTopicPage> {
  final _titleCtrl = TextEditingController();
  int _maxQuestions = 5; // 1~20
  bool _saving = false;
  bool _hovering = false;

  int? _nextOrdinal; // Quiz n 표시용

  @override
  void initState() {
    super.initState();
    _loadNextOrdinal();
  }

  Future<void> _loadNextOrdinal() async {
    final hubPath = context.read<HubProvider>().hubDocPath;
    if (hubPath == null) return;
    try {
      final qs =
          await FirebaseFirestore.instance
              .collection('$hubPath/quizTopics')
              .get();
      if (!mounted) return;
      setState(() => _nextOrdinal = (qs.size + 1));
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final hubPath = context.read<HubProvider>().hubDocPath; // hubs/{hubId}
    if (hubPath == null) {
      _snack('허브를 먼저 선택하세요.');
      return;
    }

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _snack('퀴즈(Topic) 이름을 입력해 주세요.');
      return;
    }
    if (_maxQuestions < 1) {
      _snack('문항 수는 1개 이상이어야 합니다.');
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('$hubPath/quizTopics').add({
        'title': title,
        'status': 'draft',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'currentIndex': null,
        'currentQuizId': null,
        'phase': 'finished',
        'questionStartedAt': null,
        'showSummaryOnDisplay': false,
        'totalQuizCount': _maxQuestions,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _snack('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    (m ?? ScaffoldMessenger.of(context))
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    // 화면 폭에 따라 적당한 콘텐츠 폭을 잡아서 중앙 정렬
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF6FAFF),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            FocusScope.of(context).unfocus();
            final nav = Navigator.of(context);
            if (nav.canPop()) {
              nav.pop(false);
            } else {
              Navigator.of(context, rootNavigator: true).maybePop(false);
            }
          },
        ),
        title: const Text('Create a Quiz'),
      ),

      floatingActionButton: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(right: 24, bottom: 24),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: AnimatedScale(
                scale: _hovering ? 1.08 : 1.0, // 🪶 hover 시 살짝 확대
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Opacity(
                  opacity: _saving ? 0.4 : 1.0, // 저장 중이면 흐릿하게
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: Image.asset(
                      'assets/logo_bird_make.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      body: LayoutBuilder(
        builder: (context, c) {
          // 기존 body 코드 그대로 유지
          final w = c.maxWidth;
          double scale = 1.0;
          if (w > 1800)
            scale = 1.4;
          else if (w > 1600)
            scale = 1.3;
          else if (w > 1400)
            scale = 1.2;
          else if (w > 1200)
            scale = 1.1;

          final maxW = (w * 0.92).clamp(360.0, 1600.0);

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  24 * scale,
                  24 * scale,
                  24 * scale,
                  160 * scale,
                ),
                children: [
                  // ─── Quiz n Topic ───
                  Text(
                    'Quiz ${_nextOrdinal ?? ''} Topic',
                    style: TextStyle(
                      fontSize: 24 * scale,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF001A36),
                    ),
                  ),
                  SizedBox(height: 12 * scale),
                  Container(
                    height: 65 * scale,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10 * scale),
                      border: Border.all(
                        color: const Color(0xFFD2D2D2),
                        width: 1,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Please enter your content.',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isCollapsed: true,
                      ),
                      style: TextStyle(
                        fontSize: 24 * scale,
                        height: 34 / 24,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  SizedBox(height: 32 * scale),

                  // ─── Number of Question ───
                  Text(
                    'Number of Question',
                    style: TextStyle(
                      fontSize: 24 * scale,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF001A36),
                    ),
                  ),
                  SizedBox(height: 16 * scale),

                  Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 8 * scale,
                            activeTrackColor: const Color(0xFFB6F536),
                            inactiveTrackColor: const Color(0xFFBDBDBD),
                            thumbColor: Colors.white,
                            thumbShape: RoundSliderThumbShape(
                              enabledThumbRadius: 16 * scale,
                            ),
                          ),
                          child: Slider(
                            min: 1,
                            max: 20,
                            divisions: 19,
                            value: _maxQuestions.toDouble(),
                            onChanged:
                                (v) =>
                                    setState(() => _maxQuestions = v.round()),
                          ),
                        ),
                      ),
                      SizedBox(width: 16 * scale),
                      Container(
                        width: 64 * scale,
                        height: 56 * scale,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12 * scale),
                          border: Border.all(color: const Color(0xFFD2D2D2)),
                        ),
                        child: Text(
                          '$_maxQuestions',
                          style: TextStyle(
                            fontSize: 20 * scale,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF001A36),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/* ───────────── 공용 작은 위젯 ───────────── */

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // 스샷의 "width: 484px" 느낌만 살짝 반영 (너무 좁으면 풀폭)
      constraints: const BoxConstraints(minWidth: 0, maxWidth: 484),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF001A36),
          fontSize: 24,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
      ),
    );
  }
}

class _InputSurface extends StatelessWidget {
  const _InputSurface({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD2D2D2)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: padding ?? const EdgeInsets.all(12),
      child: child,
    );
  }
}
