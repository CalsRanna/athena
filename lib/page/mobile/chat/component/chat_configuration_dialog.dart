import 'package:athena/schema/chat.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MobileChatConfigurationDialog extends ConsumerStatefulWidget {
  final Chat chat;
  final int contextToken;
  final double temperature;
  final void Function(int)? onContextChanged;
  final void Function(double)? onTemperatureChanged;
  const MobileChatConfigurationDialog({
    super.key,
    required this.chat,
    required this.contextToken,
    required this.temperature,
    this.onContextChanged,
    this.onTemperatureChanged,
  });

  @override
  ConsumerState<MobileChatConfigurationDialog> createState() =>
      _MobileConfigurationDialogState();
}

class _MobileConfigurationDialogState
    extends ConsumerState<MobileChatConfigurationDialog> {
  late double _context = widget.contextToken.toDouble();
  late double _temperature = widget.temperature;

  late final viewModel = ChatViewModel(ref);

  @override
  Widget build(BuildContext context) {
    var temperatureSlider = Slider(
      activeColor: ColorUtil.FFA7BA88,
      inactiveColor: ColorUtil.FFFFFFFF,
      label: _temperature.toStringAsFixed(1),
      max: 2,
      onChanged: _updateTemperature,
      onChangeEnd: _storeTemperature,
      padding: EdgeInsets.symmetric(horizontal: 4),
      thumbColor: ColorUtil.FFA7BA88,
      value: _temperature,
    );
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
    var children = [
      AthenaBottomSheetTile(title: 'Temperature', trailing: temperatureSlider),
      AthenaBottomSheetTile(title: 'Context', trailing: contextSlider),
    ];
    return ListView(
      padding: EdgeInsets.symmetric(vertical: 16),
      children: children,
    );
  }

  void _storeContext(double value) {
    widget.onContextChanged?.call(value.toInt());
  }

  void _storeTemperature(double value) {
    widget.onTemperatureChanged?.call(value);
  }

  void _updateContext(double value) {
    setState(() {
      _context = value;
    });
  }

  void _updateTemperature(double value) {
    setState(() {
      _temperature = value;
    });
  }
}
