import 'package:flutter/material.dart';

import '../../sidebar_menu.dart';
import 'pages/profile_page.dart';
import 'pages/notifications_page.dart';
import 'pages/appearance_page.dart';
import 'pages/class_settings_page.dart';
import 'pages/security_page.dart';
import 'pages/data_page.dart';

class PresenterSettingPage extends StatefulWidget {
  const PresenterSettingPage({super.key});

  @override
  State<PresenterSettingPage> createState() => _PresenterSettingPageState();
}

const _menuSelectedStyle = TextStyle(
  color: Color(0xFF001A36),
  fontSize: 22,
  fontWeight: FontWeight.w600,
  height: 43 / 22,
);

const _menuUnselectedStyle = TextStyle(
  color: Color(0xFFA2A2A2),
  fontSize: 20,
  fontWeight: FontWeight.w500,
  height: 35 / 20,
);

class _PresenterSettingPageState extends State<PresenterSettingPage> {
  int _selectedIndex = 0;

  final List<String> _menuTitles = [
    'Profile',
    'Notifications',
    'Appearance',
    'Class Settings',
    'Security',
    'Data',
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      selectedIndex: 2,
      body: Scaffold(
        backgroundColor: const Color(0xFFF6FAFF),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 좌측 메뉴
            Container(
              width: 220,
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
              child: ListView.builder(
                itemCount: _menuTitles.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedIndex == index;
                  return InkWell(
                    onTap: () => setState(() => _selectedIndex = index),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.chevron_right,
                            size: 24,
                            color:
                                isSelected
                                    ? const Color(0xFF1D1B20)
                                    : Colors.transparent,
                          ),
                          const SizedBox(width: 6),

                          Expanded(
                            child: Text(
                              _menuTitles[index],
                              style:
                                  isSelected
                                      ? _menuSelectedStyle
                                      : _menuUnselectedStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 우측 컨텐츠
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final double cap = 1000;
                    final double minW = 560;
                    final double w = c.maxWidth.clamp(minW, cap);

                    return SingleChildScrollView(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: w,
                          child: _buildPage(_selectedIndex),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const ProfilePage();
      case 1:
        return const NotificationsPage();
      case 2:
        return const AppearancePage();
      case 3:
        return const ClassSettingsPage();
      case 4:
        return const SecurityPage();
      case 5:
        return const DataPage();
      default:
        return const SizedBox();
    }
  }
}
