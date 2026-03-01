import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/page/mobile/provider/component/model_list_view.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/provider_view_model.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class MobileProviderFormPage extends StatefulWidget {
  final ProviderEntity provider;
  const MobileProviderFormPage({super.key, required this.provider});

  @override
  State<MobileProviderFormPage> createState() => _MobileProviderFormPageState();
}

class _MobileProviderFormPageState extends State<MobileProviderFormPage> {
  final keyController = TextEditingController();
  final urlController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var children = [
      AthenaFormTileLabel.large(title: 'API Key'),
      SizedBox(height: 12),
      AthenaInput(controller: keyController),
      SizedBox(height: 16),
      AthenaFormTileLabel.large(title: 'API Url'),
      SizedBox(height: 12),
      AthenaInput(controller: urlController),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var labels = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: column,
    );
    var modelListView = MobileModelListView(
      onLongPress: openBottomSheet,
      onTap: editModel,
      provider: widget.provider,
    );
    var listViewChildren = [
      labels,
      SizedBox(height: 16),
      _buildModelFormLabel(context),
      SizedBox(height: 12),
      modelListView,
      if (widget.provider.isPreset) SizedBox(height: 16),
      if (widget.provider.isPreset) _buildTip(),
    ];
    var listView = ListView(
      padding: EdgeInsets.zero,
      children: listViewChildren,
    );
    var columnChildren = [Expanded(child: listView), _buildSubmitButton()];
    return AthenaScaffold(
      appBar: AthenaAppBar(title: Text(widget.provider.name)),
      body: SafeArea(top: false, child: Column(children: columnChildren)),
    );
  }

  Future<void> checkConnection(ModelEntity model) async {
    AthenaDialog.dismiss();
    AthenaDialog.loading();
    var viewModel = GetIt.instance<ModelViewModel>();
    try {
      var result = await viewModel.checkConnection(model);
      AthenaDialog.dismiss();
      AthenaDialog.message(result);
    } catch (e) {
      AthenaDialog.dismiss();
      AthenaDialog.message('Connection error: $e');
    }
  }

  void createModel(BuildContext context) {
    MobileModelFormRoute(provider: widget.provider).push(context);
  }

  void destroyModel(ModelEntity model) {
    AthenaDialog.dismiss();
    GetIt.instance<ModelViewModel>().deleteModel(model);
  }

  @override
  void dispose() {
    keyController.dispose();
    urlController.dispose();
    super.dispose();
  }

  void editModel(ModelEntity model) {
    MobileModelFormRoute(model: model).push(context);
  }

  @override
  void initState() {
    super.initState();
    keyController.text = widget.provider.apiKey;
    urlController.text = widget.provider.baseUrl;
    _initializeModels();
  }

  Future<void> _initializeModels() async {
    await GetIt.instance<ModelViewModel>().initSignals();
  }

  void openBottomSheet(ModelEntity model) {
    HapticFeedback.heavyImpact();
    var editTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedConnect),
      title: 'Connect',
      onTap: () => checkConnection(model),
    );
    var deleteTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedDelete02),
      title: 'Delete',
      onTap: () => destroyModel(model),
    );
    var children = [editTile, deleteTile];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    var padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    AthenaDialog.show(SafeArea(child: padding));
  }

  Future<void> updateProvider() async {
    var viewModel = GetIt.instance<ProviderViewModel>();
    var provider = widget.provider.copyWith(
      enabled: true,
      apiKey: keyController.text,
      baseUrl: urlController.text,
    );
    await viewModel.updateProvider(provider);
  }

  Widget _buildModelFormLabel(BuildContext context) {
    var newModelButton = AthenaTextButton(
      onTap: () => createModel(context),
      text: 'New',
    );
    var label = AthenaFormTileLabel.large(
      title: 'Models',
      trailing: newModelButton,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: label,
    );
  }

  Widget _buildSubmitButton() {
    var textStyle = TextStyle(
      color: ColorUtil.FF161616,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    var button = AthenaPrimaryButton(
      onTap: updateProvider,
      child: Center(child: Text('Update', style: textStyle)),
    );
    return Padding(padding: const EdgeInsets.all(16), child: button);
  }

  Widget _buildTip() {
    var tipTextStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var tipText = Text(
      '查看${widget.provider.name}文档和模型获取更多详情',
      style: tipTextStyle,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: tipText,
    );
  }
}
