import 'package:athena/entity/chat_history_entity.dart';
import 'package:athena/page/mobile/home/component/chat_tile.dart';
import 'package:athena/view_model/chat_view_model.dart';
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
    if (chatHistories.isEmpty) return const SizedBox();
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemBuilder: (_, index) => itemBuilder(chatHistories, index),
      itemCount: chatHistories.length,
    );
  }

  Widget itemBuilder(List<ChatHistoryEntity> chatHistories, int index) {
    const left = 16.0;
    final right = index == chatHistories.length - 1 ? 16.0 : 0.0;
    return Padding(
      padding: EdgeInsets.only(left: left, right: right),
      child: ChatTile(chatHistories[index], viewModel: viewModel),
    );
  }
}
