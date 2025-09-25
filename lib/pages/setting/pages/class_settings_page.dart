import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../provider/app_settings_provider.dart';

const _sectionH2 = TextStyle(
  color: Color(0xFF001A36),
  fontSize: 22,
  fontWeight: FontWeight.w600,
  height: 43 / 22,
);

const _itemTitleStyle = TextStyle(
  color: Color(0xFF000000),
  fontSize: 20,
  fontWeight: FontWeight.w500,
  height: 34 / 20,
);

const _itemSubtitleStyle = TextStyle(
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
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFD2D2D2), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
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
  final ValueChanged<Locale?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<Locale>(value: value, groupValue: group, onChanged: onChanged),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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

class ClassSettingsPage extends StatefulWidget {
  const ClassSettingsPage({super.key});

  @override
  State<ClassSettingsPage> createState() => _ClassSettingsPageState();
}

class _ClassSettingsPageState extends State<ClassSettingsPage> {
  bool _autoSave = true;
  bool _allowAnon = true;
  bool _requireConfirm = false;

  @override
  Widget build(BuildContext context) {
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
                  group: app.locale,
                  onChanged: (loc) {
                    if (loc != null) {
                      context.read<AppSettingsProvider>().setLocale(loc);
                    }
                  },
                ),
                const SizedBox(width: 24),
                _LangRadio(
                  label: 'Korean',
                  value: const Locale('ko'),
                  group: app.locale,
                  onChanged: (loc) {
                    if (loc != null) {
                      context.read<AppSettingsProvider>().setLocale(loc);
                    }
                  },
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
}
