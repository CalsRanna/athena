import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// OpenAI 官方推理强度全集(Default = 不传参、使用模型默认)。
/// max 为 codex-max 系模型专属,由 ChatService 的解析层透传发送;
/// 选择模型不支持的档位会 400 报错(与官方一致)。
const reasoningEffortOptions = <(String?, String)>[
  (null, 'Default'),
  ('none', 'None'),
  ('minimal', 'Minimal'),
  ('low', 'Low'),
  ('medium', 'Medium'),
  ('high', 'High'),
  ('xhigh', 'Extra High'),
  ('max', 'Max'),
];

/// 推理强度的显示名;未知值回退为原值,空值显示 Default。
String reasoningEffortLabel(String? value) {
  for (final option in reasoningEffortOptions) {
    if (option.$1 == value) return option.$2;
  }
  return value ?? 'Default';
}

/// 推理强度选择对话框——桌面端,风格与 [DesktopModelSelectDialog]
/// 一致:surfaceMobile 圆角容器 + hover 高亮行,当前档位文字加粗。
class DesktopReasoningEffortSelectDialog extends StatelessWidget {
  final String? current;
  final void Function(String?)? onTap;

  const DesktopReasoningEffortSelectDialog({
    super.key,
    required this.current,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var boxDecoration = BoxDecoration(
      color: colors.surfaceMobile,
      borderRadius: BorderRadius.circular(8),
    );
    var child = ConstrainedBox(
      constraints: BoxConstraints.loose(Size(520, 640)),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final option in reasoningEffortOptions)
            _DesktopReasoningEffortTile(
              label: option.$2,
              selected: option.$1 == current,
              onTap: () => onTap?.call(option.$1),
            ),
        ],
      ),
    );
    var container = Container(
      decoration: boxDecoration,
      padding: EdgeInsets.all(8),
      child: child,
    );
    return UnconstrainedBox(child: container);
  }
}

class _DesktopReasoningEffortTile extends StatefulWidget {
  final String label;
  final bool selected;
  final void Function()? onTap;

  const _DesktopReasoningEffortTile({
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  State<_DesktopReasoningEffortTile> createState() =>
      _DesktopReasoningEffortTileState();
}

class _DesktopReasoningEffortTileState
    extends State<_DesktopReasoningEffortTile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = TextStyle(
      color: colors.textPrimary,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: widget.selected ? FontWeight.w500 : FontWeight.w400,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: hover ? colors.surfaceButtonSecondary : null,
    );
    var container = AnimatedContainer(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(widget.label, style: textStyle),
    );
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: handleEnter,
      onExit: handleExit,
      child: container,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: mouseRegion,
    );
  }

  void handleEnter(PointerEnterEvent event) {
    setState(() {
      hover = true;
    });
  }

  void handleExit(PointerExitEvent event) {
    setState(() {
      hover = false;
    });
  }
}

/// 推理强度选择对话框——移动端,行样式与 [AthenaBottomSheetTile]
/// 一致,当前档位文字加粗区分。
class MobileReasoningEffortSelectDialog extends StatelessWidget {
  final String? current;
  final void Function(String?)? onTap;

  const MobileReasoningEffortSelectDialog({
    super.key,
    required this.current,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        const SizedBox(height: 8),
        for (final option in reasoningEffortOptions)
          _MobileReasoningEffortTile(
            label: option.$2,
            selected: option.$1 == current,
            onTap: () => onTap?.call(option.$1),
          ),
      ],
    );
  }
}

class _MobileReasoningEffortTile extends StatelessWidget {
  final String label;
  final bool selected;
  final void Function()? onTap;

  const _MobileReasoningEffortTile({
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: 14,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      height: 1.5,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, style: textStyle),
        ),
      ),
    );
  }
}
