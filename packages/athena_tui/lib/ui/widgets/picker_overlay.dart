import 'package:athena_tui/ui/theme.dart';
import 'package:nocterm/nocterm.dart';

/// 模态选择列表:方向键上下移动、Enter 确认、Esc 取消。
///
/// 常驻于主 Column(children 数量恒定,避免 nocterm ListView 对兄弟
/// 组件动态插入/移除的 diff 断言);[visible] 为 false 时不渲染内容。
/// 按键由 app 层处理(app 的全局键与输入区 onKeyEvent 都会转发给
/// picker,避免 TextField 吞掉方向键)。
class PickerOverlay extends StatelessComponent {
  const PickerOverlay({
    super.key,
    this.visible = false,
    this.title = '',
    this.labels = const [],
    this.selectedIndex = 0,
    this.hint = '↑↓ 选择 · Enter 确认 · Esc 取消',
  });

  final bool visible;
  final String title;
  final List<String> labels;
  final int selectedIndex;
  final String hint;

  @override
  Component build(BuildContext context) {
    if (!visible || labels.isEmpty) return const SizedBox();
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
            child: Text(
              ' $title ',
              style: const TextStyle(
                color: AthenaColors.info,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Text(
                labels[i],
                style: i == selectedIndex
                    ? const TextStyle(
                        reverse: true,
                        fontWeight: FontWeight.bold,
                      )
                    : null,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text(hint, style: AthenaTextStyles.dim),
          ),
        ],
      ),
    );
  }
}
