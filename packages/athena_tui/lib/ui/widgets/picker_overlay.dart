import 'package:athena_tui/ui/text_util.dart';
import 'package:athena_tui/ui/theme.dart';
import 'package:nocterm/nocterm.dart';

/// 模态选择列表:方向键上下移动、Enter 确认、Esc 取消。
///
/// 常驻于主 Column(children 数量恒定,避免 nocterm ListView 对兄弟
/// 组件动态插入/移除的 diff 断言);[visible] 为 false 时不渲染内容。
/// 按键由 app 层处理(app 的全局键与输入区 onKeyEvent 都会转发给
/// picker,避免 TextField 吞掉方向键)。
///
/// 模型/角色很多时列表超高:弹层高度限制为 [_maxHeight] 行,内部
/// SingleChildScrollView 滚动;选中索引变化(方向键)后自动滚动到
/// 选中项,保证当前项始终可见。
class PickerOverlay extends StatefulComponent {
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

  /// 弹层最大高度(行);超出时内部滚动。
  static const double _maxHeight = 12;

  @override
  State<PickerOverlay> createState() => _PickerOverlayState();
}

class _PickerOverlayState extends State<PickerOverlay> {
  final _scrollController = ScrollController();

  @override
  void didUpdateComponent(PickerOverlay oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.visible &&
        (oldComponent.selectedIndex != component.selectedIndex ||
            oldComponent.visible != component.visible)) {
      // 布局完成后滚动到选中项:内容第一行为标题,每项占 1 行,
      // 所以选中项顶部 offset = 1 + index。ensureVisible 只在
      // 项超出视口时才滚动,项可见时不打扰。
      final binding = NoctermBinding.instance;
      if (binding is SchedulerBinding) {
        binding.addPostFrameCallback((_) {
          if (!mounted) return;
          _scrollController.ensureVisible(
            itemOffset: 1.0 + component.selectedIndex,
            itemExtent: 1.0,
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    if (!component.visible || component.labels.isEmpty) {
      return const SizedBox();
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: PickerOverlay._maxHeight),
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
          border: BoxBorder.all(color: AthenaColors.info),
        ),
        // keyboardScrollable 默认 false:方向键必须到达 app 层的
        // _handlePickerKey(选中索引更新),不能被滚动组件吞掉
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Text(
                  ' ${component.title} ',
                  style: const TextStyle(
                    color: AthenaColors.info,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              for (var i = 0; i < component.labels.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Text(
                    sanitizeAnsi(component.labels[i]),
                    style: i == component.selectedIndex
                        ? const TextStyle(
                            reverse: true,
                            fontWeight: FontWeight.bold,
                          )
                        : null,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Text(component.hint, style: AthenaTextStyles.dim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
