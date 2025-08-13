

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../main.dart';
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

class _VoteManagerBody extends StatelessWidget {
  const _VoteManagerBody();

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
                      onPressed: () async {
                        // ✅ 시작 전 검증: 문항형은 옵션 2개 이상
                        if (v.type == VoteType.multiple &&
                            v.options.length < 2) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('문항형 투표는 옵션이 2개 이상이어야 합니다.'),
                            ),
                          );
                          return;
                        }

                        await context.read<VoteStore>().startVote(v.id);
                        await _upsertVoteToFirestore(
                          v.copyWith(status: VoteStatus.active),
                        );
                        _broadcastStart(v); // 트랜잭션 완료 후 방송
                      },
                      icon: const Icon(Icons.play_arrow),
                    ),
                  if (v.status == VoteStatus.active)
                    IconButton(
                      tooltip: '종료',
                      onPressed: () async {
                        await context.read<VoteStore>().closeVote(v.id);
                        await _setVoteActive(v.id, false);
                        _broadcastClose(v.id);
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
                        // 진행중이면 옵션 변경을 Firestore에도 반영(득표는 제목 기준 유지)
                        await _maybeSyncIfActive(edited);
                      }
                    },
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    tooltip: '삭제',
                    onPressed: () async {
                      await context.read<VoteStore>().deleteVote(v.id);
                      await _deleteVoteFromFirestore(v.id);
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
        return '시작 전';
      case VoteStatus.active:
        return '진행 중';
      case VoteStatus.closed:
        return '종료';
    }
  }

  /// Firestore 문서가 있으면 안전 파싱 후 옵션을 제목 기준으로 머지(기존 득표 유지).
  /// 없으면 새 문서 생성.
  Future<void> _upsertVoteToFirestore(Vote v) async {
    final docRef = FirebaseFirestore.instance.collection('votes').doc(v.id);
    final isMultiple = v.type == VoteType.multiple;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);

      // 기존 옵션 안전 파싱
      final existingOptions = <_Option>[];
      if (snap.exists) {
        final data = (snap.data() ?? {}) as Map<String, dynamic>;
        final rawOptions = data['options'];
        if (rawOptions is List) {
          for (final item in rawOptions) {
            if (item is Map) {
              final id = item['id'];
              final title = item['title'];
              final votes = item['votes'];
              existingOptions.add(
                _Option(
                  id: (id is String) ? id : (title?.toString() ?? ''),
                  title: (title is String) ? title : (id?.toString() ?? ''),
                  votes: (votes is num) ? votes.toInt() : 0,
                ),
              );
            } else if (item is String) {
              existingOptions.add(_Option(id: item, title: item, votes: 0));
            }
          }
        }
      }

      // 편집 화면의 옵션 목록(문자열들)을 기준으로 머지
      final desiredTitles =
          v.options
              .map((e) => e.toString().trim())
              .where((t) => t.isNotEmpty)
              .toList();
      final merged = _mergeOptionsByTitle(existingOptions, desiredTitles);

      // 문서 쓰기
      tx.set(docRef, {
        'title': v.title,
        'type': isMultiple ? 'multiple' : 'binary',
        'active': v.status == VoteStatus.active,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
        'options':
            merged
                .asMap()
                .entries
                .map(
                  (e) => {
                    'id': e.value.id.isNotEmpty ? e.value.id : 'opt_${e.key}',
                    'title': e.value.title,
                    'votes': e.value.votes,
                  },
                )
                .toList(),
      }, SetOptions(merge: true));
    });
  }

  /// 진행중(active) 문서는 편집 시에도 Firestore 동기화(득표 유지).
  Future<void> _maybeSyncIfActive(Vote v) async {
    final doc =
        await FirebaseFirestore.instance.collection('votes').doc(v.id).get();
    final active =
        (doc.data()?['active'] is bool)
            ? (doc.data()?['active'] as bool)
            : false;
    if (active) {
      await _upsertVoteToFirestore(v.copyWith(status: VoteStatus.active));
    }
  }

  Future<void> _setVoteActive(String id, bool active) async {
    await FirebaseFirestore.instance.collection('votes').doc(id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteVoteFromFirestore(String id) async {
    await FirebaseFirestore.instance.collection('votes').doc(id).delete();
  }

  void _broadcastStart(Vote v) {
    channel.postMessage(
      jsonEncode({
        'type': 'vote_start',
        'voteId': v.id,
        'title': v.title,
        'voteType': v.type == VoteType.binary ? 'binary' : 'multiple',
      }),
    );
  }

  void _broadcastClose(String voteId) {
    channel.postMessage(jsonEncode({'type': 'vote_close', 'voteId': voteId}));
  }

  void _broadcastDelete(String id) {
    channel.postMessage(jsonEncode({'type': 'vote_delete', 'voteId': id}));
  }
}

/* ----------------- 내부 머지 도우미 ----------------- */

class _Option {
  final String id;
  final String title;
  final int votes;
  _Option({required this.id, required this.title, required this.votes});
}

/// Firestore에 이미 저장된 옵션(existing)을 유지하되,
/// 편집 화면의 옵션(desiredTitles) 순서/구성을 반영.
/// - 제목이 동일하면 투표수 유지
/// - 새로 추가된 제목은 votes=0
/// - 빠진 제목은 제거
List<_Option> _mergeOptionsByTitle(
  List<_Option> existing,
  List<String> desiredTitles,
) {
  final map = <String, _Option>{};
  for (final e in existing) {
    map[_norm(e.title)] = e;
  }
  final out = <_Option>[];
  for (final title in desiredTitles) {
    final key = _norm(title);
    if (map.containsKey(key)) {
      final keep = map[key]!;
      out.add(_Option(id: keep.id, title: keep.title, votes: keep.votes));
    } else {
      out.add(_Option(id: '', title: title, votes: 0));
    }
  }
  return out;
}

String _norm(String s) => s.trim().toLowerCase();
