// lib/widgets/help_badge.dart
import 'package:flutter/material.dart';

class HelpBadge extends StatefulWidget {
  const HelpBadge({
    super.key,
    required this.tooltip,
    this.assetPath,
    this.size = 24,
    this.color,
    this.placement = HelpPlacement.right,
    this.gap = 8.0,
    this.offset = const Offset(0, 0),
    this.semanticLabel = 'Help',
  });

  final String tooltip;
  final String? assetPath;
  final double size;
  final Color? color;
  final HelpPlacement placement;   // left | right
  final double gap;                // 아이콘과 말풍선 간격
  final Offset offset;             // 미세 위치 조정
  final String semanticLabel;

  @override
  State<HelpBadge> createState() => _HelpBadgeState();
}

class _HelpBadgeState extends State<HelpBadge> {
  final GlobalKey _anchorKey = GlobalKey();
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = _buildIcon();
    return Semantics(
      label: widget.semanticLabel,
      button: true,
      child: MouseRegion(
        onEnter: (_) => _showOverlay(),
        onExit: (_) => _removeOverlay(),
        child: Container(
          key: _anchorKey,
          padding: const EdgeInsets.all(4),
          child: icon,
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (widget.assetPath != null) {
      return Image.asset(
        widget.assetPath!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.help_rounded,
          size: widget.size,
          color: widget.color ?? Colors.grey.shade600,
        ),
      );
    }
    return Icon(
      Icons.help_rounded,
      size: widget.size,
      color: widget.color ?? Colors.grey.shade600,
    );
  }

  void _showOverlay() {
    if (_overlay != null) return;

    final anchorCtx = _anchorKey.currentContext;
    if (anchorCtx == null) return;

    final anchorBox = anchorCtx.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (anchorBox == null || overlayBox == null) return;

    // 아이콘 위치(오버레이 좌표계)
    final iconSize = anchorBox.size;
    final topLeft  = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final topRight = anchorBox.localToGlobal(Offset(iconSize.width, 0), ancestor: overlayBox);
    final centerY  = topLeft.dy + iconSize.height / 2;

    final toRight = widget.placement == HelpPlacement.right;
    final baseX = (toRight ? topRight.dx + widget.gap : topLeft.dx - widget.gap) + widget.offset.dx;
    final baseY = centerY + widget.offset.dy;

    final tip = widget.tooltip; // ★ 문자열을 캡쳐해서 아래로 전달

    _overlay = OverlayEntry(
      builder: (_) {
        final fx = toRight ? 0.0 : -1.0; // 왼쪽 배치면 자기폭만큼 왼쪽으로
        const fy = -0.5;                 // 수직 중앙 정렬
        return Positioned(
          left: baseX,
          top:  baseY,
          child: FractionalTranslation(
            translation: Offset(fx, fy),
            child: IgnorePointer(
              child: _HelpBubble(text: tip), // ★ 여기로 직접 전달
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }
}

/// 텍스트 크기에 딱 맞는 말풍선(연회색 배경 + 진회색 텍스트)
class _HelpBubble extends StatelessWidget {
  const _HelpBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.card,
      color: const Color(0xFFF3F4F6),              // 연한 회색
      elevation: 4,
      shadowColor: const Color(0x1F000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFA2A2A2)), // 옅은 테두리
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280), // 너무 길어지는 것만 방지
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            text,
            softWrap: true,
            style: const TextStyle(
              color: Color(0xFF111827), // 진한 회색 글씨
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

enum HelpPlacement { right, left }
