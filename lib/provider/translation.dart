import 'package:athena/schema/isar.dart';
import 'package:athena/schema/translation.dart';
import 'package:isar/isar.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'translation.g.dart';

@riverpod
class TransitionsNotifier extends _$TransitionsNotifier {
  @override
  Future<List<Translation>> build() async {
    var translations = await isar.translations.where().findAll();
    return translations.reversed.toList();
  }

  Future<void> destroyAllTranslations() async {
    await isar.writeTxn(() async {
      await isar.translations.where().deleteAll();
    });
    ref.invalidateSelf();
  }
}

@riverpod
class TranslationNotifier extends _$TranslationNotifier {
  Future<void> append(String content) async {
    var translation = await future;
    var copiedTranslation = translation.copyWith(
      targetText: '${translation.targetText}$content',
    );
    state = AsyncData(copiedTranslation);
    await isar.writeTxn(() async {
      await isar.translations.put(copiedTranslation);
    });
  }

  @override
  Future<Translation> build(int id) async {
    var builder = isar.translations.filter().idEqualTo(id);
    var translation = await builder.findFirst();
    if (translation == null) throw Exception('Translation not found');
    return translation;
  }

  Future<void> closeStreaming() async {
    var translation = await future;
    var targetText = translation.targetText.trim();
    var copiedTranslation = translation.copyWith(
      targetText: targetText,
    );
    state = AsyncData(copiedTranslation);
    if (targetText.isEmpty) {
      await isar.writeTxn(() async {
        await isar.translations.delete(translation.id);
      });
    } else {
      await isar.writeTxn(() async {
        await isar.translations.put(copiedTranslation);
      });
    }
  }

  Future<void> streaming(ChatCompletionStreamResponseDelta delta) async {
    var translation = await future;
    var copiedTranslation = translation.copyWith(
      targetText: '${translation.targetText}${delta.content}',
    );
    state = AsyncData(copiedTranslation);
  }

  Future<void> updateTargetText(String targetText) async {
    var translation = await future;
    var copiedTranslation = translation.copyWith(targetText: targetText);
    state = AsyncData(copiedTranslation);
  }
}
