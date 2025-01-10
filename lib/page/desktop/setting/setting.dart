import 'package:athena/page/desktop/setting/component/model_form_dialog.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class DesktopSettingPage extends StatefulWidget {
  const DesktopSettingPage({super.key});

  @override
  State<DesktopSettingPage> createState() => _DesktopSettingPageState();
}

class _DesktopSettingPageState extends State<DesktopSettingPage> {
  int index = 0;

  final _menus = ['Account', 'Model', 'Application', 'Experimental'];

  @override
  Widget build(BuildContext context) {
    var appBar = AAppBar(
      leading: DesktopPopButton(),
      title: _buildPageHeader(context),
    );
    var children = [_buildLeftBar(), const Expanded(child: AutoRouter())];
    return AScaffold(appBar: appBar, body: Row(children: children));
  }

  void changeMenu(int index) {
    setState(() {
      this.index = index;
    });
    var route = switch (index) {
      0 => const DesktopSettingAccountRoute(),
      1 => const DesktopSettingModelRoute(),
      2 => const DesktopSettingApplicationRoute(),
      3 => const DesktopSettingExperimentalRoute(),
      _ => null,
    };
    if (route == null) return;
    AutoRouter.of(context).replace(route);
  }

  Widget _buildLeftBar() {
    var listView = ListView.builder(
      itemBuilder: (_, index) => _itemBuilder(index),
      itemCount: _menus.length,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      width: 200,
      child: listView,
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    var icon = Icon(
      HugeIcons.strokeRoundedPencilEdit02,
      color: Colors.white,
      size: 24,
    );
    var createButton = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: showModelFomDialog,
      child: icon,
    );
    var title = 'Setting / ${_menus[index]}';
    var rowChildren = [
      const SizedBox(width: 16),
      Text(title, style: TextStyle(color: Colors.white)),
      const SizedBox(width: 16),
      if (index == 1) createButton
    ];
    return Row(children: rowChildren);
  }

  void showModelFomDialog() {
    ADialog.show(DesktopModelFormDialog());
  }

  Widget _itemBuilder(int index) {
    return _MenuTile(
      active: this.index == index,
      label: _menus[index],
      onTap: () => changeMenu(index),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final bool active;
  final String label;
  final void Function()? onTap;
  const _MenuTile({this.active = false, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 200);
    var animatedText = AnimatedDefaultTextStyle(
      duration: duration,
      style: TextStyle(color: active ? Color(0xFF161616) : Colors.white),
      child: Text(label),
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: active ? Colors.white : null,
    );
    var animatedContainer = AnimatedContainer(
      decoration: boxDecoration,
      duration: duration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: animatedText,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: animatedContainer,
    );
  }
}
