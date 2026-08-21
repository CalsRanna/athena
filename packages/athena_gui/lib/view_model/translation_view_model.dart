import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/translation_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_core/service/translation_service.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:athena_core/extension/list_signal_extension.dart';
import 'package:signals/signals.dart';
import 'package:uuid/uuid.dart';

/// TranslationViewModel 负责翻译功能的业务逻辑
class TranslationViewModel {
  final TranslationService _service;
  final ModelResolver _modelResolver;
  final SettingViewModel _settingViewModel;
  final AgentService _agentService;
  int _nextRunId = 0;

  /// 绑定的专属 Sentinel（Shortcut 入口传入）。null 时回退旧 prompt。
  SentinelEntity? _boundSentinel;

  TranslationViewModel({
    required TranslationService service,
    required ModelResolver modelResolver,
    required SettingViewModel settingViewModel,
    required AgentService agentService,
  })  : _service = service,
        _modelResolver = modelResolver,
        _settingViewModel = settingViewModel,
        _agentService = agentService;

  /// 设置绑定的专属 Sentinel（Shortcut 入口调用）。
  void setBoundSentinel(SentinelEntity? sentinel) {
    _boundSentinel = sentinel;
  }

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

  /// 执行翻译并自动处理流式响应（Agent 驱动）。
  ///
  /// 用绑定 Sentinel 的 prompt 作为 system 消息，走 Agent run 流式输出，
  /// 使翻译也具备统一的 Agent 能力（工具/权限/Sentinel 配置）。
  Future<void> performTranslation(TranslationEntity translation) async {
    streaming.value = true;
    error.value = null;

    try {
      final resolved = await _modelResolver.resolve(
        preferredModelId: _settingViewModel.shortModelId.value,
      );
      if (resolved == null) {
        error.value = 'No enabled providers or models found';
        streaming.value = false;
        return;
      }
      final model = resolved.model;
      final provider = resolved.provider;

      // 构建翻译消息：绑定 Sentinel prompt 作为 system
      var prompt =
          '请将以下${translation.source}文本翻译成${translation.target}:\n\n${translation.sourceText}';
      var messages = [
        if (_boundSentinel?.prompt.isNotEmpty == true)
          ChatMessage.system(_boundSentinel!.prompt),
        ChatMessage.user(prompt),
      ];

      // 走 Agent run 流式输出（翻译是自由文本，不需要 jsonMode）
      var buffer = StringBuffer();
      var agentStream = _agentService.run(
        runId: _nextRunId++,
        chat: _dummyChat(),
        provider: provider,
        model: model,
        baseMessages: messages,
        jsonMode: false,
      );
      await for (final event in agentStream) {
        if (!streaming.value) break;
        if (event is AgentTextEvent) {
          buffer.write(event.delta);
          // 实时更新信号，使翻译面板随流式响应逐步显示，而非等待整段完成
          translatedText.value = buffer.toString();
        }
      }

      // 更新translation实体并保存到列表
      var updated = translation.copyWith(targetText: buffer.toString());
      translations.replaceWhere((t) => t.id == translation.id, updated);
    } catch (e) {
      error.value = e.toString();
    } finally {
      streaming.value = false;
    }
  }

  /// 构造一个仅供 Agent run 使用的占位 Chat（翻译不落 Chat 会话）。
  ChatEntity _dummyChat() => ChatEntity(
    id: 0,
    title: '',
    sentinelId: 0,
    modelId: 0,
    retention: -1,
    temperature: 1.0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}
