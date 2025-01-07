import 'package:athena/provider/model.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/schema/model.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class DesktopSettingModelPage extends ConsumerStatefulWidget {
  const DesktopSettingModelPage({super.key});

  @override
  ConsumerState<DesktopSettingModelPage> createState() =>
      _DesktopSettingModelPageState();
}

class _AddDialog extends StatefulWidget {
  const _AddDialog();

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  final nameController = TextEditingController();
  final valueController = TextEditingController();

  @override
  void dispose() {
    super.dispose();
    nameController.dispose();
    valueController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var textButton = TextButton(
      onPressed: () => handleCancel(context),
      child: const Text('Cancel'),
    );
    var filledButton = FilledButton(
      onPressed: () => handleConfirmed(context),
      child: const Text('Submit'),
    );
    var children = [
      const Text('Model ID'),
      TextField(controller: valueController),
      const Text('Model Display Name'),
      TextField(controller: nameController),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    return AlertDialog(
      actions: [textButton, filledButton],
      content: column,
      title: const Text('Add a model'),
    );
  }

  void handleCancel(BuildContext context) {
    Navigator.of(context).pop();
  }

  void handleConfirmed(BuildContext context) {
    if (nameController.text.isEmpty || valueController.text.isEmpty) return;
    var model = Model()
      ..name = nameController.text
      ..value = valueController.text;
    var container = ProviderScope.containerOf(context);
    var provider = modelsNotifierProvider;
    var notifier = container.read(provider.notifier);
    notifier.storeModel(model);
  }
}

class _DeleteDialog extends StatelessWidget {
  final void Function()? onConfirmed;
  const _DeleteDialog({this.onConfirmed});

  @override
  Widget build(BuildContext context) {
    var textButton = TextButton(
      onPressed: () => handleCancel(context),
      child: const Text('Cancel'),
    );
    var filledButton = FilledButton(
      onPressed: () => handleConfirmed(context),
      child: const Text('Confirm'),
    );
    return AlertDialog(
      actions: [textButton, filledButton],
      content: const Text('Do you want to delete this model?'),
      title: const Text('Delete Model'),
    );
  }

  void handleCancel(BuildContext context) {
    Navigator.of(context).pop();
  }

  void handleConfirmed(BuildContext context) {
    onConfirmed?.call();
    Navigator.of(context).pop();
  }
}

class _DesktopSettingModelPageState
    extends ConsumerState<DesktopSettingModelPage> {
  @override
  Widget build(BuildContext context) {
    var provider = modelsNotifierProvider;
    var models = ref.watch(provider).valueOrNull;
    if (models == null) return const SizedBox();
    var chips = models.map(_toElement);
    var addChip = _buildAddChip(context);
    var children = [
      Wrap(runSpacing: 12, spacing: 12, children: [...chips, addChip]),
      const SizedBox(height: 16),
      _buildSelectedTip(),
      const SizedBox(height: 8),
      _buildAddTip(),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var colorScheme = Theme.of(context).colorScheme;
    var surface = colorScheme.surface;
    return Container(
      color: surface,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: column,
    );
  }

  void handleAdd(BuildContext context) {
    showDialog(context: context, builder: (_) => const _AddDialog());
  }

  Widget _buildAddChip(BuildContext context) {
    return ActionChip(
      avatar: const Icon(HugeIcons.strokeRoundedAdd01),
      label: const Text('Add a model'),
      onPressed: () => handleAdd(context),
    );
  }

  Widget _buildAddTip() {
    const icon = Icon(HugeIcons.strokeRoundedAdd01);
    const tip = Text('You can add an OpenAI compatible model.');
    return const Row(children: [icon, tip]);
  }

  Widget _buildSelectedTip() {
    const icon = Icon(HugeIcons.strokeRoundedTick02);
    const tip = Text('means this model is the default model.');
    return const Row(children: [icon, tip]);
  }

  Widget _toElement(Model model) {
    return _ModelChip(model: model);
  }
}

class _ModelChip extends ConsumerWidget {
  final Model model;
  const _ModelChip({required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = settingNotifierProvider;
    var setting = ref.watch(provider).valueOrNull;
    var selected = setting?.model == model.value;
    return FilterChip(
      deleteIcon: const Icon(HugeIcons.strokeRoundedDelete02),
      label: Text(model.name),
      selected: selected,
      onDeleted: () => handleDelete(context, ref),
      onSelected: (value) => handleSelect(ref, value),
    );
  }

  void handleDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _DeleteDialog(onConfirmed: () => _confirmDelete(ref)),
    );
  }

  void handleSelect(WidgetRef ref, bool value) {
    if (!value) return;
    var provider = settingNotifierProvider;
    final notifier = ref.read(provider.notifier);
    notifier.updateModel(model.value);
  }

  void _confirmDelete(WidgetRef ref) {
    var provider = modelsNotifierProvider;
    final notifier = ref.read(provider.notifier);
    notifier.deleteModel(model);
  }
}
