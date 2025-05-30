import 'package:athena/provider/chat.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class MobileChatListPage extends ConsumerWidget {
  const MobileChatListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = chatsNotifierProvider;
    var state = ref.watch(provider);
    var listView = switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
    return AthenaScaffold(
      appBar: AthenaAppBar(title: const Text('Chat history')),
      body: listView,
    );
  }

  Widget _buildData(List<Chat> chats) {
    return ListView.separated(
      itemCount: chats.length,
      itemBuilder: (context, index) => _ListTile(chats[index]),
      padding: EdgeInsets.symmetric(horizontal: 16),
      separatorBuilder: (context, index) => _separatorBuilder(),
    );
  }

  Widget _separatorBuilder() {
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
}

class _ListTile extends ConsumerWidget {
  final Chat chat;
  const _ListTile(this.chat);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openBottomSheet(context, ref),
      child: Icon(HugeIcons.strokeRoundedMoreHorizontal,
          color: ColorUtil.FFFFFFFF),
    );
    var rowChildren = [Expanded(child: title), gestureDetector];
    var columnChildren = [
      Row(children: rowChildren),
      const SizedBox(height: 8),
      _buildMessage(ref),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columnChildren,
    );
    var padding = Padding(padding: const EdgeInsets.all(12.0), child: column);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => navigateChat(context),
      child: padding,
    );
  }

  void destroyChat(BuildContext context, WidgetRef ref) {
    AthenaDialog.dismiss();
    ChatViewModel(ref).destroyChat(chat);
  }

  void navigateChat(BuildContext context) {
    MobileChatRoute(chat: chat).push(context);
  }

  void navigateChatRename(BuildContext context, WidgetRef ref) {
    AthenaDialog.dismiss();
    ChatViewModel(ref).renameChat(chat);
  }

  void openBottomSheet(BuildContext context, WidgetRef ref) {
    var editTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedPencilEdit02),
      title: 'Rename',
      onTap: () => navigateChatRename(context, ref),
    );
    var deleteTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedDelete02),
      title: 'Delete',
      onTap: () => destroyChat(context, ref),
    );
    var children = [editTile, deleteTile];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    var padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    AthenaDialog.show(SafeArea(child: padding));
  }

  Widget _buildMessage(WidgetRef ref) {
    var provider = messagesNotifierProvider(chat.id);
    var messages = ref.watch(provider).valueOrNull;
    if (messages == null) return const SizedBox(height: 72);
    if (messages.isEmpty) return const SizedBox(height: 72);
    var content = messages.last.content.replaceAll('\n', ' ').trim();
    var messageTextStyle = TextStyle(
      color: ColorUtil.FFE0E0E0,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    return Text(
      content,
      style: messageTextStyle,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }
}
