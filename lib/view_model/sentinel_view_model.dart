import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/service/sentinel_service.dart';
import 'package:athena/extension/list_signal_extension.dart';
import 'package:signals/signals.dart';

class SentinelViewModel {
  late final SentinelRepository _sentinelRepository;
  late final ProviderRepository _providerRepository;
  late final ModelRepository _modelRepository;
  late final SentinelService _sentinelService;

  SentinelViewModel({
    required SentinelRepository sentinelRepository,
    required ProviderRepository providerRepository,
    required ModelRepository modelRepository,
    required SentinelService sentinelService,
  })  : _sentinelRepository = sentinelRepository,
        _providerRepository = providerRepository,
        _modelRepository = modelRepository,
        _sentinelService = sentinelService;

  // Signals 状态
  final sentinels = listSignal<SentinelEntity>([]);
  final isLoading = signal(false);
  final isGenerating = signal(false);
  final error = signal<String?>(null);

  // Computed signals
  late final defaultSentinel = computed(() {
    return sentinels.value.where((s) => s.name == defaultName).firstOrNull ??
        defaultSentinelEntity;
  });

  static const defaultName = 'Athena';

  static SentinelEntity get defaultSentinelEntity => SentinelEntity(
        name: defaultName,
        description: '一个友好且高效的聊天助手,随时为您提供信息和帮助。',
        prompt: '你是一个智能聊天助手。',
        tags: '',
      );

  late final tags = computed(() {
    var allTags = <String>[];
    for (var sentinel in sentinels.value) {
      allTags.addAll(sentinel.tagList);
    }
    var sortedTags = allTags.toSet().toList();
    sortedTags.sort((a, b) => a.compareTo(b));
    return sortedTags;
  });

  // 业务方法
  Future<void> getSentinels() async {
    isLoading.value = true;
    error.value = null;
    try {
      var loadedSentinels = await _sentinelRepository.getAllSentinels();

      // 如果没有 sentinel,创建默认的
      if (loadedSentinels.isEmpty) {
        var entity = defaultSentinelEntity;
        var id = await _sentinelRepository.createSentinel(entity);
        entity = entity.copyWith(id: id);
        loadedSentinels = [entity];
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

  /// 按名称查找 sentinel（先查内存信号，再查数据库）
  Future<SentinelEntity?> getSentinelByName(String name) async {
    // 优先从已加载列表查找
    var match = sentinels.value.cast<SentinelEntity?>().firstWhere(
          (s) => s!.name == name,
          orElse: () => null,
        );
    if (match != null) return match;
    // 回退到数据库
    return await _sentinelRepository.getSentinelByName(name);
  }

  Future<SentinelEntity> getFirstSentinel() async {
    if (sentinels.value.isEmpty) {
      await getSentinels();
    }
    return sentinels.value.firstOrNull ?? defaultSentinel.value;
  }

  /// 仅生成并返回 Sentinel 名称
  Future<String?> generateSentinelName(
    String prompt, {
    required int modelId,
  }) async {
    isGenerating.value = true;
    error.value = null;
    try {
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
      return await _sentinelService.generateName(
        prompt,
        provider: provider,
        model: model,
      );
    } catch (e) {
      error.value = e.toString();
      return null;
    } finally {
      isGenerating.value = false;
    }
  }

  /// 仅生成并返回 Sentinel 描述
  Future<String?> generateSentinelDescription(
    String prompt, {
    required int modelId,
    String existingName = '',
  }) async {
    isGenerating.value = true;
    error.value = null;
    try {
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
      return await _sentinelService.generateDescription(
        prompt,
        provider: provider,
        model: model,
        existingName: existingName,
      );
    } catch (e) {
      error.value = e.toString();
      return null;
    } finally {
      isGenerating.value = false;
    }
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

      var provider = await _providerRepository.getProviderById(
        model.providerId,
      );
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
      sentinels.replaceWhere((s) => s.id == sentinel.id, sentinel);
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
      sentinels.value = sentinels.value
          .where((s) => s.id != sentinel.id)
          .toList();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
