import 'package:athena_tui/ui/text_util.dart';
import 'package:athena_tui/ui/theme.dart';
import 'package:athena_tui/view_model/chat_controller.dart';
import 'package:nocterm/nocterm.dart';

/// 底部状态栏: 模型 | 角色 ｜ 工作区 | 右侧:迭代/工具状态 + token 用量。
class StatusBar extends StatelessComponent {
  const StatusBar({
    super.key,
    required this.controller,
    required this.workspace,
  });

  final ChatController controller;

  /// 当前工作区目录名(Agent 工具的工作根目录)。
  final String workspace;

  @override
  Component build(BuildContext context) {
    final model = controller.currentModel.value;
    final sentinel = controller.currentSentinel.value;
    final usage = controller.currentTokenUsage.value;
    final chat = controller.currentChat.value;

    final title = truncateText(chat?.title ?? 'Athena', 24);
    final modelName = truncateText(model?.name ?? '未选模型', 20);
    final sentinelName = truncateText(sentinel?.name ?? '未选角色', 12);
    // Windows 路径用反斜杠：统一转 / 再取末段
    final workspaceName = workspace.replaceAll('\\', '/').split('/').last;

    final rightParts = <String>[];
    if (usage != null) {
      final total = _formatTokens(usage.totalTokens);
      rightParts.add('tokens: $total');
    }
    final right = rightParts.isEmpty ? '按 /help 查看命令' : rightParts.join(' | ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$sentinelName | $modelName | $workspaceName | $title',
              style: AthenaTextStyles.dim,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(right, style: AthenaTextStyles.dim),
        ],
      ),
    );
  }

  static String _formatTokens(int tokens) {
    if (tokens >= 10000) return '${(tokens / 1000).toStringAsFixed(1)}k';
    return tokens.toString();
  }
}
