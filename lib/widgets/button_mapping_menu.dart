// lib/widgets/button_mapping_menu.dart
import 'package:flutter/material.dart';

/// 🔹 버튼-제스처 매핑 정보 구조체
class Binding {
  final int button; // 1 | 2
  final String gesture; // 'single' | 'hold'
  const Binding({required this.button, required this.gesture});

  @override
  bool operator ==(Object other) =>
      other is Binding && other.button == button && other.gesture == gesture;

  @override
  int get hashCode => Object.hash(button, gesture);
}

/// 🔹 메뉴 옵션 데이터 구조
class MenuOpt {
  final int value;
  final String label;
  final String key;
  const MenuOpt(this.value, this.label, this.key);
}

/// 🔹 버튼 매핑 메뉴 항목 생성
List<PopupMenuEntry<int>> buildMappingMenuItems({
  required Binding current,
  required Set<String> usedExceptMe,
}) {
  final currentKey = '${current.button}-${current.gesture}';
  const opts = [
    MenuOpt(1, '1 - single', '1-single'),
    MenuOpt(2, '1 - hold', '1-hold'),
    MenuOpt(3, '2 - single', '2-single'),
    MenuOpt(4, '2 - hold', '2-hold'),
  ];

  final items = <PopupMenuEntry<int>>[
    const PopupMenuItem<int>(
      enabled: false,
      child: Text(
        '— Button mapping —',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF001A36),
        ),
      ),
    ),
    const PopupMenuDivider(),
  ];

  for (final o in opts) {
    final selected = o.key == currentKey;
    items.add(
      PopupMenuItem<int>(
        value: o.value,
        enabled: true,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: selected
                  ? const Icon(Icons.check, size: 18, color: Colors.black87)
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                o.label,
                style: const TextStyle(
                  color: Colors.black,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  items.add(const PopupMenuDivider());
  items.add(const PopupMenuItem<int>(value: 9, child: Text('문항 삭제')));
  return items;
}

/// 🔹 메뉴 선택 시 실제 Binding으로 변환
Binding onMappingSelected(int v) {
  switch (v) {
    case 1:
      return const Binding(button: 1, gesture: 'single');
    case 2:
      return const Binding(button: 1, gesture: 'hold');
    case 3:
      return const Binding(button: 2, gesture: 'single');
    case 4:
      return const Binding(button: 2, gesture: 'hold');
    default:
      return const Binding(button: 1, gesture: 'single');
  }
}
