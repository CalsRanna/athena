import 'package:athena/entity/summary_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/service/summary_service.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:signals/signals.dart';
import 'package:uuid/uuid.dart';

/// SummaryViewModel 负责网页摘要功能的业务逻辑
class SummaryViewModel {
  late final SummaryService _service;
  late final ModelRepository _modelRepository;
  late final ProviderRepository _providerRepository;
  late final SettingViewModel _settingViewModel;

  SummaryViewModel({
    required SummaryService service,
    required ModelRepository modelRepository,
    required ProviderRepository providerRepository,
    required SettingViewModel settingViewModel,
  })  : _service = service,
        _modelRepository = modelRepository,
        _providerRepository = providerRepository,
        _settingViewModel = settingViewModel;

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

      var prompt = '请对以下网页内容生成摘要:\n\n${content.value}';
      var messages = [ChatMessage.user(prompt)];

      var buffer = StringBuffer();
      var stream = _service.summarize(
        messages: messages,
        provider: provider,
        model: model,
      );

      await for (final chunk in stream) {
        if (!streaming.value) break;
        if (chunk.content != null) {
          buffer.write(chunk.content);
          summary.value = buffer.toString();
        }
      }

      // 更新 summaries 列表中的对应 entity
      var index = summaries.value.indexWhere((s) => s.id == summaryEntity.id);
      if (index >= 0) {
        var updated = summaries.value[index].copyWith(
          content: buffer.toString(),
        );
        var updatedList = List<SummaryEntity>.from(summaries.value);
        updatedList[index] = updated;
        summaries.value = updatedList;
      }
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
}
