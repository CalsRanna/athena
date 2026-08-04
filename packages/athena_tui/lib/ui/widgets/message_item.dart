import 'dart:convert';

import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_tui/ui/theme.dart';
import 'package:athena_tui/view_model/chat_controller.dart';
import 'package:nocterm/nocterm.dart';

/// 单条消息渲染:用户/助手文本、思考折叠块、工具调用卡片与结果。
class MessageItem extends StatelessComponent {
  const MessageItem({super.key, required this.message, required this.controller});

  final MessageEntity message;
  final ChatController controller;

  @override
  Component build(BuildContext context) {
    final isUser = message.role == 'user';
    final isCancelled = message.content.contains('[Cancelled]');
    final isError = message.content.startsWith('Error:') ||
        message.content.contains('[Error:');
    final isSystem = message.role == 'system';

    final children = <Component>[];

    // 角色前缀
    final prefix = isUser
        ? const Text('❯ 你', style: AthenaTextStyles.teal)
        : isSystem
            ? const Text('▸ 系统', style: AthenaTextStyles.dim)
            : const Text('▸ Athena', style: AthenaTextStyles.dim);
    children.add(prefix);

    // 思考块(流式中或已结束)。内容始终展示:终端里推理过程默认可见,
    // 流式中标题为 [思考中…],结束后为 [思考]。reasoningContent 为空但
    // 仍在流式(reasoning=true)时,只显示标题占位。
    // 顺序在正文之前:思考是"如何得出答案"的过程,应显示在回答之前
    // (与 LLM 流式输出顺序一致:先推理、后正文)。
    if (message.reasoningContent.isNotEmpty || message.reasoning) {
      children.add(_ReasoningBlock(
        content: message.reasoningContent,
        reasoning: message.reasoning,
      ));
    }

    // 正文
    final content = message.content;
    if (content.isNotEmpty) {
      TextStyle? style;
      if (isCancelled) {
        style = AthenaTextStyles.warning;
      } else if (isError) {
        style = AthenaTextStyles.error;
      }
      children.add(Padding(
        padding: const EdgeInsets.only(left: 2, top: 0),
        child: Text(content, style: style, softWrap: true),
      ));
    }

    // 工具调用卡片
    if (message.toolCalls.isNotEmpty) {
      children.addAll(_buildToolCards(message));
    }

    // 工具结果
    if (message.toolResults.isNotEmpty) {
      children.addAll(_buildToolResults(message));
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 0),
      margin: const EdgeInsets.only(bottom: 1),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  List<Component> _buildToolCards(MessageEntity message) {
    final cards = <Component>[];
    try {
      final calls = jsonDecode(message.toolCalls) as List;
      for (final call in calls) {
        final map = call as Map<String, dynamic>;
        final name = map['name'] as String? ?? 'tool';
        final arguments = map['arguments'] as String? ?? '';
        cards.add(Container(
          margin: const EdgeInsets.only(left: 2, top: 1),
          padding: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            border: BoxBorder.all(color: AthenaColors.toolBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('⚙ $name', style: const TextStyle(
                color: AthenaColors.info,
                fontWeight: FontWeight.bold,
              )),
              if (arguments.isNotEmpty)
                Text(arguments, style: AthenaTextStyles.dim, softWrap: true),
            ],
          ),
        ));
      }
    } catch (_) {
      // 解析失败时原样显示,不中断渲染
      cards.add(Text(message.toolCalls, style: AthenaTextStyles.dim));
    }
    return cards;
  }

  List<Component> _buildToolResults(MessageEntity message) {
    final results = <Component>[];
    try {
      final list = jsonDecode(message.toolResults) as List;
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final name = map['name'] as String? ?? 'tool';
        final result = map['result'] as String? ?? '';
        results.add(Container(
          margin: const EdgeInsets.only(left: 2, top: 1),
          padding: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            border: BoxBorder.all(color: AthenaColors.toolBorder),
          ),
          child: Text(
            '↩ $name: ${_truncate(result, 2000)}',
            style: AthenaTextStyles.dim,
            softWrap: true,
          ),
        ));
      }
    } catch (_) {
      results.add(Text(message.toolResults, style: AthenaTextStyles.dim));
    }
    return results;
  }

  static String _truncate(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}…(截断)';
  }
}

/// 思考块:流式中显示 [思考中…] 并实时展示推理增量,结束后显示 [思考]。
/// 内容始终展示(终端无点击展开交互,推理过程默认可见)。
class _ReasoningBlock extends StatelessComponent {
  const _ReasoningBlock({required this.content, required this.reasoning});

  final String content;
  final bool reasoning;

  @override
  Component build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          reasoning ? ' [思考中…] ' : ' [思考] ',
          style: reasoning
              ? AthenaTextStyles.warning
              : const TextStyle(color: AthenaColors.dim),
        ),
        if (content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(content, style: AthenaTextStyles.dim, softWrap: true),
          ),
      ],
    );
  }
}
