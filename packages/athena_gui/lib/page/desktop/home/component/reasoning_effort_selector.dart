import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/widget/reasoning_effort.dart';
import 'package:athena_gui/page/desktop/home/component/composer_selection_menu.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

/// 工具栏上的推理强度文字（如 `High`）。只负责显示：点击由外层
/// `AthenaGhostButton` 接管，弹出 [DesktopReasoningEffortMenu]。
class DesktopReasoningEffortLabel extends StatelessWidget {
  final String current;
  const DesktopReasoningEffortLabel({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    return Text(
      ReasoningEffort.reasoningEffortLabel(current),
      // 与模型名同字号同字重（都是常规字重）
      style: AthenaTextStyle.body.copyWith(color: colors.textPrimary),
    );
  }
}

/// 与模型选择共用列表样式，当前推理强度在行尾打钩。
class DesktopReasoningEffortMenu extends StatelessWidget {
  final Rect anchor;
  final String current;
  final void Function(String)? onSelected;

  const DesktopReasoningEffortMenu({
    super.key,
    required this.anchor,
    required this.current,
    this.onSelected,
  });

  static void show(
    BuildContext context,
    Rect anchor, {
    required String current,
    void Function(String)? onSelected,
  }) {
    DesktopContextMenuManager.instance.show(
      context,
      DesktopReasoningEffortMenu(
        anchor: anchor,
        current: current,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultEffort =
        GetIt.instance<SettingViewModel>().defaultReasoningEffort.value;
    return DesktopComposerSelectionMenu(
      anchor: anchor,
      children: [
        const DesktopContextMenuGroupLabel(text: 'Reasoning effort'),
        for (final (value, label) in ReasoningEffort.reasoningEffortOptions)
          DesktopContextMenuTile(
            text: label,
            badge: value == defaultEffort
                ? const DesktopMenuDefaultBadge()
                : null,
            selected: value == current,
            onTap: () {
              if (value != current) onSelected?.call(value);
            },
          ),
      ],
    );
  }
}
