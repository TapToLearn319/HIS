import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum VoteType { binary, multiple }
enum VoteStatus { draft, active, closed }

@immutable
class Vote {
  final String id;
  final String title;
  final VoteType type;

  final List<String> options;
  final VoteStatus status;

  const Vote({
    required this.id,
    required this.title,
    required this.type,
    required this.options,
    required this.status,
  });

  Vote copyWith({
    String? id,
    String? title,
    VoteType? type,
    List<String>? options,
    VoteStatus? status,
  }) {
    return Vote(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      options: options ?? this.options,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': _voteTypeToString(type),
      'options': options,
      'status': _voteStatusToString(status),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Vote fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};

    final rawOptions = (d['options'] as List?) ?? const [];
    final parsedTitles = <String>[];
    for (final item in rawOptions) {
      if (item is String) {
        final t = item.trim();
        if (t.isNotEmpty) parsedTitles.add(t);
      } else if (item is Map) {
        final t = (item['title'] ?? '').toString().trim();
        if (t.isNotEmpty) parsedTitles.add(t);
      }
    }

    final String? rawStatus = d['status']?.toString();
    final bool? activeBool = (d['active'] is bool) ? d['active'] as bool : null;
    final VoteStatus status = (rawStatus != null)
        ? _voteStatusFromString(rawStatus)
        : (activeBool == true ? VoteStatus.active : VoteStatus.draft);

    return Vote(
      id: doc.id,
      title: (d['title'] ?? '').toString(),
      type: _voteTypeFromString(d['type']?.toString()),
      options: parsedTitles,
      status: status,
    );
  }
}

class VoteStore extends ChangeNotifier {
  final String sessionId;
  final CollectionReference<Map<String, dynamic>> _col;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  final List<Vote> _items = [];
  List<Vote> get items => List.unmodifiable(_items);

  VoteStore({required this.sessionId})
      : _col = FirebaseFirestore.instance.collection('sessions/$sessionId/votes') {
    _sub = _col.orderBy('createdAt', descending: true).snapshots().listen((snap) {
      _items
        ..clear()
        ..addAll(snap.docs.map(Vote.fromDoc));
      notifyListeners();
    });
  }

  Future<void> createVote({
    required String title,
    required VoteType type,
    required List<String> options,
  }) async {
    final normalizedOptions = (type == VoteType.binary)
        ? const ['찬성', '반대']
        : options.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();

    final data = Vote(
      id: '_new',
      title: title,
      type: type,
      options: normalizedOptions,
      status: VoteStatus.draft,
    ).toMap()
      ..putIfAbsent('createdAt', () => FieldValue.serverTimestamp());

    await _col.add(data);
  }

  Future<void> updateVote(Vote updated) async {
    await _col.doc(updated.id).update(updated.toMap());
  }

  Future<void> deleteVote(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> startVote(String id) async {
    await _col.doc(id).set({
      'status': _voteStatusToString(VoteStatus.active),
      'startedAt': FieldValue.serverTimestamp(),
      'endedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> closeVote(String id) async {
    final endedAtTS = Timestamp.now();
    await _col.doc(id).set({
      'status': _voteStatusToString(VoteStatus.closed),
      'endedAt': endedAtTS,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> syncActiveIfNeeded(String id) async {
    final snap = await _col.doc(id).get();
    final data = snap.data();
    if (data == null) return;
    final isActive = data['status'] == 'active';
    if (!isActive) return;

    final raw = (data['options'] as List?) ?? const [];
    final existing = <Map<String, dynamic>>[];
    for (final it in raw) {
      if (it is Map) {
        existing.add({
          'id': (it['id'] ?? '').toString(),
          'title': (it['title'] ?? '').toString(),
          'votes': (it['votes'] is num) ? (it['votes'] as num).toInt() : 0,
          'binding': (it['binding'] is Map) ? (it['binding'] as Map) : const {},
        });
      } else if (it is String) {
        existing.add({'id': it, 'title': it, 'votes': 0});
      }
    }

    final edited = items.firstWhere((e) => e.id == id, orElse: () => throw Exception('vote not found'));
    final desired = edited.options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final mapByNorm = {for (final o in existing) _norm((o['title'] ?? '').toString()): o};
    final rebuilt = <Map<String, dynamic>>[];
    for (var i = 0; i < desired.length; i++) {
      final t = desired[i];
      final k = _norm(t);
      if (mapByNorm.containsKey(k)) {
        final keep = mapByNorm[k]!;
        rebuilt.add({
          'id': keep['id'] ?? 'opt_$i',
          'title': keep['title'] ?? t,
          'votes': keep['votes'] ?? 0,
          if (keep['binding'] != null) 'binding': keep['binding'],
        });
      } else {
        rebuilt.add({'id': 'opt_$i', 'title': t, 'votes': 0});
      }
    }

    await _col.doc(id).update({'options': rebuilt, 'updatedAt': FieldValue.serverTimestamp()});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

String _voteTypeToString(VoteType t) => t == VoteType.binary ? 'binary' : 'multiple';

VoteType _voteTypeFromString(String? s) {
  switch (s) {
    case 'binary':
      return VoteType.binary;
    case 'multiple':
      return VoteType.multiple;
    default:
      return VoteType.binary;
  }
}

String _voteStatusToString(VoteStatus s) {
  switch (s) {
    case VoteStatus.draft:
      return 'draft';
    case VoteStatus.active:
      return 'active';
    case VoteStatus.closed:
      return 'closed';
  }
}

VoteStatus _voteStatusFromString(String? s) {
  switch (s) {
    case 'draft':
      return VoteStatus.draft;
    case 'active':
      return VoteStatus.active;
    case 'closed':
      return VoteStatus.closed;
    default:
      return VoteStatus.draft;
  }
}

String _norm(String s) => s.trim().toLowerCase();