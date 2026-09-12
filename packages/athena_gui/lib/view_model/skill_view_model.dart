import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:signals/signals.dart';

/// SkillViewModel：Skill（技能）的可视化管理。
///
/// 数据源是 core 的 [SkillRegistry]（用户级目录 `~/.athena/skills`，
/// 移动端为沙盒内目录），与 Agent 的 skill / skill_evolve 工具同源；
/// 写入复用 [SkillLoader.saveSkill]，保证 front matter 格式一致。
/// 内置 Skill（self-evolve）只读，不可编辑或删除。
class SkillViewModel {
  final SkillRegistry _skillRegistry;

  SkillViewModel({required SkillRegistry skillRegistry})
      : _skillRegistry = skillRegistry;

  /// 全部 Skill（含内置 self-evolve）。
  final skills = listSignal<Skill>([]);
  final isLoading = signal(false);
  final error = signal<String?>(null);

  /// 用户级 Skill（首页卡片与管理列表使用；不含内置），按名称排序。
  late final userSkills = computed(() {
    var list = skills.value.where((s) => !s.isBuiltin).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  });

  /// 重新扫描用户级目录（复用 [SkillRegistry] 的 homeDir 配置）。
  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      _skillRegistry.reload();
      skills.value = _skillRegistry.all;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// 新建 Skill；成功返回 true。
  ///
  /// 名称需通过 [SkillLoader.isValidSkillName] 校验且未被占用。
  Future<bool> createSkill({
    required String name,
    required String description,
    String allowedTools = '',
    required String body,
  }) async {
    final trimmedName = name.trim();
    if (!SkillLoader.isValidSkillName(trimmedName)) {
      error.value = 'Invalid skill name';
      return false;
    }
    if (description.trim().isEmpty) {
      error.value = 'Description is required';
      return false;
    }
    if (_skillRegistry.get(trimmedName) != null) {
      error.value = 'Skill "$trimmedName" already exists';
      return false;
    }
    final targetDir = '${_skillRegistry.skillsDirectory}/$trimmedName';
    return _write(
      name: trimmedName,
      description: description,
      allowedTools: allowedTools,
      body: body,
      targetDir: targetDir,
    );
  }

  /// 更新已有 Skill（名称不变）；内置 Skill 拒绝修改。
  Future<bool> updateSkill(
    Skill skill, {
    required String description,
    String allowedTools = '',
    required String body,
  }) async {
    if (skill.isBuiltin) {
      error.value = 'Built-in skills cannot be modified';
      return false;
    }
    return _write(
      name: skill.name,
      description: description,
      allowedTools: allowedTools,
      body: body,
      targetDir: skill.sourcePath,
    );
  }

  /// 删除用户级 Skill（目录与内存一并移除）；内置 Skill 拒绝删除。
  Future<bool> deleteSkill(Skill skill) async {
    if (skill.isBuiltin) {
      error.value = 'Built-in skills cannot be deleted';
      return false;
    }
    isLoading.value = true;
    error.value = null;
    try {
      final removed = _skillRegistry.deleteSkill(skill.name);
      if (!removed) {
        error.value = 'Skill "${skill.name}" not found';
        return false;
      }
      skills.value = _skillRegistry.all;
      return true;
    } catch (e) {
      error.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> _write({
    required String name,
    required String description,
    required String allowedTools,
    required String body,
    required String targetDir,
  }) async {
    isLoading.value = true;
    error.value = null;
    try {
      SkillLoader().saveSkill(
        name: name,
        description: description.trim(),
        allowedTools: allowedTools.trim(),
        body: body,
        targetDir: targetDir,
      );
      _skillRegistry.reloadSkill(name, targetDir);
      skills.value = _skillRegistry.all;
      return true;
    } catch (e) {
      error.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
