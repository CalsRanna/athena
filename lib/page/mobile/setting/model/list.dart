import 'package:athena/provider/model.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class MobileModelListPage extends ConsumerWidget {
  const MobileModelListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = modelsNotifierProvider;
    var state = ref.watch(provider);
    var listView = switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
    return AScaffold(
      appBar: const AAppBar(title: Text('Model')),
      body: Stack(children: [listView, _buildCreateButton(context)]),
    );
  }

  void navigateModelFormPage(BuildContext context) {
    MobileModelFormRoute().push(context);
  }

  Widget _buildCreateButton(BuildContext context) {
    var boxDecoration = BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    );
    var iconContainer = Container(
      decoration: boxDecoration,
      height: 24,
      width: 24,
      child: Icon(HugeIcons.strokeRoundedAdd01, size: 12),
    );
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    var children = [
      iconContainer,
      const SizedBox(width: 8),
      const Text('Add a model', style: textStyle),
    ];
    var shapeDecoration = ShapeDecoration(
      color: Color(0xFF161616),
      shape: StadiumBorder(),
    );
    var outerContainer = Container(
      decoration: shapeDecoration,
      padding: EdgeInsets.fromLTRB(8, 12, 12, 12),
      margin: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => navigateModelFormPage(context),
      child: outerContainer,
    );
    return Align(alignment: Alignment.bottomCenter, child: gestureDetector);
  }

  Widget _buildData(List<Model> models) {
    if (models.isEmpty) return const SizedBox();
    return ListView.builder(
      itemBuilder: (context, index) => _Tile(model: models[index]),
      itemCount: models.length,
      padding: EdgeInsets.zero,
    );
  }
}

class _ActionDialog extends StatelessWidget {
  final Model model;
  const _ActionDialog({required this.model});

  @override
  Widget build(BuildContext context) {
    var children = [
      APrimaryButton(
        child: Center(child: Text('Select')),
        onTap: () => selectModel(context),
      ),
      const SizedBox(height: 12),
      _OutlinedButton(
        text: 'Edit',
        onTap: () => navigateModelFormPage(context),
      ),
      const SizedBox(height: 12),
      _OutlinedButton(
        onTap: () => _showDeleteConfirmDialog(context),
        text: 'Delete',
      ),
      SizedBox(height: MediaQuery.paddingOf(context).bottom),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  void navigateModelFormPage(BuildContext context) {
    ADialog.dismiss();
    MobileModelFormRoute(model: model).push(context);
  }

  void selectModel(BuildContext context) {
    var container = ProviderScope.containerOf(context);
    var provider = settingNotifierProvider;
    var notifier = container.read(provider.notifier);
    notifier.updateModel(model.value);
    ADialog.dismiss();
  }

  void _confirmDelete(BuildContext context) {
    var container = ProviderScope.containerOf(context);
    var provider = modelsNotifierProvider;
    var notifier = container.read(provider.notifier);
    notifier.deleteModel(model);
    ADialog.dismiss();
    ADialog.success('Model deleted successfully');
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    ADialog.dismiss();
    ADialog.confirm(
      'Are you sure you want to delete this model?',
      onConfirmed: _confirmDelete,
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  final void Function()? onTap;
  final String text;
  const _OutlinedButton({this.onTap, required this.text});

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return AOutlinedButton(
      onTap: onTap,
      child: Center(child: Text(text, style: textStyle)),
    );
  }
}

class _Tile extends ConsumerWidget {
  final Model model;

  const _Tile({required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(settingNotifierProvider).valueOrNull;
    const color = Color(0xffffffff);
    const selected = HugeIcon(
      color: color,
      icon: HugeIcons.strokeRoundedTick02,
    );
    const textStyle = TextStyle(
      color: color,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    );
    var children = [
      Expanded(child: Text(model.name, style: textStyle)),
      setting?.model == model.value ? selected : const SizedBox(),
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showActionDialog(ref),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(children: children),
      ),
    );
  }

  void _showActionDialog(WidgetRef ref) {
    ADialog.show(_ActionDialog(model: model));
  }
}
