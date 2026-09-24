import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/seed/athena_preset_prompt.dart';

/// 首次启动创建 Athena 预设角色(sentinel)。GUI 与 TUI 共用。
///
/// 预设 provider/模型种子已由 ModelCatalogService(models.dev)取代,
/// sentinel 无外部数据源,保留为唯一的内置种子。
class SentinelSeed {
  const SentinelSeed();

  Future<void> applyIfNeeded({required SentinelRepository sentinelRepo}) async {
    if (await sentinelRepo.getSentinelsCount() > 0) return;
    await sentinelRepo.createSentinel(
      SentinelEntity(
        name: 'Athena',
        description: '专业、冷静且深度的AI助手，以精准执行与逻辑严谨著称。',
        prompt: athenaPresetPrompt,
        tags: '专业助手, 冷静执行, 逻辑严谨, AI助手, 深度分析',
        isPreset: true,
      ),
    );
  }
}
