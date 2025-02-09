import 'package:athena/page/desktop/setting/component/model_form_dialog.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/menu.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class DesktopSettingProviderPage extends ConsumerStatefulWidget {
  const DesktopSettingProviderPage({super.key});

  @override
  ConsumerState<DesktopSettingProviderPage> createState() =>
      _DesktopSettingModelPageState();
}

class _ContextMenu extends StatelessWidget {
  final Offset offset;
  final Model model;
  final void Function()? onTap;
  const _ContextMenu({
    required this.offset,
    required this.model,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    var editOption = DesktopContextMenuOption(
      text: 'Edit',
      onTap: () => navigateSentinelFormPage(context),
    );
    var deleteOption = DesktopContextMenuOption(
      text: 'Delete',
      onTap: () => destroySentinel(context),
    );
    return DesktopContextMenu(
      offset: offset,
      onBarrierTapped: onTap,
      children: [editOption, deleteOption],
    );
  }

  void destroySentinel(BuildContext context) {
    var container = ProviderScope.containerOf(context);
    var provider = modelsNotifierProvider;
    var notifier = container.read(provider.notifier);
    notifier.deleteModel(model);
    onTap?.call();
  }

  void navigateSentinelFormPage(BuildContext context) {
    ADialog.show(DesktopModelFormDialog(model: model));
    onTap?.call();
  }
}

class _DesktopSettingModelPageState
    extends ConsumerState<DesktopSettingProviderPage> {
  OverlayEntry? entry;
  String model = '';

  @override
  Widget build(BuildContext context) {
    var provider = modelsNotifierProvider;
    var state = ref.watch(provider);
    var body = switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(width: double.infinity),
    };
    var children = [_buildProviderListView(), Expanded(child: body)];
    var row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return AScaffold(body: row);
  }

  Container _buildProviderListView() {
    var borderSide = BorderSide(color: Colors.white.withValues(alpha: 0.2));
    var listView = ListView(
      padding: const EdgeInsets.all(12),
      children: [
        DesktopMenuTile(
          active: true,
          label: 'Open Router',
          trailing: _buildProviderEnabledIndicator(),
        ),
      ],
    );
    return Container(
      decoration: BoxDecoration(border: Border(right: borderSide)),
      width: 200,
      child: listView,
    );
  }

  @override
  void initState() {
    super.initState();
    _initState();
  }

  void removeEntry() {
    if (entry != null) {
      entry!.remove();
      entry = null;
    }
  }

  void showContextMenu(TapUpDetails details, Model model) {
    var contextMenu = _ContextMenu(
      offset: details.globalPosition - Offset(200, 50),
      onTap: removeEntry,
      model: model,
    );
    entry = OverlayEntry(builder: (_) => contextMenu);
    Overlay.of(context).insert(entry!);
  }

  Future<void> updateModel(Model model) async {
    setState(() {
      this.model = model.value;
    });
    var container = ProviderScope.containerOf(context);
    var provider = settingNotifierProvider;
    var notifier = container.read(provider.notifier);
    await notifier.updateModel(model.value);
  }

  Widget _buildData(List<Model> models) {
    var children = models.map(_itemBuilder).toList();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      children: [
        Row(
          children: [
            Text('Open Router'),
            Icon(HugeIcons.strokeRoundedLinkSquare02, size: 12),
            Spacer(),
            Switch.adaptive(value: true, onChanged: (_) {})
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            SizedBox(width: 120, child: Text('API Key')),
            Expanded(child: AInput(controller: TextEditingController()))
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(width: 120, child: Text('API URL')),
            Expanded(child: AInput(controller: TextEditingController()))
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(width: 120, child: Text('Connect')),
            Spacer(),
            ASecondaryButton(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text('Check'),
              ),
            )
          ],
        ),
        const SizedBox(height: 12),
        Text('Models'),
        const SizedBox(height: 12),
        ...children,
        Text('查看OpenRouter文档和模型获取更多详情')
      ],
    );
  }

  Widget _buildProviderEnabledIndicator() {
    return Container(
      decoration: ShapeDecoration(color: Colors.green, shape: StadiumBorder()),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text('ON', style: TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  Future<void> _initState() async {
    var provider = settingNotifierProvider;
    var setting = await ref.read(provider.future);
    model = setting.model;
  }

  Widget _itemBuilder(Model model) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) => showContextMenu(details, model),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(model.name),
                  SizedBox(width: 12),
                  Text(model.value),
                ],
              ),
              Text(r'发布于2024-06-20 输入$3.00/M 输出$15.00/M')
            ],
          ),
        ),
      ),
    );
    // return GestureDetector(
    //   behavior: HitTestBehavior.opaque,
    //   onSecondaryTapUp: (details) => showContextMenu(details, model),
    //   onTap: () => updateModel(model),
    //   child: ATag(selected: this.model == model.value, text: model.name),
    // );
  }
}
