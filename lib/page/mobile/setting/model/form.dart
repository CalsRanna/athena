import 'package:athena/provider/model.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class MobileModelFormPage extends StatefulWidget {
  final Model? model;
  const MobileModelFormPage({super.key, this.model});

  @override
  State<MobileModelFormPage> createState() => _MobileModelFormPageState();
}

class _MobileModelFormPageState extends State<MobileModelFormPage> {
  final nameController = TextEditingController();
  final valueController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var children = [
      const AFormTileLabel(title: 'Name'),
      const SizedBox(height: 12),
      AInput(controller: nameController),
      const SizedBox(height: 16),
      const AFormTileLabel(title: 'Value'),
      const SizedBox(height: 12),
      AInput(controller: valueController),
      const SizedBox(height: 32),
      _buildStoreButton(),
    ];
    var bottom = MediaQuery.paddingOf(context).bottom;
    var listView = ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
      children: children,
    );
    return AScaffold(
      appBar: AAppBar(title: Text(widget.model?.name ?? 'New Model')),
      body: listView,
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    valueController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    nameController.text = widget.model?.name ?? '';
    valueController.text = widget.model?.value ?? '';
  }

  Future<void> storeSentinel() async {
    var message = _validate();
    if (message != null) return ADialog.success(message);
    if (widget.model == null) return _store();
    _update();
  }

  Widget _buildStoreButton() {
    var textStyle = TextStyle(
      color: Color(0xFF161616),
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return APrimaryButton(
      onTap: storeSentinel,
      child: Center(child: Text('Store', style: textStyle)),
    );
  }

  Future<void> _store() async {
    var container = ProviderScope.containerOf(context);
    var provider = modelsNotifierProvider;
    var notifier = container.read(provider.notifier);
    var model = Model()
      ..name = nameController.text
      ..value = valueController.text;
    await notifier.storeModel(model);
    if (!mounted) return;
    AutoRouter.of(context).maybePop();
  }

  Future<void> _update() async {
    var container = ProviderScope.containerOf(context);
    var provider = modelsNotifierProvider;
    var notifier = container.read(provider.notifier);
    var model = widget.model!.copyWith(
      name: nameController.text,
      value: valueController.text,
    );
    await notifier.updateModel(model);
    if (!mounted) return;
    AutoRouter.of(context).maybePop();
  }

  String? _validate() {
    if (nameController.text.isEmpty) return 'Name is required';
    if (valueController.text.isEmpty) return 'Value is required';
    return null;
  }
}
