import 'package:athena/api/translation.dart';
import 'package:athena/preset/prompt.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/provider/translation.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/translation.dart';
import 'package:athena/view_model/view_model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openai_dart/openai_dart.dart';

class TranslationViewModel extends ViewModel {
  final WidgetRef ref;

  TranslationViewModel(this.ref);

  Future<void> destroyAllTranslations() async {
    var notifier = ref.read(transitionsNotifierProvider.notifier);
    await notifier.destroyAllTranslations();
    AthenaDialog.message('Clear translations successfully');
  }

  Future<int> storeTranslation(Translation translation) async {
    var id = translation.id;
    await isar.writeTxn(() async {
      id = await isar.translations.put(translation);
    });
    return id;
  }

  Future<void> translate(Translation translation) async {
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
    var translationProvider = translationNotifierProvider(translation.id);
    var translationNotifier = ref.read(translationProvider.notifier);
    await translationNotifier.updateTargetText('');
    try {
      var prompt = PresetPrompt.translatePrompt
          .replaceAll('{source}', translation.source)
          .replaceAll('{target}', translation.target);
      var userMessageContent = ChatCompletionUserMessageContent.string(
        translation.sourceText,
      );
      var messages = [
        ChatCompletionMessage.system(content: prompt),
        ChatCompletionMessage.user(content: userMessageContent)
      ];
      var response = TranslationApi().translate(
        messages: messages,
        model: model,
        provider: provider,
      );
      await for (final delta in response) {
        await translationNotifier.streaming(delta);
      }
      await translationNotifier.closeStreaming();
    } catch (error) {
      translationNotifier.append(error.toString());
    }
    streamingNotifier.close();
    ref.invalidate(transitionsNotifierProvider);
  }
}
