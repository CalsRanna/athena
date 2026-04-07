import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/widget/tag.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopSentinelIndicator extends StatelessWidget {
  final void Function()? onTap;

  const DesktopSentinelIndicator({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
    return Watch((context) {
      var sentinel = chatViewModel.currentSentinel.value;
      var label = sentinel?.name ?? 'Athena';
      var row = Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          const Icon(HugeIcons.strokeRoundedArtificialIntelligence03),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      );
      return AthenaTagButton.small(onTap: onTap, child: row);
    });
  }
}
