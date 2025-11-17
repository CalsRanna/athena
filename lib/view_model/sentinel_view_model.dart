import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/repository/ai_provider_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/service/sentinel_service.dart';
import 'package:signals/signals.dart';

class SentinelViewModel {
  // ViewModel 内部直接持有 Service/Repository
  final SentinelRepository _sentinelRepository = SentinelRepository();
  final AIProviderRepository _providerRepository = AIProviderRepository();
  final ModelRepository _modelRepository = ModelRepository();
  final SentinelService _sentinelService = SentinelService();

  // Signals 状态
  final sentinels = listSignal<SentinelEntity>([]);
  final isLoading = signal(false);
  final isGenerating = signal(false);
  final error = signal<String?>(null);

  // Computed signals
  late final defaultSentinel = computed(() {
    return sentinels.value
            .where((s) => s.name == 'Athena')
            .firstOrNull ??
        SentinelEntity(
          name: 'Athena',
          description: '一个友好且高效的聊天助手,随时为您提供信息和帮助。',
          prompt: '你是一个智能聊天助手。',
          tags: [],
        );
  });

  late final tags = computed(() {
    var allTags = <String>[];
    for (var sentinel in sentinels.value) {
      allTags.addAll(sentinel.tags);
    }
    var sortedTags = allTags.toSet().toList();
    sortedTags.sort((a, b) => a.compareTo(b));
    return sortedTags;
  });

  // 业务方法
  Future<void> loadSentinels() async {
    isLoading.value = true;
    error.value = null;
    try {
      var loadedSentinels = await _sentinelRepository.getAllSentinels();

      // 如果没有 sentinel,创建默认的
      if (loadedSentinels.isEmpty) {
        var defaultSentinelEntity = SentinelEntity(
          name: 'Athena',
          description: '一个友好且高效的聊天助手,随时为您提供信息和帮助。',
          prompt: '你是一个智能聊天助手。',
          tags: [],
        );
        var id = await _sentinelRepository.createSentinel(defaultSentinelEntity);
        defaultSentinelEntity = defaultSentinelEntity.copyWith(id: id);
        loadedSentinels = [defaultSentinelEntity];
      }

      sentinels.value = loadedSentinels;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<SentinelEntity?> getSentinelById(int id) async {
    try {
      return await _sentinelRepository.getSentinelById(id);
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  Future<SentinelEntity> getFirstSentinel() async {
    if (sentinels.value.isEmpty) {
      await loadSentinels();
    }
    return sentinels.value.firstOrNull ?? defaultSentinel.value;
  }

  Future<SentinelEntity?> generateSentinel(
    String prompt, {
    required int modelId,
  }) async {
    isGenerating.value = true;
    error.value = null;
    try {
      // 获取模型和提供商
      var model = await _modelRepository.getModelById(modelId);
      if (model == null) {
        error.value = 'Model not found';
        return null;
      }

      var provider = await _providerRepository.getProviderById(model.providerId);
      if (provider == null) {
        error.value = 'Provider not found';
        return null;
      }

      // 生成 sentinel 元数据
      var sentinel = await _sentinelService.generate(
        prompt,
        provider: provider,
        model: model,
      );

      return sentinel;
    } catch (e) {
      error.value = e.toString();
      return null;
    } finally {
      isGenerating.value = false;
    }
  }

  Future<void> createSentinel(SentinelEntity sentinel) async {
    isLoading.value = true;
    error.value = null;
    try {
      var id = await _sentinelRepository.createSentinel(sentinel);
      var created = sentinel.copyWith(id: id);
      sentinels.value = [...sentinels.value, created];
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateSentinel(SentinelEntity sentinel) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _sentinelRepository.updateSentinel(sentinel);
      var index = sentinels.value.indexWhere((s) => s.id == sentinel.id);
      if (index >= 0) {
        var updated = List<SentinelEntity>.from(sentinels.value);
        updated[index] = sentinel;
        sentinels.value = updated;
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteSentinel(SentinelEntity sentinel) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _sentinelRepository.deleteSentinel(sentinel.id!);
      sentinels.value =
          sentinels.value.where((s) => s.id != sentinel.id).toList();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void dispose() {
    sentinels.dispose();
    isLoading.dispose();
    isGenerating.dispose();
    error.dispose();
    defaultSentinel.dispose();
    tags.dispose();
  }
}
