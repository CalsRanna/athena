import 'package:athena/provider/chat.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sentinel.g.dart';

@riverpod
class SentinelTagsNotifier extends _$SentinelTagsNotifier {
  @override
  Future<List<String>> build() async {
    final sentinels = await ref.watch(sentinelsNotifierProvider.future);
    var tags = <String>[];
    for (var sentinel in sentinels) {
      tags.addAll(sentinel.tags);
    }
    return tags.toSet().toList();
  }
}
