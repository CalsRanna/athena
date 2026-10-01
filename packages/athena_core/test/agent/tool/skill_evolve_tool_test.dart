import 'dart:io';

import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/tool/skill_evolve_tool.dart';
import 'package:athena_core/agent/tool/tool_result.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late SkillRegistry registry;
  late SkillEvolveTool tool;
  setUp(() {
    root = Directory.systemTemp.createTempSync('athena_skill_evolve_');
    registry = SkillRegistry()..loadAll(homeDir: root.path);
    tool = SkillEvolveTool(skillRegistry: registry, homeDir: root.path);
  });
  tearDown(() => root.deleteSync(recursive: true));

  test(
    'an unknown action cannot create a file even when called directly',
    () async {
      final result = await tool.executeResult({
        'name': 'demo',
        'action': 'delete',
        'description': 'demo',
        'body': 'demo',
      });
      expect(result.status, ToolResultStatus.executionError);
      expect(
        File('${root.path}/.athena/skills/demo/SKILL.md').existsSync(),
        isFalse,
      );
    },
  );

  test(
    'built-in skills cannot be written to a relative builtin directory',
    () async {
      registry.registerBuiltin(
        const Skill(
          name: 'builtin',
          description: 'demo',
          body: 'original',
          sourcePath: '(builtin)',
        ),
      );
      final result = await tool.executeResult({
        'name': 'builtin',
        'action': 'update',
        'body': 'changed',
      });
      expect(result.status, ToolResultStatus.executionError);
      expect(registry.get('builtin')!.body, 'original');
    },
  );
}
