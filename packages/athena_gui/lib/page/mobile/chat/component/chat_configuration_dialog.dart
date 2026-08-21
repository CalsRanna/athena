import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:athena_gui/widget/switch.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

class MobileChatConfigurationDialog extends StatefulWidget {
  final ChatEntity? chat;
  final int retention;
  final double temperature;
  final void Function(int)? onRetentionChanged;
  final void Function(double)? onTemperatureChanged;
  const MobileChatConfigurationDialog({
    super.key,
    this.chat,
    required this.retention,
    required this.temperature,
    this.onRetentionChanged,
    this.onTemperatureChanged,
  });

  @override
  State<MobileChatConfigurationDialog> createState() =>
      _MobileConfigurationDialogState();
}

class _MobileConfigurationDialogState
    extends State<MobileChatConfigurationDialog> {
  late final _zeroContext = signal(widget.retention == 0);
  late final _temperature = signal(widget.temperature);

  @override
  Widget build(BuildContext context) {
    var children = [
      AthenaBottomSheetTile(
        title: 'Temperature',
        trailing: _buildTemperatureSlider(),
      ),
      AthenaBottomSheetTile(
        title: 'Zero Context',
        trailing: _buildRetentionSwitch(),
      ),
    ];
    return ListView(
      padding: EdgeInsets.symmetric(vertical: 16),
      shrinkWrap: true,
      children: children,
    );
  }

  void _storeRetention(bool value) {
    widget.onRetentionChanged?.call(value ? 0 : -1);
  }

  void _storeTemperature(double value) {
    widget.onTemperatureChanged?.call(value);
  }

  Widget _buildRetentionSwitch() {
    return Watch((_) {
      return AthenaSwitch(
        value: _zeroContext.value,
        onChanged: (v) {
          _zeroContext.value = v;
          _storeRetention(v);
        },
      );
    });
  }

  Widget _buildTemperatureSlider() {
    return Watch((context) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
      return Slider(
        activeColor: colors.sage,
        inactiveColor: colors.borderStrong,
        label: _temperature.value.toStringAsFixed(1),
        max: 2,
        onChanged: (v) => _temperature.value = v,
        onChangeEnd: _storeTemperature,
        padding: EdgeInsets.symmetric(horizontal: 4),
        thumbColor: colors.sage,
        value: _temperature.value,
      );
    });
  }
}
