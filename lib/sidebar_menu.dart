// lib/sidebar_menu.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../main.dart'; // channel, slideIndex 전역 참조

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
  final double _defaultOpenedWidth = 250;
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
                width: dWidth,
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
    final highlightColor = const Color(0xFF397751);

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
        color: isSelected ? highlightColor.withOpacity(0.2) : Colors.transparent,
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
                    color: isSelected ? highlightColor : const Color(0xFF828282),
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              icon,
              size: 36,
              color: isSelected ? highlightColor : const Color(0xFF828282),
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
      drawerOpenedWidth: 250,
      drawerClosedWidth: 50,
      header: header ??
          AppBar(
            title: const Text('My Button'),
            backgroundColor: const Color(0xFF397751),
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _drawerKey.currentState?.toggleDrawer(),
            ),
          ),
      drawer: Material(
        child: Column(
          children: [
            _buildDrawerItem(
              context,
              index: 0,
              icon: Icons.home,
              title: 'Home',
              routeName: '/home',
              selectedIndex: selectedIndex,
            ),
            _buildDrawerItem(
              context,
              index: 1,
              icon: Icons.quiz,
              title: 'Quiz',
              routeName: '/quiz',
              selectedIndex: selectedIndex,
            ),
            _buildDrawerItem(
              context,
              index: 2,
              icon: Icons.sports_esports,
              title: 'Class Contents',
              routeName: '/game',
              selectedIndex: selectedIndex,
            ),
            _buildDrawerItem(
              context,
              index: 3,
              icon: Icons.timer,
              title: 'Class Tools',
              routeName: '/tools',
              selectedIndex: selectedIndex,
            ),
            _buildDrawerItem(
              context,
              index: 4,
              icon: Icons.settings,
              title: 'Setting',
              routeName: '/setting',
              selectedIndex: selectedIndex,
            ),
          ],
        ),
      ),
      body: body,
    );
  }
}
