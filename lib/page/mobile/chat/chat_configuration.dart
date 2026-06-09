import 'package:athena/entity/chat_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileChatConfigurationPage extends StatefulWidget {
  final ChatEntity chat;
  const MobileChatConfigurationPage({super.key, required this.chat});

  @override
  State<MobileChatConfigurationPage> createState() =>
      _MobileChatConfigurationPageState();
}

class _MobileChatConfigurationPageState
    extends State<MobileChatConfigurationPage> {
  late final _context = signal(widget.chat.context.toDouble());
  late final _temperature = signal(widget.chat.temperature);

  late final viewModel = GetIt.instance<ChatViewModel>();

  @override
  Widget build(BuildContext context) {
    var children = [
      AthenaFormTileLabel.large(title: 'Temperature'),
      const SizedBox(height: 12),
      _buildTemperatureSlider(),
      const SizedBox(height: 24),
      AthenaFormTileLabel.large(title: 'Context'),
      const SizedBox(height: 12),
      _buildContextSlider(),
    ];
    var listView = ListView(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      children: children,
    );
    return AthenaScaffold(
      appBar: AthenaAppBar(title: Text('Chat Configuration')),
      body: listView,
    );
  }

  void _storeContext(double value) {
    viewModel.updateContext(value.toInt(), chat: widget.chat);
  }

  void _storeTemperature(double value) {
    viewModel.updateTemperature(value, chat: widget.chat);
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
