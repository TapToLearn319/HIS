import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../sidebar_menu.dart';
import '../../provider/hub_provider.dart';

const _kAppBg = Color(0xFFF6FAFF);

const String kRouteRandomSeatPresenter = '/random-seat/presenter';
const String kRouteRandomSeatCreate = '/random-seat/create';

class RandomSeatFilesPage extends StatelessWidget {
  const RandomSeatFilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final hubId = context.watch<HubProvider>().hubId;

    return AppScaffold(
      selectedIndex: 1,
      body: Scaffold(
        backgroundColor: _kAppBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child:
                hubId == null
                    ? const Center(child: Text('허브가 설정되지 않았습니다.'))
                    : _FilesGrid(hubId: hubId),
          ),
        ),

        floatingActionButton: _CreateFab(
          onTap: () {
            Navigator.pushNamed(context, kRouteRandomSeatCreate);
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}

class _FilesGrid extends StatelessWidget {
  const _FilesGrid({required this.hubId});
  final String hubId;

  Future<void> _showMoreMenu(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final fs = FirebaseFirestore.instance;

    final action = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 100, 24, 0),
      items: const [
        PopupMenuItem(value: 'open', child: Text('Open')),
        PopupMenuItem(value: 'rename', child: Text('Rename')),
        PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );

    if (action == null) return;

    // 공통 레퍼런스
    final fileRef = fs.doc('hubs/$hubId/randomSeatFiles/${doc.id}');
    final seatCol = fs.collection(
      'hubs/$hubId/randomSeatFiles/${doc.id}/seatMap',
    );

    switch (action) {
      case 'open':
        Navigator.pushNamed(
          context,
          kRouteRandomSeatPresenter,
          arguments: {'fileId': doc.id},
        );
        break;

      case 'rename':
        {
          final ctrl = TextEditingController(
            text: (data['title'] ?? '').toString(),
          );
          final ok = await showDialog<bool>(
            context: context,
            builder:
                (_) => AlertDialog(
                  title: const Text('Rename'),
                  content: TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(hintText: 'Enter title'),
                    autofocus: true,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Save'),
                    ),
                  ],
                ),
          );
          if (ok == true) {
            await fileRef.set({
              'title': ctrl.text.trim().isEmpty ? 'Untitled' : ctrl.text.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
          break;
        }

      case 'duplicate':
        {
          // 새 문서 만들기
          final newRef = fs.collection('hubs/$hubId/randomSeatFiles').doc();
          // 메타 복사
          final meta = Map<String, dynamic>.from(data);
          meta['title'] = '${(meta['title'] ?? 'Untitled')} (copy)';
          meta['createdAt'] = FieldValue.serverTimestamp();
          meta['updatedAt'] = FieldValue.serverTimestamp();
          await newRef.set(meta, SetOptions(merge: true));

          // seatMap 복사
          final seats = await seatCol.get();
          final batch = fs.batch();
          for (final s in seats.docs) {
            final dst = newRef.collection('seatMap').doc(s.id);
            batch.set(dst, s.data());
          }
          await batch.commit();

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Duplicated.')));
          break;
        }

      case 'delete':
        {
          final ok = await showDialog<bool>(
            context: context,
            builder:
                (_) => AlertDialog(
                  title: const Text('Delete'),
                  content: const Text(
                    'This file and its seat map will be deleted.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
          );
          if (ok == true) {
            // seatMap 먼저 삭제
            final seats = await seatCol.get();
            final batch = fs.batch();
            for (final s in seats.docs) {
              batch.delete(s.reference);
            }
            batch.delete(fileRef);
            await batch.commit();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Deleted.')));
          }
          break;
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    final q = fs
        .collection('hubs/$hubId/randomSeatFiles')
        .orderBy('updatedAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const _EmptyView();
        }

        final w = MediaQuery.sizeOf(context).width;
        final cross = w >= 1100 ? 3 : (w >= 800 ? 2 : 1);

        return GridView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 467 / 301,
          ),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i];
            final data = d.data();
            final title = (data['title'] as String?)?.trim() ?? d.id;
            final cols = (data['cols'] as num?)?.toInt() ?? 6;
            final rows = (data['rows'] as num?)?.toInt() ?? 4;
            final total = (data['total'] as num?)?.toInt();
            final type = (data['type'] as String?) ?? 'individual';
            final createdAt =
                _readTs(data['createdAt']) ?? _readTs(data['updatedAt']);
            final createdStr = createdAt != null ? _fmtDate(createdAt) : '-';

            return _FileCard(
              title: title,
              cols: cols,
              rows: rows,
              total: total,
              type: type,
              dateStr: createdStr,
              onOpen: () {
                Navigator.pushNamed(
                  context,
                  kRouteRandomSeatPresenter,
                  arguments: {'fileId': d.id},
                );
              },
              onMore: () => _showMoreMenu(context, d),
            );
          },
        );
      },
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.title,
    required this.cols,
    required this.rows,
    required this.type,
    required this.dateStr,
    this.total,
    required this.onOpen,
    required this.onMore,
  });

  final String title;
  final int cols;
  final int rows;
  final int? total;
  final String type;
  final String dateStr;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final typeLabel = type == 'group' ? 'group' : 'individual';
    final typeColor =
        type == 'group' ? const Color(0x33A0DA1B) : const Color(0x339A6EFF);
    final typeTextColor =
        type == 'group' ? const Color(0xFF87BC0E) : const Color(0xFF9A6EFF);

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD2D2D2), width: 1),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF001A36),
                    ),
                  ),
                ),
                Container(
                  width: 95,
                  height: 36,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    typeLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: typeTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(
              color: Color(0xFFD9D9D9),
              thickness: 1,
              height: 1,
            ),
            const SizedBox(height: 12),

            _infoRow(
              Icons.grid_view_rounded,
              '${cols} column arrangement${rows > 1 ? ' / $rows row' : ''}',
            ),
            const SizedBox(height: 6),
            if (total != null)
              _infoRow(Icons.people_alt_outlined, 'Total $total'),
            const Spacer(),

SizedBox(
  width: double.infinity,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      OutlinedButton(
        onPressed: onMore,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
          minimumSize: const Size(80, 31),
          side: const BorderSide(color: Color.fromRGBO(0, 0, 0, 0.1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        child: const Text(
          'more ›',
          style: TextStyle(
            fontSize: 13.3,
            fontWeight: FontWeight.w400,
            fontFamily: 'Pretendard Variable',
            color: Colors.black,
            height: 1.0,
          ),
        ),
      ),
    ],
  ),
),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.black87),
        const SizedBox(width: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: Colors.black,
            height: 2.5,
          ),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.event_seat, size: 72, color: Colors.black26),
          SizedBox(height: 10),
          Text(
            '아직 생성된 랜덤시팅 파일이 없어요.\n오른쪽 아래 CREATE로 새로 만들어보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateFab extends StatelessWidget {
  const _CreateFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Tooltip(
            message: 'Create new random seat file',
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                'assets/logo_bird_create.png',
                fit: BoxFit.contain,
                errorBuilder:
                    (_, __, ___) => const Icon(
                      Icons.add_circle,
                      size: 64,
                      color: Colors.indigo,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

DateTime? _readTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  return null;
}

String _fmtDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}
