import 'package:athena_tui/ui/theme.dart';
import 'package:nocterm/nocterm.dart';

/// 错误提示条:消息列表下方的非模态错误展示。
///
/// 消费 [ChatController.error](sendMessage 的 RunError / 异常、配置引导)。
/// 常驻于主 Column(children 数量恒定),[message] 为 null 时不渲染内容,
/// 与 PickerOverlay / PermissionBar 的模式一致。
class ErrorBar extends StatelessComponent {
  const ErrorBar({super.key, required this.message});

  final String? message;

  @override
  Component build(BuildContext context) {
    final text = message;
    if (text == null || text.isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
      decoration: BoxDecoration(
        border: BoxBorder.all(color: AthenaColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚠ 错误',
            style: TextStyle(
              color: AthenaColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(text, style: AthenaTextStyles.error, softWrap: true),
        ],
      ),
    );
  }
}
