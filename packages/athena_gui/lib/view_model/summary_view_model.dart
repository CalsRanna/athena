import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/runtime_context.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/summary_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_core/service/summary_service.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:athena_core/extension/list_signal_extension.dart';
import 'package:signals/signals.dart';
import 'package:uuid/uuid.dart';

/// SummaryViewModel 负责网页摘要功能的业务逻辑
class SummaryViewModel {
  final SummaryService _service;
  final ModelResolver _modelResolver;
  final SettingViewModel _settingViewModel;
  final AgentService _agentService;
  int _nextRunId = 0;

  /// 绑定的专属 Sentinel（Shortcut 入口传入）。null 时回退旧 prompt。
  SentinelEntity? _boundSentinel;

  SummaryViewModel({
    required SummaryService service,
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
  final url = signal('');
  final content = signal('');
  final summary = signal('');
  final title = signal('');
  final icon = signal('');
  final streaming = signal(false);
  final isLoading = signal(false);
  final error = signal<String?>(null);
  final summaries = listSignal<SummaryEntity>([]);

  /// 创建摘要记录
  Future<String> createSummary(String link) async {
    var summaryEntity = SummaryEntity(
      id: const Uuid().v4(),
      link: link,
      title: '',
      content: '',
      icon: '',
      createdAt: DateTime.now(),
    );
    summaries.value = [summaryEntity, ...summaries.value];
    return summaryEntity.id;
  }

  /// 解析网页文档
  Future<void> parse(SummaryEntity summary) async {
    isLoading.value = true;
    error.value = null;

    try {
      var result = await _service.parseDocument(summary.link);
      content.value = result['html'] ?? '';
      title.value = result['title'] ?? '';
      icon.value = result['icon'] ?? '';
      url.value = summary.link;

      // 回写到 summaries 列表中的对应 entity
      var index = summaries.value.indexWhere((s) => s.id == summary.id);
      if (index >= 0) {
        var updated = summary.copyWith(
          title: title.value,
          icon: icon.value,
        );
        var updatedList = List<SummaryEntity>.from(summaries.value);
        updatedList[index] = updated;
        summaries.value = updatedList;
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// 执行摘要生成
  Future<void> performSummary(SummaryEntity summaryEntity) async {
    if (content.value.isEmpty) {
      error.value = 'No content to summarize';
      return;
    }

    streaming.value = true;
    error.value = null;
    summary.value = '';

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

      var prompt = '请对以下网页内容生成摘要:\n\n${content.value}';
      var messages = [
        if (_boundSentinel?.prompt.isNotEmpty == true)
          ChatMessage.system(_boundSentinel!.prompt),
        ChatMessage.user(prompt),
      ];

      var buffer = StringBuffer();
      // 走 Agent run 流式输出（摘要是自由文本，不需要 jsonMode）
      var agentStream = _agentService.run(
        runId: _nextRunId++,
        chat: _dummyChat(),
        provider: provider,
        model: model,
        baseMessages: messages,
        runtimePrompt: runtimeContextPrompt(RuntimeEnvironment.gui),
        jsonMode: false,
      );
      await for (final event in agentStream) {
        if (!streaming.value) break;
        if (event is AgentTextEvent) {
          buffer.write(event.delta);
          summary.value = buffer.toString();
        }
      }

      // 更新 summaries 列表中的对应 entity
      summaries.replaceWhere(
        (s) => s.id == summaryEntity.id,
        summaries.value.firstWhere((s) => s.id == summaryEntity.id).copyWith(content: buffer.toString()),
      );
    } catch (e) {
      error.value = e.toString();
    } finally {
      streaming.value = false;
    }
  }

  /// 清空摘要结果
  void clear() {
    url.value = '';
    content.value = '';
    summary.value = '';
    title.value = '';
    icon.value = '';
    error.value = null;
  }

  /// 清空历史
  void deleteAllSummaries() {
    summaries.value = [];
  }

  /// 构造一个仅供 Agent run 使用的占位 Chat（摘要不落 Chat 会话）。
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
