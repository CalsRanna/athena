import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/seed/athena_preset_prompt.dart';
import 'package:athena_core/seed/daedalus_preset_prompt.dart';

/// 首次启动创建内置预设角色(sentinel)。GUI 与 TUI 共用。
///
/// 预设 provider/模型种子已由 ModelCatalogService(models.dev)取代,
/// sentinel 无外部数据源,保留为唯一的内置种子。
class SentinelSeed {
  const SentinelSeed();

  /// 内置角色清单:名字 → 提示词。
  ///
  /// 按**名字**逐个补齐而不是「一个都没有才建」:新增内置角色时,已有用户
  /// 也要能拿到,否则升级后只有全新安装才见得到 Daedalus。判定依据是名字,
  /// 所以已存在同名角色一律原样保留,不覆盖用户的任何改动。
  static const builtins =
      <(String name, String description, String prompt, String tags)>[
        (
          SentinelEntity.athenaName,
          '专业、冷静且深度的AI助手，以精准执行与逻辑严谨著称。',
          athenaPresetPrompt,
          '专业助手, 冷静执行, 逻辑严谨, AI助手, 深度分析',
        ),
        (
          SentinelEntity.daedalusName,
          '专精软件工程的AI助手，擅长读懂现有代码、精准改动并验证结果。',
          daedalusPresetPrompt,
          '软件工程, 代码编写, 重构, 调试, 工程实践',
        ),
      ];

  Future<void> applyIfNeeded({required SentinelRepository sentinelRepo}) async {
    for (final (name, description, prompt, tags) in builtins) {
      if (await sentinelRepo.getSentinelByName(name) != null) continue;
      await sentinelRepo.createSentinel(
        SentinelEntity(
          name: name,
          description: description,
          prompt: prompt,
          tags: tags,
          isPreset: true,
        ),
      );
    }
  }
}
