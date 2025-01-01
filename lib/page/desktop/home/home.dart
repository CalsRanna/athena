import 'package:athena/page/desktop/home/component/chat.dart';
import 'package:athena/page/desktop/home/component/sentinel.dart';
import 'package:athena/page/desktop/home/component/workspace.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class DesktopHomePage extends StatelessWidget {
  const DesktopHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const aAppBar = AAppBar(action: _CreateButton(), title: SentinelSelector());
    const body = Row(children: [ChatList(), Expanded(child: WorkSpace())]);
    return const AScaffold(appBar: aAppBar, body: body);
  }
}

class _CreateButton extends ConsumerWidget {
  const _CreateButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var colorScheme = Theme.of(context).colorScheme;
    var onSurface = colorScheme.onSurface;
    var icon = Icon(
      HugeIcons.strokeRoundedPencilEdit02,
      color: onSurface.withValues(alpha: 0.2),
    );
    return IconButton(onPressed: () => handleTap(ref), icon: icon);
  }

  void handleTap(WidgetRef ref) {
    ref.invalidate(chatNotifierProvider);
  }
}
