import 'package:flutter/material.dart';

import 'vote_models.dart';

class VoteEditPage extends StatefulWidget {
  final Vote? initial;                            // null이면 생성, 아니면 수정
  const VoteEditPage({super.key, this.initial});
  
  @override
  State<VoteEditPage> createState() => _VoteEditPageState();
}

class _VoteEditPageState extends State<VoteEditPage> {
  late final TextEditingController _titleCtrl;
  VoteType _type = VoteType.binary;
  final List<TextEditingController> _optionCtrls = [];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initial?.title ?? '');
    _type = widget.initial?.type ?? VoteType.binary;

    final options = widget.initial?.options ?? const ['보기 1', '보기 2'];
    for (final o in options) {
      _optionCtrls.add(TextEditingController(text: o));
    }
    if (_type == VoteType.binary) {
      _ensureBinaryOptions();
    }
  }

  void _ensureBinaryOptions() {
    // 편집 화면에서 binary를 선택하면 옵션은 고정적으로 보여주되 비활성화
    _optionCtrls
      ..clear()
      ..addAll([TextEditingController(text: '찬성'), TextEditingController(text: '반대')]);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? '투표 수정' : '투표 생성')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: '투표 제목',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<VoteType>(
            segments: const [
              ButtonSegment(value: VoteType.binary, label: Text('찬반')),
              ButtonSegment(value: VoteType.multiple, label: Text('문항 선택')),
            ],
            selected: {_type},
            onSelectionChanged: (s) {
              setState(() {
                _type = s.first;
                if (_type == VoteType.binary) {
                  _ensureBinaryOptions();
                } else if (_optionCtrls.length < 2) {
                  _optionCtrls
                    ..clear()
                    ..addAll([TextEditingController(text: '보기 1'), TextEditingController(text: '보기 2')]);
                }
              });
            },
          ),
          const SizedBox(height: 16),
          if (_type == VoteType.multiple) ...[
            const Text('문항 (2개 이상)'),
            const SizedBox(height: 8),
            ..._optionCtrls.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: e.value,
                        decoration: InputDecoration(
                          hintText: '보기 ${e.key + 1}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _optionCtrls.length <= 2
                          ? null
                          : () => setState(() => _optionCtrls.removeAt(e.key)),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _optionCtrls.add(TextEditingController(text: ''));
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('문항 추가'),
              ),
            ),
          ] else ...[
            const Text('문항'),
            const SizedBox(height: 8),
            ..._optionCtrls.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: c,
                  enabled: false,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              final title = _titleCtrl.text.trim();
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('제목을 입력하세요.')),
                );
                return;
              }
              final List<String> options = _type == VoteType.binary
                  ? const ['찬성', '반대']
                  : _optionCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
              if (_type == VoteType.multiple && options.length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('문항은 2개 이상이어야 합니다.')),
                );
                return;
              }

              Navigator.pop(context, Vote(
                id: widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                title: title,
                type: _type,
                options: options,
                status: widget.initial?.status ?? VoteStatus.draft,
              ));
            },
            child: Text(isEdit ? '저장' : '생성'),
          ),
        ],
      ),
    );
  }
}