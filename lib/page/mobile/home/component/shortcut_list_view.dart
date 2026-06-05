import 'package:athena/model/shortcut.dart';
import 'package:athena/page/mobile/home/component/shortcut_tile.dart';
import 'package:athena/router/router.gr.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class ShortcutListView extends StatelessWidget {
  const ShortcutListView({super.key});

  @override
  Widget build(BuildContext context) {
    final icons = [
      HugeIcons.strokeRoundedTranslate,
      HugeIcons.strokeRoundedAiBrowser,
      HugeIcons.strokeRoundedCookBook,
      HugeIcons.strokeRoundedCode,
      HugeIcons.strokeRoundedGame,
    ];
    final shortcuts = [
      Shortcut()
        ..name = 'Translation'
        ..description = 'Translate input into selected language',
      Shortcut()
        ..name = 'Summary'
        ..description = 'Summary the content in the internet link',
      Shortcut()
        ..name = 'Food'
        ..description = 'Give you a recipe suggestion of healthy food',
      Shortcut()
        ..name = 'Code'
        ..description =
            'Give you a code suggestion about variables, functions, etc',
      Shortcut()
        ..name = 'TRPG'
        ..description = 'Play an unique tabletop role-playing game.',
    ];
    return ListView.separated(
      itemBuilder: (_, index) => ShortcutTile(
        icon: icons[index],
        onTap: () => navigate(context, shortcuts[index]),
        shortcut: shortcuts[index],
      ),
      itemCount: shortcuts.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      separatorBuilder: (context, index) => const SizedBox(width: 12),
    );
  }

  void navigate(BuildContext context, Shortcut shortcut) {
    PageRouteInfo? route = switch (shortcut.name) {
      'Translation' => MobileTranslationRoute(),
      'Summary' => MobileSummaryRoute(),
      'TRPG' => MobileTRPGRoute(),
      'Food' => MobileChatRoute(),
      'Code' => MobileChatRoute(),
      _ => null,
    };
    if (route != null) route.push(context);
  }
}
