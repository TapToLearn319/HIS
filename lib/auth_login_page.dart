// lib/auth_login_page.dart
// Firebase Auth 로그인 화면 (이메일/비밀번호)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 앱 최초 진입 시 인증 상태에 따라 /login 또는 /hub-select로 보냄
class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  bool _navigated = false;

  void _navigateOnce(String route) {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  void initState() {
    super.initState();
    // 첫 번째 auth 상태 이벤트만 사용 (웹에서 세션 복원 후 한 번만 이동)
    FirebaseAuth.instance.authStateChanges().first.then((User? user) async {
      if (!mounted || _navigated) return;
      if (user == null) {
        _navigateOnce('/login');
        return;
      }
      await user.reload();
      if (!mounted || _navigated) return;
      // 로그인된 사용자(이메일 인증 여부 무관)는 허브 선택으로
      final fresh = FirebaseAuth.instance.currentUser;
      if (fresh != null) {
        _navigateOnce('/hub-select');
      } else {
        _navigateOnce('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF6FAFF),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('로그인 확인 중...', style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

/// 이메일/비밀번호 로그인 폼
class AuthLoginPage extends StatefulWidget {
  const AuthLoginPage({super.key});

  @override
  State<AuthLoginPage> createState() => _AuthLoginPageState();
}

class _AuthLoginPageState extends State<AuthLoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _errorText;

  static const _labelColor = Color(0xFF0F172A);
  static const _textColor = Color(0xFF111827);
  static const _hintColor = Color(0xFF6B7280);
  static const _bgColor = Colors.white;
  static const _borderColor = Color(0xFFBFD6FF);
  static const _focusBorderColor = Color(0xFF7CA6FF);
  static const _ctaColor = Color(0xFF9370F7);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = '이메일과 비밀번호를 입력하세요.');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      final u = cred.user;
      if (u != null) {
        await u.reload();
        if (!mounted) return;
        // 로그인 성공 시 항상 허브 선택으로 이동.
        // (Firebase 콘솔에서 생성한 관리자 계정은 emailVerified가 false라
        //  이전에는 verify-email로 보내져서 진입이 막혀 있었음)
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/hub-select',
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = '로그인에 실패했습니다.';
      switch (e.code) {
        case 'user-not-found':
          msg = '등록되지 않은 이메일입니다.';
          break;
        case 'wrong-password':
          msg = '비밀번호가 올바르지 않습니다.';
          break;
        case 'invalid-email':
          msg = '올바른 이메일 형식이 아닙니다.';
          break;
        case 'invalid-credential':
          msg = '이메일 또는 비밀번호가 올바르지 않습니다.';
          break;
      }
      setState(() {
        _errorText = msg;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = '로그인에 실패했습니다. 다시 시도해 주세요.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: 1440, height: 720, child: _buildBody()),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        Positioned(
          left: -98,
          top: 175,
          child: Container(
            width: 563,
            height: 563,
            decoration: const BoxDecoration(
              color: Color(0XFFDCFE83),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: -192,
          top: -262,
          child: Container(
            width: 667,
            height: 667,
            decoration: const BoxDecoration(
              color: Color(0xFFC4F6FE),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final h = c.maxHeight;
              final scale = (w / 1440.0 < h / 720.0) ? w / 1440.0 : h / 720.0;
              final logoW = 647 * scale;
              final logoH = 380 * scale;
              final gap = 12 * scale;
              final btnW = 320 * scale;
              final btnH = 54 * scale;
              final radius = 28 * scale;
              final fontZ = 18 * scale;

              return Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: _bgColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    labelStyle: const TextStyle(
                      color: _labelColor,
                      fontWeight: FontWeight.w600,
                    ),
                    hintStyle: const TextStyle(color: _hintColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _borderColor,
                        width: 1.4,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _borderColor,
                        width: 1.4,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _focusBorderColor,
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor: 0.85,
                          child: Image.asset(
                            'assets/logo_bird_main.png',
                            width: logoW,
                            height: logoH,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      SizedBox(height: gap),
                      Text(
                        '로그인',
                        style: TextStyle(
                          fontSize: 24 * scale,
                          fontWeight: FontWeight.w700,
                          color: _textColor,
                        ),
                      ),
                      SizedBox(height: gap * 2),
                      SizedBox(
                        width: btnW,
                        child: TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: '이메일',
                            hintText: 'example@email.com',
                          ),
                          onChanged: (_) => setState(() => _errorText = null),
                        ),
                      ),
                      SizedBox(height: gap),
                      SizedBox(
                        width: btnW,
                        child: TextField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: '비밀번호',
                            hintText: '비밀번호 입력',
                          ),
                          onChanged: (_) => setState(() => _errorText = null),
                        ),
                      ),
                      if (_errorText != null) ...[
                        SizedBox(height: gap),
                        SizedBox(
                          width: btnW,
                          child: Text(
                            _errorText!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: gap * 2),
                      SizedBox(
                        width: btnW,
                        height: btnH.clamp(48.0, double.infinity),
                        child: ElevatedButton(
                          onPressed: _loading ? null : _signIn,
                          style: ButtonStyle(
                            backgroundColor: const WidgetStatePropertyAll(
                              _ctaColor,
                            ),
                            foregroundColor: const WidgetStatePropertyAll(
                              Colors.white,
                            ),
                            elevation: const WidgetStatePropertyAll(0),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(radius),
                              ),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  '로그인',
                                  style: TextStyle(
                                    fontSize: fontZ,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: gap * 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '계정이 없으신가요? ',
                            style: TextStyle(
                              fontSize: 14 * scale,
                              color: _hintColor,
                            ),
                          ),
                          GestureDetector(
                            onTap: _loading
                                ? null
                                : () => Navigator.of(context).pushNamed('/signup'),
                            child: Text(
                              '회원가입',
                              style: TextStyle(
                                fontSize: 14 * scale,
                                fontWeight: FontWeight.w600,
                                color: _ctaColor,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20 * scale),
                      Opacity(
                        opacity: 0.85,
                        child: Text(
                          "© 2025 Team MyButton. All rights reserved.",
                          style: TextStyle(
                            fontSize: 12 * scale,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 이메일 인증 대기: 링크 확인 후 '인증 완료 확인'으로 가입 완료
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _loading = false;
  String? _message;

  static const _textColor = Color(0xFF111827);
  static const _ctaColor = Color(0xFF9370F7);

  Future<void> _checkVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    await user.reload();
    if (!mounted) return;
    final fresh = FirebaseAuth.instance.currentUser;
    setState(() => _loading = false);
    if (fresh != null && fresh.emailVerified) {
      setState(() =>
          _message = '인증이 완료되었습니다. 잠시 후 로그인 페이지로 이동합니다.');
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      setState(() =>
          _message = '아직 인증되지 않았습니다. 이메일의 링크를 확인해 주세요.');
    }
  }

  Future<void> _resendVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = '인증 메일을 다시 보냈습니다. 받은편지함을 확인해 주세요.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = '재발송에 실패했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: 1440, height: 720, child: _buildBody()),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        Positioned(
          left: -98,
          top: 175,
          child: Container(
            width: 563,
            height: 563,
            decoration: const BoxDecoration(
              color: Color(0XFFDCFE83),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: -192,
          top: -262,
          child: Container(
            width: 667,
            height: 667,
            decoration: const BoxDecoration(
              color: Color(0xFFC4F6FE),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final h = c.maxHeight;
              final scale =
                  (w / 1440.0 < h / 720.0) ? w / 1440.0 : h / 720.0;
              final logoH = 200 * scale;
              final gap = 16 * scale;
              final btnW = 320 * scale;
              final btnH = 54 * scale;
              final radius = 28 * scale;
              final fontZ = 18 * scale;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 24 * scale),
                    ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: 0.85,
                        child: Image.asset(
                          'assets/logo_bird_main.png',
                          width: 400 * scale,
                          height: logoH,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(height: gap * 2),
                    Text(
                      '이메일 인증',
                      style: TextStyle(
                        fontSize: 24 * scale,
                        fontWeight: FontWeight.w700,
                        color: _textColor,
                      ),
                    ),
                    SizedBox(height: gap),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40 * scale),
                      child: Text(
                        '인증 링크를 이메일로 보냈습니다.\n이메일을 확인하고 링크를 클릭한 뒤\n아래 버튼을 눌러 주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16 * scale,
                          color: _textColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (_message != null) ...[
                      SizedBox(height: gap),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40 * scale),
                        child: Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14 * scale,
                            color: _message!.startsWith('아직')
                                ? Colors.red
                                : Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: gap * 2),
                    SizedBox(
                      width: btnW,
                      height: btnH,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _checkVerified,
                        style: ButtonStyle(
                          backgroundColor: const WidgetStatePropertyAll(
                            _ctaColor,
                          ),
                          foregroundColor: const WidgetStatePropertyAll(
                            Colors.white,
                          ),
                          elevation: const WidgetStatePropertyAll(0),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(radius),
                            ),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                '인증 완료 확인',
                                style: TextStyle(
                                  fontSize: fontZ,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: gap),
                    TextButton(
                      onPressed: _loading ? null : _resendVerification,
                      child: Text(
                        '인증 메일 다시 보내기',
                        style: TextStyle(
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.w600,
                          color: _ctaColor,
                        ),
                      ),
                    ),
                    SizedBox(height: gap),
                    TextButton(
                      onPressed: _loading ? null : _signOut,
                      child: Text(
                        '로그아웃',
                        style: TextStyle(
                          fontSize: 14 * scale,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    SizedBox(height: 20 * scale),
                    Opacity(
                      opacity: 0.85,
                      child: Text(
                        "© 2025 Team MyButton. All rights reserved.",
                        style: TextStyle(
                          fontSize: 12 * scale,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 이메일/비밀번호 회원가입 폼
class AuthSignUpPage extends StatefulWidget {
  const AuthSignUpPage({super.key});

  @override
  State<AuthSignUpPage> createState() => _AuthSignUpPageState();
}

class _AuthSignUpPageState extends State<AuthSignUpPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();
  bool _loading = false;
  String? _errorText;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  static const _labelColor = Color(0xFF0F172A);
  static const _textColor = Color(0xFF111827);
  static const _hintColor = Color(0xFF6B7280);
  static const _bgColor = Colors.white;
  static const _borderColor = Color(0xFFBFD6FF);
  static const _focusBorderColor = Color(0xFF7CA6FF);
  static const _ctaColor = Color(0xFF9370F7);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _passwordConfirmCtrl.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _errorText = '모든 항목을 입력하세요.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorText = '비밀번호가 일치하지 않습니다.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorText = '비밀번호는 6자 이상이어야 합니다.');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user != null) {
        await user.sendEmailVerification();
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/verify-email');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = '회원가입에 실패했습니다.';
      switch (e.code) {
        case 'email-already-in-use':
          msg = '이미 사용 중인 이메일입니다.';
          break;
        case 'invalid-email':
          msg = '올바른 이메일 형식이 아닙니다.';
          break;
        case 'weak-password':
          msg = '비밀번호를 6자 이상으로 설정해 주세요.';
          break;
      }
      setState(() {
        _errorText = msg;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = '회원가입에 실패했습니다. 다시 시도해 주세요.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: 1440, height: 720, child: _buildBody()),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        Positioned(
          left: -98,
          top: 175,
          child: Container(
            width: 563,
            height: 563,
            decoration: const BoxDecoration(
              color: Color(0XFFDCFE83),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: -192,
          top: -262,
          child: Container(
            width: 667,
            height: 667,
            decoration: const BoxDecoration(
              color: Color(0xFFC4F6FE),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final h = c.maxHeight;
              final scale =
                  (w / 1440.0 < h / 720.0) ? w / 1440.0 : h / 720.0;
              final logoW = 647 * scale;
              final logoH = 320 * scale;
              final gap = 12 * scale;
              final btnW = 320 * scale;
              final btnH = 54 * scale;
              final radius = 28 * scale;
              final fontZ = 18 * scale;

              return Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: _bgColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    labelStyle: const TextStyle(
                      color: _labelColor,
                      fontWeight: FontWeight.w600,
                    ),
                    hintStyle: const TextStyle(color: _hintColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _borderColor,
                        width: 1.4,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _borderColor,
                        width: 1.4,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _focusBorderColor,
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor: 0.85,
                          child: Image.asset(
                            'assets/logo_bird_main.png',
                            width: logoW,
                            height: logoH,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      SizedBox(height: gap),
                      Text(
                        '회원가입',
                        style: TextStyle(
                          fontSize: 24 * scale,
                          fontWeight: FontWeight.w700,
                          color: _textColor,
                        ),
                      ),
                      SizedBox(height: gap * 2),
                      SizedBox(
                        width: btnW,
                        child: TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: '이메일',
                            hintText: 'example@email.com',
                          ),
                          onChanged: (_) => setState(() => _errorText = null),
                        ),
                      ),
                      SizedBox(height: gap),
                      SizedBox(
                        width: btnW,
                        child: TextField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: '비밀번호',
                            hintText: '6자 이상',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: _hintColor,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          onChanged: (_) => setState(() => _errorText = null),
                        ),
                      ),
                      SizedBox(height: gap),
                      SizedBox(
                        width: btnW,
                        child: TextField(
                          controller: _passwordConfirmCtrl,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: '비밀번호 확인',
                            hintText: '비밀번호 다시 입력',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: _hintColor,
                              ),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          onChanged: (_) => setState(() => _errorText = null),
                        ),
                      ),
                      if (_errorText != null) ...[
                        SizedBox(height: gap),
                        SizedBox(
                          width: btnW,
                          child: Text(
                            _errorText!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: gap * 2),
                      SizedBox(
                        width: btnW,
                        height: btnH,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _signUp,
                          style: ButtonStyle(
                            backgroundColor: const WidgetStatePropertyAll(
                              _ctaColor,
                            ),
                            foregroundColor: const WidgetStatePropertyAll(
                              Colors.white,
                            ),
                            elevation: const WidgetStatePropertyAll(0),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(radius),
                              ),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  '가입하기',
                                  style: TextStyle(
                                    fontSize: fontZ,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: gap),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(
                          '로그인으로 돌아가기',
                          style: TextStyle(
                            fontSize: fontZ,
                            fontWeight: FontWeight.w600,
                            color: _ctaColor,
                          ),
                        ),
                      ),
                      SizedBox(height: 20 * scale),
                      Opacity(
                        opacity: 0.85,
                        child: Text(
                          "© 2025 Team MyButton. All rights reserved.",
                          style: TextStyle(
                            fontSize: 12 * scale,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
