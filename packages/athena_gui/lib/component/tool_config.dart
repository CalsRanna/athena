import 'package:athena_core/agent/tool/tool_interface.dart';

abstract final class ToolConfig {
  /// 工具配置区的展示顺序：业务工具在前，与系统块耦合的常开工具在后。
  static const kToolConfigOrder = [
    'file_read',
    'file_write',
    'file_update',
    'bash',
    'powershell',
    'background_task',
    'ask_user_question',
    'web_fetch',
    'web_search',
    'skill',
    'experience_recall',
    'experience_learn',
    'tool_output_read',
  ];

  /// 工具配置区的短标签与说明。工具名是对外契约，展示文案在这里维护；
  /// 未登记的新工具回退到工具名与模型描述的首行。
  static const kToolConfigCopy = <String, (String, String)>{
    'file_read': ('Read files', 'Open text and image files in the workspace.'),
    'file_write': ('Write files', 'Create files or overwrite existing ones.'),
    'file_update': ('Edit files', 'Apply targeted string replacements.'),
    'bash': ('Terminal (bash)', 'Run shell commands.'),
    'powershell': ('Terminal (PowerShell)', 'Run PowerShell commands.'),
    'background_task': (
      'Background tasks',
      'Inspect and stop background shell tasks.',
    ),
    'ask_user_question': (
      'Ask questions',
      'Ask you to choose when a decision is yours.',
    ),
    'web_fetch': ('Fetch web pages', 'Read the contents of a URL.'),
    'web_search': ('Web search', 'Search the web through Brave Search.'),
    'skill': ('Skills', 'Load workspace skills on demand.'),
    'experience_learn': ('Record experience', 'Save lessons for future runs.'),
    'experience_recall': ('Recall experience', 'Search lessons saved earlier.'),
    'tool_output_read': (
      'Read tool output',
      'Page back through truncated tool output.',
    ),
  };

  /// 按 [ToolConfig.kToolConfigOrder] 排序；未登记的工具排在最后。
  static List<Tool> orderedToolsForConfig(List<Tool> tools) {
    int rank(Tool tool) {
      final index = ToolConfig.kToolConfigOrder.indexOf(tool.name);
      return index < 0 ? ToolConfig.kToolConfigOrder.length : index;
    }

    return [...tools]..sort((a, b) => rank(a).compareTo(rank(b)));
  }
}
