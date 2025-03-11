import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopImageExportDialog extends ConsumerWidget {
  final Chat chat;
  const DesktopImageExportDialog({super.key, required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = messagesNotifierProvider(chat.id);
    var state = ref.watch(provider);
    var child = switch (state) {
      AsyncData(:final value) => _buildData(ref, value),
      _ => const SizedBox(),
    };
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FF282F32,
      borderRadius: BorderRadius.circular(8),
    );
    var container = Container(decoration: boxDecoration, child: child);
    return UnconstrainedBox(child: container);
  }

  Widget _buildData(WidgetRef ref, List<Message> messages) {
    if (messages.isEmpty == true) return const SizedBox();
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
      onTap: () => exportImage(ref, repaintBoundaryKey),
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

  Future<void> exportImage(WidgetRef ref, GlobalKey key) async {
    AthenaDialog.dismiss();
    AthenaDialog.loading();
    final viewModel = ChatViewModel(ref);
    await viewModel.exportImage(chat: chat, repaintBoundaryKey: key);
    AthenaDialog.dismiss();
  }
}
