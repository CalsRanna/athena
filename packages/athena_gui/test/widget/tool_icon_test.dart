import 'dart:io';

import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/tool/tool_set.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/storage/json_array_sentinel_repository.dart';
import 'package:athena_core/storage/json_file_key_value_store.dart';
import 'package:athena_gui/component/step_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  for (final mobile in [false, true]) {
    test('${mobile ? '移动' : '桌面'}端所有注册工具均有明确图标', () async {
      final temp = await Directory.systemTemp.createTemp('athena_tool_icons_');
      addTearDown(() => temp.delete(recursive: true));
      final registry = buildToolRegistry(
        skillRegistry: SkillRegistry(),
        experienceRepository: ExperienceRepository(homeDir: temp.path),
        sentinelRepository: JsonArraySentinelRepository(
          file: File.fromUri(temp.uri.resolve('sentinels.json')),
        ),
        store: JsonFileKeyValueStore(
          file: File.fromUri(temp.uri.resolve('kv.json')),
        ),
        defaultWorkdir: temp.path,
        mobileHomeDir: temp.path,
        mobile: mobile,
      );
      addTearDown(registry.backgroundTasks.dispose);

      expect(registry.all, isNotEmpty);
      for (final tool in registry.all) {
        expect(
          StepCard.toolIcon(tool.name),
          isNot(LucideIcons.wrench),
          reason: '${tool.name} 已注册但未配置工具图标',
        );
      }
    });
  }

  // 断言直接遍历 core 的清单，而不是再抄一份 ['bash', 'powershell']：
  // core 新增 shell 工具时这条自动跟着扩展，图标映射也必须跟上。
  test('core 里的每个 shell 工具都用终端图标', () {
    expect(kShellToolNames, isNotEmpty);
    for (final name in kShellToolNames) {
      expect(StepCard.toolIcon(name), LucideIcons.terminal);
    }
  });

  test('未知或空工具名称使用通用图标', () {
    for (final name in ['unknown_tool', '']) {
      expect(StepCard.toolIcon(name), LucideIcons.wrench);
    }
  });
}
