

// lib/pages/setting/presenter_setting_page.dart
import 'package:flutter/material.dart';
import '../../sidebar_menu.dart';

class PresenterSettingPage extends StatefulWidget {
  const PresenterSettingPage({super.key});

  @override
  State<PresenterSettingPage> createState() => _PresenterSettingPageState();
}

const _menuSelectedStyle = TextStyle(
  color: Color(0xFF001A36),
  fontFamily: 'Poppins',
  fontSize: 22,
  fontWeight: FontWeight.w600,
  height: 43 / 22,
);

const _menuUnselectedStyle = TextStyle(
  color: Color(0xFFA2A2A2),
  fontFamily: 'Poppins',
  fontSize: 20,
  fontWeight: FontWeight.w500,
  height: 35 / 20,
);

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.leadingIcon});

  final String title;
  final Widget child;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 30, color: const Color(0xFF001A36)),
              const SizedBox(width: 6),
            ],
            const SizedBox(width: 0),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF001A36),
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.w600,
                height: 43 / 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ✅ 카드 자체를 흰색 박스로
        Material(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), // <-- 여기 교체!
            side: const BorderSide(color: Color(0xFFD2D2D2), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            // ✅ 필드 배경을 투명하게(카드 흰색이 비치도록)
            child: Theme(
              data: theme.copyWith(
                inputDecorationTheme: const InputDecorationTheme(
                  filled: false, // 배경 채우지 않음
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide(color: Color(0xFFD2D2D2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide(color: Color(0xFFD2D2D2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide(color: Color(0xFF9DBCFD)),
                  ),
                  fillColor: Colors.transparent,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

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
    final base = Theme.of(context);
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
        return _buildProfilePage();
      case 1:
        return _buildNotificationPage();
      case 2:
        return _buildAppearancePage();
      case 3:
        return _buildClassSettingsPage();
      case 4:
        return _buildSecurityPage();
      case 5:
        return _buildDataPage();
      default:
        return const SizedBox();
    }
  }

  // ====== Profile ======
  Widget _buildProfilePage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "👤 Personal Information",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const CircleAvatar(radius: 32, child: Text("SJ")),
            const SizedBox(width: 20),
            Expanded(
              child: TextFormField(
                initialValue: "Sarah Johnson",
                decoration: const InputDecoration(labelText: "Full Name"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: "sarah@school.org",
                decoration: const InputDecoration(labelText: "Email Address"),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                initialValue: "+82 010-3512-1234",
                decoration: const InputDecoration(labelText: "Phone Number"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: "wow School",
                decoration: const InputDecoration(labelText: "School"),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                initialValue: "Teacher for 3rd Grade",
                decoration: const InputDecoration(labelText: "Subject / Role"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextFormField(
          initialValue: "halo",
          decoration: const InputDecoration(labelText: "Bio"),
        ),
      ],
    );
  }

  // ====== Notifications ======
  Widget _buildNotificationPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "🔔 Notification Preferences",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        SwitchListTile(
          title: const Text("Email Notifications"),
          subtitle: const Text("Receive important updates via email"),
          value: true,
          onChanged: (_) {},
        ),
        SwitchListTile(
          title: const Text("Sound Notifications"),
          subtitle: const Text("Get real-time notifications in the app"),
          value: false,
          onChanged: (_) {},
        ),
        SwitchListTile(
          title: const Text("Push Notifications"),
          subtitle: const Text("Play sounds for notifications"),
          value: true,
          onChanged: (_) {},
        ),
        const Divider(),
        SwitchListTile(
          title: const Text("Quiz Completions"),
          subtitle: const Text("When students complete quizzes"),
          value: true,
          onChanged: (_) {},
        ),
        SwitchListTile(
          title: const Text("Roll Responses"),
          subtitle: const Text("When students participate in polls"),
          value: true,
          onChanged: (_) {},
        ),
        SwitchListTile(
          title: const Text("Attendance Reminder"),
          subtitle: const Text("Reminders for attendance check times"),
          value: false,
          onChanged: (_) {},
        ),
      ],
    );
  }

  // ====== Appearance ======
  Widget _buildAppearancePage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "✨ Appearance",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Row(
          children: const [
            Expanded(
              child: _ThemeModeCard(label: "Light", icon: Icons.light_mode),
            ),
            Expanded(
              child: _ThemeModeCard(label: "Dark", icon: Icons.dark_mode),
            ),
            Expanded(
              child: _ThemeModeCard(label: "System", icon: Icons.computer),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: const [
            Text("Theme Mode: "),
            SizedBox(width: 16),
            Expanded(
              child: RadioListTile(
                value: "en",
                groupValue: "en",
                onChanged: null,
                title: Text("English"),
              ),
            ),
            Expanded(
              child: RadioListTile(
                value: "ko",
                groupValue: "en",
                onChanged: null,
                title: Text("Korean"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ====== Class Settings ======
  Widget _buildClassSettingsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "⏱ Class Settings",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        TextFormField(
          initialValue: "10",
          decoration: const InputDecoration(
            labelText: "Default Time Duration (minutes)",
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: const [
            Text("Class Language: "),
            SizedBox(width: 16),
            Expanded(
              child: RadioListTile(
                value: "en",
                groupValue: "en",
                onChanged: null,
                title: Text("English"),
              ),
            ),
            Expanded(
              child: RadioListTile(
                value: "ko",
                groupValue: "en",
                onChanged: null,
                title: Text("Korean"),
              ),
            ),
          ],
        ),
        const Divider(),
        SwitchListTile(
          title: const Text("Auto-save Results"),
          subtitle: const Text("Automatically save quiz and poll results"),
          value: true,
          onChanged: (_) {},
        ),
        SwitchListTile(
          title: const Text("Allow Anonymous Participation"),
          subtitle: const Text("Let students participate anonymously"),
          value: true,
          onChanged: (_) {},
        ),
        SwitchListTile(
          title: const Text("Require Confirmation"),
          subtitle: const Text(
            "Show confirmation dialogs for important actions",
          ),
          value: false,
          onChanged: (_) {},
        ),
      ],
    );
  }

  // ====== Security ======
  Widget _buildSecurityPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "🔒 Security Settings",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        TextFormField(
          decoration: const InputDecoration(labelText: "Current Password"),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextFormField(
          decoration: const InputDecoration(labelText: "New Password"),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextFormField(
          decoration: const InputDecoration(labelText: "Confirm Password"),
          obscureText: true,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
          child: const Text("Update Password"),
        ),
      ],
    );
  }

  // ====== Data ======
  Widget _buildDataPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "📦 Data Management",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        ListTile(
          title: const Text("Export All Data"),
          subtitle: const Text(
            "Download all quizzes, polls, and seating arrangements",
          ),
          trailing: ElevatedButton(
            onPressed: () {},
            child: const Text("Export"),
          ),
        ),
        ListTile(
          title: const Text("Import Data"),
          subtitle: const Text("Restore data from backup file"),
          trailing: ElevatedButton(
            onPressed: () {},
            child: const Text("Import"),
          ),
        ),
        ListTile(
          title: const Text("Delete Account"),
          subtitle: const Text("Permanently delete your account and all data"),
          trailing: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ),
      ],
    );
  }
}

class _ThemeModeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  const _ThemeModeCard({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 80,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(icon), Text(label)],
          ),
        ),
      ),
    );
  }
}
