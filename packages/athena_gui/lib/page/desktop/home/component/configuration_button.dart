import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopConfigurationButton extends StatelessWidget {
  final ChatEntity? chat;
  final int currentRetention;
  final double currentTemperature;
  final bool compact;
  final String? label;
  final void Function(int)? onRetentionChange;
  final void Function(double)? onTemperatureChange;
  const DesktopConfigurationButton({
    super.key,
    this.chat,
    required this.currentRetention,
    required this.currentTemperature,
    this.compact = false,
    this.label,
    this.onRetentionChange,
    this.onTemperatureChange,
  });

  const DesktopConfigurationButton.compact({
    super.key,
    this.chat,
    this.currentRetention = -1,
    this.currentTemperature = 0.7,
    this.label = 'Configure',
    this.onRetentionChange,
    this.onTemperatureChange,
  }) : compact = true;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    if (compact) return _buildCompactButton(context);
    var icon = Icon(
      HugeIcons.strokeRoundedSlidersHorizontal,
      color: colors.textPrimary,
      size: 24,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: openDialog,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: icon),
    );
  }

  Widget _buildCompactButton(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          HugeIcons.strokeRoundedSlidersHorizontal,
          color: colors.textPrimary,
          size: 14,
        ),
        const SizedBox(width: 8),
        Text(label ?? 'Configure'),
      ],
    );
    return AthenaSecondaryButton.small(onTap: openDialog, child: row);
  }

  void openDialog() {
    var desktopConfigurationDialog = _DesktopConfigurationDialog(
      chat: chat,
      currentRetention: currentRetention,
      currentTemperature: currentTemperature,
      onRetentionChange: onRetentionChange,
      onTemperatureChange: onTemperatureChange,
    );
    AthenaDialog.show(desktopConfigurationDialog, barrierDismissible: true);
  }
}

class _DesktopConfigurationDialog extends StatefulWidget {
  final ChatEntity? chat;
  final int currentRetention;
  final double currentTemperature;
  final void Function(int)? onRetentionChange;
  final void Function(double)? onTemperatureChange;
  const _DesktopConfigurationDialog({
    this.chat,
    required this.currentRetention,
    required this.currentTemperature,
    this.onRetentionChange,
    this.onTemperatureChange,
  });

  @override
  State<_DesktopConfigurationDialog> createState() =>
      _DesktopConfigurationDialogState();
}

class _DesktopConfigurationDialogState
    extends State<_DesktopConfigurationDialog> {
  late bool _zeroContext;

  @override
  void initState() {
    super.initState();
    final retention = widget.chat?.retention ?? widget.currentRetention;
    _zeroContext = retention == 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var retentionTile = _DesktopConfigurationDialogTile(
      help:
          'When enabled, each message is sent independently without any '
          'conversation history. Ideal for one-shot tasks.',
      title: 'Zero Context',
      child: AthenaSwitch(
        value: _zeroContext,
        onChanged: (v) {
          setState(() => _zeroContext = v);
          widget.onRetentionChange?.call(v ? 0 : -1);
        },
      ),
    );
    var temperatureSlider = _DesktopConfigurationDialogTemperatureSlider(
      temperature: widget.chat?.temperature ?? widget.currentTemperature,
      onChange: widget.onTemperatureChange,
    );
    var children = [
      retentionTile,
      _DesktopConfigurationDialogTile(
        title: 'Temperature',
        child: temperatureSlider,
      ),
    ];
    var child = ConstrainedBox(
      constraints: BoxConstraints.loose(Size(520, 640)),
      child: ListView(shrinkWrap: true, children: children),
    );
    // Material 包裹:Slider/pill 等 Material 组件需要 Material 环境;
    // 改用 Material 而非自绘 BoxDecoration,避免 dialog 默认白色
    // Material 表面从容器边缘露出。
    var material = Material(
      color: colors.surfaceMobile,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: EdgeInsets.all(8), child: child),
    );
    return UnconstrainedBox(child: material);
  }
}

class _DesktopConfigurationDialogTemperatureSlider extends StatefulWidget {
  final double temperature;
  final void Function(double)? onChange;
  const _DesktopConfigurationDialogTemperatureSlider({
    required this.temperature,
    this.onChange,
  });

  @override
  State<_DesktopConfigurationDialogTemperatureSlider> createState() =>
      _DesktopConfigurationDialogTemperatureSliderState();
}

class _DesktopConfigurationDialogTemperatureSliderState
    extends State<_DesktopConfigurationDialogTemperatureSlider> {
  double value = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = TextStyle(
      color: colors.textPrimary,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    var slider = Slider(
      activeColor: colors.sage,
      inactiveColor: colors.textPrimary,
      label: value.toStringAsFixed(1),
      max: 2,
      onChanged: _updateValue,
      onChangeEnd: (value) => widget.onChange?.call(value),
      padding: EdgeInsets.symmetric(horizontal: 4),
      thumbColor: colors.sage,
      value: value,
    );
    var text = Text(
      value.toStringAsFixed(1),
      style: textStyle,
      textAlign: TextAlign.end,
    );
    var children = [
      SizedBox(width: 240, child: slider),
      SizedBox(width: 40, child: text),
    ];
    return Row(children: children);
  }

  @override
  void initState() {
    super.initState();
    value = widget.temperature;
  }

  @override
  void didUpdateWidget(_DesktopConfigurationDialogTemperatureSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.temperature != oldWidget.temperature) {
      value = widget.temperature;
    }
  }

  void _updateValue(double value) {
    setState(() {
      this.value = value;
    });
  }
}

class _DesktopConfigurationDialogTile extends StatefulWidget {
  final String title;
  final String? help;
  final Widget child;
  const _DesktopConfigurationDialogTile({
    this.help,
    required this.title,
    required this.child,
  });

  @override
  State<_DesktopConfigurationDialogTile> createState() =>
      _DesktopConfigurationDialogTileState();
}

class _DesktopConfigurationDialogTileState
    extends State<_DesktopConfigurationDialogTile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = TextStyle(
      color: colors.textPrimary,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
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
      child: Row(
        children: [
          Expanded(
            child: Row(
              spacing: 4,
              children: [
                Flexible(child: Text(widget.title, style: textStyle)),
                if (widget.help != null) _buildTooltip(context),
              ],
            ),
          ),
          widget.child,
        ],
      ),
    );
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: handleEnter,
      onExit: handleExit,
      child: container,
    );
    return Material(color: Colors.transparent, child: mouseRegion);
  }

  Widget _buildTooltip(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var icon = Icon(
      HugeIcons.strokeRoundedHelpCircle,
      color: colors.textPrimary,
      size: 14,
    );
    return Tooltip(
      constraints: BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: colors.surfaceMobile,
        borderRadius: BorderRadius.circular(8),
      ),
      message: widget.help,
      padding: EdgeInsets.all(8),
      preferBelow: false,
      child: icon,
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
