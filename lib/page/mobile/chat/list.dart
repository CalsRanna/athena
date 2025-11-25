import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileChatListPage extends StatefulWidget {
  const MobileChatListPage({super.key});

  @override
  State<MobileChatListPage> createState() => _MobileChatListPageState();
}

class _MobileChatListPageState extends State<MobileChatListPage> {
  final viewModel = GetIt.instance<ChatViewModel>();

  @override
  Widget build(BuildContext context) {
    return AthenaScaffold(
      appBar: AthenaAppBar(title: const Text('Chat history')),
      body: _buildData(),
    );
  }

  Widget _buildData() {
    return Watch(
      (_) => ListView.separated(
        itemCount: viewModel.chats.value.length,
        itemBuilder: _buildItem,
        padding: EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (context, index) => _buildSeparator(),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    var chat = viewModel.chats.value[index];
    var titleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var title = Text(
      chat.title.isNotEmpty ? chat.title : 'New Chat',
      style: titleTextStyle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    var icon = Icon(
      HugeIcons.strokeRoundedMoreHorizontal,
      color: ColorUtil.FFFFFFFF,
    );
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openBottomSheet(context, chat),
      child: icon,
    );
    var rowChildren = [Expanded(child: title), gestureDetector];
    var messages = viewModel.messages.value.where((m) => m.chatId == chat.id);
    var content = '';
    if (messages.isNotEmpty) {
      content = messages.last.content.replaceAll('\n', ' ').trim();
    }
    var messageTextStyle = TextStyle(
      color: ColorUtil.FFE0E0E0,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var message = Text(
      content,
      style: messageTextStyle,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
    var columnChildren = [
      Row(children: rowChildren),
      const SizedBox(height: 8),
      message,
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columnChildren,
    );
    var padding = Padding(padding: const EdgeInsets.all(12.0), child: column);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateMobileChatPage(context, chat),
      child: padding,
    );
  }

  Widget _buildSeparator() {
    var divider = Divider(
      color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2),
      height: 1,
      thickness: 1,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: divider,
    );
  }

  void _destroyChat(BuildContext context, ChatEntity chat) {
    AthenaDialog.dismiss();
    viewModel.deleteChat(chat);
  }

  void _navigateMobileChatPage(BuildContext context, ChatEntity chat) {
    MobileChatRoute(chat: chat).push(context);
  }

  void _openBottomSheet(BuildContext context, ChatEntity chat) {
    var editTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedPencilEdit02),
      title: 'Rename',
      onTap: () => _renameChat(context, chat),
    );
    var deleteTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedDelete02),
      title: 'Delete',
      onTap: () => _destroyChat(context, chat),
    );
    var children = [editTile, deleteTile];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    var padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    AthenaDialog.show(SafeArea(child: padding));
  }

  void _renameChat(BuildContext context, ChatEntity chat) async {
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
