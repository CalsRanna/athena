import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/chat_history_entity.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:athena/widget/dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

class ChatTile extends StatelessWidget {
  final ChatHistoryEntity chatHistory;
  final ChatViewModel viewModel;
  const ChatTile(this.chatHistory, {super.key, required this.viewModel});

  ChatEntity get chat => chatHistory.chat;

  @override
  Widget build(BuildContext context) {
    const shapeDecoration = ShapeDecoration(
      color: ColorUtil.FFFFFFFF,
      shape: StadiumBorder(),
    );
    final body = Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text(chat.title.isNotEmpty ? chat.title.trim() : '新的对话'),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handlePressed(context),
      onLongPress: () => handleLongPress(context),
      child: body,
    );
  }

  void handlePressed(BuildContext context) async {
    MobileChatRoute(chat: chat).push(context);
  }

  void handleLongPress(BuildContext context) {
    HapticFeedback.heavyImpact();
    var renameTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedPencilEdit02),
      title: 'Rename',
      onTap: () => _renameChat(context, viewModel),
    );
    var deleteTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedDelete02),
      title: 'Delete',
      onTap: () => _deleteChat(viewModel),
    );
    var children = [renameTile, deleteTile];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    var padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    AthenaDialog.show(SafeArea(child: padding));
  }

  void _deleteChat(ChatViewModel viewModel) {
    AthenaDialog.dismiss();
    viewModel.deleteChat(chat);
  }

  void _renameChat(BuildContext context, ChatViewModel viewModel) async {
    AthenaDialog.dismiss();
    var title = await AthenaDialog.input(
      'Rename Chat',
      initialValue: chat.title,
    );
    if (title != null && title.isNotEmpty && title != chat.title) {
      await viewModel.renameChatManually(chat, title);
    }
  }
}
