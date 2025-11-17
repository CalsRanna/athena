import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/component/message_list_tile.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileChatExportPage extends StatelessWidget {
  final ChatEntity chat;
  const MobileChatExportPage({super.key, required this.chat});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var chatViewModel = GetIt.instance<ChatViewModel>();
      var messages = chatViewModel.messages.value
          .where((m) => m.chatId == chat.id)
          .toList();

      var appBar = AthenaAppBar(title: Text('Export Image'));
      return AthenaScaffold(appBar: appBar, body: _buildData(messages));
    });
  }

  Future<void> exportImage(GlobalKey key) async {
    AthenaDialog.loading();
    final viewModel = GetIt.instance<ChatViewModel>();
    await viewModel.exportImage(chat: chat, repaintBoundaryKey: key);
    AthenaDialog.dismiss();
  }

  Widget _buildBarrier(GlobalKey repaintBoundaryKey) {
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
    return Container(
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(gradient: linearGradient),
      padding: EdgeInsets.all(16),
      child: SafeArea(child: exportButton),
    );
  }

  Widget _buildData(List<MessageEntity> messages) {
    if (messages.isEmpty == true) return const SizedBox();
    var repaintBoundaryKey = GlobalKey();
    var barrier = _buildBarrier(repaintBoundaryKey);
    var listView = _buildRenderListView(
      messages,
      repaintBoundaryKey: repaintBoundaryKey,
    );
    var stackChildren = [
      Positioned.fill(child: listView),
      Positioned.fill(child: AbsorbPointer(child: const SizedBox())),
      Positioned(bottom: 0, left: 0, right: 0, child: barrier),
    ];
    return Stack(children: stackChildren);
  }

  Widget _buildRenderListView(
    List<MessageEntity> messages, {
    required GlobalKey repaintBoundaryKey,
  }) {
    List<Widget> children = [];
    var emptySentinel = SentinelEntity(
      id: 0,
      name: '',
      avatar: '',
      description: '',
      tags: [],
      prompt: '',
    );
    for (var message in messages) {
      var messageListTile = MessageListTile(
        message: message.copyWith(expanded: true),
        sentinel: emptySentinel,
      );
      children.add(messageListTile);
      children.add(const SizedBox(height: 12));
    }
    children.removeLast();
    var container = Container(
      decoration: BoxDecoration(color: ColorUtil.FF282F32),
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
    var repaintBoundary = RepaintBoundary(
      key: repaintBoundaryKey,
      child: container,
    );
    return SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: repaintBoundary,
    );
  }
}
