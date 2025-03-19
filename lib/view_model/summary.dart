import 'package:athena/api/summary.dart';
import 'package:athena/preset/prompt.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/provider/summary.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/summary.dart';
import 'package:athena/view_model/view_model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:openai_dart/openai_dart.dart';

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
    var document = await SummaryApi().parseDocument(summary.link);
    var copiedSummary = summary.copyWith(
      html: document['html'],
      icon: document['icon'],
      title: document['title'],
    );
    await isar.writeTxn(() async {
      await isar.summaries.put(copiedSummary);
    });
    ref.invalidate(summaryNotifierProvider(summary.id));
    ref.invalidate(summariesNotifierProvider);
  }

  Future<void> summarize(Summary summary) async {
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
    var summaryProvider = summaryNotifierProvider(summary.id);
    var summaryNotifier = ref.read(summaryProvider.notifier);
    await summaryNotifier.updateContent('');
    var latestSummary = await ref.read(summaryProvider.future);
    try {
      var prompt = PresetPrompt.summaryPrompt;
      var userMessageContent = ChatCompletionUserMessageContent.string(
        latestSummary.html,
      );
      var messages = [
        ChatCompletionMessage.system(content: prompt),
        ChatCompletionMessage.user(content: userMessageContent)
      ];
      var response = SummaryApi().summarize(
        messages: messages,
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
