import 'package:flutter/material.dart';

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

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _notifEmail = true;
  bool _notifSound = false;
  bool _notifPush = true;

  bool _notifQuiz = true;
  bool _notifRoll = true;
  bool _notifAttend = false;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Notification Preferences',
      leadingIcon: Icons.notifications_none,
      child: SwitchTheme(
        data: SwitchThemeData(
          trackColor: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return selected ? const Color(0xFF000000) : const Color(0xFFBDBDBD);
          }),
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
}
