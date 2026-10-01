import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
      appBar: const AthenaAppBar(title: Text('Chat history')),
      body: _buildData(),
    );
  }

  Widget _buildData() {
    return Watch(
      (_) => RefreshIndicator(
        onRefresh: () => viewModel.getChats(),
        child: ListView.separated(
          itemCount: viewModel.chatHistories.value.length,
          itemBuilder: _buildItem,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          separatorBuilder: (context, index) => _buildSeparator(context),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final chatHistory = viewModel.chatHistories.value[index];
    final chat = chatHistory.chat;
    final titleTextStyle = AthenaTextStyle.section.copyWith(
      color: colors.textPrimary,
    );
    final title = Text(
      chat.title.isNotEmpty ? chat.title.trim() : 'New Chat',
      style: titleTextStyle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final icon = Icon(AthenaIcons.more, color: colors.textPrimary);
    final gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openBottomSheet(context, chat),
      child: icon,
    );
    final rowChildren = [Expanded(child: title), gestureDetector];
    final content = chatHistory.lastMessageContent.replaceAll('\n', ' ').trim();
    final messageTextStyle = AthenaTextStyle.caption.copyWith(
      color: colors.iconSecondary,
    );
    final message = Text(
      content,
      style: messageTextStyle,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
    final columnChildren = [
      Row(children: rowChildren),
      const SizedBox(height: 8),
      message,
    ];
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columnChildren,
    );
    final padding = Padding(padding: const EdgeInsets.all(12.0), child: column);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateMobileChatPage(context, chat),
      child: padding,
    );
  }

  Widget _buildSeparator(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final divider = Divider(color: colors.border, height: 1, thickness: 1);
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
    MobileChatRoute(chat: chat).push<void>(context);
  }

  void _openBottomSheet(BuildContext context, ChatEntity chat) {
    final editTile = AthenaBottomSheetTile(
      leading: const Icon(LucideIcons.pencilLine),
      title: 'Rename',
      onTap: () => _renameChat(context, chat),
    );
    final deleteTile = AthenaBottomSheetTile(
      leading: const Icon(LucideIcons.trash2),
      title: 'Delete',
      onTap: () => _destroyChat(context, chat),
    );
    final children = [editTile, deleteTile];
    final column = Column(mainAxisSize: MainAxisSize.min, children: children);
    final padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    AthenaDialog.show(SafeArea(child: padding));
  }

  void _renameChat(BuildContext context, ChatEntity chat) async {
    AthenaDialog.dismiss();

    final title = await AthenaDialog.input(
      'Rename Chat',
      initialValue: chat.title,
    );

    if (title != null && title.isNotEmpty && title != chat.title) {
      await viewModel.renameChatManually(chat, title);
    }
  }
}
