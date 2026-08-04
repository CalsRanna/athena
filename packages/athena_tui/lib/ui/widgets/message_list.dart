import 'package:athena_tui/ui/theme.dart';
import 'package:athena_tui/ui/widgets/message_item.dart';
import 'package:athena_tui/view_model/chat_controller.dart';
import 'package:nocterm/nocterm.dart';

/// 消息列表:滚动显示全部消息,新消息/流式更新时自动滚底。
///
/// 用 SingleChildScrollView + Column 而非 ListView:nocterm 0.8.0 的
/// ListView 在父级组件树动态变化(如 Overlay 插入)时会触发元素复用
/// 断言(`newComponent != component`);消息量级下整树构建开销可接受。
class MessageList extends StatelessComponent {
  const MessageList({super.key, required this.controller, required this.scrollController});

  final ChatController controller;
  final ScrollController scrollController;

  @override
  Component build(BuildContext context) {
    final messages = controller.messages.value;

    return SingleChildScrollView(
      controller: scrollController,
      // 关闭键盘滚动:nocterm 的按键分发是深度优先全树,滚动组件会先于
      // TextField 消费方向键,导致选择模态(picker)收不到 ↑↓
      keyboardScrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (messages.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: const Center(
                child: Text(
                  '在下方输入消息开始对话。\n输入 /help 查看命令。',
                  style: AthenaTextStyles.dim,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            for (final message in messages)
              MessageItem(message: message, controller: controller),
          // 底部留白,让输入区与最后一条消息之间有呼吸感
          const SizedBox(height: 1),
        ],
      ),
    );
  }
}
