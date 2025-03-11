import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/message.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class MobileChatExportPage extends ConsumerWidget {
  final Chat chat;
  const MobileChatExportPage({super.key, required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = messagesNotifierProvider(chat.id);
    var state = ref.watch(provider);
    var child = switch (state) {
      AsyncData(:final value) => _buildData(ref, value),
      _ => const SizedBox(),
    };
    var appBar = AthenaAppBar(title: Text('Export Image'));
    return AthenaScaffold(appBar: appBar, body: child);
  }

  Future<void> exportImage(WidgetRef ref, GlobalKey key) async {
    AthenaDialog.loading();
    final viewModel = ChatViewModel(ref);
    await viewModel.exportImage(chat: chat, repaintBoundaryKey: key);
    AthenaDialog.dismiss();
  }

  Widget _buildBarrier(WidgetRef ref, GlobalKey repaintBoundaryKey) {
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
      onTap: () => exportImage(ref, repaintBoundaryKey),
      child: padding,
    );
    return Container(
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(gradient: linearGradient),
      padding: EdgeInsets.all(16),
      child: SafeArea(child: exportButton),
    );
  }

  Widget _buildData(WidgetRef ref, List<Message> messages) {
    if (messages.isEmpty == true) return const SizedBox();
    var repaintBoundaryKey = GlobalKey();
    var barrier = _buildBarrier(ref, repaintBoundaryKey);
    var stackChildren = [
      _buildRepaintBoundary(repaintBoundaryKey, messages),
      Positioned.fill(child: _buildRenderListView(messages)),
      Positioned.fill(child: AbsorbPointer(child: const SizedBox())),
      Positioned(bottom: 0, left: 0, right: 0, child: barrier),
    ];
    return Stack(children: stackChildren);
  }

  Widget _buildRenderListView(List<Message> messages) {
    var emptySentinel = Sentinel();
    var listView = ListView.separated(
      itemBuilder: (_, index) =>
          MessageListTile(message: messages[index], sentinel: emptySentinel),
      itemCount: messages.length,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
    );
    return Container(color: ColorUtil.FF282F32, child: listView);
  }

  Widget _buildRepaintBoundary(
    GlobalKey repaintBoundaryKey,
    List<Message> messages,
  ) {
    List<Widget> children = [];
    var emptySentinel = Sentinel();
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
    var repaintBoundary = RepaintBoundary(
      key: repaintBoundaryKey,
      child: container,
    );
    var verticalSingleChildScrollView = SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: repaintBoundary,
    );
    var constrainedBox = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 960, minWidth: 960),
      child: verticalSingleChildScrollView,
    );
    var horizontalSingleChildScrollView = SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      scrollDirection: Axis.horizontal,
      child: constrainedBox,
    );
    return horizontalSingleChildScrollView;
  }
}
