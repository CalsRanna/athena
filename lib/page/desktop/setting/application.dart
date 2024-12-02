import 'package:athena/page/desktop/setting/component/tile.dart';
import 'package:athena/provider/setting.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class DesktopSettingApplicationPage extends StatelessWidget {
  const DesktopSettingApplicationPage({super.key});

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;
    var surface = colorScheme.surface;
    const children = [
      SettingTile(label: 'Dark Mode', child: _DarkMode()),
    ];
    return Container(
      color: surface,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: const Column(children: children),
    );
  }
}

class _DarkMode extends ConsumerWidget {
  const _DarkMode();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(settingNotifierProvider).value;
    final darkMode = setting?.darkMode ?? false;
    return Switch(
      value: darkMode,
      onChanged: (value) => toggleMode(ref, value),
    );
  }

  void toggleMode(WidgetRef ref, bool value) {
    final notifier = ref.read(settingNotifierProvider.notifier);
    notifier.toggleMode();
  }
}
