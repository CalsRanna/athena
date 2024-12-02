import 'package:athena/page/desktop/setting/component/tile.dart';
import 'package:athena/provider/setting.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class DesktopSettingExperimentalPage extends StatelessWidget {
  const DesktopSettingExperimentalPage({super.key});

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;
    var surface = colorScheme.surface;
    const latexTile = SettingTile(
      label: 'Latex Support',
      subtitle: 'May cause render issues',
      child: _Experimental(),
    );
    return Container(
      color: surface,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: const Column(children: [latexTile]),
    );
  }
}

class _Experimental extends ConsumerWidget {
  const _Experimental();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(settingNotifierProvider).value;
    final latex = setting?.latex ?? false;
    return Switch(value: latex, onChanged: (value) => toggleLatex(ref, value));
  }

  void toggleLatex(WidgetRef ref, bool value) {
    final notifier = ref.read(settingNotifierProvider.notifier);
    notifier.toggleLatex();
  }
}
