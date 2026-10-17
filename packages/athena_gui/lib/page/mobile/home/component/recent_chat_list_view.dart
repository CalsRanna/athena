import 'package:athena_core/entity/chat_history_entity.dart';
import 'package:athena_gui/page/mobile/home/component/chat_tile.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:flutter/material.dart';

class RecentChatListView extends StatelessWidget {
  final List<ChatHistoryEntity> chatHistories;
  final ChatViewModel viewModel;
  const RecentChatListView({
    super.key,
    required this.chatHistories,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    if (chatHistories.isEmpty) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'No sessions yet',
          style: AthenaTextStyle.caption.copyWith(color: colors.textWeak),
        ),
      );
    }
    // 与最近会话的单行性质一致：用横向 Row 让高度跟随文字，而不是把
    // 整个列表锁在 52 高——系统字号放大后胶囊会被裁掉。
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        spacing: 12,
        children: [
          for (final history in chatHistories)
            ChatTile(history, viewModel: viewModel),
        ],
      ),
    );
  }
}
