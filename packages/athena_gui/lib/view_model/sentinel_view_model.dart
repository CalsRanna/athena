import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_gui/service/sentinel_service.dart';
import 'package:athena_gui/extension/list_signal_extension.dart';
import 'package:athena_core/seed/sentinel_seed.dart';
import 'package:signals/signals.dart';

class SentinelViewModel {
  static const directChatName = 'Direct chat';
  static const directChatOptionLabel = 'No Sentinel (Direct chat)';

  /// 仅用于 GUI 状态与渲染，不写入 sentinels 表。
  /// ChatStoreService 将其保存为 sentinel_id: null。
  static const directChatSentinel = SentinelEntity(
    id: ChatEntity.noSentinelId,
    name: directChatName,
    description: 'Talk directly to the model without a Sentinel prompt.',
    prompt: '',
    isPreset: true,
  );

  final SentinelRepository _sentinelRepository;
  final ProviderRepository _providerRepository;
  final ModelRepository _modelRepository;
  final SentinelService _sentinelService;

  SentinelViewModel({
    required SentinelRepository sentinelRepository,
    required ProviderRepository providerRepository,
    required ModelRepository modelRepository,
    required SentinelService sentinelService,
  }) : _sentinelRepository = sentinelRepository,
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
    return sentinels.value
            .where((s) => s.name == SentinelEntity.athenaName)
            .firstOrNull ??
        defaultSentinelEntity;
  });

  static const defaultName = SentinelEntity.athenaName;

  /// 兜底角色：只在库中没有 Athena 时使用（种子未跑、数据被手工清空）。
  ///
  /// 提示词取 [SentinelSeed.builtins] 里的 Athena 条目，而不是就地再写一份——
  /// 两份文案必然漂移，兜底角色本就是「种子缺失时的临时替身」，与真正的
  /// Athena 用同一份提示词才符合预期。
  static SentinelEntity get defaultSentinelEntity {
    final athena = SentinelSeed.builtins.firstWhere((b) => b.$1 == defaultName);
    return SentinelEntity(
      name: athena.$1,
      description: athena.$2,
      prompt: athena.$3,
      tags: athena.$4,
      isPreset: true,
    );
  }

  late final tags = computed(() {
    final allTags = <String>[];
    for (var sentinel in sentinels.value) {
      allTags.addAll(sentinel.tagList);
    }
    final sortedTags = allTags.toSet().toList();
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
        final id = await _sentinelRepository.createSentinel(entity);
        entity = entity.copyWith(id: id);
        loadedSentinels = [entity];
      } else {
        // 预设角色仅白名单内的展示,其余隐藏(数据仍在库中,聊天引用可解析);
        // 过滤后为空时用默认实体兜底,保证聊天页始终有可选角色
        var visible = loadedSentinels.where((s) => s.isListVisible).toList();
        if (visible.isEmpty) visible = [defaultSentinelEntity];
        loadedSentinels = visible;
      }

      sentinels.value = loadedSentinels;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<SentinelEntity?> getSentinelById(String id) async {
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
    final match = sentinels.value.cast<SentinelEntity?>().firstWhere(
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
    required String modelId,
  }) async {
    isGenerating.value = true;
    error.value = null;
    try {
      final model = await _modelRepository.getModelById(modelId);
      if (model == null) {
        error.value = 'Model not found';
        return null;
      }
      final provider = await _providerRepository.getProviderById(
        model.providerId,
      );
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
    required String modelId,
    String existingName = '',
  }) async {
    isGenerating.value = true;
    error.value = null;
    try {
      final model = await _modelRepository.getModelById(modelId);
      if (model == null) {
        error.value = 'Model not found';
        return null;
      }
      final provider = await _providerRepository.getProviderById(
        model.providerId,
      );
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
    required String modelId,
  }) async {
    isGenerating.value = true;
    error.value = null;
    try {
      // 获取模型和提供商
      final model = await _modelRepository.getModelById(modelId);
      if (model == null) {
        error.value = 'Model not found';
        return null;
      }

      final provider = await _providerRepository.getProviderById(
        model.providerId,
      );
      if (provider == null) {
        error.value = 'Provider not found';
        return null;
      }

      // 生成 sentinel 元数据
      final sentinel = await _sentinelService.generate(
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

  /// 新建角色;成功返回带 id 的实体(设置页据此直接打开它)。
  Future<SentinelEntity?> createSentinel(SentinelEntity sentinel) async {
    isLoading.value = true;
    error.value = null;
    try {
      final id = await _sentinelRepository.createSentinel(sentinel);
      final created = sentinel.copyWith(id: id);
      sentinels.value = [...sentinels.value, created];
      return created;
    } catch (e) {
      error.value = e.toString();
      return null;
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
