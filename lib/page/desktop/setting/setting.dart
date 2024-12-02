import 'package:athena/router/router.gr.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class DesktopSettingPage extends StatelessWidget {
  const DesktopSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var textTheme = theme.textTheme;
    var bodyLarge = textTheme.bodyLarge;
    const icon = Icon(HugeIcons.strokeRoundedArrowLeft02);
    var leadingChildren = [
      IconButton(icon: icon, onPressed: () => handleTap(context)),
      const SizedBox(width: 8),
      const Text('Back'),
    ];
    var leading = Row(children: leadingChildren);
    var header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text('Setting', style: bodyLarge),
    );
    var menuChildren = [
      header,
      const SizedBox(height: 12),
      const Expanded(child: _Menu())
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: menuChildren,
    );
    var container = Container(
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      width: 200,
      child: column,
    );
    var children = [
      container,
      const Expanded(child: AutoRouter()),
    ];
    return AScaffold(
      appBar: AAppBar(leading: leading),
      body: Row(children: children),
    );
  }

  void handleTap(BuildContext context) {
    AutoRouter.of(context).back();
  }
}

class _Menu extends StatefulWidget {
  const _Menu();

  @override
  State<_Menu> createState() => _MenuState();
}

class _MenuState extends State<_Menu> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    return ListView(children: _getChildren());
  }

  void handleTap(int i) {
    if (index == i) return;
    setState(() {
      index = i;
    });
    var route = switch (i) {
      0 => const DesktopSettingAccountRoute(),
      1 => const DesktopSettingModelRoute(),
      2 => const DesktopSettingApplicationRoute(),
      3 => const DesktopSettingExperimentalRoute(),
      _ => null,
    };
    if (route == null) return;
    AutoRouter.of(context).replace(route);
  }

  List<Widget> _getChildren() {
    const menus = ['Account', 'Model', 'Application', 'Experimental'];
    List<Widget> children = [];
    for (var i = 0; i < menus.length; i++) {
      var child = _MenuTile(
        active: index == i,
        label: menus[i],
        onTap: () => handleTap(i),
      );
      children.add(child);
    }
    return children;
  }
}

class _MenuTile extends StatelessWidget {
  final bool active;
  final String label;
  final void Function()? onTap;
  const _MenuTile({this.active = false, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;
    var primaryContainer = colorScheme.primaryContainer;
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: active ? primaryContainer : null,
    );
    var animatedContainer = AnimatedContainer(
      decoration: boxDecoration,
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(label),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: animatedContainer,
    );
  }
}
