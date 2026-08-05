import 'dart:convert';

import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_tui/ui/text_util.dart';
import 'package:athena_tui/ui/theme.dart';
import 'package:athena_tui/view_model/chat_controller.dart';
import 'package:nocterm/nocterm.dart';

/// 单条消息渲染:推理、正文、每次工具调用、每次工具结果各为独立卡片,
/// 通过不同颜色的左边框区分类型(不再使用 "你"/"Athena"/"[思考]" 等文字前缀):
/// - 推理卡片:黄色实线,内容弱化(灰)
/// - 正文卡片:按消息类型 —— 用户 teal、助手白、系统灰、错误红、取消灰虚线
/// - 工具调用卡片:蓝色实线,每次调用一张卡(⚙ 工具名 + 参数)
/// - 工具结果卡片:绿色实线,每次结果一张卡(↩ 工具名: 结果)
///
/// 边框必须是纯色(不透明):nocterm 的 `_blendStyle` 会对半透明颜色做
/// alpha 混合,多行换行处边框段叠色会发暗。纯色则连续无接缝。
class MessageItem extends StatelessComponent {
  const MessageItem({
    super.key,
    required this.message,
    required this.controller,
  });

  final MessageEntity message;
  final ChatController controller;

  @override
  Component build(BuildContext context) {
    final isUser = message.role == 'user';
    final isCancelled = message.content.contains('[Cancelled]');
    final isError =
        message.content.startsWith('Error:') ||
        message.content.contains('[Error:');
    final isSystem = message.role == 'system';

    // 正文卡片边框颜色与样式由消息类型决定
    var borderColor = isUser
        ? AthenaCardColors.user
        : isSystem
        ? AthenaCardColors.system
        : isError
        ? AthenaCardColors.error
        : isCancelled
        ? AthenaCardColors.cancelled
        : AthenaCardColors.assistant;
    var borderStyle = BoxBorderStyle.solid;
    TextStyle? contentStyle;
    if (isCancelled) {
      contentStyle = AthenaTextStyles.warning;
      borderStyle = BoxBorderStyle.dashed;
    } else if (isError) {
      contentStyle = AthenaTextStyles.error;
    }

    final children = <Component>[];

    // 推理卡片:与正文拆分,黄色左边框,内容弱化(灰)。
    // 顺序在正文之前:思考是"如何得出答案"的过程,应显示在回答之前
    // (与 LLM 流式输出顺序一致:先推理、后正文)。
    if (message.reasoningContent.isNotEmpty || message.reasoning) {
      children.add(
        _ReasoningCard(
          content: message.reasoningContent,
          reasoning: message.reasoning,
        ),
      );
    }

    // 正文卡片:仅正文内容,不含工具调用/结果。
    if (message.content.isNotEmpty) {
      children.add(
        _Card(
          color: borderColor,
          borderStyle: borderStyle,
          child: Text(message.content, style: contentStyle, softWrap: true),
        ),
      );
    }

    // 工具调用卡片:每次调用一张独立卡片。仅在解析成功且调用数 > 0
    // 时生成,解析失败时原样显示在正文卡片中。
    if (message.toolCalls.isNotEmpty) {
      children.addAll(_buildToolCalls(message));
    }

    // 工具结果卡片:每次结果一张独立卡片。
    if (message.toolResults.isNotEmpty) {
      children.addAll(_buildToolResults(message));
    }

    // 多卡片连排:nocterm 边框布局上下各留 1 行,天然形成卡片间距。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  List<Component> _buildToolCalls(MessageEntity message) {
    final cards = <Component>[];
    try {
      final calls = jsonDecode(message.toolCalls) as List;
      for (final call in calls) {
        final map = call as Map<String, dynamic>;
        final name = map['name'] as String? ?? 'tool';
        final arguments = map['arguments'] as String? ?? '';
        cards.add(
          _Card(
            color: AthenaCardColors.toolCall,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚙ $name',
                  style: const TextStyle(
                    color: AthenaColors.info,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (arguments.isNotEmpty)
                  Text(arguments, style: AthenaTextStyles.dim, softWrap: true),
              ],
            ),
          ),
        );
      }
    } catch (_) {
      // 解析失败时原样显示,不中断渲染
      cards.add(Text(message.toolCalls, style: AthenaTextStyles.dim));
    }
    return cards;
  }

  List<Component> _buildToolResults(MessageEntity message) {
    final cards = <Component>[];
    try {
      final list = jsonDecode(message.toolResults) as List;
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final name = map['name'] as String? ?? 'tool';
        final result = map['result'] as String? ?? '';
        cards.add(
          _Card(
            color: AthenaCardColors.toolResult,
            child: Text(
              '↩ $name: ${truncateText(result, 2000, suffix: '…(截断)')}',
              style: AthenaTextStyles.dim,
              softWrap: true,
            ),
          ),
        );
      }
    } catch (_) {
      // 解析失败时原样显示,不中断渲染
      cards.add(Text(message.toolResults, style: AthenaTextStyles.dim));
    }
    return cards;
  }
}

/// 消息卡片:纯色左边框 + 内边距,颜色与线型由消息类型决定。
class _Card extends StatelessComponent {
  const _Card({
    required this.color,
    required this.child,
    this.borderStyle = BoxBorderStyle.solid,
  });

  final Color color;
  final BoxBorderStyle borderStyle;
  final Component child;

  @override
  Component build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        border: BoxBorder(
          left: BorderSide(color: color, style: borderStyle),
        ),
      ),
      child: child,
    );
  }
}

/// 推理卡片:黄色左边框,内容弱化(灰);流式刚开始、内容未到时
/// 显示黄色省略号表示思考中。内容始终展示(终端无点击展开交互)。
class _ReasoningCard extends StatelessComponent {
  const _ReasoningCard({required this.content, required this.reasoning});

  final String content;
  final bool reasoning;

  @override
  Component build(BuildContext context) {
    return _Card(
      color: AthenaCardColors.reasoning,
      child: content.isNotEmpty
          ? Text(content, style: AthenaTextStyles.dim, softWrap: true)
          : // 流式刚开始、内容未到时用省略号占位
            const Text('…', style: AthenaTextStyles.warning),
    );
  }
}
