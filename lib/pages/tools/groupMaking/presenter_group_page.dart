import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'grouping_controller.dart';
import '/widgets/help_badge.dart'; 

import '../../../sidebar_menu.dart';
import '../../../provider/hub_provider.dart';

class PresenterGroupPage extends StatefulWidget {
  const PresenterGroupPage({super.key});

  @override
  State<PresenterGroupPage> createState() => _PresenterGroupPageState();
}

class _PresenterGroupPageState extends State<PresenterGroupPage>
    with SingleTickerProviderStateMixin {
  late final GroupingController c;
  late final TabController _tab;

  final Set<String> _tempAdded = <String>{}; // 현장 추가 학생 리스트
  final TextEditingController _addCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;

  bool _readyToShow = false;

  @override
  void initState() {
    super.initState();
    c = GroupingController(hub: context.read<HubProvider>())..init();
    _tab = TabController(length: 2, vsync: this, initialIndex: 0);
    _tab.addListener(() {
      if (_tab.indexIsChanging) return;
      c.setMode(_tab.index == 0 ? GroupingMode.byGroups : GroupingMode.bySize);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tab.dispose();
    c.disposeAll();
    c.dispose();
    _addCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        final filtered = c.filtered;
        final totalSelected = c.selected.length;
        final groupsPreview = List.generate(9, (i) => i + 2);
        final sizePreview = List.generate(9, (i) => i + 2);

        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            final scale = (w / 1440.0 < h / 720.0) ? (w / 1440.0) : (h / 720.0);

            return AppScaffold(
              selectedIndex: 0,
              body: Scaffold(
                appBar: AppBar(
                  elevation: 0,
                  backgroundColor: const Color(0xFFF6FAFF),
                  leading: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
                backgroundColor: const Color(0xFFF6FAFF),
                body: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 왼쪽 카드
                              Expanded(
                                flex: 5,
                                child: Center(
                                  child: SizedBox(
                                    width: 449 * scale,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Choose List',
                                                style: TextStyle(
                                                  fontSize: 24 * scale,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(0xFF001A36),
                                                ),
                                              ),
                                              SizedBox(width: 6 * scale),
                                              const HelpBadge(
                                                tooltip: 'Select students to participate in the random grouping process. You can also add participants beyond the existing students.',
                                                // assetPath: 'assets/icons/help_gray.png', // 이미지 쓰면 경로 지정
                                                size: 24,
                                                gap: -4.0,
                                                placement: HelpPlacement.right,
                                              ),
                                            ],
                                          ),
                                        SizedBox(height: 8 * scale),
                                        _chooseListCard(
                                          filtered,
                                          scale: scale,
                                          tempAdded: _tempAdded,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // 오른쪽 카드
                              Expanded(
                                flex: 5,
                                child: Center(
                                  child: SizedBox(
                                    width: 449 * scale,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'How to',
                                              style: TextStyle(
                                                fontSize: 24 * scale,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF001A36),
                                              ),
                                            ),
                                            SizedBox(width: 6 * scale),
                                              const HelpBadge(
                                                tooltip: 'Please specify the criteria by which you are grouping.        ',
                                                // assetPath: 'assets/icons/help_gray.png', // 이미지 쓰면 경로 지정
                                                size: 24,
                                                gap: -4.0,
                                                placement: HelpPlacement.right,
                                              ),
                                          ],
                                        ),
                                        SizedBox(height: 8 * scale),
                                        _howToCard(
                                          scale: scale,
                                          totalSelected: totalSelected,
                                          groupsPreview: groupsPreview,
                                          sizePreview: sizePreview,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          ChangeNotifierProvider<GroupingController>.value(
                            value: c,
                            child: Consumer<GroupingController>(
                              builder:
                                  (_, c, __) => Padding(
                                    padding: EdgeInsets.only(top: 16.0),
                                    child: _EditableGroupBoard(controller: c),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 174,
                      bottom: 6,
                      child: _ShowButton(
                        scale: 1.0,
                        enabled: (c.currentGroups != null && c.currentGroups!.isNotEmpty),
                        onTap: () {
                          if (c.currentGroups == null || c.currentGroups!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('먼저 “Make”로 그룹을 생성하세요.')),
                            );
                            return; 
                          }
                          c.broadcastCurrentGroups(title: 'Find your Team !');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('디스플레이로 전송했습니다.')),
                          );
                        },
                        imageAsset: 'assets/logo_bird_show.png', // 없으면 아래 위젯에서 아이콘 fallback
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 6,
                      child: _MakeButton(
                        scale: 1.0,
                        onTap: c.makeGroups,
                        imageAsset: 'assets/logo_bird_make.png',
                      ),
                    ),
                    const Positioned(
                      right: 10,
                      bottom: 130,
                      child: HelpBadge(
                        tooltip:
                            "After selecting all the settings, click to start grouping. Groups that have been created can be modified.",
                        placement: HelpPlacement.left,
                        size: 28,
                      ),
                    ),
                    // Positioned(
                    //   right: 24,
                    //   bottom: 60,
                    //   child: _readyToShow
                    //       // ====== SHOW 단계 ======
                    //       ? _ShowButton(
                    //           scale: 1.0,
                    //           // 그룹이 방금 만들어진 뒤라면 true이지만, 안전하게 체크
                    //           enabled: (c.currentGroups != null && c.currentGroups!.isNotEmpty),
                    //           onTap: () {
                    //             if (c.currentGroups == null || c.currentGroups!.isEmpty) {
                    //               ScaffoldMessenger.of(context).showSnackBar(
                    //                 const SnackBar(content: Text('먼저 “Make”로 그룹을 생성하세요.')),
                    //               );
                    //               return;
                    //             }
                    //             c.broadcastCurrentGroups(title: 'Find your Team !');
                    //             ScaffoldMessenger.of(context).showSnackBar(
                    //               const SnackBar(content: Text('디스플레이로 전송했습니다.')),
                    //             );
                    //             // 🔒 여기서 _readyToShow를 다시 false로 만들지 않음 → Make로 되돌아가지 않음
                    //           },
                    //           imageAsset: 'assets/logo_bird_show.png',
                    //         )
                    //       // ====== MAKE 단계 ======
                    //       : _MakeButton(
                    //           scale: 1.0,
                    //           onTap: () async {
                    //             await c.makeGroups();                // 1) 그룹 생성
                    //             if (!mounted) return;
                    //             setState(() => _readyToShow = true); // 2) 버튼을 Show로 전환(되돌리지 않음)
                    //             // (선택) 안내 토스트
                    //             // ScaffoldMessenger.of(context).showSnackBar(
                    //             //   const SnackBar(content: Text('그룹을 만들었습니다. 이제 Show로 전송할 수 있어요.')),
                    //             // );
                    //           },
                    //           imageAsset: 'assets/logo_bird_make.png',
                    //         ),
                    // ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _chooseListCard(
    List<String> filtered, {
    required double scale,
    required Set<String> tempAdded,
  }) {
    const baseW = 449.0;
    const baseH = 486.0;

    final selectedAll =
        c.selected.length == c.allStudents.length && c.allStudents.isNotEmpty;

    final remain = filtered.where((n) => !tempAdded.contains(n)).toList();

    return Center(
      child: SizedBox(
        width: baseW * scale,
        height: baseH * scale,
        child: Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10 * scale),
            side: const BorderSide(color: Color(0xFFD2D2D2), width: 1),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20 * scale,
              18 * scale,
              20 * scale,
              20 * scale,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'TOTAL ${c.selected.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 19 * scale,
                        color: const Color(0xFF000000),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 260 * scale,
                      child: _SearchField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        scale: scale,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10 * scale),

                Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!selectedAll) {
                          c.selected
                            ..clear()
                            ..addAll(c.allStudents);
                        } else {
                          c.selected.clear();
                        }
                        c.notifyListeners();
                      },
                      child: Row(
                        children: [
                          _RadioDot(selected: selectedAll, size: 18 * scale),
                          SizedBox(width: 10 * scale),
                          Text(
                            'Select All',
                            style: TextStyle(
                              color: const Color(0xFF868C98),
                              fontSize: 14 * scale,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 260 * scale,
                      child: TextField(
                        controller: _addCtrl,
                        onSubmitted: (v) {
                          final name = v.trim();
                          if (name.isEmpty) return;
                          setState(() => tempAdded.add(name));
                          c.addName(name);
                          _addCtrl.clear();
                        },
                        decoration: InputDecoration(
                          hintText: 'Add name',
                          isDense: true,
                          border: const UnderlineInputBorder(),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF46A5FF)),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4 * scale,
                            vertical: 6 * scale,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.add, size: 20 * scale),
                            onPressed: () {
                              final name = _addCtrl.text.trim();
                              if (name.isEmpty) return;
                              setState(() => tempAdded.add(name));
                              c.addName(name);
                              _addCtrl.clear();
                            },
                            tooltip: 'Add',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12 * scale),

                if (tempAdded.isNotEmpty) ...[
                  _TempAddedList(
                    names:
                        filtered.where((n) => tempAdded.contains(n)).toList(),
                    scale: scale,
                    isSelected: (name) => c.selected.contains(name),
                    onToggle: (name) => c.toggleName(name),
                    onRemove: (name) {
                      setState(() => tempAdded.remove(name));
                      // try { c.removeName(name); } catch (_) {}
                    },
                  ),
                  SizedBox(height: 8 * scale),
                ],

                const Divider(height: 16),

                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchCtrl,
                    builder: (_, val, __) {
                      final q = val.text.trim().toLowerCase();
                      // 컨트롤러 전체를 건드리지 않고, 여기서만 필터
                      final remain =
                          c.allStudents
                              .where((n) => !tempAdded.contains(n))
                              .where((n) => n.toLowerCase().contains(q))
                              .toList();

                      return Scrollbar(
                        child: GridView.builder(
                          // shrinkWrap 기본(false) 유지 → 성능 유리
                          itemCount: remain.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio:
                                    (6 / scale).clamp(3.5, 8.0).toDouble(),
                                crossAxisSpacing: 12 * scale,
                                mainAxisSpacing: 2 * scale,
                              ),
                          itemBuilder: (_, i) {
                            final name = remain[i];
                            final selected = c.selected.contains(name);
                            return InkWell(
                              onTap: () => c.toggleName(name),
                              child: Row(
                                children: [
                                  _RadioDot(
                                    selected: selected,
                                    size: 18 * scale,
                                  ),
                                  SizedBox(width: 10 * scale),
                                  Expanded(
                                    child: Text(
                                      name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 18 * scale,
                                      color: Colors.black,
                                    
                                      ),
                                      
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _howToCard({
    required double scale,
    required int totalSelected,
    required List<int> groupsPreview,
    required List<int> sizePreview,
  }) {
    const baseW = 449.0;
    const baseH = 486.0;

    return Center(
      child: SizedBox(
        width: baseW * scale,
        height: baseH * scale,
        child: Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10 * scale),
            side: const BorderSide(color: Color(0xFFD2D2D2), width: 1),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20 * scale,
              18 * scale,
              20 * scale,
              20 * scale,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFD9D9D9), width: 1),
                    ),
                  ),
                  child: TabBar(
                    controller: _tab,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelPadding: EdgeInsets.only(right: 16 * scale),
                    indicator: const UnderlineTabIndicator(
                      borderSide: BorderSide(width: 3, color: Colors.black),
                      insets: EdgeInsets.fromLTRB(0, 0, 0, -1),
                    ),
                    dividerColor: Colors.transparent,
                    labelColor: const Color(0xFF111827),
                    unselectedLabelColor: const Color(0xFF9AA6B2),
                    labelStyle: TextStyle(
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(text: 'Number of groups'),
                      Tab(text: 'Participants per group'),
                    ],
                  ),
                ),
                SizedBox(height: 8 * scale),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _radioList(
                        items: groupsPreview,
                        isGroupsMode: true,
                        totalSelected: totalSelected,
                        value: c.groupsCount,
                        onChange: c.setGroupsCount,
                        scale: scale,
                      ),
                      _radioList(
                        items: sizePreview,
                        isGroupsMode: false,
                        totalSelected: totalSelected,
                        value: c.sizePerGroup,
                        onChange: c.setSizePerGroup,
                        scale: scale,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _radioList({
    required List<int> items,
    required bool isGroupsMode,
    required int totalSelected,
    required int value,
    required ValueChanged<int> onChange,
    required double scale,
  }) {
    final optionTextStyle = TextStyle(
      fontSize: 18 * scale,
      fontWeight: FontWeight.normal,
      color: Colors.black,
    );

    return Scrollbar(
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(height: 4 * scale),
        itemBuilder: (_, i) {
          final n = items[i];
          final label =
              isGroupsMode
                  ? '$n groups - ${(totalSelected == 0 ? 0 : (totalSelected / n).ceil())} participants'
                  : '$n participants - ${(n == 0 ? 0 : (totalSelected / n).ceil())} groups';

          return RadioListTile<int>(
            value: n,
            groupValue: value,
            onChanged: (v) => onChange(v ?? value),
            dense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 4 * scale),
            title: Text(label, style: optionTextStyle),
            activeColor: const Color(0xFF46A5FF),
          );
        },
      ),
    );
  }
}

class _MakeButton extends StatefulWidget {
  const _MakeButton({
    required this.scale,
    required this.onTap,
    required this.imageAsset,
  });

  final double scale;
  final VoidCallback onTap;
  final String imageAsset;

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
    final scaleAnim = _down ? 0.98 : (_hover ? 1.03 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: scaleAnim,
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(widget.imageAsset, fit: BoxFit.contain),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _kBlue = Color(0xFF6ED3FF);
const _kGrey = Color(0xFFA2A2A2);

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected, required this.size});

  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      container: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? _kBlue : Colors.white,
          border: Border.all(color: selected ? _kBlue : _kGrey, width: 2),
        ),
      ),
    );
  }
}

class _EditableGroupBoard extends StatelessWidget {
  const _EditableGroupBoard({required this.controller, this.teamNames});
  final GroupingController controller;
  final List<String>? teamNames;

  @override
  Widget build(BuildContext context) {
    final groups = controller.currentGroups;
    if (groups == null || groups.isEmpty) {
      return const SizedBox.shrink();
    }

    // ★★★ 변경된 부분 시작: 카드 폭을 더 좁게 보기 위한 자동 컬럼 계산 ★★★
    final width = MediaQuery.sizeOf(context).width;
    const minCardW = 260.0; // 카드 최소 폭(더 좁게 하려면 240~260 사이로 조정)
    const gap = 16.0;       // cross/main spacing 과 동일하게
    int cols = (width / (minCardW + gap)).floor().clamp(2, 6);
    // ★★★ 변경된 부분 끝 ★★★

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,          // ★ 변경: 자동 계산된 컬럼 수 사용
        crossAxisSpacing: gap,
        mainAxisSpacing: gap,
        childAspectRatio: 0.9,         // ★ 조금 더 컴팩트하게(기존 1.2 → 1.1)
      ),
      itemCount: groups.length,
      itemBuilder: (_, i) {
        final name =
            (teamNames != null && i < teamNames!.length)
                ? teamNames![i]
                : 'Team ${i + 1}';
        return _GroupCardEditable(
          groupIndex: i,
          title: name,
          members: groups[i],
          onDrop: (student) {
            controller.moveMemberToGroup(student, i);
          },
        );
      },
    );
  }
}

class _GroupCardEditable extends StatefulWidget {
  const _GroupCardEditable({
    required this.groupIndex,
    required this.title,
    required this.members,
    required this.onDrop,
  });

  final int groupIndex;
  final String title;
  final List<String> members;
  final ValueChanged<String> onDrop;

  @override
  State<_GroupCardEditable> createState() => _GroupCardEditableState();
}

class _GroupCardEditableState extends State<_GroupCardEditable> {
  bool _hovering = false;
  static const double _kFeedbackScale = 0.88;

  Widget _buildDraggableChip(BuildContext context, String name) {
    final isDesktopLike =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;

    final normal = _MemberChip(name: name);

    final dragging = Transform.scale(
      scale: _kFeedbackScale,
      child: Material(
        color: Colors.transparent,
        child: _MemberChip(name: name, dragging: true),
      ),
    );

    final childWhenDragging = Opacity(
      opacity: 0.4,
      child: _MemberChip(name: name),
    );

    if (isDesktopLike) {
      return Draggable<String>(
        data: name,
        feedback: dragging,
        childWhenDragging: childWhenDragging,
        child: normal,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedbackOffset: const Offset(0, -8),
      );
    } else {
      return LongPressDraggable<String>(
        data: name,
        feedback: dragging,
        childWhenDragging: childWhenDragging,
        child: normal,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedbackOffset: const Offset(0, -8),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAccept: (_) {
        setState(() => _hovering = true);
        return true;
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAccept: (data) {
        setState(() => _hovering = false);
        widget.onDrop(data);
      },
      builder: (context, candidate, rejected) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovering ? const Color(0xFFF0F9FF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  _hovering ? const Color(0xFF38BDF8) : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.members.length}명',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,      // 2열 유지
                    mainAxisExtent: 34,     // ★ 각 칩 셀 높이 고정(더 작게: 30~36 사이 실험)
                    mainAxisSpacing: 4,     // ★ 행 간격 (세로 간격)
                    crossAxisSpacing: 6,    // ★ 열 간격 (가로 간격)
                  ),
                  itemCount: widget.members.length,
                  itemBuilder: (_, i) => Align(
                    alignment: Alignment.centerLeft,
                    child: _buildDraggableChip(context, widget.members[i]),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              const Text(
                'Drag onto another team card to move',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.name, this.dragging = false});
  final String name;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: dragging ? const Color(0xFFDBEAFE) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: dragging ? const Color(0xFF1D4ED8) : const Color(0xFF0B1324),
        ),
      ),
    );
  }
}

class _TempAddedList extends StatelessWidget {
  const _TempAddedList({
    required this.names,
    required this.scale,
    required this.isSelected,
    required this.onToggle,
    required this.onRemove,
  });

  final List<String> names;
  final double scale;
  final bool Function(String name) isSelected;
  final void Function(String name) onToggle;
  final void Function(String name) onRemove;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: names.length,
      separatorBuilder: (_, __) => SizedBox(height: 6 * scale),
      itemBuilder: (_, i) {
        final name = names[i];
        final selected = isSelected(name);
        return InkWell(
          onTap: () => onToggle(name),
          child: Row(
            children: [
              _RadioDot(selected: selected, size: 18 * scale),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF001A36),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8 * scale),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onRemove(name),
                child: Padding(
                  padding: EdgeInsets.all(1 * scale),
                  child: Icon(
                    Icons.close,
                    size: 15 * scale,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.scale,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final double scale;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final has = widget.controller.text.isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      decoration: InputDecoration(
        hintText: 'Search name',
        isDense: true,
        prefixIcon: Icon(Icons.search, size: 18 * scale),
        suffixIcon:
            _hasText
                ? IconButton(
                  icon: Icon(Icons.close, size: 18 * scale),
                  tooltip: 'Clear',
                  onPressed: () {
                    widget.controller.clear();
                    if (!widget.focusNode.hasFocus) {
                      widget.focusNode.requestFocus();
                    }
                  },
                )
                : null,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12 * scale,
          vertical: 10 * scale,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22 * scale),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22 * scale),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22 * scale),
          borderSide: const BorderSide(color: Color(0xFF46A5FF)),
        ),
        fillColor: const Color(0xFFF9FAFB),
        filled: true,
      ),
      textInputAction: TextInputAction.search,
    );
  }
}

class _ShowButton extends StatefulWidget {
  const _ShowButton({
    required this.scale,
    required this.onTap,
    required this.imageAsset,
    this.enabled = true,
  });

  final double scale;
  final VoidCallback onTap;
  final String imageAsset;
  final bool enabled;

  @override
  State<_ShowButton> createState() => _ShowButtonState();
}

class _ShowButtonState extends State<_ShowButton> {
  bool _hover = false;
  bool _down = false;

  static const _baseW = 195.0;
  static const _baseH = 172.0;

  @override
  Widget build(BuildContext context) {
    final w = _baseW * widget.scale;
    final h = _baseH * widget.scale;
    final scaleAnim = _down ? 0.98 : (_hover ? 1.03 : 1.0);

    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.5,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: (_) { if (widget.enabled) setState(() => _down = true); },
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: scaleAnim,
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    widget.imageAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.visibility, size: 64, color: Colors.indigo),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
