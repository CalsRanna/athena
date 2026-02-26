import 'package:athena/entity/summary_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/service/summary_service.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:get_it/get_it.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:signals/signals.dart';

/// SummaryViewModel 负责网页摘要功能的业务逻辑
class SummaryViewModel {
  final SummaryService _service = SummaryService();
  final ModelRepository _modelRepository = ModelRepository();
  final ProviderRepository _providerRepository = ProviderRepository();

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
  Future<int> createSummary(String link) async {
    var summaryEntity = SummaryEntity(
      id: DateTime.now().millisecondsSinceEpoch,
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
      var settingViewModel = GetIt.instance<SettingViewModel>();
      ModelEntity? model;
      ProviderEntity? provider;
      var shortModelId = settingViewModel.shortModelId.value;
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
      var messages = [
        ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(prompt),
        ),
      ];

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
