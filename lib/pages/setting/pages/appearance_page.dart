import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../provider/app_settings_provider.dart';

const _itemTitleStyle = TextStyle(
  color: Color(0xFF000000),
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
        height: 95,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF001A36) : const Color(0xFFD2D2D2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: const Color(0xFF001A36)),
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

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
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
                label: 'English',
                value: const Locale('en'),
                group: settings.locale,
                onChanged:
                    (v) => context.read<AppSettingsProvider>().setLocale(v),
              ),
              const SizedBox(width: 28),
              _LangRadio(
                label: 'Korean',
                value: const Locale('ko'),
                group: settings.locale,
                onChanged:
                    (v) => context.read<AppSettingsProvider>().setLocale(v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
