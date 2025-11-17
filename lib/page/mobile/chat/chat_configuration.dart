import 'package:athena/entity/chat_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

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
  late var _context = widget.chat.context.toDouble();
  late var temperature = widget.chat.temperature;

  late final viewModel = GetIt.instance<ChatViewModel>();

  @override
  Widget build(BuildContext context) {
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
      AthenaFormTileLabel.large(title: 'Temperature'),
      const SizedBox(height: 12),
      temperatureSlider,
      const SizedBox(height: 24),
      AthenaFormTileLabel.large(title: 'Context'),
      const SizedBox(height: 12),
      contextSlider,
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
