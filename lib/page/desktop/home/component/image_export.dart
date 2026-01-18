import 'package:athena/component/message_list_tile.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopImageExportDialog extends StatelessWidget {
  final ChatEntity chat;
  const DesktopImageExportDialog({super.key, required this.chat});

  @override
  Widget build(BuildContext context) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FF282F32,
      borderRadius: BorderRadius.circular(8),
    );

    return Watch((context) {
      var messages = chatViewModel.messages.value;
      var child = _buildData(messages);
      var container = Container(decoration: boxDecoration, child: child);
      return UnconstrainedBox(child: container);
    });
  }

  Widget _buildData(List<MessageEntity> messages) {
    if (messages.isEmpty == true) return const SizedBox();
    List<Widget> children = [];
    var emptySentinel = SentinelEntity(
      id: 0,
      name: '',
      prompt: '',
      avatar: '',
      description: '',
      tags: '',
    );
    for (var message in messages) {
      var expandedMessage = message.copyWith(expanded: true);
      var messageListTile = MessageListTile(
        message: expandedMessage,
        sentinel: emptySentinel,
      );
      children.add(messageListTile);
      children.add(const SizedBox(height: 12));
    }
    children.removeLast();
    var container = Container(
      decoration: BoxDecoration(color: ColorUtil.FF282F32),
      padding: const EdgeInsets.all(64),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
    var repaintBoundaryKey = GlobalKey();
    var repaintBoundary = RepaintBoundary(
      key: repaintBoundaryKey,
      child: container,
    );
    var singleChildScrollView = SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: repaintBoundary,
    );
    var constrainedBox = ConstrainedBox(
      constraints: BoxConstraints.loose(Size(960, 600)),
      child: singleChildScrollView,
    );
    var linearGradient = LinearGradient(
      begin: Alignment.topCenter,
      colors: [Colors.transparent, ColorUtil.FF282F32],
      end: Alignment.bottomCenter,
    );
    var padding = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text('Export'),
    );
    var exportButton = AthenaPrimaryButton(
      onTap: () => exportImage(repaintBoundaryKey),
      child: padding,
    );
    var barrier = Container(
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(gradient: linearGradient),
      padding: EdgeInsets.all(16),
      child: exportButton,
    );
    var stackChildren = [
      constrainedBox,
      Positioned.fill(child: AbsorbPointer(child: const SizedBox())),
      Positioned(bottom: 0, left: 0, right: 0, child: barrier),
    ];
    return Material(
      type: MaterialType.transparency,
      child: Stack(children: stackChildren),
    );
  }

  Future<void> exportImage(GlobalKey key) async {
    AthenaDialog.loading();
    final chatViewModel = GetIt.instance<ChatViewModel>();
    await chatViewModel.exportImage(chat: chat, repaintBoundaryKey: key);
    AthenaDialog.dismiss();
    AthenaDialog.dismiss();
  }
}
