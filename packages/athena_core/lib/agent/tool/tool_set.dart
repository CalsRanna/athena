import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/tool/bash_shell_tool.dart';
import 'package:athena_core/agent/tool/experience_learn_tool.dart';
import 'package:athena_core/agent/tool/file_read_tool.dart';
import 'package:athena_core/agent/tool/file_update_tool.dart';
import 'package:athena_core/agent/tool/file_write_tool.dart';
import 'package:athena_core/agent/tool/powershell_shell_tool.dart';
import 'package:athena_core/agent/tool/sentinel_evolve_tool.dart';
import 'package:athena_core/agent/tool/skill_evolve_tool.dart';
import 'package:athena_core/agent/tool/skill_tool.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/agent/tool/web_fetch_tool.dart';
import 'package:athena_core/agent/tool/web_search_tool.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/storage/key_value_store.dart';
import 'package:athena_core/util/platform_util.dart';

/// 内置工具集的唯一真相源。
///
/// 每个前端各有自己的装配层（GUI 的 `di.dart`、TUI 的 `tui_di.dart`），
/// 但「有哪些工具、按什么顺序注册、哪个平台注册哪些」是引擎的事实而非
/// 装配层的选择。此前两处各自铺开同一份清单，只靠注释断言一致——加一个
/// 工具就必须同时改两个包，漏一处就是两端能力静默漂移。
///
/// 前端只提供自己特有的差异项（工作目录、变更回调），清单本身在这里。
ToolRegistry buildToolRegistry({
  required SkillRegistry skillRegistry,
  required ExperienceRepository experienceRepository,
  required SentinelRepository sentinelRepository,
  required KeyValueStore store,

  /// Shell 工具的默认工作目录。null = 使用用户主目录。
  String? defaultWorkdir,

  /// Sentinel 被 `sentinel_evolve` 改写后的回调（GUI 用它刷新角色列表）。
  void Function()? onSentinelChanged,

  /// 移动端用户级 `.athena` 根目录（Skill/进化数据根目录；移动端无可靠
  /// `$HOME`，由 GUI 装配层传入沙盒内 Application Support 目录）。
  String? mobileHomeDir,

  /// 覆盖平台判定，仅供测试。
  bool? mobile,
}) {
  final isMobile = mobile ?? PlatformUtil.isMobile;
  final registry = ToolRegistry();

  // 移动端不注册任意文件/进程工具，但进化工具只写自己的 .athena 沙盒目录，
  // 属于移动端可用能力；skill_evolve 在移动端写沙盒内用户级目录。
  if (isMobile) {
    registry.registerAll([
      WebFetchTool(),
      WebSearchTool(store: store),
      SkillTool(skillRegistry),
      SkillEvolveTool(
        skillRegistry: skillRegistry,
        homeDir: mobileHomeDir,
      ),
      ExperienceLearnTool(repository: experienceRepository),
      ExperienceRecallTool(repository: experienceRepository),
      SentinelEvolveTool(
        repository: sentinelRepository,
        onChanged: onSentinelChanged,
      ),
    ]);
    return registry;
  }

  registry.registerAll([
    FileReadTool(),
    FileWriteTool(),
    FileUpdateTool(),
    // bash 与 powershell 按操作系统互斥，运行时只存在一个
    PlatformUtil.isWindows
        ? PowerShellShellTool(defaultWorkdir: defaultWorkdir)
        : BashShellTool(defaultWorkdir: defaultWorkdir),
    WebFetchTool(),
    WebSearchTool(store: store),
    SkillTool(skillRegistry),
    SkillEvolveTool(skillRegistry: skillRegistry),
    ExperienceLearnTool(repository: experienceRepository),
    ExperienceRecallTool(repository: experienceRepository),
    SentinelEvolveTool(
      repository: sentinelRepository,
      onChanged: onSentinelChanged,
    ),
  ]);
  return registry;
}
