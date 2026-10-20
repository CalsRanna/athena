import 'package:athena_core/agent/evolution/sentinel_history_store.dart';
import 'package:athena_core/agent/evolution/skill_history_store.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/task/background_task.dart';
import 'package:athena_core/agent/tool/ask_user_question_tool.dart';
import 'package:athena_core/agent/tool/background_task_tool.dart';
import 'package:athena_core/agent/tool/bash_shell_tool.dart';
import 'package:athena_core/agent/tool/experience_learn_tool.dart';
import 'package:athena_core/agent/tool/file_read_tool.dart';
import 'package:athena_core/agent/tool/file_update_tool.dart';
import 'package:athena_core/agent/tool/file_write_tool.dart';
import 'package:athena_core/agent/tool/powershell_shell_tool.dart';
import 'package:athena_core/agent/tool/sentinel_evolve_tool.dart';
import 'package:athena_core/agent/tool/sentinel_get_tool.dart';
import 'package:athena_core/agent/tool/sentinel_list_tool.dart';
import 'package:athena_core/agent/tool/sentinel_revert_tool.dart';
import 'package:athena_core/agent/tool/skill_evolve_tool.dart';
import 'package:athena_core/agent/tool/skill_revert_tool.dart';
import 'package:athena_core/agent/tool/skill_tool.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/agent/tool/tool_output_read_tool.dart';
import 'package:athena_core/agent/tool/tool_output_store.dart';
import 'package:athena_core/agent/tool/web_fetch_tool.dart';
import 'package:athena_core/agent/tool/web_search_tool.dart';
import 'package:athena_core/storage/experience_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/storage/user_settings_store.dart';
import 'package:athena_core/util/platform_util.dart';
import 'package:meta/meta.dart';

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
  required UserSettingsStore settings,
  ToolOutputStore? outputStore,

  /// 后台任务登记表（桌面端有 shell 才有意义）。null = 新建一个。
  BackgroundTaskService? backgroundTasks,

  /// Shell 工具的默认工作目录。null = 使用用户主目录。
  String? defaultWorkdir,

  /// Sentinel 被 `sentinel_evolve` 改写后的回调（GUI 用它刷新角色列表）。
  void Function()? onSentinelChanged,

  /// 移动端用户级 `.athena` 根目录（Skill/进化数据根目录；移动端无可靠
  /// `$HOME`，由 GUI 装配层传入沙盒内 Application Support 目录）。
  String? mobileHomeDir,

  /// 角色演进快照的共享实例。前端另有入口（删除角色时级联清理快照）需要
  /// 读到同一目录，此时传入；不传则按与技能/经验相同的口径自建。
  SentinelHistoryStore? historyStore,

  /// 技能演进快照的共享实例，用途同 [historyStore]。
  SkillHistoryStore? skillHistoryStore,

  /// 覆盖平台判定，仅供测试。
  @visibleForTesting bool? mobile,
}) {
  final isMobile = mobile ?? PlatformUtil.isMobile;
  final registry = ToolRegistry(
    outputStore: outputStore,
    backgroundTasks: backgroundTasks,
  );
  final tasks = registry.backgroundTasks;
  registry.register(ToolOutputReadTool(registry.outputStore));
  // 快照与经验、技能落在同一个用户级根目录：桌面 `$HOME`、移动端沙盒。
  // 这里必须与 SkillEvolveTool 的 [mobileHomeDir] 口径一致——桌面端无条件
  // 采用沙盒目录会把演进历史写到一个 TUI 看不到的地方。
  final snapshots =
      historyStore ??
      SentinelHistoryStore(homeDir: isMobile ? mobileHomeDir : null);
  // 技能快照与 SKILL.md 同根（`skills/<name>/history/`），因此与
  // skill_evolve 的 homeDir 取同一个值。
  final skillHomeDir = isMobile ? mobileHomeDir : null;
  final skillSnapshots =
      skillHistoryStore ?? SkillHistoryStore(homeDir: skillHomeDir);

  // 移动端不注册任意文件/进程工具，但进化工具只写自己的 .athena 沙盒目录，
  // 属于移动端可用能力；skill_evolve 在移动端写沙盒内用户级目录。
  // 提问不是文件/进程能力，移动端已有提问卡，因此和联网工具一样保留。
  registry.registerAll([
    if (!isMobile) ...[
      FileReadTool(),
      FileWriteTool(),
      FileUpdateTool(),
      PlatformUtil.isWindows
          ? PowerShellShellTool(defaultWorkdir: defaultWorkdir, tasks: tasks)
          : BashShellTool(defaultWorkdir: defaultWorkdir, tasks: tasks),
      BackgroundTaskTool(tasks),
    ],
    AskUserQuestionTool(),
    WebFetchTool(),
    WebSearchTool(settings: settings),
    SkillTool(skillRegistry),
    SkillEvolveTool(
      skillRegistry: skillRegistry,
      historyStore: skillSnapshots,
      homeDir: skillHomeDir,
    ),
    SkillRevertTool(skillRegistry: skillRegistry, historyStore: skillSnapshots),
    ExperienceLearnTool(repository: experienceRepository),
    ExperienceRecallTool(repository: experienceRepository),
    SentinelListTool(repository: sentinelRepository),
    SentinelGetTool(repository: sentinelRepository),
    SentinelEvolveTool(
      repository: sentinelRepository,
      historyStore: snapshots,
      onChanged: onSentinelChanged,
    ),
    SentinelRevertTool(
      repository: sentinelRepository,
      historyStore: snapshots,
      onChanged: onSentinelChanged,
    ),
  ]);
  return registry;
}
