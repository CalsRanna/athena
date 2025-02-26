import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

@RoutePage()
class MobileModelFormPage extends ConsumerStatefulWidget {
  final Model? model;
  final Provider? provider;
  const MobileModelFormPage({super.key, this.model, this.provider});

  @override
  ConsumerState<MobileModelFormPage> createState() =>
      _MobileModelFormPageState();
}

class _MobileModelFormPageState extends ConsumerState<MobileModelFormPage> {
  final nameController = TextEditingController();
  final valueController = TextEditingController();

  late final viewModel = ModelViewModel(ref);

  @override
  Widget build(BuildContext context) {
    var listViewChildren = [
      AFormTileLabel.large(title: 'Id'),
      SizedBox(height: 12),
      AInput(controller: valueController),
      SizedBox(height: 16),
      AFormTileLabel.large(title: 'Name'),
      SizedBox(height: 12),
      AInput(controller: nameController),
    ];
    var listView = ListView(
      padding: EdgeInsets.symmetric(horizontal: 16),
      children: listViewChildren,
    );
    var columnChildren = [Expanded(child: listView), _buildSubmitButton()];
    return AScaffold(
      appBar: AAppBar(title: Text(widget.model?.name ?? 'New Model')),
      body: SafeArea(top: false, child: Column(children: columnChildren)),
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

  void submitModel() {
    if (widget.model == null) {
      var newModel = Model()
        ..name = nameController.text
        ..value = valueController.text
        ..providerId = widget.provider!.id;
      viewModel.storeModel(newModel);
    } else {
      var copiedModel = widget.model!.copyWith(
        name: nameController.text,
        value: valueController.text,
      );
      viewModel.updateModel(copiedModel);
    }
    AutoRouter.of(context).maybePop();
  }

  Widget _buildSubmitButton() {
    var textStyle = TextStyle(
      color: ColorUtil.FF161616,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    var button = APrimaryButton(
      onTap: submitModel,
      child: Center(child: Text('Submit', style: textStyle)),
    );
    return Padding(padding: const EdgeInsets.all(16), child: button);
  }
}
