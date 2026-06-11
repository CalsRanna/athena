import 'dart:io';

import 'package:athena/agent/permission/sandbox.dart';
import 'package:athena/agent/skill/skill_registry.dart';
import 'package:athena/agent/tool/tool_interface.dart';

/// 创建或更新 Skill 的工具，使 Agent 具备自我进化能力。
///
/// Agent 可以在遇到无法很好处理的任务时，创建一个新的 Skill
/// 来扩展自己的能力；也可以改进已有的 Skill。
///
/// Skill 保存在项目级（`.athena/skills/`）或用户级（`~/.athena/skills/`）
/// 目录下，以 `SKILL.md` 文件形式存在。
class SkillEvolveTool implements Tool {
  final SkillRegistry _skillRegistry;
  final PathSandbox _sandbox;

  SkillEvolveTool({
    required SkillRegistry skillRegistry,
    required PathSandbox sandbox,
  })  : _skillRegistry = skillRegistry,
        _sandbox = sandbox;

  @override
  String get name => 'skill_evolve';

  @override
  String get description =>
      'Create a new Skill or update an existing one to improve your future '
      'capabilities. Skills are specialized instruction sets that extend your '
      'abilities. Use this tool to:\n'
      '- Create a skill when you encounter a task type that reoccurs and would '
      'benefit from specialized guidance.\n'
      '- Update an existing skill when you discover better approaches or need '
      'to fix issues.\n'
      '- Evolve your capabilities over time based on experience.\n'
      'Skills are saved as SKILL.md files and become available in future '
      'conversations.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description':
                'Skill name (kebab-case, max 64 chars). Must match existing '
                'skill name when updating.',
          },
          'action': {
            'type': 'string',
            'enum': ['create', 'update'],
            'description':
                'Whether to create a new skill or update an existing one.',
          },
          'description': {
            'type': 'string',
            'description':
                'Brief description of what the skill does (required for create, optional for update).',
          },
          'allowed_tools': {
            'type': 'string',
            'description':
                'Comma-separated list of tool names this skill is allowed to '
                'use without approval (e.g. "file_read, search, web_search"). '
                'Dangerous tools (bash, file_write, etc.) will always require '
                'approval regardless of this setting.',
          },
          'body': {
            'type': 'string',
            'description':
                'The full SKILL.md body content — the instructions, workflows, '
                'and guidance that define how the skill operates. Use Markdown. '
                'For updates, provide the complete new body.',
          },
          'scope': {
            'type': 'string',
            'enum': ['project', 'user'],
            'description':
                'Where to save the skill. "project" saves to .athena/skills/ '
                'in the current project (shared via version control). "user" '
                'saves to ~/.athena/skills/ (private, available in all projects). '
                'Default: "project" when working in a project, "user" otherwise.',
          },
        },
        'required': ['name', 'action', 'body'],
      };

  @override
  DangerLevel get dangerLevel => DangerLevel.needsApproval;

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final skillName = args['name'] as String;
    final action = args['action'] as String;
    final description = args['description'] as String? ?? '';
    final allowedTools = args['allowed_tools'] as String? ?? '';
    final body = args['body'] as String;
    final scope = args['scope'] as String? ?? 'project';

    // 验证 skill name
    if (!_isValidSkillName(skillName)) {
      return 'Error: Invalid skill name "$skillName". '
          'Use kebab-case, max 64 chars, no special characters or path separators.';
    }

    if (action == 'update') {
      // 查找现有 skill 的源路径
      final existing = _skillRegistry.get(skillName);
      if (existing == null) {
        return 'Error: Skill "$skillName" not found. '
            'Use action "create" to create a new skill, or check the name spelling.';
      }
      return _writeSkill(
        skillName: skillName,
        description: description.isNotEmpty ? description : existing.description,
        allowedTools: allowedTools.isNotEmpty ? allowedTools : (existing.allowedTools ?? ''),
        body: body,
        targetDir: existing.sourcePath,
      );
    }

    // action == 'create'
    if (_skillRegistry.get(skillName) != null) {
      return 'Error: Skill "$skillName" already exists. '
          'Use action "update" to modify it, or choose a different name.';
    }

    if (description.isEmpty) {
      return 'Error: description is required when creating a new skill.';
    }

    // 确定保存目录
    String targetDir;
    if (scope == 'user') {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '/';
      targetDir = '$home/.athena/skills/$skillName';
    } else {
      targetDir = '${Directory.current.path}/.athena/skills/$skillName';
    }

    return _writeSkill(
      skillName: skillName,
      description: description,
      allowedTools: allowedTools,
      body: body,
      targetDir: targetDir,
    );
  }

  String _writeSkill({
    required String skillName,
    required String description,
    required String allowedTools,
    required String body,
    required String targetDir,
  }) {
    // 沙箱检查
    final skillFile = '$targetDir/SKILL.md';
    if (!_sandbox.canWrite(skillFile)) {
      return 'Error: Cannot write to "$targetDir" — path is in a restricted area.';
    }

    // 构建 SKILL.md 内容
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('name: $skillName');
    buffer.writeln('description: $description');
    if (allowedTools.isNotEmpty) {
      buffer.writeln('allowed-tools: $allowedTools');
    }
    buffer.writeln('---');
    buffer.writeln();
    buffer.write(body.trim());
    if (!body.endsWith('\n')) {
      buffer.writeln();
    }

    try {
      final dir = Directory(targetDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      File(skillFile).writeAsStringSync(buffer.toString());

      // 重新加载该 skill 到 registry
      _skillRegistry.reloadSkill(skillName, targetDir);

      return 'Successfully created/updated skill "$skillName" at $skillFile.\n'
          'The skill is now available for use in future conversations. '
          'You can invoke it with the "skill" tool when needed.';
    } catch (e) {
      return 'Error writing skill file: $e';
    }
  }

  bool _isValidSkillName(String name) {
    if (name.isEmpty || name.length > 64) return false;
    for (final code in name.codeUnits) {
      if (code < 0x20 || code == 0x7f) return false; // 控制字符
      if (code == 0x2f || code == 0x5c) return false; // / \
    }
    if (name == '.' || name == '..') return false;
    return true;
  }
}
