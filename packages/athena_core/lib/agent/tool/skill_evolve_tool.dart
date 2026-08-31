import 'dart:io';

import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';

/// 创建或更新 Skill 的工具，使 Agent 具备自我进化能力。
///
/// Agent 可以在遇到无法很好处理的任务时，创建一个新的 Skill
/// 来扩展自己的能力；也可以改进已有的 Skill。
///
/// Skill 统一保存在用户级目录（`~/.athena/skills/`，移动端为沙盒内
/// `.athena/skills/`），以 `SKILL.md` 文件形式存在，对所有会话可用。
class SkillEvolveTool implements Tool {
  @override
  ExecutionMode get executionMode => ExecutionMode.sequential;
  @override
  bool canExecuteParallel(Map<String, dynamic> args) => false;
  final SkillRegistry _skillRegistry;

  /// 用户级 `.athena` 根目录。空 = 使用 `$HOME`（桌面端）。
  final String? _homeDir;

  SkillEvolveTool({
    required SkillRegistry skillRegistry,
    String? homeDir,
  })  : _skillRegistry = skillRegistry,
        _homeDir = homeDir;

  @override
  ToolRisk get risk => ToolRisk.dangerous;

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
      'Skills are saved as SKILL.md files in ~/.athena/skills/ and become '
      'available in all future conversations.';

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
                'use without approval (e.g. "file_read, search, web_search").',
          },
          'body': {
            'type': 'string',
            'description':
                'The full SKILL.md body content — the instructions, workflows, '
                'and guidance that define how the skill operates. Use Markdown. '
                'For updates, provide the complete new body.',
          },
        },
        'required': ['name', 'action', 'body'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args, {void Function(String)? onUpdate}) async {
    final skillName = args['name'] as String;
    final action = args['action'] as String;
    final description = args['description'] as String? ?? '';
    final allowedTools = args['allowed_tools'] as String? ?? '';
    final body = args['body'] as String;

    if (!_isValidSkillName(skillName)) {
      return 'Error: Invalid skill name "$skillName". '
          'Use kebab-case, max 64 chars, no special characters or path separators.';
    }

    if (action == 'update') {
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

    if (_skillRegistry.get(skillName) != null) {
      return 'Error: Skill "$skillName" already exists. '
          'Use action "update" to modify it, or choose a different name.';
    }

    if (description.isEmpty) {
      return 'Error: description is required when creating a new skill.';
    }

    final home = _homeDir ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
    final targetDir = '$home/.athena/skills/$skillName';

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
    final skillFile = '$targetDir/SKILL.md';

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
      if (code < 0x20 || code == 0x7f) return false;
      if (code == 0x2f || code == 0x5c) return false;
      if (code == 0x3a || // :
          code == 0x2a || // *
          code == 0x3f || // ?
          code == 0x22 || // "
          code == 0x3c || // <
          code == 0x3e || // >
          code == 0x7c) {
        return false; // Windows 文件名非法字符
      }
    }
    if (name == '.' || name == '..') return false;
    return true;
  }
}
