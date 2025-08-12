// lib/sidebar_menu.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../main.dart';
import 'l10n/app_localizations.dart'; // channel, slideIndex 전역 참조

enum DrawerScrollDirection { leftToRight, rightToLeft }

class SlideMenuDrawer extends StatefulWidget {
  final Widget? header;
  final Widget drawer;
  final Widget body;
  final double? drawerOpenedWidth;
  final double? drawerClosedWidth;
  final Duration? animationDuration;
  final DrawerScrollDirection drawerScrollDirection;

  const SlideMenuDrawer({
    Key? key,
    this.header,
    required this.drawer,
    required this.body,
    this.drawerOpenedWidth,
    this.drawerClosedWidth,
    this.animationDuration,
    this.drawerScrollDirection = DrawerScrollDirection.leftToRight,
  }) : super(key: key);

  @override
  SlideMenuDrawerState createState() => SlideMenuDrawerState();
}

class SlideMenuDrawerState extends State<SlideMenuDrawer> {
  bool _isOpen = false;
  final double _defaultOpenedWidth = 192;
  final double _defaultClosedWidth = 0;
  final int _defaultAnimationTime = 300;

  void toggleDrawer() {
    setState(() => _isOpen = !_isOpen);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final opened = widget.drawerOpenedWidth ?? _defaultOpenedWidth;
    final closed = widget.drawerClosedWidth ?? _defaultClosedWidth;
    final animTime = widget.animationDuration ?? Duration(milliseconds: _defaultAnimationTime);

    double? dLeft, dRight, bLeft, bRight;
    final dWidth = opened;
    final bWidth = _isOpen ? (width - opened) : (width - closed);

    if (widget.drawerScrollDirection == DrawerScrollDirection.leftToRight) {
      dLeft = _isOpen ? 0 : -(opened - closed);
      bLeft = _isOpen ? opened : closed;
    } else {
      dRight = _isOpen ? 0 : -(opened - closed);
      bRight = _isOpen ? opened : closed;
    }

    return Column(
      children: [
        widget.header ?? const SizedBox(),
        Expanded(
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: animTime,
                curve: Curves.easeInOut,
                left: dLeft,
                right: dRight,
                top: 0,
                bottom: 0,
                width: opened,
                child: widget.drawer,
              ),
              AnimatedPositioned(
                duration: animTime,
                curve: Curves.easeInOut,
                left: bLeft,
                right: bRight,
                top: 0,
                bottom: 0,
                width: bWidth,
                child: widget.body,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AppScaffold extends StatelessWidget {
  final GlobalKey<SlideMenuDrawerState> _drawerKey = GlobalKey();
  final Widget body;
  final int selectedIndex;
  final Widget? header;

  AppScaffold({
    Key? key,
    required this.body,
    required this.selectedIndex,
    this.header,
  }) : super(key: key);

  Widget _buildDrawerItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String title,
    required String routeName,
    required int selectedIndex,
  }) {
    final isSelected = index == selectedIndex;
    final highlightColor = const Color.fromARGB(255, 0, 0, 0);

    return InkWell(
      onTap: () {
        // 1) 사이드바 닫기
        _drawerKey.currentState?.toggleDrawer();
        // 2) Presenter→Display 동기화 메시지 전송
        channel.postMessage(jsonEncode({
          'type': 'route',
          'route': routeName,
          'slide': slideIndex.value,
        }));
        // 3) Presenter 네비게이션
        Navigator.pushReplacementNamed(context, routeName);
      },
      child: Container(
        decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(12), // ✅ 둥근 모서리
      ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  title,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: isSelected ? highlightColor : const Color.fromARGB(255, 255, 255, 255),
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              icon,
              size: 36,
              color: isSelected ? highlightColor : const Color.fromARGB(255, 255, 255, 255),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SlideMenuDrawer(
  key: _drawerKey,
  drawerScrollDirection: DrawerScrollDirection.leftToRight,
  drawerOpenedWidth: 192, // ✅ 열렸을 때 너비
  drawerClosedWidth: 60,  // ✅ 닫혔을 때 너비
  header: null,
  drawer: Material(
  color: const Color.fromARGB(255, 189, 189, 189),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ✅ Drawer 상단 메뉴 아이콘
      Container(
  width: double.infinity,
  color: Colors.grey[400], // 상단 배경 강조
  padding: const EdgeInsets.only(right: 8.0, top: 16.0, bottom: 8.0),
  child: Align(
    alignment: Alignment.centerRight, // ✅ 오른쪽 정렬
    child: IconButton(
      icon: const Icon(Icons.menu, size: 30, color: Colors.black),
      onPressed: () => _drawerKey.currentState?.toggleDrawer(),
    ),
  ),
),
      const SizedBox(height: 16),
      // 🔹 기존 메뉴들
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildDrawerItem(context,
              index: 0, icon: Icons.home, title: AppLocalizations.of(context)!.home,
              routeName: '/tools', selectedIndex: selectedIndex),
            _buildDrawerItem(context,
              index: 1, icon: Icons.dashboard, title: AppLocalizations.of(context)!.presenterMain,
              routeName: '/profile', selectedIndex: selectedIndex),
            // _buildDrawerItem(context,
            //   index: 2, icon: Icons.sports_esports, title: AppLocalizations.of(context)!.classContents,
            //   routeName: '/game', selectedIndex: selectedIndex),
            // _buildDrawerItem(context,
            //   index: 3, icon: Icons.timer, title: AppLocalizations.of(context)!.classTools,
            //   routeName: '/tools', selectedIndex: selectedIndex),
            // _buildDrawerItem(context,
            //   index: 4, icon: Icons.voice_chat, title: AppLocalizations.of(context)!.aiChat,
            //   routeName: '/AI', selectedIndex: selectedIndex),
            _buildDrawerItem(context,
              index: 2, icon: Icons.settings, title: AppLocalizations.of(context)!.setting,
              routeName: '/setting', selectedIndex: selectedIndex),
            
          ],
        ),
      ),
    ],
  ),
),
  body: body,
);
  }
}
