import 'package:athena_tui/ui/theme.dart';
import 'package:nocterm/nocterm.dart';

/// 斜杠命令实时建议:输入以 `/` 开头时,在输入区上方展示匹配的命令。
///
/// 常驻于主 Column(children 数量恒定,与 PickerOverlay 同模式);
/// [visible] 为 false 时不渲染内容。过滤逻辑在 app 层(监听输入框),
/// 本组件只负责渲染,不做按键处理。
class CommandSuggestions extends StatelessComponent {
  const CommandSuggestions({
    super.key,
    required this.visible,
    required this.commands,
  });

  final bool visible;

  /// (命令, 描述) 列表,已按输入前缀过滤。
  final List<(String, String)> commands;

  @override
  Component build(BuildContext context) {
    if (!visible || commands.isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        border: BoxBorder.all(color: AthenaColors.info),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: const Text(
              ' 命令提示(Tab 补全) ',
              style: TextStyle(
                color: AthenaColors.info,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          for (final command in commands)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Row(
                children: [
                  Text(
                    command.$1,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('  ${command.$2}', style: AthenaTextStyles.dim),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
