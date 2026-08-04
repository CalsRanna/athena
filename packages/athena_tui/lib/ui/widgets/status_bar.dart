import 'package:athena_tui/ui/theme.dart';
import 'package:athena_tui/view_model/chat_controller.dart';
import 'package:nocterm/nocterm.dart';

/// 顶部状态栏:应用名 | 模型 | 角色 | 右侧:迭代/工具状态 + token 用量。
class StatusBar extends StatelessComponent {
  const StatusBar({super.key, required this.controller});

  final ChatController controller;

  @override
  Component build(BuildContext context) {
    final model = controller.currentModel.value;
    final sentinel = controller.currentSentinel.value;
    final iteration = controller.currentIteration.value;
    final toolName = controller.currentToolName.value;
    final usage = controller.currentTokenUsage.value;
    final chat = controller.currentChat.value;

    final title = _truncate(chat?.title ?? 'Athena', 24);
    final modelName = _truncate(model?.name ?? '未选模型', 20);
    final sentinelName = _truncate(sentinel?.name ?? '未选角色', 12);

    final rightParts = <String>[];
    if (iteration > 0) rightParts.add('迭代 $iteration');
    if (toolName != null) rightParts.add('工具: $toolName');
    if (usage != null) {
      final total = _formatTokens(usage.totalTokens);
      rightParts.add('tokens: $total');
    }
    final right = rightParts.isEmpty ? '按 /help 查看命令' : rightParts.join('  ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        children: [
          const Text('● Athena', style: AthenaTextStyles.statusBar),
          const Text('  '),
          Expanded(
            child: Text(
              ' $modelName  |  $sentinelName  |  $title',
              style: AthenaTextStyles.dim,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(' $right ', style: AthenaTextStyles.dim),
        ],
      ),
    );
  }

  static String _truncate(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max - 1)}…';
  }

  static String _formatTokens(int tokens) {
    if (tokens >= 10000) return '${(tokens / 1000).toStringAsFixed(1)}k';
    return tokens.toString();
  }
}
