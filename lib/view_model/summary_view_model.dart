import 'package:athena/entity/summary_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/service/summary_service.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:signals/signals.dart';

/// SummaryViewModel 负责网页摘要功能的业务逻辑
class SummaryViewModel {
  final SummaryService _service = SummaryService();

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
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// 生成摘要 - 返回原始流
  /// UI 层需要处理流式响应并调用 appendSummary() 更新状态
  Stream<ChatCompletionStreamResponseDelta> summarize({
    required List<ChatCompletionMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
  }) {
    streaming.value = true;
    error.value = null;
    summary.value = '';

    return _service.summarize(
      messages: messages,
      provider: provider,
      model: model,
    );
  }

  /// 追加摘要文本 (从流中接收)
  void appendSummary(String text) {
    summary.value = summary.value + text;
  }

  /// 完成摘要后添加到历史
  void addToHistory(SummaryEntity summaryEntity) {
    summaries.value = [summaryEntity, ...summaries.value];
    streaming.value = false;
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
