import 'package:athena/provider/chat.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

class DesktopSentinelIndicator extends ConsumerWidget {
  final Chat chat;
  const DesktopSentinelIndicator({super.key, required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var chatProvider = chatNotifierProvider(chat.id);
    var latestChat = ref.watch(chatProvider).value;
    if (latestChat == null) return const SizedBox();
    var sentinelProvider = sentinelNotifierProvider(latestChat.sentinelId);
    var sentinel = ref.watch(sentinelProvider).value;
    if (sentinel == null) return const SizedBox();
    const textStyle = TextStyle(color: ColorUtil.FFFFFFFF, fontSize: 14);
    return Container(
      padding: const EdgeInsets.only(left: 16),
      child: Text(sentinel.name, style: textStyle),
    );
  }
}
