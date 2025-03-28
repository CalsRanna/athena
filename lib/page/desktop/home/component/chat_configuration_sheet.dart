import 'package:athena/schema/chat.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopChatConfigurationSheet extends ConsumerStatefulWidget {
  final Chat chat;
  const DesktopChatConfigurationSheet({super.key, required this.chat});
  @override
  ConsumerState<DesktopChatConfigurationSheet> createState() =>
      _DesktopChatConfigurationSheetState();
}

class _DesktopChatConfigurationSheetState
    extends ConsumerState<DesktopChatConfigurationSheet> {
  late var _context = widget.chat.context.toDouble();
  late var temperature = widget.chat.temperature;

  late final viewModel = ChatViewModel(ref);

  @override
  Widget build(BuildContext context) {
    var moduleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var labelTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var temperatureChildren = [
      Text('Temperature', style: labelTextStyle),
      const Spacer(),
      Text(temperature.toStringAsFixed(1), style: labelTextStyle),
    ];
    var temperatureSlider = Slider(
      activeColor: ColorUtil.FFA7BA88,
      inactiveColor: ColorUtil.FFFFFFFF,
      label: temperature.toStringAsFixed(1),
      max: 2,
      onChanged: _updateTemperature,
      onChangeEnd: _storeTemperature,
      padding: EdgeInsets.symmetric(horizontal: 4),
      thumbColor: ColorUtil.FFA7BA88,
      value: temperature,
    );
    var contextChildren = [
      Text('Context', style: labelTextStyle),
      const Spacer(),
      Text(_context.toStringAsFixed(0), style: labelTextStyle),
    ];
    var contextSlider = Slider(
      activeColor: ColorUtil.FFA7BA88,
      inactiveColor: ColorUtil.FFFFFFFF,
      label: _context.toStringAsFixed(0),
      max: 20,
      onChanged: _updateContext,
      onChangeEnd: _storeContext,
      padding: EdgeInsets.symmetric(horizontal: 4),
      thumbColor: ColorUtil.FFA7BA88,
      value: _context,
    );
    return ListView(
      padding: EdgeInsets.all(12),
      children: [
        Text('Model Configuration', style: moduleTextStyle),
        const SizedBox(height: 12),
        Row(children: temperatureChildren),
        const SizedBox(height: 12),
        temperatureSlider,
        const SizedBox(height: 12),
        Row(children: contextChildren),
        const SizedBox(height: 12),
        contextSlider,
      ],
    );
  }

  @override
  void didUpdateWidget(covariant DesktopChatConfigurationSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {
      _context = widget.chat.context.toDouble();
      temperature = widget.chat.temperature;
    });
  }

  void _storeContext(double value) {
    viewModel.updateContext(value.toInt(), chat: widget.chat);
  }

  void _storeTemperature(double value) {
    viewModel.updateTemperature(value, chat: widget.chat);
  }

  void _updateContext(double value) {
    setState(() {
      _context = value;
    });
  }

  void _updateTemperature(double value) {
    setState(() {
      temperature = value;
    });
  }
}
