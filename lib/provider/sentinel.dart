import 'package:athena/schema/isar.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sentinel.g.dart';

@riverpod
class DefaultSentinelNotifier extends _$DefaultSentinelNotifier {
  @override
  Future<Sentinel> build() async {
    final sentinels = await ref.watch(sentinelsNotifierProvider.future);
    return sentinels.where((sentinel) => sentinel.name == 'Athena').first;
  }
}

@riverpod
class SentinelNotifier extends _$SentinelNotifier {
  @override
  Future<Sentinel> build(int id) async {
    final sentinel = await isar.sentinels.where().idEqualTo(id).findFirst();
    if (sentinel != null) return sentinel;
    return await ref.watch(defaultSentinelNotifierProvider.future);
  }
}

@riverpod
class SentinelsNotifier extends _$SentinelsNotifier {
  @override
  Future<List<Sentinel>> build() async {
    var sentinels = await isar.sentinels.where().findAll();
    if (sentinels.isNotEmpty) return sentinels;
    var defaultSentinel = Sentinel()
      ..name = 'Athena'
      ..description = '一个友好且高效的聊天助手，随时为您提供信息和帮助。'
      ..prompt = '你是一个智能聊天助手。';
    await isar.writeTxn(() async {
      await isar.sentinels.put(defaultSentinel);
    });
    return [defaultSentinel];
  }
}

@riverpod
class SentinelTagsNotifier extends _$SentinelTagsNotifier {
  @override
  Future<List<String>> build() async {
    final sentinels = await ref.watch(sentinelsNotifierProvider.future);
    var tags = <String>[];
    for (var sentinel in sentinels) {
      tags.addAll(sentinel.tags);
    }
    var sortedTags = tags.toSet().toList();
    sortedTags.sort((a, b) => a.compareTo(b));
    return sortedTags;
  }
}
