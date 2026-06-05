import 'package:athena/entity/translation_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/service/translation_service.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:signals/signals.dart';
import 'package:uuid/uuid.dart';

/// TranslationViewModel 负责翻译功能的业务逻辑
class TranslationViewModel {
  late final TranslationService _service;
  late final ProviderRepository _providerRepository;
  late final ModelRepository _modelRepository;
  late final SettingViewModel _settingViewModel;

  TranslationViewModel({
    required TranslationService service,
    required ProviderRepository providerRepository,
    required ModelRepository modelRepository,
    required SettingViewModel settingViewModel,
  })  : _service = service,
        _providerRepository = providerRepository,
        _modelRepository = modelRepository,
        _settingViewModel = settingViewModel;

  // Signals 状态
  final sourceText = signal('');
  final translatedText = signal('');
  final sourceLanguage = signal('auto');
  final targetLanguage = signal('en');
  final streaming = signal(false);
  final error = signal<String?>(null);
  final translations = listSignal<TranslationEntity>([]);

  /// 创建翻译记录
  Future<String> createTranslation(
    String source,
    String sourceText,
    String target,
  ) async {
    var translationEntity = TranslationEntity(
      id: const Uuid().v4(),
      source: source,
      sourceText: sourceText,
      target: target,
      targetText: '',
      createdAt: DateTime.now(),
    );
    translations.value = [translationEntity, ...translations.value];
    return translationEntity.id;
  }

  /// 执行翻译 - 返回原始流
  /// UI 层需要处理流式响应并调用 appendTranslatedText() 更新状态
  Stream<ChatDelta> translate({
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
  }) {
    streaming.value = true;
    error.value = null;
    translatedText.value = '';

    return _service.translate(
      messages: messages,
      provider: provider,
      model: model,
    );
  }

  /// 追加翻译文本 (从流中接收)
  void appendTranslatedText(String text) {
    translatedText.value = translatedText.value + text;
  }

  /// 完成翻译后添加到历史
  void addToHistory(TranslationEntity translation) {
    translations.value = [translation, ...translations.value];
    streaming.value = false;
  }

  /// 清空翻译结果
  void clear() {
    sourceText.value = '';
    translatedText.value = '';
    error.value = null;
  }

  /// 清空历史
  void deleteAllTranslations() {
    translations.value = [];
  }

  /// 执行翻译并自动处理流式响应
  Future<void> performTranslation(TranslationEntity translation) async {
    streaming.value = true;
    error.value = null;

    try {
      // 优先使用设置中配置的 shortModelId
      ModelEntity? model;
      ProviderEntity? provider;
      var shortModelId = _settingViewModel.shortModelId.value;
      if (shortModelId > 0) {
        model = await _modelRepository.getModelById(shortModelId);
        if (model != null) {
          provider = await _providerRepository.getProviderById(
            model.providerId,
          );
        }
      }

      // Fallback: 获取第一个启用的模型和provider
      if (model == null || provider == null) {
        var providers = await _providerRepository.getEnabledProviders();
        if (providers.isEmpty) {
          error.value = 'No enabled providers found';
          streaming.value = false;
          return;
        }
        provider = providers.first;

        var models = await _modelRepository.getModelsByProviderId(
          provider.id!,
        );
        if (models.isEmpty) {
          error.value = 'No models found for provider';
          streaming.value = false;
          return;
        }
        model = models.first;
      }

      // 构建翻译消息
      var prompt =
          '请将以下${translation.source}文本翻译成${translation.target}:\n\n${translation.sourceText}';
      var messages = [ChatMessage.user(prompt)];

      // 获取流式翻译
      var buffer = StringBuffer();
      var stream = translate(
        messages: messages,
        provider: provider,
        model: model,
      );

      await for (final chunk in stream) {
        if (!streaming.value) break;
        if (chunk.content != null) {
          buffer.write(chunk.content);
          // 实时更新信号，使翻译面板随流式响应逐步显示，而非等待整段完成
          translatedText.value = buffer.toString();
        }
      }

      // 更新translation实体并保存到列表
      var updated = translation.copyWith(targetText: buffer.toString());

      // 更新列表中的translation
      var index = translations.value.indexWhere((t) => t.id == translation.id);
      if (index >= 0) {
        var updatedList = List<TranslationEntity>.from(translations.value);
        updatedList[index] = updated;
        translations.value = updatedList;
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      streaming.value = false;
    }
  }
}
