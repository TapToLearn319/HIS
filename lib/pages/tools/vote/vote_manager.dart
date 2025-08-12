
// lib/pages/tools/vote/vote_manager.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../main.dart'; // ✅ 전역 channel 사용
import 'vote_models.dart';
import 'vote_edit.dart';

class VoteManagerPage extends StatelessWidget {
  const VoteManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VoteStore(),
      child: const _VoteManagerBody(),
    );
  }
}

class _VoteManagerBody extends StatefulWidget {
  const _VoteManagerBody();

  @override
  State<_VoteManagerBody> createState() => _VoteManagerBodyState();
}

class _VoteManagerBodyState extends State<_VoteManagerBody> {
  @override
  void initState() {
    super.initState();
    channel.postMessage(jsonEncode({'type': 'tool_mode', 'mode': 'vote'}));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<VoteStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('투표 관리')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<Vote>(
            context,
            MaterialPageRoute(builder: (_) => const VoteEditPage()),
          );
          if (created != null) {
            await store.createVote(
              title: created.title,
              type: created.type,
              options: created.options,
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('새 투표'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: store.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final v = store.items[i];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              title: Text(
                v.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${v.type == VoteType.binary ? '찬반' : '문항선택'} · ${_statusLabel(v.status)}'
                '${v.type == VoteType.multiple ? ' · 문항 ${v.options.length}개' : ''}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (v.status != VoteStatus.active)
                    IconButton(
                      tooltip: '시작',
                      onPressed: () {
                        context.read<VoteStore>().startVote(v.id);
                        _broadcastStart(v);
                      },
                      icon: const Icon(Icons.play_arrow),
                    ),
                  if (v.status == VoteStatus.active)
                    IconButton(
                      tooltip: '종료',
                      onPressed: () {
                        context.read<VoteStore>().closeVote(v.id);
                        _broadcastClose(v);
                      },
                      icon: const Icon(Icons.stop),
                    ),
                  IconButton(
                    tooltip: '편집',
                    onPressed: () async {
                      final edited = await Navigator.push<Vote>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VoteEditPage(initial: v),
                        ),
                      );
                      if (edited != null) {
                        await context.read<VoteStore>().updateVote(edited);
                      }
                    },
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    tooltip: '삭제',
                    onPressed: () async {
                      await context.read<VoteStore>().deleteVote(v.id);
                      _broadcastDelete(v.id);
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _statusLabel(VoteStatus s) {
    switch (s) {
      case VoteStatus.draft:
        return '초안';
      case VoteStatus.active:
        return '진행중';
      case VoteStatus.closed:
        return '종료';
    }
  }

  void _broadcastStart(Vote v) {
    channel.postMessage(
      jsonEncode({
        'type': 'vote_start',
        'voteId': v.id,
        'title': v.title,
        'voteType': v.type == VoteType.binary ? 'binary' : 'multiple',
        'options': v.options,
      }),
    );
  }

  void _broadcastClose(Vote v) {
    channel.postMessage(jsonEncode({'type': 'vote_close', 'voteId': v.id}));
  }

  void _broadcastDelete(String id) {
    channel.postMessage(jsonEncode({'type': 'vote_delete', 'voteId': id}));
  }
}
