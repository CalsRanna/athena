import 'package:athena_tui/ui/theme.dart';
import 'package:athena_tui/ui/widgets/streaming_progress_bar.dart';
import 'package:athena_tui/view_model/chat_controller.dart';
import 'package:nocterm/nocterm.dart';

/// 输入区:多行输入框 + 底部状态行(流式时显示运行状态)。
class InputArea extends StatelessComponent {
  const InputArea({
    super.key,
    required this.controller,
    required this.textController,
    required this.onSubmitted,
    required this.onKeyEvent,
    this.placeholder = '输入消息…',
    this.statusText = '',
  });

  final ChatController controller;
  final TextEditingController textController;
  final ValueChanged<String> onSubmitted;
  final KeyEventHandler onKeyEvent;

  /// 非默认时显示为输入框 placeholder(如"输入 API key…")。
  final String placeholder;

  /// 非空时覆盖默认状态行(如 API key 输入提示)。
  final String statusText;

  @override
  Component build(BuildContext context) {
    final isStreaming = controller.isStreaming.value;

    return Column(
      children: [
        if (isStreaming)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Row(
              children: [
                // 流式生成时:循环动画进度条 + Esc 停止提示
                const StreamingProgressBar(),
                const Spacer(),
                Text('Esc 停止', style: AthenaTextStyles.warning),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            border: BoxBorder.all(color: AthenaColors.toolBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // onKeyEvent 必须传给 TextField 自身:它在 TextField 内部按键
              // 处理(含 Enter 提交、方向键移动光标)之前被调用,返回 true 即
              // 拦截。包在外层 Focusable 上收不到被 TextField 消费的按键。
              TextField(
                controller: textController,
                focused: true,
                maxLines: 4,
                minLines: 1,
                placeholder: placeholder,
                placeholderStyle: AthenaTextStyles.dim,
                onKeyEvent: onKeyEvent,
                onSubmitted: onSubmitted,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
