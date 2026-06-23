import 'package:athena/entity/chat_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/switch.dart';
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
    if (compact) return _buildCompactButton();
    var icon = Icon(
      HugeIcons.strokeRoundedSlidersHorizontal,
      color: ColorUtil.FFFFFFFF,
      size: 24,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: openDialog,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: icon),
    );
  }

  Widget _buildCompactButton() {
    var row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          HugeIcons.strokeRoundedSlidersHorizontal,
          color: ColorUtil.FFFFFFFF,
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
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FF282F32,
      borderRadius: BorderRadius.circular(8),
    );
    var container = Container(
      decoration: boxDecoration,
      padding: EdgeInsets.all(8),
      child: child,
    );
    return UnconstrainedBox(child: container);
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
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    var slider = Slider(
      activeColor: ColorUtil.FFA7BA88,
      inactiveColor: ColorUtil.FFFFFFFF,
      label: value.toStringAsFixed(1),
      max: 2,
      onChanged: _updateValue,
      onChangeEnd: (value) => widget.onChange?.call(value),
      padding: EdgeInsets.symmetric(horizontal: 4),
      thumbColor: ColorUtil.FFA7BA88,
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
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: hover ? ColorUtil.FF616161 : null,
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
                if (widget.help != null) _buildTooltip(),
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

  Widget _buildTooltip() {
    var icon = Icon(
      HugeIcons.strokeRoundedHelpCircle,
      color: ColorUtil.FFFFFFFF,
      size: 14,
    );
    return Tooltip(
      constraints: BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: ColorUtil.FF282F32,
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
