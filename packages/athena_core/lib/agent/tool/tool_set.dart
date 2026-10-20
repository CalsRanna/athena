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
import 'package:athena_core/agent/tool/sentinel_get_tool.dart';
import 'package:athena_core/agent/tool/sentinel_list_tool.dart';
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
/// 前端只提供自己特有的差异项（工作目录），清单本身在这里。
///
/// **这里没有自我改写类工具**：Agent 不能新建或改写技能，也不能改写自己的
/// 系统提示词。技能与角色是用户的编辑权（GUI 设置页），Agent 只有读取权
/// ——`skill` 按需加载、`sentinel_list` / `sentinel_get` 查看。经验记忆是
/// 唯一的自我积累通道，且它记录的是参考，不是生效中的规则。
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

  // 移动端不注册任意文件/进程工具；经验记忆只写自己的 `.athena` 沙盒目录，
  // 属于移动端可用能力。提问不是文件/进程能力，移动端已有提问卡，因此和
  // 联网工具一样保留。
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
    ExperienceLearnTool(repository: experienceRepository),
    ExperienceRecallTool(repository: experienceRepository),
    SentinelListTool(repository: sentinelRepository),
    SentinelGetTool(repository: sentinelRepository),
  ]);
  return registry;
}
