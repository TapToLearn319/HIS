import 'package:flutter/material.dart';

const _sectionH2 = TextStyle(
  color: Color(0xFF001A36),
  fontSize: 22,
  fontWeight: FontWeight.w600,
  height: 43 / 22,
);

const _fieldLabelStyle = TextStyle(
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

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
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
        _newPwd.text.length >= 8;
    setState(() => _canSubmitPwd = ok);
  }

  @override
  void dispose() {
    _curPwd.dispose();
    _newPwd.dispose();
    _cfmPwd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              width: 226,
              height: 51,
              child: ElevatedButton(
                onPressed:
                    _canSubmitPwd
                        ? () {
                          // TODO: 비밀번호 변경 로직
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  disabledBackgroundColor: const Color(0xFFA9A9A9),
                  disabledForegroundColor: Colors.white,
                  backgroundColor:
                      _canSubmitPwd ? const Color(0xFF001A36) : null,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text(
                  'Update Password',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
