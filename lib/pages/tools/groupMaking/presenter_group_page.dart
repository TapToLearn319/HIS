

import 'package:flutter/material.dart';
import 'grouping_controller.dart';

class PresenterGroupPage extends StatefulWidget {
  const PresenterGroupPage({super.key});

  @override
  State<PresenterGroupPage> createState() => _PresenterGroupPageState();
}

class _PresenterGroupPageState extends State<PresenterGroupPage>
    with SingleTickerProviderStateMixin {
  late final GroupingController c;
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    c = GroupingController()..init();
    _tab = TabController(length: 2, vsync: this, initialIndex: 0);
    _tab.addListener(() {
      if (_tab.indexIsChanging) return;
      c.setMode(_tab.index == 0 ? GroupingMode.byGroups : GroupingMode.bySize);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    c.disposeAll();
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 간단히 setState로만 그려도 되지만, 필요하면 AnimatedBuilder/ValueListenableBuilder로 감싸도 됨
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        final filtered = c.filtered;
        final totalSelected = c.selected.length;
        final groupsPreview = List.generate(9, (i) => i + 2);
        final sizePreview = List.generate(9, (i) => i + 2);

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 6),
                                child: Text(
                                  'Choose List',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.normal,
                                    color: Color(0xFF001A36),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _chooseListCard(filtered),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // 오른쪽 카드
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 6),
                                child: Text(
                                  'How to',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.normal,
                                    color: Color(0xFF001A36),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _howToCard(
                                totalSelected: totalSelected,
                                groupsPreview: groupsPreview,
                                sizePreview: sizePreview,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // MAKE 버튼
              Positioned(
                right: 24,
                bottom: 60,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: c.makeGroups,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset('assets/logo_bird.png', height: 160),
                        const Positioned(
                          left: 50,
                          bottom: 50,
                          child: Text(
                            'MAKE',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ----- 왼쪽 카드 UI -----
  Widget _chooseListCard(List<String> filtered) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFD2D2D2)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: SizedBox(
          height: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  Text(
                    'TOTAL ${c.selected.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 19,
                      color: Color(0xFF000000),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      onChanged: c.setQuery,
                      decoration: InputDecoration(
                        hintText: 'Search name',
                        isDense: true,
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: Color(0xFF46A5FF)),
                        ),
                        fillColor: const Color(0xFFF9FAFB),
                        filled: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: c.selected.length == c.allStudents.length &&
                            c.allStudents.isNotEmpty,
                        onChanged: (v) {
                          if (v == true) {
                            c.selected
                              ..clear()
                              ..addAll(c.allStudents);
                          } else {
                            c.selected.clear();
                          }
                          c.notifyListeners();
                        },
                      ),
                      const Text(
                        'Select All',
                        style: TextStyle(color: Color(0xFF868C98)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      onSubmitted: c.addName,
                      decoration: const InputDecoration(
                        hintText: 'Add name',
                        isDense: true,
                        border: UnderlineInputBorder(),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF46A5FF)),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        suffixIcon: Icon(Icons.add),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 16),

              // list
              Expanded(
                child: Scrollbar(
                  child: GridView.builder(
                    itemCount: filtered.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 6,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 2,
                    ),
                    itemBuilder: (_, i) {
                      final name = filtered[i];
                      final selected = c.selected.contains(name);
                      return InkWell(
                        onTap: () => c.toggleName(name),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: selected
                                  ? const Color(0xFF46A5FF)
                                  : const Color(0xFF9AA6B2),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                            if (selected)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: CircleAvatar(
                                  radius: 5,
                                  backgroundColor: Color(0xFF46A5FF),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----- 오른쪽 카드 UI -----
  Widget _howToCard({
    required int totalSelected,
    required List<int> groupsPreview,
    required List<int> sizePreview,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFD2D2D2)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: SizedBox(
          height: 520,
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
                  labelPadding: const EdgeInsets.only(right: 16),
                  indicator: const UnderlineTabIndicator(
                    borderSide: BorderSide(width: 3, color: Colors.black),
                    insets: EdgeInsets.fromLTRB(0, 0, 0, -1),
                  ),
                  dividerColor: Colors.transparent,
                  labelColor: const Color(0xFF111827),
                  unselectedLabelColor: const Color(0xFF9AA6B2),
                  labelStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Number of groups'),
                    Tab(text: 'Participants per group'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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
                    ),
                    _radioList(
                      items: sizePreview,
                      isGroupsMode: false,
                      totalSelected: totalSelected,
                      value: c.sizePerGroup,
                      onChange: c.setSizePerGroup,
                    ),
                  ],
                ),
              ),
            ],
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
  }) {
    const TextStyle optionTextStyle =
        TextStyle(fontSize: 18, fontWeight: FontWeight.normal, color: Colors.black);

    return Scrollbar(
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, i) {
          final n = items[i];
          final label = isGroupsMode
              ? '$n groups - ${(totalSelected == 0 ? 0 : (totalSelected / n).ceil())} participants'
              : '$n participants - ${(n == 0 ? 0 : (totalSelected / n).ceil())} groups';

          return RadioListTile<int>(
            value: n,
            groupValue: value,
            onChanged: (v) => onChange(v ?? value),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(label, style: optionTextStyle),
            activeColor: const Color(0xFF46A5FF),
          );
        },
      ),
    );
  }
}