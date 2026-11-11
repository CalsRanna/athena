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
import 'package:athena_core/agent/tool/skill_tool.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/agent/tool/tool_output_read_tool.dart';
import 'package:athena_core/agent/tool/tool_output_store.dart';
import 'package:athena_core/agent/tool/web_fetch_tool.dart';
import 'package:athena_core/agent/tool/web_search_tool.dart';
import 'package:athena_core/storage/experience_repository.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/storage/user_settings_store.dart';
import 'package:athena_core/util/platform_util.dart';
import 'package:meta/meta.dart';

abstract final class ToolSet {
  /// 与注入到上下文的系统块强耦合、因此不随角色工具配置关闭的工具。
  ///
  /// - [tool_output_read]：截断提示直接教模型调用它
  /// - [experience_learn] / [experience_recall]：经验提示与目录无条件注入，
  ///   反思通道还会程序化调用 [experience_learn]
  /// - [skill]：skill level1 目录无条件注入
  ///
  /// 角色工具配置只裁剪这组之外的业务工具；要放开这里，得同时把对应的
  /// 提示块按有效工具集收口。
  static const kUndeactivatableToolNames = {
    'tool_output_read',
    'experience_learn',
    'experience_recall',
    'skill',
  };

  /// 内置工具集的唯一真相源。
  ///
  /// 每个前端各有自己的装配层（GUI 的 `di.dart`、TUI 的 `tui_di.dart`），
  /// 但「有哪些工具、按什么顺序注册、哪个平台注册哪些」是引擎的事实而非
  /// 装配层的选择。此前两处各自铺开同一份清单，只靠注释断言一致——加一个
  /// 工具就必须同时改两个包，漏一处就是两端能力静默漂移。
  ///
  /// 前端只提供自己特有的差异项（工作目录），清单本身在这里。
  ///
  /// 技能创建复用文件与 shell 工具，按需加载时重新扫描；角色定义不提供读写
  /// 工具，始终由用户在设置中维护。
  /// 技能目录与审批边界见 CONVENTIONS.md §12.5。
  static ToolRegistry buildToolRegistry({
    required SkillRegistry skillRegistry,
    required ExperienceRepository experienceRepository,
    required UserSettingsStore settings,
    ChatRepository? chatRepository,
    MessageRepository? messageRepository,
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

    // 移动端不注册任意文件/进程工具；经验只写自己的 `.athena` 沙盒目录，
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
      ExperienceRecallTool(
        repository: experienceRepository,
        chatRepository: chatRepository,
        messageRepository: messageRepository,
      ),
    ]);
    return registry;
  }
}
