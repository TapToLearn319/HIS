// lib/widgets/help_badge.dart
import 'package:flutter/material.dart';

/// 물음표(?) 배지 + Hover 오버레이 말풍선.
/// - 데스크톱/웹: 마우스 올리면 즉시 표시, 벗어나면 즉시 숨김(hover 중에는 계속 보임)
/// - 모바일/터치: 탭하면 토글로 표시/숨김
/// - assetPath가 있으면 해당 이미지를, 없으면 기본 ? 아이콘을 사용
class HelpBadge extends StatefulWidget {
  const HelpBadge({
    super.key,
    required this.tooltip,
    this.assetPath,
    this.size = 24,
    this.color,
    this.placement = HelpPlacement.right,
    this.offset = const Offset(0, 0), // 기본은 0,0로 아주 가깝게
    this.gap = 2.0,                   // 아이콘과 말풍선 사이 간격(px). 0~2 권장
    this.semanticLabel = 'Help',
  });

  /// 툴팁 텍스트
  final String tooltip;

  /// 아이콘 이미지 경로(null이면 기본 아이콘)
  final String? assetPath;

  /// 아이콘 크기
  final double size;

  /// 기본 아이콘 색상(assetPath 없을 때만 적용)
  final Color? color;

  /// 말풍선 배치 방향(left/right)
  final HelpPlacement placement;

  /// 말풍선 위치 미세 조정
  final Offset offset;

  /// 아이콘과 말풍선 사이 간격(px). 작을수록 더 바짝 붙음(음수도 가능)
  final double gap;

  /// 접근성 라벨
  final String semanticLabel;

  @override
  State<HelpBadge> createState() => _HelpBadgeState();
}

class _HelpBadgeState extends State<HelpBadge> {
  final GlobalKey _anchorKey = GlobalKey();
  OverlayEntry? _overlay;
  bool _hovering = false; // 데스크톱/웹
  bool _openByTap = false; // 모바일/터치

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
        onEnter: (_) {
          _hovering = true;
          _showOverlay();
        },
        onExit: (_) {
          _hovering = false;
          if (!_openByTap) _removeOverlay();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // 모바일/터치: 탭 토글
            _openByTap = !_openByTap;
            if (_openByTap) {
              _showOverlay();
            } else {
              if (!_hovering) _removeOverlay();
            }
          },
          child: Container(
            key: _anchorKey,
            padding: const EdgeInsets.all(4),
            child: icon,
          ),
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
          Icons.help_outline_rounded,
          size: widget.size,
          color: widget.color ?? Colors.grey.shade500,
        ),
      );
    }
    return Icon(
      Icons.help_outline_rounded,
      size: widget.size,
      color: widget.color ?? Colors.grey.shade500,
    );
  }

  void _showOverlay() {
    if (_overlay != null) return;

    final anchor = _anchorKey.currentContext;
    if (anchor == null) return;

    final renderBox = anchor.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlayBox == null) return;

    final anchorSize = renderBox.size;
    final topLeft  = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final topRight = renderBox.localToGlobal(Offset(anchorSize.width, 0), ancestor: overlayBox);

    // 아이콘과 말풍선 간격(px)
    final gap = widget.gap;

    // 세로는 아이콘 중앙 근처에 배치
    Offset pos;
    switch (widget.placement) {
      case HelpPlacement.right:
        // 아이콘 오른쪽에 딱 붙이듯이
        pos = topRight + Offset(gap, -(anchorSize.height * 0.5));
        break;
      case HelpPlacement.left:
        // 아이콘 왼쪽에 딱 붙이듯이 (살짝 겹치고 싶으면 gap을 음수로)
        pos = topLeft + Offset(-gap, -(anchorSize.height * 0.5));
        break;
    }

    // 최종 미세 조정
    pos += widget.offset;

    _overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: pos.dx,
        top:  pos.dy,
        child: _HelpBubble(
          text: widget.tooltip,
          marginScreen: const EdgeInsets.all(8),
        ),
      ),
    );

    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }
}

/// 오버레이 말풍선
class _HelpBubble extends StatelessWidget {
  const _HelpBubble({
    required this.text,
    this.marginScreen = EdgeInsets.zero,
  });

  final String text;
  final EdgeInsets marginScreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: marginScreen,
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: DefaultTextStyle( // << const 제거
        style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
        child: Text(text),      // << 전달된 텍스트 사용
        // 또는 child: SelectableText(text),
      ),
    );
  }
}

/// 배치 방향
enum HelpPlacement { right, left }
