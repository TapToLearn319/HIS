import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../../provider/session_provider.dart';
import '../../../provider/hub_provider.dart'; // ⬅️ 추가
import 'vote_edit.dart';
import 'vote_models.dart';

class VoteManagerPage extends StatelessWidget {
  const VoteManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sid = context.watch<SessionProvider>().sessionId;
    final hubId = context.watch<HubProvider>().hubId; // ⬅️ 추가
    if (sid == null) {
      return const Scaffold(
        body: Center(child: Text('No session. Please set a session first.')),
      );
    }
    if (hubId == null || hubId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No hub. Please set a hub first.')),
      );
    }
    return ChangeNotifierProvider(
      // create: (_) => VoteStore(sessionId: sid),
      create: (_) => VoteStore(hubId: hubId), // ⬅️ 허브 기반으로 변경
      child: const _VoteManagerScaffold(),
    );
  }
}

class _VoteManagerScaffold extends StatefulWidget {
  const _VoteManagerScaffold();

  @override
  State<_VoteManagerScaffold> createState() => _VoteManagerScaffoldState();
}

class _VoteManagerScaffoldState extends State<_VoteManagerScaffold> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _quickAddCtrl = TextEditingController();
  String _keyword = '';
  bool _busy = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _quickAddCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<VoteStore>();
    final sid = context.read<SessionProvider>().sessionId!;
    final hubId = context.read<HubProvider>().hubId!; // ⬅️ 추가

    final items = store.items.where((v) {
      if (_keyword.isEmpty) return true;
      final k = _keyword.toLowerCase();
      return v.title.toLowerCase().contains(k);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Vote'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
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
          ),
        ],
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, -2))],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _quickAddCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.add_circle_outline),
                  hintText: 'Add a question',
                  filled: true,
                  fillColor: const Color(0xFFF3F6FC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black12.withOpacity(0.06)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black12.withOpacity(0.06)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF8CA8FF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) => _quickAdd(context),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(onPressed: () => _quickAdd(context), child: const Text('Add')),
          ],
        ),
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopInfoBar(
            classLabel: 'Class : ${sid.substring(0, sid.length > 4 ? 4 : sid.length)}  |  Mathematics',
            searchController: _searchCtrl,
            onChanged: (s) => setState(() => _keyword = s.trim()),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No questions. Use “새 투표” or quick add below.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final v = items[i];
                      return _VoteCardItem(
                        vote: v,
                        onStart: (v) async {
                          if (v.type == VoteType.multiple && v.options.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('문항형 투표는 옵션이 2개 이상이어야 합니다.')),
                            );
                            return;
                          }
                          setState(() => _busy = true);
                          try {
                            await _stopAllActive(hubId); // ⬅️ 허브 기준으로 변경
                            await store.startVote(v.id);
                            _broadcastStart(sid, v); // 방송 포맷은 그대로 두었음
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                        onStop: (v) async {
                          setState(() => _busy = true);
                          try {
                            await store.closeVote(v.id);
                            _broadcastClose(sid, v.id);
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                        onEdit: (v) async {
                          final edited = await Navigator.push<Vote>(
                            context,
                            MaterialPageRoute(builder: (_) => VoteEditPage(initial: v)),
                          );
                          if (edited != null) {
                            await store.updateVote(edited);
                            await store.syncActiveIfNeeded(edited.id);
                          }
                        },
                        onDelete: (v) async {
                          setState(() => _busy = true);
                          try {
                            await store.deleteVote(v.id);
                            _broadcastDelete(sid, v.id);
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _quickAdd(BuildContext context) async {
    final text = _quickAddCtrl.text.trim();
    if (text.isEmpty) return;
    await context.read<VoteStore>().createVote(
          title: text,
          type: VoteType.binary,
          options: const ['찬성', '반대'],
        );
    _quickAddCtrl.clear();
  }

  Future<void> _stopAllActive(String hubId) async { // ⬅️ 시그니처/경로 허브 기준
    final fs = FirebaseFirestore.instance;
    final running =
        await fs.collection('hubs/$hubId/votes').where('status', isEqualTo: 'active').get();
    final batch = fs.batch();
    final now = FieldValue.serverTimestamp();
    for (final d in running.docs) {
      batch.set(d.reference, {'status': 'closed', 'endedAt': now, 'updatedAt': now}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  void _broadcastStart(String sid, Vote v) {
    channel.postMessage(jsonEncode({
      'type': 'vote_start',
      'sid': sid,
      'voteId': v.id,
      'title': v.title,
      'voteType': v.type == VoteType.binary ? 'binary' : 'multiple',
    }));
  }

  void _broadcastClose(String sid, String voteId) {
    channel.postMessage(jsonEncode({'type': 'vote_close', 'sid': sid, 'voteId': voteId}));
  }

  void _broadcastDelete(String sid, String voteId) {
    channel.postMessage(jsonEncode({'type': 'vote_delete', 'sid': sid, 'voteId': voteId}));
  }
}

class _TopInfoBar extends StatelessWidget {
  const _TopInfoBar({
    required this.classLabel,
    required this.searchController,
    required this.onChanged,
  });

  final String classLabel;
  final TextEditingController searchController;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Expanded(
            child: Text(
              classLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 260,
            child: TextField(
              controller: searchController,
              onChanged: onChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search Tools',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF3F6FC),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black12.withOpacity(0.06)),
                  borderRadius: BorderRadius.circular(20),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black12.withOpacity(0.06)),
                  borderRadius: BorderRadius.circular(20),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF8CA8FF)),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteCardItem extends StatelessWidget {
  const _VoteCardItem({
    required this.vote,
    required this.onStart,
    required this.onStop,
    required this.onEdit,
    required this.onDelete,
  });

  final Vote vote;
  final ValueChanged<Vote> onStart;
  final ValueChanged<Vote> onStop;
  final ValueChanged<Vote> onEdit;
  final ValueChanged<Vote> onDelete;

  @override
  Widget build(BuildContext context) {
    final isActive = vote.status == VoteStatus.active;
    final bg = const Color(0xFFEFF5FF);
    final border = const Color(0xFFDBE6FF);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 + 삭제
          Row(
            children: [
              Expanded(
                child: Text(
                  vote.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.close),
                onPressed: () => onDelete(vote),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              _StatusChip(status: vote.status),
              const Spacer(),
              if (!isActive)
                OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                  onPressed: () => onStart(vote),
                ),
              if (isActive)
                FilledButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  onPressed: () => onStop(vote),
                ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
                onPressed: () => onEdit(vote),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final VoteStatus status;

  @override
  Widget build(BuildContext context) {
    late Color c;
    late String t;
    switch (status) {
      case VoteStatus.draft:
        c = const Color(0xFFFFC36D);
        t = 'Private';
        break;
      case VoteStatus.active:
        c = const Color(0xFF41C983);
        t = 'Active';
        break;
      case VoteStatus.closed:
        c = Colors.grey;
        t = 'Closed';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c),
      ),
      child: Text(
        t,
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
