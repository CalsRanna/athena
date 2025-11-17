import 'package:athena/entity/chat_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopConfigurationButton extends StatelessWidget {
  final ChatEntity chat;
  final void Function(int)? onContextChange;
  final void Function(double)? onTemperatureChange;
  const DesktopConfigurationButton({
    super.key,
    required this.chat,
    this.onContextChange,
    this.onTemperatureChange,
  });

  @override
  Widget build(BuildContext context) {
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

  void openDialog() {
    var desktopConfigurationDialog = _DesktopConfigurationDialog(
      chat: chat,
      onContextChange: onContextChange,
      onTemperatureChange: onTemperatureChange,
    );
    AthenaDialog.show(desktopConfigurationDialog, barrierDismissible: true);
  }
}

class _DesktopConfigurationDialog extends StatelessWidget {
  final ChatEntity chat;
  final void Function(int)? onContextChange;
  final void Function(double)? onTemperatureChange;
  const _DesktopConfigurationDialog({
    required this.chat,
    this.onContextChange,
    this.onTemperatureChange,
  });

  @override
  Widget build(BuildContext context) {
    var contextSlider = _DesktopConfigurationDialogContextSlider(
      context: chat.context,
      onChange: onContextChange,
    );
    var temperatureSlider = _DesktopConfigurationDialogTemperatureSlider(
      temperature: chat.temperature,
      onChange: onTemperatureChange,
    );
    var children = [
      _DesktopConfigurationDialogTile(
        help:
            'The number of previous turns to include in the conversation\'s '
            'context. Set to 0 for no limit.',
        title: 'Context',
        child: contextSlider,
      ),
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

class _DesktopConfigurationDialogContextSlider extends StatefulWidget {
  final int context;
  final void Function(int)? onChange;
  const _DesktopConfigurationDialogContextSlider({
    required this.context,
    this.onChange,
  });

  @override
  State<_DesktopConfigurationDialogContextSlider> createState() =>
      _DesktopConfigurationDialogContextSliderState();
}

class _DesktopConfigurationDialogContextSliderState
    extends State<_DesktopConfigurationDialogContextSlider> {
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
      label: value.toStringAsFixed(0),
      max: 20,
      onChanged: _updateValue,
      onChangeEnd: (value) => widget.onChange?.call(value.toInt()),
      padding: EdgeInsets.symmetric(horizontal: 4),
      thumbColor: ColorUtil.FFA7BA88,
      value: value,
    );
    var text = Text(
      value.toStringAsFixed(0),
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
    value = widget.context.toDouble();
  }

  void _updateValue(double value) {
    setState(() {
      this.value = value;
    });
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
