import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

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

class _LabeledTextField extends StatelessWidget {
  final String label;
  final String? initialValue;
  final TextInputType? keyboardType;

  const _LabeledTextField({
    required this.label,
    this.initialValue,
    this.keyboardType,
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
          keyboardType: keyboardType,
          decoration: const InputDecoration(),
        ),
      ],
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Uint8List? _avatarBytes;

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
    });
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

  @override
  Widget build(BuildContext context) {
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
}
