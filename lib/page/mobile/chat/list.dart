import 'package:athena/provider/chat.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
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
    return AScaffold(
      appBar: AAppBar(title: const Text('Chat history')),
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
      color: Colors.white.withValues(alpha: 0.2),
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
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var title = Text(
      chat.title.isNotEmpty ? chat.title : '新的对话',
      style: titleTextStyle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openBottomSheet(context),
      child: Icon(HugeIcons.strokeRoundedMoreHorizontal, color: Colors.white),
    );
    var rowChildren = [Expanded(child: title), gestureDetector];
    var messageTextStyle = TextStyle(
      color: Color(0xFFE0E0E0),
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var message = Text(
      _getContent(ref),
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
      onTap: () => navigateChat(context),
      child: padding,
    );
  }

  void confirmDelete(BuildContext context) {
    var container = ProviderScope.containerOf(context);
    var provider = chatsNotifierProvider;
    var notifier = container.read(provider.notifier);
    notifier.destroy(chat.id);
    ADialog.dismiss();
    ADialog.success('Chat deleted successfully');
  }

  void navigateChat(BuildContext context) {
    MobileChatRoute(chat: chat).push(context);
  }

  void navigateChatRename(BuildContext context) {
    ADialog.dismiss();
    MobileChatRenameRoute(chat: chat).push(context);
  }

  void openBottomSheet(BuildContext context) {
    var children = [
      _buildRenameButton(context),
      const SizedBox(height: 12),
      _buildDeleteButton(context),
      SizedBox(height: MediaQuery.paddingOf(context).bottom)
    ];
    var dialog = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
    ADialog.show(dialog);
  }

  void showConfirmDialog(BuildContext context) {
    ADialog.dismiss();
    ADialog.confirm(
      'Are you sure you want to delete this chat?',
      onConfirmed: confirmDelete,
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return ASecondaryButton(
      onTap: () => showConfirmDialog(context),
      child: Center(child: Text('Delete')),
    );
  }

  Widget _buildRenameButton(BuildContext context) {
    return ASecondaryButton(
      onTap: () => navigateChatRename(context),
      child: Center(child: Text('Rename')),
    );
  }

  String _getContent(WidgetRef ref) {
    var provider = messagesNotifierProvider(chat.id);
    var messages = ref.watch(provider).valueOrNull;
    if (messages == null) return '';
    if (messages.isEmpty) return '';
    return messages.last.content.replaceAll('\n', ' ');
  }
}
