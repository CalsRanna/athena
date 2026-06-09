import 'package:athena/entity/chat_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

class MobileChatConfigurationDialog extends StatefulWidget {
  final ChatEntity? chat;
  final int contextToken;
  final double temperature;
  final void Function(int)? onContextChanged;
  final void Function(double)? onTemperatureChanged;
  const MobileChatConfigurationDialog({
    super.key,
    this.chat,
    required this.contextToken,
    required this.temperature,
    this.onContextChanged,
    this.onTemperatureChanged,
  });

  @override
  State<MobileChatConfigurationDialog> createState() =>
      _MobileConfigurationDialogState();
}

class _MobileConfigurationDialogState
    extends State<MobileChatConfigurationDialog> {
  late final _context = signal(widget.contextToken.toDouble());
  late final _temperature = signal(widget.temperature);

  @override
  Widget build(BuildContext context) {
    var children = [
      AthenaBottomSheetTile(
        title: 'Temperature',
        trailing: _buildTemperatureSlider(),
      ),
      AthenaBottomSheetTile(
        title: 'Context',
        trailing: _buildContextSlider(),
      ),
    ];
    return ListView(
      padding: EdgeInsets.symmetric(vertical: 16),
      shrinkWrap: true,
      children: children,
    );
  }

  void _storeContext(double value) {
    widget.onContextChanged?.call(value.toInt());
  }

  void _storeTemperature(double value) {
    widget.onTemperatureChanged?.call(value);
  }

  Widget _buildContextSlider() {
    return Watch((_) {
      return Slider(
        activeColor: ColorUtil.FFA7BA88,
        inactiveColor: ColorUtil.FFFFFFFF,
        label: _context.value.toStringAsFixed(0),
        max: 20,
        onChanged: (v) => _context.value = v,
        onChangeEnd: _storeContext,
        padding: EdgeInsets.symmetric(horizontal: 4),
        thumbColor: ColorUtil.FFA7BA88,
        value: _context.value,
      );
    });
  }

  Widget _buildTemperatureSlider() {
    return Watch((_) {
      return Slider(
        activeColor: ColorUtil.FFA7BA88,
        inactiveColor: ColorUtil.FFFFFFFF,
        label: _temperature.value.toStringAsFixed(1),
        max: 2,
        onChanged: (v) => _temperature.value = v,
        onChangeEnd: _storeTemperature,
        padding: EdgeInsets.symmetric(horizontal: 4),
        thumbColor: ColorUtil.FFA7BA88,
        value: _temperature.value,
      );
    });
  }
}
