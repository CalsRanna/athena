import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:isar/isar.dart';
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

@riverpod
class ChatRelatedSentinelNotifier extends _$ChatRelatedSentinelNotifier {
  @override
  Future<Sentinel> build(int chatId) async {
    final chat = await ref.watch(chatNotifierProvider(chatId).future);
    var sentinelId = chat.sentinelId;
    var sentinel =
        await isar.sentinels.where().idEqualTo(sentinelId).findFirst();
    if (sentinel != null) return sentinel;
    return Sentinel();
  }
}
