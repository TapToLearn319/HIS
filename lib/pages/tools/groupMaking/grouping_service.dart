import 'dart:math';

class GroupingService {
  const GroupingService();

  List<List<String>> generate({
    required List<String> selected,
    required bool byGroups,
    required int groupsCount,
    required int sizePerGroup,
    Random? random,
  }) {
    final rnd = random ?? Random();
    final names = [...selected]..shuffle(rnd);

    if (byGroups) {
      final n = groupsCount.clamp(1, names.length);
      final groups = List.generate(n, (_) => <String>[]);
      for (int i = 0; i < names.length; i++) {
        groups[i % n].add(names[i]);
      }
      return groups;
    } else {
      final size = sizePerGroup.clamp(1, names.length);
      final n = (names.length / size).ceil();
      final groups = List.generate(n, (_) => <String>[]);
      int gi = 0;
      for (final name in names) {
        groups[gi].add(name);
        if (groups[gi].length >= size) gi++;
        if (gi >= groups.length) gi = groups.length - 1;
      }
      return groups;
    }
  }

  int scoreGroups(List<List<String>> groups, Map<String, int> penalty) {
    int score = 0;
    for (final g in groups) {
      for (int i = 0; i < g.length; i++) {
        for (int j = i + 1; j < g.length; j++) {
          score += penalty[_pairKey(g[i], g[j])] ?? 0;
        }
      }
    }
    return score;
  }

  String _pairKey(String a, String b) =>
      (a.compareTo(b) <= 0) ? '$a|$b' : '$b|$a';
}
