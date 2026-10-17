import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/chat_history_entity.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:athena_gui/widget/dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatTile extends StatelessWidget {
  final ChatHistoryEntity chatHistory;
  final ChatViewModel viewModel;
  const ChatTile(this.chatHistory, {super.key, required this.viewModel});

  ChatEntity get chat => chatHistory.chat;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final title = Text(
      chat.title.isNotEmpty ? chat.title.trim() : 'New Session',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AthenaTextStyle.body.copyWith(color: colors.textPrimary),
    );
    final body = Container(
      constraints: const BoxConstraints(maxWidth: 240),
      decoration: BoxDecoration(
        color: colors.surfaceButtonSecondary,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AthenaRadius.control),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chat.pinned) ...[
            Icon(
              LucideIcons.pin,
              size: AthenaIcon.inlineSize,
              color: colors.iconSecondary,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(child: title),
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handlePressed(context),
      onLongPress: () => handleLongPress(context),
      child: body,
    );
  }

  void handlePressed(BuildContext context) async {
    MobileChatRoute(chat: chat).push<void>(context);
  }

  void handleLongPress(BuildContext context) {
    HapticFeedback.heavyImpact();
    final renameTile = AthenaBottomSheetTile(
      leading: const Icon(LucideIcons.pencilLine),
      title: 'Rename',
      onTap: () => _renameChat(context, viewModel),
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
      onTap: () => _deleteChat(context, viewModel),
    );
    final children = [renameTile, pinTile, deleteTile];
    final column = Column(mainAxisSize: MainAxisSize.min, children: children);
    final padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    AthenaDialog.show(SafeArea(child: padding));
  }

  Future<void> _deleteChat(
    BuildContext context,
    ChatViewModel viewModel,
  ) async {
    AthenaDialog.dismiss();
    final confirmed = await AthenaDialog.confirm(
      'Delete this session and all its messages?',
    );
    if (confirmed != true) return;
    await viewModel.deleteChat(chat);
    final error = viewModel.error.value;
    if (error != null) AthenaDialog.error(error);
  }

  void _renameChat(BuildContext context, ChatViewModel viewModel) async {
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
