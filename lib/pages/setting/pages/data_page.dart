import 'package:flutter/material.dart';

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
          backgroundColor: const Color(0xFFFFF7ED),
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

class DataPage extends StatelessWidget {
  const DataPage({super.key});

  @override
  Widget build(BuildContext context) {
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
