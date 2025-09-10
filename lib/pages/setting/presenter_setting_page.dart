

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../provider/app_settings_provider.dart';
import '../../sidebar_menu.dart';

class PresenterSettingPage extends StatefulWidget {
  const PresenterSettingPage({super.key});

  @override
  State<PresenterSettingPage> createState() => _PresenterSettingPageState();
}

const _sectionH2 = TextStyle(
  // “Default Behavior” 같은 소제목
  color: Color(0xFF001A36),
  fontSize: 22,
  fontWeight: FontWeight.w600,
  height: 43 / 22,
);

const _itemTitleStyle = TextStyle(
  // 항목 제목
  color: Color(0xFF000000),
  fontSize: 20,
  fontWeight: FontWeight.w500,
  height: 34 / 20,
);

const _itemSubtitleStyle = TextStyle(
  // 항목 설명
  color: Color(0xFFA2A2A2),
  fontSize: 20,
  fontWeight: FontWeight.w500,
  height: 34 / 20,
);

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

const _fieldLabelStyle = TextStyle(
  color: Color(0xFF000000),
  fontSize: 20,
  fontWeight: FontWeight.w500,
  height: 34 / 20,
);

const _notifTitleStyle = TextStyle(
  color: Color(0xFF000000),
  fontSize: 20,
  fontWeight: FontWeight.w500,
  height: 34 / 20,
);

const _notifDescStyle = TextStyle(
  color: Color(0xFFA2A2A2),
  fontSize: 20,
  fontWeight: FontWeight.w500,
  height: 34 / 20,
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
                  filled: false,
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

                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
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
  bool _autoSave = true;
  bool _allowAnon = true;
  bool _requireConfirm = false;
  int _selectedIndex = 0;

  bool _notifEmail = true;
  bool _notifSound = false;
  bool _notifPush = true;

  bool _notifQuiz = true;
  bool _notifRoll = true;
  bool _notifAttend = false;

  final _curPwd = TextEditingController();
  final _newPwd = TextEditingController();
  final _cfmPwd = TextEditingController();

  bool _showCur = false;
  bool _showNew = false;
  bool _showCfm = false;
  bool _canSubmitPwd = false;

  void _recomputeCanSubmitPwd() {
    final ok =
        _curPwd.text.isNotEmpty &&
        _newPwd.text.isNotEmpty &&
        _cfmPwd.text.isNotEmpty &&
        _newPwd.text == _cfmPwd.text &&
        _newPwd.text.length >= 8; // 필요시 조건 수정
    setState(() => _canSubmitPwd = ok);
  }

  @override
  void dispose() {
    _curPwd.dispose();
    _newPwd.dispose();
    _cfmPwd.dispose();
    super.dispose();
  }

  final List<String> _menuTitles = [
    'Profile',
    'Notifications',
    'Appearance',
    'Class Settings',
    'Security',
    'Data',
  ];

  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('en');

  Uint8List? _avatarBytes;
  String? _avatarFileName;

  Future<void> _pickAvatar() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;

    final f = res.files.first;
    if (f.bytes == null) return;

    if (f.size > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 크기는 5MB 이하만 업로드할 수 있습니다.')),
      );
      return;
    }

    setState(() {
      _avatarBytes = f.bytes;
      _avatarFileName = f.name;
    });
  }

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

  Widget _avatarPicker() {
    const double size = 94;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundColor: const Color(0xFF44A0FF),
          backgroundImage:
              _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _pickAvatar,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 16,
                  color: Color(0xFF001A36),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePage() {
    return _Section(
      title: 'Personal Information',
      leadingIcon: Icons.person_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatarPicker(),
              const SizedBox(width: 20),
              const Expanded(
                child: _LabeledTextField(
                  label: "Full Name",
                  initialValue: "Handong Kim",
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: _LabeledTextField(
                  label: "Email Address",
                  initialValue: "kim@handong.ac.kr",
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: _LabeledTextField(
                  label: "Phone Number",
                  initialValue: "+82 010-1234-5678",
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: _LabeledTextField(
                  label: "School",
                  initialValue: "Handong Global School",
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: _LabeledTextField(
                  label: "Subject / Role",
                  initialValue: "Teacher for 3rd Grade",
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _LabeledTextField(label: "Bio", initialValue: "halo"),
        ],
      ),
    );
  }

  Widget _buildNotificationPage() {
    return _Section(
      title: 'Notification Preferences',
      leadingIcon: Icons.notifications_none,
      child: SwitchTheme(
        // ⬅️ 추가
        data: SwitchThemeData(
          // 선택됨: 검은색 트랙, 선택 안됨: 회색 트랙
          trackColor: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return selected ? const Color(0xFF000000) : const Color(0xFFBDBDBD);
          }),
          // 항상 흰색 썸
          thumbColor: const WidgetStatePropertyAll(Colors.white),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          thumbIcon: const WidgetStatePropertyAll(null),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingSwitchRow(
              title: 'Email Notifications',
              description: 'Receive important updates via email',
              value: _notifEmail,
              onChanged: (v) => setState(() => _notifEmail = v),
            ),
            _SettingSwitchRow(
              title: 'Sound Notifications',
              description: 'Get real-time notifications in the app',
              value: _notifSound,
              onChanged: (v) => setState(() => _notifSound = v),
            ),
            _SettingSwitchRow(
              title: 'Push Notifications',
              description: 'Play sounds for notifications',
              value: _notifPush,
              onChanged: (v) => setState(() => _notifPush = v),
            ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Activity Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF001A36),
                ),
              ),
            ),
            _SettingSwitchRow(
              title: 'Quiz Completions',
              description: 'When students complete quizzes',
              value: _notifQuiz,
              onChanged: (v) => setState(() => _notifQuiz = v),
            ),
            _SettingSwitchRow(
              title: 'Roll Responses',
              description: 'When students participate in polls',
              value: _notifRoll,
              onChanged: (v) => setState(() => _notifRoll = v),
            ),
            _SettingSwitchRow(
              title: 'Attendance Reminder',
              description: 'Reminders for attendance check times',
              value: _notifAttend,
              onChanged: (v) => setState(() => _notifAttend = v),
            ),
          ],
        ),
      ),
    );
  }

  // ====== Appearance ======
  Widget _buildAppearancePage() {
    final settings = context.watch<AppSettingsProvider>();
    final themeMode = settings.themeMode;

    return _Section(
      title: 'Appearance',
      leadingIcon: Icons.brightness_5_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Theme Mode 선택 카드 ----
          const Text(
            'Theme Mode',
            style: TextStyle(
              color: Color(0xFF000000),
              fontSize: 20,
              fontWeight: FontWeight.w500,
              height: 34 / 20,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ModeChoiceCard(
                  label: 'Light',
                  icon: Icons.light_mode_outlined,
                  selected: themeMode == ThemeMode.light,
                  onTap:
                      () => context.read<AppSettingsProvider>().setThemeMode(
                        ThemeMode.light,
                      ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _ModeChoiceCard(
                  label: 'Dark',
                  icon: Icons.dark_mode_outlined,
                  selected: themeMode == ThemeMode.dark,
                  onTap:
                      () => context.read<AppSettingsProvider>().setThemeMode(
                        ThemeMode.dark,
                      ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _ModeChoiceCard(
                  label: 'System',
                  icon: Icons.computer_outlined,
                  selected: themeMode == ThemeMode.system,
                  onTap:
                      () => context.read<AppSettingsProvider>().setThemeMode(
                        ThemeMode.system,
                      ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ---- Language (l10n) ----
          const Text(
            'Language',
            style: TextStyle(
              color: Color(0xFF000000),
              fontSize: 20,
              fontWeight: FontWeight.w500,
              height: 34 / 20,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _LangRadio(
                label: 'English', // 라벨은 고정 텍스트여도 OK (실제 앱 문자열은 locale에 따라 바뀜)
                value: const Locale('en'),
                group: settings.locale,
                onChanged:
                    (v) => context.read<AppSettingsProvider>().setLocale(v!),
              ),
              const SizedBox(width: 28),
              _LangRadio(
                label: 'Korean',
                value: const Locale('ko'),
                group: settings.locale,
                onChanged:
                    (v) => context.read<AppSettingsProvider>().setLocale(v!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ====== Class Settings ======
  Widget _buildClassSettingsPage() {
    final app = context.watch<AppSettingsProvider>();

    return _Section(
      title: 'Class Settings',
      leadingIcon: Icons.alarm_add_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Default Time
          TextFormField(
            initialValue: "10",
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Default Time Duration (minutes)",
            ),
          ),
          const SizedBox(height: 24),

          // Language
          const Text('Class Language', style: _itemTitleStyle),
          const SizedBox(height: 10),
          RadioTheme(
            data: RadioThemeData(
              fillColor: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return selected
                    ? const Color(0xFF001A36)
                    : const Color(0xFFD9D9D9);
              }),
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              children: [
                _LangRadio(
                  label: 'English',
                  value: const Locale('en'),
                  group: app.locale ?? const Locale('en'),
                  onChanged:
                      (loc) =>
                          context.read<AppSettingsProvider>().setLocale(loc),
                ),
                const SizedBox(width: 24),
                _LangRadio(
                  label: 'Korean',
                  value: const Locale('ko'),
                  group: app.locale ?? const Locale('en'),
                  onChanged:
                      (loc) =>
                          context.read<AppSettingsProvider>().setLocale(loc),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFFD2D2D2)),
          const SizedBox(height: 8),

          // Default Behavior (subtitle)
          const Text('Default Behavior', style: _sectionH2),
          const SizedBox(height: 8),

          // Switch 공통 테마 (남색 트랙/흰색 썸)
          SwitchTheme(
            data: SwitchThemeData(
              trackColor: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return selected
                    ? const Color(0xFF001A36)
                    : const Color(0xFFBDBDBD);
              }),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                return Colors.white;
              }),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              thumbIcon: WidgetStateProperty.resolveWith((states) => null),
            ),
            child: Column(
              children: [
                _SettingSwitch(
                  title: 'Auto-save Results',
                  subtitle: 'Automatically save quiz and poll results',
                  value: _autoSave,
                  onChanged: (v) => setState(() => _autoSave = v),
                ),
                const SizedBox(height: 8),
                _SettingSwitch(
                  title: 'Allow Anonymous Participation',
                  subtitle: 'Let students participate anonymously',
                  value: _allowAnon,
                  onChanged: (v) => setState(() => _allowAnon = v),
                ),
                const SizedBox(height: 8),
                _SettingSwitch(
                  title: 'Require Confirmation',
                  subtitle: 'Show confirmation dialogs for important actions',
                  value: _requireConfirm,
                  onChanged: (v) => setState(() => _requireConfirm = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityPage() {
    return _Section(
      title: 'Security Settings',
      leadingIcon: Icons.lock_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카드 내부 섹션 타이틀
          const Text('Change Password', style: _sectionH2),
          const SizedBox(height: 16),

          // Current Password
          const Text('Current Password', style: _fieldLabelStyle),
          const SizedBox(height: 6),
          TextFormField(
            controller: _curPwd,
            obscureText: !_showCur,
            onChanged: (_) => _recomputeCanSubmitPwd(),
            decoration: InputDecoration(
              suffixIcon: IconButton(
                tooltip: _showCur ? 'Hide' : 'Show',
                icon: Icon(
                  _showCur
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                color: const Color(0xFF9E9E9E),
                onPressed: () => setState(() => _showCur = !_showCur),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // New Password
          const Text('New Password', style: _fieldLabelStyle),
          const SizedBox(height: 6),
          TextFormField(
            controller: _newPwd,
            obscureText: !_showNew,
            onChanged: (_) => _recomputeCanSubmitPwd(),
            decoration: InputDecoration(
              suffixIcon: IconButton(
                tooltip: _showNew ? 'Hide' : 'Show',
                icon: Icon(
                  _showNew
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                color: const Color(0xFF9E9E9E),
                onPressed: () => setState(() => _showNew = !_showNew),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Confirm Password
          const Text('Confirm Password', style: _fieldLabelStyle),
          const SizedBox(height: 6),
          TextFormField(
            controller: _cfmPwd,
            obscureText: !_showCfm,
            onChanged: (_) => _recomputeCanSubmitPwd(),
            decoration: InputDecoration(
              suffixIcon: IconButton(
                tooltip: _showCfm ? 'Hide' : 'Show',
                icon: Icon(
                  _showCfm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                color: const Color(0xFF9E9E9E),
                onPressed: () => setState(() => _showCfm = !_showCfm),
              ),
            ),
          ),

          const SizedBox(height: 22),

          Center(
            child: SizedBox(
              width: 226, // ← 226px
              height: 51, // ← 51px
              child: ElevatedButton(
                onPressed:
                    _canSubmitPwd
                        ? () {
                          // TODO: 비밀번호 변경 로직
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14), // ← r=14px
                  ),
                  disabledBackgroundColor: const Color(0xFFA9A9A9), // ← 비활성 색
                  disabledForegroundColor: Colors.white,
                  backgroundColor:
                      _canSubmitPwd ? const Color(0xFF001A36) : null, // ← 활성 색
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text(
                  'Update Password',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====== Data ======
  Widget _buildDataPage() {
    return _Section(
      title: 'Data Management',
      leadingIcon: Icons.inbox,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Backup',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF001A36),
              height: 43 / 22,
            ),
          ),
          const SizedBox(height: 20),

          // Export
          _ActionRow(
            title: 'Export All Data',
            subtitle: 'Download all quizzes, polls, and seating arrangements',
            trailing: _GhostButton.icon(
              icon: Icons.download_outlined,
              label: 'Export',
              onPressed: () {
                // TODO: export 로직
              },
            ),
          ),
          const SizedBox(height: 12),

          // Import
          _ActionRow(
            title: 'Import Data',
            subtitle: 'Restore data from backup file',
            trailing: _GhostButton.icon(
              icon: Icons.upload_outlined,
              label: 'Import',
              onPressed: () {
                // TODO: import 로직
              },
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Color(0xFFD2D2D2)),
          ),

          // Delete
          _ActionRow(
            title: 'Delete Account',
            subtitle: 'Permanently delete your account and all data',
            trailing: _DangerGhostButton.icon(
              icon: Icons.delete_outline,
              label: 'Delete',
              onPressed: () {
                // TODO: 삭제 확인 다이얼로그
              },
            ),
          ),
        ],
      ),
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

class _LabeledTextField extends StatelessWidget {
  final String label;
  final String? initialValue;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _LabeledTextField({
    required this.label,
    this.initialValue,
    this.obscureText = false,
    this.keyboardType,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _fieldLabelStyle),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: initialValue,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: const InputDecoration(),
        ),
      ],
    );
  }
}

class _SettingSwitchRow extends StatelessWidget {
  const _SettingSwitchRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 235),
                  child: Text(
                    title,
                    style: _notifTitleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 577),
                  child: Text(description, style: _notifDescStyle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        width: 236,
        height: 95,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF9DBCFD) : const Color(0xFFD2D2D2),
            width: 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: const Color(0xFF000000)),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF000000),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 22 / 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocaleRadio extends StatelessWidget {
  const _LocaleRadio({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final Locale value;
  final Locale groupValue;
  final ValueChanged<Locale?> onChanged;

  static const _radioColor = Color(0xFF001A36);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Theme(
          data: Theme.of(context).copyWith(
            radioTheme: RadioThemeData(
              fillColor: WidgetStateProperty.resolveWith<Color>(
                (states) => _radioColor,
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            ),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: SizedBox(
            width: 25,
            height: 24,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Radio<Locale>(
                value: value,
                groupValue: groupValue,
                onChanged: onChanged,
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF000000),
            fontSize: 20,
            fontWeight: FontWeight.w500,
            height: 34 / 20,
          ),
        ),
      ],
    );
  }
}

class _ModeChoiceCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChoiceCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 95, // 디자인 스펙: 95px
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white, // 카드 배경 #FFF
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF001A36) : const Color(0xFFD2D2D2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: const Color(0xFF001A36)), // 아이콘 색상 스펙
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF000000),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangRadio extends StatelessWidget {
  const _LangRadio({
    required this.label,
    required this.value,
    required this.group,
    required this.onChanged,
  });

  final String label;
  final Locale value;
  final Locale group;
  final ValueChanged<Locale> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<Locale>(
          value: value,
          groupValue: group,
          onChanged: (loc) {
            if (loc != null) onChanged(loc);
          },
        ),
        Text(label, style: _itemTitleStyle),
      ],
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8), // 높이 여유
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // 위로 맞추기
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _itemTitleStyle),
                const SizedBox(height: 2),
                Text(subtitle, style: _itemSubtitleStyle),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 좌측: 제목/설명
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _itemTitleStyle),
              const SizedBox(height: 2),
              Text(subtitle, style: _itemSubtitleStyle),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // 우측: 버튼
        trailing,
      ],
    );
  }
}

/// 회색 보더의 고스트 버튼 (Export/Import)
class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.child,
    required this.onPressed,
    this.width = 120,
    this.height = 42,
  });

  factory _GhostButton.icon({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    double width = 120,
    double height = 42,
  }) {
    return _GhostButton(
      width: width,
      height: height,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF111827)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  final Widget child;
  final VoidCallback onPressed;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          elevation: 0,
        ),
        child: child,
      ),
    );
  }
}

/// 주황색 테두리 + 옅은 주황 배경의 위험 버튼 (Delete)
class _DangerGhostButton extends StatelessWidget {
  const _DangerGhostButton({
    required this.child,
    required this.onPressed,
    this.width = 120,
    this.height = 42,
  });

  factory _DangerGhostButton.icon({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    double width = 120,
    double height = 42,
  }) {
    return _DangerGhostButton(
      width: width,
      height: height,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFF97316)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF97316),
            ),
          ),
        ],
      ),
    );
  }

  final Widget child;
  final VoidCallback onPressed;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFFFF7ED), // 아주 옅은 주황
          side: const BorderSide(color: Color(0xFFF97316), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          elevation: 0,
        ),
        child: child,
      ),
    );
  }
}
