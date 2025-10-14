// tools/draw/presenter_random_draw.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../../../sidebar_menu.dart';
import '../../../provider/hub_provider.dart';

enum DrawType { lots, ordering }

class PresenterRandomDrawPage extends StatefulWidget {
  const PresenterRandomDrawPage({super.key});

  @override
  State<PresenterRandomDrawPage> createState() =>
      _PresenterRandomDrawPageState();
}

class _PresenterRandomDrawPageState extends State<PresenterRandomDrawPage> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _numToPickCtrl = TextEditingController(text: '');
  final TextEditingController _numToOrderCtrl = TextEditingController(text: '');

  DrawType _type = DrawType.lots;

  /// 선택된 학생 (Dialog에서 관리/반영)
  final Set<String> _selected = <String>{};

  /// Dialog에서 임시 추가한 로컬 이름(파이어스토어에 쓰진 않음)
  final Set<String> _tempAdded = <String>{};

  final _formKey = GlobalKey<FormState>();

  // 자동검증 모드 (유효성 실패 후 항상 표시)
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;

  @override
void initState() {
  super.initState();
  _resetDisplayOnEnter();
}

Future<void> _resetDisplayOnEnter() async {
  final hubId = context.read<HubProvider>().hubId;
  if (hubId == null) return;

  final fs = FirebaseFirestore.instance;
  final doc = fs.doc('hubs/$hubId/draws/display');

  await doc.set({
    'show': false,
    'names': [],
    'title': '',
    'mode': 'lots',
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

  @override
  void dispose() {
    _titleCtrl.dispose();
    _numToPickCtrl.dispose();
    _numToOrderCtrl.dispose();
    super.dispose();
  }

  // ===== Firestore BroadCast =====
  Future<void> _broadcastToDisplay({
    required String hubId,
    required DrawType type,
    required String title,
    required List<String> pool, // 대상 풀 (선택 or 전체)
    required int count, // 뽑을/정렬할 인원
  }) async {
    final fs = FirebaseFirestore.instance;

    // 풀에서 count만큼 섞어서 추출
    final shuffled = [...pool]..shuffle(Random());
    final take = count.clamp(1, shuffled.length);
    final picked = shuffled.take(take).toList();

    // 쓰는 문서 경로(둘 다 동일하게 맞춰서 사용)
    final doc = fs.doc('hubs/$hubId/draws/display');

    if (type == DrawType.lots) {
      await doc.set({
        'mode': 'lots',
        'title': title,
        'names': picked, // ["홍길동","김철수",...]
        'show': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      // ordering → 랜덤 순서의 리스트를 넘겨주고, 디스플레이에서 번호만 붙임
      await doc.set({
        'mode': 'ordering',
        'title': title,
        'names': picked,
        'show': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // ===== Choose List Dialog =====
  Future<void> _openChooseListDialog({
    required List<String> allFromFirebase,
  }) async {
    final searchCtrl = TextEditingController();
    final addCtrl = TextEditingController();
    final searchFocus = FocusNode();

    // 기본: 전부 선택
    final allMerged = <String>{...allFromFirebase, ..._tempAdded}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    Set<String> localSelected =
        _selected.isEmpty ? {...allMerged} : {..._selected};
    Set<String> localTempAdded = {..._tempAdded};

    List<String> computeList() {
      final full = <String>{...allFromFirebase, ...localTempAdded}.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return full;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final q = searchCtrl.text.trim().toLowerCase();
            final full = computeList();
            final filtered = full
                .where((n) => n.toLowerCase().contains(q))
                .toList(growable: false);

            final allChecked =
                localSelected.length == full.length && full.isNotEmpty;

            void addName() {
              final name = addCtrl.text.trim();
              if (name.isEmpty) return;
              setLocal(() {
                localTempAdded.add(name);
                localSelected.add(name);
              });
              addCtrl.clear();
            }

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860, maxHeight: 640),
                child: SafeArea(
                  top: true,
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 헤더
                        Row(
                          children: [
                            const Text(
                              'Choose List',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.black),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: 'Close',
                              icon: const Icon(Icons.close, color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // TOTAL / Search
                        Row(
                          children: [
                            Text(
                              'TOTAL ${localSelected.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: Colors.black,
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 260,
                              child: TextField(
                                controller: searchCtrl,
                                focusNode: searchFocus,
                                decoration: const InputDecoration(
                                  hintText: 'Search name',
                                  isDense: true,
                                  prefixIcon:
                                      Icon(Icons.search, color: Colors.black54),
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: const TextStyle(color: Colors.black),
                                onChanged: (_) => setLocal(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Select All / Add
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setLocal(() {
                                  if (!allChecked) {
                                    localSelected
                                      ..clear()
                                      ..addAll(full);
                                  } else {
                                    localSelected.clear();
                                  }
                                });
                              },
                              icon: Icon(
                                allChecked
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: Colors.black87,
                                size: 18,
                              ),
                              label: const Text(
                                'Select All',
                                style: TextStyle(color: Colors.black, fontSize: 14),
                              ),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.black),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 260,
                              child: TextField(
                                controller: addCtrl,
                                onSubmitted: (_) => addName(),
                                decoration: InputDecoration(
                                  hintText: 'Add name',
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.add),
                                    color: Colors.black87,
                                    onPressed: addName,
                                    tooltip: 'Add',
                                  ),
                                ),
                                style: const TextStyle(color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 16),

                        // 목록
                        Expanded(
                          child: Scrollbar(
                            child: GridView.builder(
                              itemCount: filtered.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisExtent: 38,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 4,
                              ),
                              itemBuilder: (_, i) {
                                final name = filtered[i];
                                final selected = localSelected.contains(name);
                                return InkWell(
                                  onTap: () => setLocal(() {
                                    if (selected) {
                                      localSelected.remove(name);
                                    } else {
                                      localSelected.add(name);
                                    }
                                  }),
                                  child: Row(
                                    children: [
                                      // 라디오 점
                                      Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: selected
                                              ? const Color(0xFF6ED3FF)
                                              : Colors.white,
                                          border: Border.all(
                                            color: selected
                                                ? const Color(0xFF6ED3FF)
                                                : const Color(0xFFA2A2A2),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      if (localTempAdded.contains(name))
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.close,
                                              size: 16, color: Colors.black87),
                                          tooltip: 'Remove temp',
                                          onPressed: () => setLocal(() {
                                            localTempAdded.remove(name);
                                            localSelected.remove(name);
                                          }),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),
                        // 하단 버튼
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selected
                                    ..clear()
                                    ..addAll(localSelected);
                                  _tempAdded
                                    ..clear()
                                    ..addAll(localTempAdded);
                                });
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Apply'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    searchCtrl.dispose();
    addCtrl.dispose();
    searchFocus.dispose();
  }

  // ===== Helpers =====
  String get _typeLabel =>
      _type == DrawType.lots ? 'Drawing lots' : 'Ordering';

  @override
  Widget build(BuildContext context) {
    final hubId = context.watch<HubProvider>().hubId;

    return AppScaffold(
      selectedIndex: 0,
      body: Scaffold(
        backgroundColor: const Color(0xFFF6FAFF),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFF6FAFF),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text(
            'Random Draw',
            style: TextStyle(color: Colors.black),
          ),
          centerTitle: false,
        ),
        body: Padding(
          // ⬇️ 상단 패딩 제거
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SafeArea(
            top: true,
            bottom: false,
            child: Padding(
              // ⬇️ SafeArea 내부도 상단 패딩 제거
              padding: EdgeInsets.zero,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  final scale =
                      (w / 1280.0 < h / 720.0) ? (w / 1280.0) : (h / 720.0);

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: (hubId == null)
                        ? const Stream.empty()
                        : FirebaseFirestore.instance
                            .collection('hubs/$hubId/students')
                            .snapshots(),
                    builder: (context, snap) {
                      final allFromFirebase = <String>[];
                      if (snap.data != null) {
                        for (final d in snap.data!.docs) {
                          final name = (d.data()['name'] as String?)?.trim();
                          if (name != null && name.isNotEmpty) {
                            allFromFirebase.add(name);
                          }
                        }
                      }
                      allFromFirebase.sort(
                        (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                      );

                      // Dialog에서 임시 추가한 이름까지 합친 전체 후보
                      final full = <String>{...allFromFirebase, ..._tempAdded}
                          .toList()
                        ..sort((a, b) =>
                            a.toLowerCase().compareTo(b.toLowerCase()));

                      final totalCount =
                          _selected.isEmpty ? full.length : _selected.length;

                      // 제목 입력 폭 약간 줄임 (420 권장)
                      final titleWidth =
                          (420 * scale).clamp(360, 520).toDouble();

                      // ⬇️ 가운데 정렬된 영역 내부에서 Stack으로 본문+버튼 배치
                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 980),
                          child: Stack(
                            children: [
                              // 본문 스크롤
                              Form(
                                key: _formKey,
                                autovalidateMode: _autoValidate,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.only(
                                      bottom:
                                          120), // 버튼과 겹치지 않게 충분한 하단 여백
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Title
                                      const Text(
                                        'Title',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: titleWidth,
                                        child: TextFormField(
                                          controller: _titleCtrl,
                                          style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 20),
                                          decoration: const InputDecoration(
                                            hintText: 'Enter title',
                                            hintStyle: TextStyle(
                                                color: Colors.black54),
                                            border: OutlineInputBorder(),
                                            filled: true,
                                            fillColor: Colors.white,
                                            errorBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: Colors.red,
                                                  width: 1.5),
                                            ),
                                            focusedErrorBorder:
                                                OutlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: Colors.red,
                                                  width: 1.5),
                                            ),
                                          ),
                                          validator: (v) {
                                            if ((v ?? '').trim().isEmpty) {
                                              return 'Please enter a title.';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 20),

                                      // Type
                                      const Text(
                                        'Type',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          RadioListTile<DrawType>(
                                            value: DrawType.lots,
                                            groupValue: _type,
                                            onChanged: (v) =>
                                                setState(() => _type = v!),
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            title: const Text(
                                              'Drawing lots',
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 18),
                                            ),
                                            activeColor: Colors.black,
                                          ),
                                          RadioListTile<DrawType>(
                                            value: DrawType.ordering,
                                            groupValue: _type,
                                            onChanged: (v) =>
                                                setState(() => _type = v!),
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            title: const Text(
                                              'Ordering',
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 18),
                                            ),
                                            activeColor: Colors.black,
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 16),

                                      // Number of students …
                                      Text(
                                        _type == DrawType.lots
                                            ? 'Number of students to be selected'
                                            : 'Number of students to order',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: 200,
                                        child: TextFormField(
                                          controller: _type == DrawType.lots
                                              ? _numToPickCtrl
                                              : _numToOrderCtrl,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly
                                          ],
                                          style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 20),
                                          decoration: const InputDecoration(
                                            hintText: 'ex) 3',
                                            hintStyle: TextStyle(
                                                color: Colors.black54),
                                            border: OutlineInputBorder(),
                                            filled: true,
                                            fillColor: Colors.white,
                                            errorBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: Colors.red,
                                                  width: 1.5),
                                            ),
                                            focusedErrorBorder:
                                                OutlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: Colors.red,
                                                  width: 1.5),
                                            ),
                                          ),
                                          validator: (v) {
                                            final raw = (v ?? '').trim();
                                            if (raw.isEmpty) {
                                              return 'Please enter a number.';
                                            }
                                            final n = int.tryParse(raw);
                                            if (n == null) {
                                              return 'Numbers only.';
                                            }
                                            if (n < 1) {
                                              return 'Must be at least 1.';
                                            }
                                            if (n > totalCount) {
                                              return 'Cannot exceed $totalCount.';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),

                                      const SizedBox(height: 20),

                                      // Total Number of students + 숫자 버튼(톱니)
                                      const Text(
                                        'Total Number of students',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      InkWell(
                                        onTap: () =>
                                            _openChooseListDialog(
                                                allFromFirebase:
                                                    allFromFirebase),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: const Color(0xFFD2D2D2),
                                              width: 1,
                                            ),
                                          ),
                                          child: SizedBox(
                                            width: 180 ,
                                            child: Row(
                                              
                                              children: [
                                                Text(
                                                  '$totalCount',
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                const Spacer(),
                                                const Icon(Icons.mode,
                                                    color: Colors.black87),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 40),
                                    ],
                                  ),
                                ),
                              ),

                              // ⬇️ "가운데 영역"의 우하단에 위치하는 Show 버튼
                              Positioned(
                                right: 16,
                                bottom: 16,
                                child: _MakeButton(
                                  scale: 160 / 195, // 기존 크기(160)에 맞게 스케일 조정
                                  imageAsset: 'assets/logo_bird_show.png',
                                  onTap: () async {
                                    final hubId = context.read<HubProvider>().hubId;
                                    if (hubId == null) return;

                                    // 폼 검증
                                    if (!_formKey.currentState!.validate()) {
                                      setState(() => _autoValidate = AutovalidateMode.always);
                                      return;
                                    }

                                    // 전체 풀 결정
                                    final snap = await FirebaseFirestore.instance
                                        .collection('hubs/$hubId/students')
                                        .get();

                                    final allFromFirebase = <String>[];
                                    for (final d in snap.docs) {
                                      final name = (d.data()['name'] as String?)?.trim();
                                      if (name != null && name.isNotEmpty) allFromFirebase.add(name);
                                    }
                                    allFromFirebase.sort(
                                        (a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

                                    final full = <String>{...allFromFirebase, ..._tempAdded}.toList()
                                      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

                                    final list = _selected.isNotEmpty ? _selected.toList() : full;
                                    final raw = _type == DrawType.lots
                                        ? _numToPickCtrl.text
                                        : _numToOrderCtrl.text;
                                    final count = int.parse(raw.trim());

                                    await _broadcastToDisplay(
                                      hubId: hubId,
                                      type: _type,
                                      title: _titleCtrl.text.trim(),
                                      pool: list,
                                      count: count,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────
// 공통 Bird Button (Hover/Click Scale 애니메이션)
// ─────────────────────────────────────────────
class _MakeButton extends StatefulWidget {
  const _MakeButton({
    required this.scale,
    required this.imageAsset,
    required this.onTap,
    this.enabled = true,
  });

  final double scale;
  final String imageAsset;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_MakeButton> createState() => _MakeButtonState();
}

class _MakeButtonState extends State<_MakeButton> {
  bool _hover = false;
  bool _down = false;

  static const _baseW = 195.0;
  static const _baseH = 172.0;

  @override
  Widget build(BuildContext context) {
    final w = _baseW * widget.scale;
    final h = _baseH * widget.scale;
    final scaleAnim = _down
        ? 0.96
        : (_hover ? 1.05 : 1.0);

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        if (widget.enabled) setState(() => _hover = true);
      },
      onExit: (_) {
        if (widget.enabled) setState(() => _hover = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.enabled) setState(() => _down = true);
        },
        onTapUp: (_) {
          if (widget.enabled) setState(() => _down = false);
        },
        onTapCancel: () {
          if (widget.enabled) setState(() => _down = false);
        },
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: scaleAnim,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Opacity(
            opacity: widget.enabled ? 1.0 : 0.5,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Image.asset(
                widget.imageAsset,
                key: ValueKey<String>(widget.imageAsset),
                width: w,
                height: h,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

