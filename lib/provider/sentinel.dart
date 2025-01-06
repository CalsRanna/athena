import 'package:athena/api/sentinel.dart';
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

@riverpod
class SentinelsNotifier extends _$SentinelsNotifier {
  @override
  Future<List<Sentinel>> build() async {
    var sentinels = await isar.sentinels.where().findAll();
    if (sentinels.isNotEmpty) return sentinels;
    var defaultSentinel = Sentinel()..name = 'Athena';
    await isar.writeTxn(() async {
      await isar.sentinels.put(defaultSentinel);
    });
    return [defaultSentinel];
  }

  Future<void> destroy(Sentinel sentinel) async {
    await isar.writeTxn(() async {
      await isar.sentinels.delete(sentinel.id);
    });
    ref.invalidateSelf();
  }

  Future<void> store(Sentinel sentinel) async {
    await isar.writeTxn(() async {
      await isar.sentinels.put(sentinel);
    });
    ref.invalidateSelf();
  }

  Future<void> updateSentinel(Sentinel sentinel) async {
    await isar.writeTxn(() async {
      await isar.sentinels.put(sentinel);
    });
    ref.invalidateSelf();
  }
}

@riverpod
class SentinelNotifier extends _$SentinelNotifier {
  @override
  Future<Sentinel> build(int id) async {
    final sentinel = await isar.sentinels.where().idEqualTo(id).findFirst();
    if (sentinel != null) return sentinel;
    return Sentinel()..name = 'Athena';
  }

  void select(Sentinel sentinel, {bool invalidate = true}) {
    state = AsyncData(sentinel);
    if (!invalidate) return;
    ref.invalidate(chatNotifierProvider);
  }

  Future<Sentinel> generate(String prompt) async {
    return SentinelApi().generate(prompt, model: 'gpt-4o-mini');
  }
}
