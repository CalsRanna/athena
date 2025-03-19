import 'package:athena/schema/isar.dart';
import 'package:athena/schema/summary.dart';
import 'package:isar/isar.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'summary.g.dart';

@riverpod
class SummaryNotifier extends _$SummaryNotifier {
  Future<void> append(String content) async {
    var summary = await future;
    var copiedSummary = summary.copyWith(
      content: '${summary.content}$content',
    );
    state = AsyncValue.data(copiedSummary);
    await isar.writeTxn(() async {
      await isar.summaries.put(copiedSummary);
    });
  }

  @override
  Future<Summary> build(int id) async {
    var summary = await isar.summaries.filter().idEqualTo(id).findFirst();
    if (summary == null) throw Exception('Summary not found');
    return summary;
  }

  Future<void> closeStreaming() async {
    var summary = await future;
    await isar.writeTxn(() async {
      await isar.summaries.put(summary);
    });
  }

  Future<void> streaming(ChatCompletionStreamResponseDelta delta) async {
    var summary = await future;
    var copiedSummary = summary.copyWith(
      content: '${summary.content}${delta.content}',
    );
    state = AsyncValue.data(copiedSummary);
  }

  Future<void> updateContent(String content) async {
    var summary = await future;
    var copiedSummary = summary.copyWith(content: content);
    state = AsyncValue.data(copiedSummary);
  }
}

@riverpod
class SummariesNotifier extends _$SummariesNotifier {
  @override
  Future<List<Summary>> build() async {
    var summaries = await isar.summaries.where().findAll();
    return summaries.reversed.toList();
  }
}
