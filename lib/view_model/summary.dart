import 'package:athena/api/chat.dart';
import 'package:athena/preset/prompt.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/provider/summary.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/summary.dart';
import 'package:athena/view_model/view_model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart';
import 'package:isar/isar.dart';

class SummaryViewModel extends ViewModel {
  final WidgetRef ref;

  SummaryViewModel(this.ref);

  Future<int> storeSummary(String link) async {
    var summary = Summary()..link = link;
    var id = 0;
    await isar.writeTxn(() async {
      id = await isar.summaries.put(summary);
    });
    return id;
  }

  Future<void> parse(Summary summary) async {
    var uri = Uri.parse(summary.link);
    var response = await get(uri);
    var body = response.body;
    var plainBody = body
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>'), '') // 移除脚本
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>'), '') // 移除样式
        .replaceAll(RegExp(r'<[^>]+>'), ' ') // 移除常规标签
        .replaceAll(RegExp(r'\s{2,}'), ' ') // 合并空白
        .trim();
    var copiedSummary = summary.copyWith(html: plainBody);
    await isar.writeTxn(() async {
      await isar.summaries.put(copiedSummary);
    });
    ref.invalidate(summaryNotifierProvider(summary.id));
    ref.invalidate(summariesNotifierProvider);
  }

  Future<void> summarize(Summary summary) async {
    var summaryProvider = summaryNotifierProvider(summary.id);
    var summaryNotifier = ref.read(summaryProvider.notifier);
    summaryNotifier.updateContent('');
    final streamingNotifier = ref.read(streamingNotifierProvider.notifier);
    streamingNotifier.streaming();
    var modelProvider = translatingModelNotifierProvider;
    var model = await ref.read(modelProvider.future);
    var providerProvider = providerNotifierProvider(model.providerId);
    var provider = await ref.read(providerProvider.future);
    if (provider.url.isEmpty) {
      streamingNotifier.close();
      AthenaDialog.message('You should set translating model first');
      return;
    }
    var latestSummary = await ref.read(summaryProvider.future);
    var prompt = PresetPrompt.summaryPrompt;
    final system = {'role': 'system', 'content': prompt};
    var user = {'role': 'user', 'content': latestSummary.html};
    try {
      final response = ChatApi().getCompletion(
        chat: Chat(),
        messages: [Message.fromJson(system), Message.fromJson(user)],
        model: model,
        provider: provider,
      );
      await for (final delta in response) {
        await summaryNotifier.streaming(delta);
      }
      await summaryNotifier.closeStreaming();
    } catch (error) {
      summaryNotifier.append(error.toString());
    }
    streamingNotifier.close();
    ref.invalidate(summariesNotifierProvider);
  }

  Future<void> destroyAllSummaries() async {
    await isar.writeTxn(() async {
      await isar.summaries.where().deleteAll();
    });
    ref.invalidate(summariesNotifierProvider);
  }
}
