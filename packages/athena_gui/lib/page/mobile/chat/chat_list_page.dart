import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/chat_history_entity.dart';
import 'package:athena_gui/component/message_tiles.dart';
import 'package:athena_gui/page/mobile/component/empty_state.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

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
    final action = AthenaIconButton(
      icon: LucideIcons.plus,
      onTap: () => MobileChatRoute().push<void>(context),
    );
    return AthenaScaffold(
      appBar: AthenaAppBar(
        action: action,
        title: const Text('Session history'),
      ),
      body: _buildData(),
    );
  }

  Widget _buildData() {
    return Watch((context) {
      final histories = viewModel.chatHistories.value;
      if (histories.isEmpty) {
        return MobileEmptyState(
          icon: LucideIcons.messageSquare,
          title: 'No sessions yet',
          hint: 'Start a new session and it will show up here.',
          action: AthenaPrimaryButton(
            onTap: () => MobileChatRoute().push<void>(context),
            child: const Center(child: Text('New Session')),
          ),
        );
      }
      final pinned = histories.where((history) => history.chat.pinned).toList();
      final recent = histories
          .where((history) => !history.chat.pinned)
          .toList();
      final children = <Widget>[
        if (pinned.isNotEmpty) _buildGroupLabel(context, 'Pinned'),
        if (pinned.isNotEmpty) ..._buildGroup(context, pinned),
        if (recent.isNotEmpty) _buildGroupLabel(context, 'Recent'),
        if (recent.isNotEmpty) ..._buildGroup(context, recent),
      ];
      return RefreshIndicator(
        onRefresh: () => viewModel.getChats(),
        child: ListView(
          padding: EdgeInsets.only(
            top: 4,
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          children: children,
        ),
      );
    });
  }

  List<Widget> _buildGroup(
    BuildContext context,
    List<ChatHistoryEntity> histories,
  ) {
    final children = <Widget>[];
    for (var i = 0; i < histories.length; i++) {
      if (i > 0) children.add(_buildSeparator(context));
      children.add(_buildItem(context, histories[i]));
    }
    return children;
  }

  Widget _buildGroupLabel(BuildContext context, String label) {
    final colors = context.athenaColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 4),
      child: Text(
        label,
        style: AthenaTextStyle.caption.copyWith(color: colors.textWeak),
      ),
    );
  }

  Widget _buildItem(BuildContext context, ChatHistoryEntity chatHistory) {
    final colors = context.athenaColors;
    final chat = chatHistory.chat;
    final streaming = viewModel.isStreamingChat(chat.id!);
    final titleTextStyle = AthenaTextStyle.section.copyWith(
      color: colors.textPrimary,
    );
    final title = Text(
      chat.title.isNotEmpty ? chat.title.trim() : 'New Session',
      style: titleTextStyle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final titleRow = Row(
      children: [
        if (streaming) ...[
          const StreamingIndicator(),
          const SizedBox(width: 6),
        ],
        if (chat.pinned) ...[
          Icon(
            LucideIcons.pin,
            size: AthenaIcon.inlineSize,
            color: colors.iconSecondary,
          ),
          const SizedBox(width: 6),
        ],
        Expanded(child: title),
      ],
    );
    final moreButton = AthenaGhostIconButton(
      icon: AthenaIcons.more,
      box: AthenaIconButtonSize.touchTarget,
      iconSize: AthenaIcon.regularSize,
      onTap: () => _openBottomSheet(context, chat),
    );
    final rowChildren = [Expanded(child: titleRow), moreButton];
    final content = chatHistory.lastMessageContent.replaceAll('\n', ' ').trim();
    final messageTextStyle = AthenaTextStyle.caption.copyWith(
      color: colors.iconSecondary,
    );
    final message = Text(
      content,
      style: messageTextStyle,
      maxLines: 2,
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
    final colors = context.athenaColors;
    final divider = Divider(color: colors.border, height: 1, thickness: 1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: divider,
    );
  }

  Future<void> _destroyChat(BuildContext context, ChatEntity chat) async {
    AthenaDialog.dismiss();
    final confirmed = await AthenaDialog.confirm(
      'Delete this session and all its messages?',
    );
    if (confirmed != true) return;
    await viewModel.deleteChat(chat);
    final error = viewModel.error.value;
    if (error != null) AthenaDialog.error(error);
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
    final pinTile = AthenaBottomSheetTile(
      leading: Icon(chat.pinned ? LucideIcons.pinOff : LucideIcons.pin),
      title: chat.pinned ? 'Unpin' : 'Pin',
      onTap: () {
        AthenaDialog.dismiss();
        viewModel.togglePin(chat);
      },
    );
    final deleteTile = AthenaBottomSheetTile(
      leading: const Icon(LucideIcons.trash2),
      title: 'Delete',
      onTap: () => _destroyChat(context, chat),
    );
    final children = [editTile, pinTile, deleteTile];
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
      'Rename Session',
      initialValue: chat.title,
    );

    if (title != null && title.isNotEmpty && title != chat.title) {
      await viewModel.renameChatManually(chat, title);
    }
  }
}
