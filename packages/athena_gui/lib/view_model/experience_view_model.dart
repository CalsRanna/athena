import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:signals/signals.dart';

/// ExperienceViewModel：Experience（经验记忆）的可视化管理。
///
/// 数据源是 core 的 [ExperienceRepository]（`~/.athena/experiences/`，
/// 移动端为沙盒内目录），与 Agent 的 experience_learn / experience_recall
/// 工具同源。经验内容由 Agent 工具产出，界面仅支持浏览、归档/恢复与删除；
/// 归档项始终展示（条目尾部提供 Restore 按钮）；归属展示尽力映射为角色名。
class ExperienceViewModel {
  final ExperienceRepository _experienceRepository;
  final SentinelRepository _sentinelRepository;

  ExperienceViewModel({
    required ExperienceRepository experienceRepository,
    required SentinelRepository sentinelRepository,
  })  : _experienceRepository = experienceRepository,
        _sentinelRepository = sentinelRepository;

  final experiences = listSignal<ExperienceEntity>([]);
  final isLoading = signal(false);
  final error = signal<String?>(null);

  /// sentinelId -> 角色名（仅供归属展示；查不到时回退原始 id）。
  final sentinelNames = signal<Map<String, String>>({});

  /// 重新加载全部经验（所有 Sentinel 私有 + shared）。
  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      experiences.value = await _experienceRepository.listAll(
        includeArchived: true,
      );
      await _loadSentinelNames();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// 展示用归属标签：shared → "Shared"，私有 → 角色名（缺失时原样显示）。
  String ownerLabel(ExperienceEntity entity) {
    if (entity.scope == 'shared') return 'Shared';
    return sentinelNames.value[entity.sentinelId] ?? entity.sentinelId;
  }

  /// 归档（保留为记录，默认不再检索/展示）。
  Future<bool> archiveExperience(ExperienceEntity entity) =>
      _update(entity, status: ExperienceEntity.statusArchived);

  /// 恢复归档项为 active。
  Future<bool> restoreExperience(ExperienceEntity entity) =>
      _update(entity, status: ExperienceEntity.statusActive);

  /// 永久删除（文件删除，不可恢复）。
  Future<bool> deleteExperience(ExperienceEntity entity) async {
    isLoading.value = true;
    error.value = null;
    try {
      final removed = await _experienceRepository.delete(
        entity.sentinelId,
        entity.id,
      );
      if (!removed) {
        error.value = 'Experience not found';
        return false;
      }
      await load();
      return true;
    } catch (e) {
      error.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> _update(
    ExperienceEntity entity, {
    String? lesson,
    String? context,
    List<String>? tags,
    String? scope,
    String? status,
  }) async {
    isLoading.value = true;
    error.value = null;
    try {
      final updated = await _experienceRepository.update(
        sentinelId: entity.sentinelId,
        id: entity.id,
        lesson: lesson,
        context: context,
        tags: tags,
        scope: scope,
        status: status,
      );
      if (updated == null) {
        error.value = 'Experience not found';
        return false;
      }
      await load();
      return true;
    } catch (e) {
      error.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadSentinelNames() async {
    try {
      final sentinels = await _sentinelRepository.getAllSentinels();
      sentinelNames.value = {
        for (final s in sentinels)
          if (s.id != null) '${s.id}': s.name,
      };
    } catch (_) {
      // 归属名仅为展示，加载失败不影响经验列表
    }
  }
}
