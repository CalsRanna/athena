import 'package:athena/entity/chat_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopSentinelIndicator extends StatelessWidget {
  final ChatEntity chat;
  const DesktopSentinelIndicator({super.key, required this.chat});

  @override
  Widget build(BuildContext context) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
    final sentinelViewModel = GetIt.instance<SentinelViewModel>();

    return Watch((context) {
      var currentChat = chatViewModel.currentChat.value;
      if (currentChat == null || currentChat.id != chat.id) {
        return const SizedBox();
      }

      var sentinel = sentinelViewModel.sentinels.value
          .where((s) => s.id == currentChat.sentinelId)
          .firstOrNull;
      if (sentinel == null) return const SizedBox();

      const textStyle = TextStyle(color: ColorUtil.FFFFFFFF, fontSize: 14);
      return Container(
        padding: const EdgeInsets.only(left: 16),
        child: Text(sentinel.name, style: textStyle),
      );
    });
  }
}
