import 'package:athena/page/desktop/setting/component/model_form_dialog.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/menu.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class DesktopSettingModelPage extends ConsumerStatefulWidget {
  const DesktopSettingModelPage({super.key});

  @override
  ConsumerState<DesktopSettingModelPage> createState() =>
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
    extends ConsumerState<DesktopSettingModelPage> {
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
    return AScaffold(body: body);
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
    if (models.isEmpty) return const SizedBox();
    var wrap = Wrap(
      runSpacing: 12,
      spacing: 12,
      children: models.map(_itemBuilder).toList(),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      width: double.infinity,
      child: wrap,
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
      onTap: () => updateModel(model),
      child: ATag(selected: this.model == model.value, text: model.name),
    );
  }
}
