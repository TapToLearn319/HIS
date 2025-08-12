
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
    return Vote(
      id: doc.id,
      title: (d['title'] == null) ? '' : d['title'].toString(),
      type: _voteTypeFromString(d['type']?.toString()),
      options:
          ((d['options'] as List?) ?? const [])
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList(),
      status: _voteStatusFromString(d['status']?.toString()),
    );
  }
}

class VoteStore extends ChangeNotifier {
  final _col = FirebaseFirestore.instance.collection('votes');
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  final List<Vote> _items = [];
  List<Vote> get items => List.unmodifiable(_items);

  VoteStore() {
    _sub = _col.snapshots().listen((snap) {
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
    final data =
        Vote(
            id: '_new',
            title: title,
            type: type,
            options:
                type == VoteType.binary
                    ? const ['찬성', '반대']
                    : options.map((e) => e.toString()).toList(),
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
    await _col.doc(id).update({
      'status': _voteStatusToString(VoteStatus.active),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> closeVote(String id) async {
    await _col.doc(id).update({
      'status': _voteStatusToString(VoteStatus.closed),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

String _voteTypeToString(VoteType t) {
  switch (t) {
    case VoteType.binary:
      return 'binary';
    case VoteType.multiple:
      return 'multiple';
  }
}

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

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:wave_progress_indicator/wave_progress_indicator.dart';
// import 'package:project/main.dart';

// class DebatePage extends StatefulWidget {
//   const DebatePage({super.key});

//   @override
//   State<DebatePage> createState() => _DebatePageState();
// }

// class _DebatePageState extends State<DebatePage> {
//   int agreeCount = 0;
//   int disagreeCount = 0;

//   @override
//   void initState() {
//     super.initState();
//     // 학생 화면에 수업 도구 모드를 debate로 전달
//     channel.postMessage(jsonEncode({'type': 'tool_mode', 'mode': 'debate'}));
//   }

//   // 버튼 클릭 시 찬성/반대 수치 갱신 및 학생 화면에 전송
//   void _vote(bool agree) {
//     setState(() {
//       if (agree) {
//         agreeCount++;
//       } else {
//         disagreeCount++;
//       }
//     });

//     channel.postMessage(
//       jsonEncode({
//         'type': 'debate_vote',
//         'agree': agree,
//         'agreeCount': agreeCount,
//         'disagreeCount': disagreeCount,
//       }),
//     );
//   }

//   // 비율 계산 함수
//   double _getRatio(bool agree) {
//     final total = agreeCount + disagreeCount;
//     if (total == 0) return 0.0;
//     return agree ? agreeCount / total : disagreeCount / total;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFFFFBF2),
//       appBar: AppBar(title: const Text('수업 도구 - DEBATE')),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 // 찬성 도형
//                 GestureDetector(
//                   onTap: () => _vote(true),
//                   child: _buildWaveBalloon(
//                     label: "찬성",
//                     value: _getRatio(true),
//                     gradientColors: [Colors.redAccent, Colors.red],
//                   ),
//                 ),
//                 // 반대 도형
//                 GestureDetector(
//                   onTap: () => _vote(false),
//                   child: _buildWaveBalloon(
//                     label: "반대",
//                     value: _getRatio(false),
//                     gradientColors: [Colors.blueAccent, Colors.blue],
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // WaveProgressIndicator를 원형 안에 감싸서 도형 형태로 표시
//   Widget _buildWaveBalloon({
//     required String label,
//     required double value,
//     required List<Color> gradientColors,
//   }) {
//     return Column(
//       children: [
//         Container(
//           width: 200,
//           height: 200,
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             color: Colors.white,
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withAlpha(128),
//                 spreadRadius: 2,
//                 blurRadius: 4,
//               ),
//             ],
//           ),
//           child: ClipOval(
//             child: TweenAnimationBuilder<double>(
//               tween: Tween<double>(begin: 0.0, end: value),
//               duration: const Duration(milliseconds: 800), // 애니메이션 속도
//               curve: Curves.easeOut, // 곡선 애니메이션
//               builder: (context, animatedValue, _) {
//                 return WaveProgressIndicator(
//                   value: animatedValue, // 애니메이션된 비율
//                   gradientColors: gradientColors, // 파도 색상
//                   waveHeight: 15.0, // 파도 높이
//                   speed: 2.5, // 파도 속도
//                   borderRadius: BorderRadius.circular(100), // 도형 경계 (원형)
//                   child: Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Text(
//                           label,
//                           style: const TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           "${(value * 100).toStringAsFixed(0)}%",
//                           style: TextStyle(
//                             fontSize: 20,
//                             color: animatedValue >= 0.5 ? Colors.white : Colors.black,
//                             shadows: [
//                               Shadow(
//                                 offset: Offset(0, 0),
//                                 blurRadius: 4.0,
//                                 color: Colors.black26,
//                               )
//                             ]
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ),
//         const SizedBox(height: 12),
//       ],
//     );
//   }
// }
