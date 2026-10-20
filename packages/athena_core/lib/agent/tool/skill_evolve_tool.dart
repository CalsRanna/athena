import 'dart:io';

import 'package:athena_core/agent/evolution/skill_history_store.dart';
import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/util/logger_util.dart';

/// 创建、更新或删除 Skill 的工具，使 Agent 具备自我进化能力。
///
/// Agent 可以在遇到无法很好处理的任务时，创建一个新的 Skill
/// 来扩展自己的能力；也可以改进已有的 Skill；改坏了能删掉重来。
///
/// Skill 统一保存在用户级目录（`~/.athena/skills/`，移动端为沙盒内
/// `.athena/skills/`），以 `SKILL.md` 文件形式存在，对所有会话可用。
///
/// 每次写入前都把旧版 SKILL.md 存一份快照（[SkillHistoryStore]），
/// 使覆盖不可恢复这件事不再成立；`skill_revert` 据此回滚。
class SkillEvolveTool extends Tool {
  final SkillRegistry _skillRegistry;
  final SkillHistoryStore _historyStore;

  /// 用户级 `.athena` 根目录。空 = 使用 `$HOME`（桌面端）。
  final String? _homeDir;

  SkillEvolveTool({
    required SkillRegistry skillRegistry,
    required SkillHistoryStore historyStore,
    String? homeDir,
  }) : _skillRegistry = skillRegistry,
       _historyStore = historyStore,
       _homeDir = homeDir;

  /// SKILL.md 正文的最大字符数。
  ///
  /// 正文是每次加载技能都进入上下文的内容，而 `skill` 工具的结果超过
  /// `ToolOutputStore.inlineLimit`（24000 字符）后只把前 2000 字符交给模型，
  /// 其余要靠 `tool_output_read` 分页取——模型会以为自己加载了完整技能。
  /// 上限设在远低于该阈值处，让「写进去的」与「读得回的」始终一致。
  static const int maxBodyChars = 8000;

  @override
  String get name => 'skill_evolve';

  @override
  String get description =>
      'Create, update, or delete a Skill to improve your future capabilities. '
      'Skills are specialized instruction sets that extend your abilities. '
      'Use this tool to:\n'
      '- Create a skill when you encounter a task type that reoccurs and would '
      'benefit from specialized guidance.\n'
      '- Update an existing skill when you discover better approaches or need '
      'to fix issues. The previous version is snapshotted first, so it can be '
      'restored with skill_revert.\n'
      '- Delete a skill that is wrong or no longer useful.\n'
      'Skills are saved as SKILL.md files in ~/.athena/skills/ and are '
      'available in every conversation, including the current one.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description':
            'Skill name (kebab-case, max 64 chars). Must match existing '
            'skill name when updating or deleting.',
      },
      'action': {
        'type': 'string',
        'enum': ['create', 'update', 'delete'],
        'description':
            'Whether to create a new skill, update an existing one, or delete '
            'it. "delete" removes the skill directory and its history.',
      },
      'description': {
        'type': 'string',
        'description':
            'Brief description of what the skill does (required for create, '
            'optional for update; ignored for delete).',
      },
      'body': {
        'type': 'string',
        'description':
            'The full SKILL.md body content — the instructions, workflows, '
            'and guidance that define how the skill operates. Use Markdown. '
            'For updates, provide the complete new body. Required for create '
            'and update; omit for delete.',
      },
    },
    'required': ['name', 'action'],
  };

  @override
  Future<ToolExecutionResult> executeResult(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async {
    final skillName = args['name'] as String;
    final action = args['action'] as String;
    final description = args['description'] as String? ?? '';
    final body = args['body'] as String? ?? '';

    if (!const ['create', 'update', 'delete'].contains(action)) {
      return ToolExecutionResult.error(
        'Error: Unknown action "$action". Use "create", "update", or '
        '"delete".',
      );
    }

    if (!SkillLoader.isValidSkillName(skillName)) {
      return ToolExecutionResult.error(
        'Error: Invalid skill name "$skillName". '
        'Use kebab-case, max 64 chars, no special characters or path separators.',
      );
    }

    if (action == 'delete') return _deleteSkill(skillName);

    if (body.trim().isEmpty) {
      return ToolExecutionResult.error(
        'Error: body is required when action is "$action".',
      );
    }
    if (body.length > maxBodyChars) {
      return ToolExecutionResult.error(
        'Error: body must not exceed $maxBodyChars characters '
        '(${body.length} given). Move long reference material into separate '
        'files under the skill directory and point to them from the body.',
      );
    }

    if (action == 'update') {
      final existing = _skillRegistry.get(skillName);
      if (existing == null) {
        return ToolExecutionResult.error(
          'Error: Skill "$skillName" not found. '
          'Use action "create" to create a new skill, or check the name spelling.',
        );
      }
      if (existing.isBuiltin) {
        return const ToolExecutionResult.error(
          'Error: Built-in skills cannot be updated.',
        );
      }
      return _writeSkill(
        skillName: skillName,
        description: description.isNotEmpty
            ? description
            : existing.description,
        body: body,
        targetDir: existing.sourcePath,
        snapshotPrevious: true,
      );
    }

    if (_skillRegistry.get(skillName) != null) {
      return ToolExecutionResult.error(
        'Error: Skill "$skillName" already exists. '
        'Use action "update" to modify it, or choose a different name.',
      );
    }

    if (description.isEmpty) {
      return const ToolExecutionResult.error(
        'Error: description is required when creating a new skill.',
      );
    }

    final home =
        _homeDir ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
    final targetDir = '$home/.athena/skills/$skillName';

    return _writeSkill(
      skillName: skillName,
      description: description,
      body: body,
      targetDir: targetDir,
      snapshotPrevious: false,
    );
  }

  Future<ToolExecutionResult> _deleteSkill(String skillName) async {
    final existing = _skillRegistry.get(skillName);
    if (existing == null) {
      return ToolExecutionResult.error(
        'Error: Skill "$skillName" not found. '
        'Run the "skill" tool or check the settings to see available skills.',
      );
    }
    if (existing.isBuiltin) {
      return const ToolExecutionResult.error(
        'Error: Built-in skills cannot be deleted.',
      );
    }

    // 删除会一并删掉快照目录：留住一份没有 SKILL.md 的历史没有意义，
    // 也没有入口能再读到它。重建同名技能时从空开始，避免旧快照被
    // 「继承」——这与角色按 id 归档的顾虑同源，只是技能只有一个名字。
    final removed = _skillRegistry.deleteSkill(skillName);
    if (!removed) {
      return ToolExecutionResult.error(
        'Error: Skill "$skillName" not found in the registry.',
      );
    }
    await _historyStore.deleteAllFor(skillName);
    return ToolExecutionResult.success(
      'Skill "$skillName" deleted. Recreate it with action="create" if you '
      'need it again.',
    );
  }

  Future<ToolExecutionResult> _writeSkill({
    required String skillName,
    required String description,
    required String body,
    required String targetDir,
    required bool snapshotPrevious,
  }) async {
    final skillFile = '$targetDir/SKILL.md';
    try {
      final snapshotId = snapshotPrevious
          ? await _snapshotExisting(skillName, targetDir)
          : null;

      // 与 GUI 管理页共用同一写入实现，保证 front matter 转义一致。
      SkillLoader().saveSkill(
        name: skillName,
        description: description,
        body: body,
        targetDir: targetDir,
      );

      _skillRegistry.reloadSkill(skillName, targetDir);

      return ToolExecutionResult.success(
        'Successfully '
        '${snapshotPrevious ? 'updated' : 'created'} skill "$skillName" '
        'at $skillFile.\n'
        '${snapshotId == null ? '' : 'Previous version saved as snapshot '
                  '"$snapshotId"; restore it with skill_revert.\n'}'
        'The skill is available now, including in this conversation. '
        'You can invoke it with the "skill" tool.',
      );
    } catch (e) {
      return ToolExecutionResult.error('Error writing skill file: $e');
    }
  }

  /// 把即将被覆盖的 SKILL.md 存成快照，返回快照 id。
  ///
  /// 快照失败不阻断写入：历史记录缺失不应阻止一次合法的技能改进，与
  /// `SentinelEvolveTool` 的口径一致（缺失只告警）。
  Future<String?> _snapshotExisting(String skillName, String targetDir) async {
    final file = File('$targetDir/SKILL.md');
    try {
      if (!await file.exists()) return null;
      return await _historyStore.save(
        skillName,
        await file.readAsString(),
        reason: 'pre-update state',
      );
    } catch (e) {
      LoggerUtil.w('Skill history snapshot failed for "$skillName": $e');
      return null;
    }
  }
}
