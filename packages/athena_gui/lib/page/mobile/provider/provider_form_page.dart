import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_gui/component/api_format_label.dart';
import 'package:athena_gui/page/mobile/provider/component/model_list_view.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/form_tile_label.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
  var _obscureKey = true;
  ApiFormat _apiFormat = ApiFormat.chatCompletions;
  bool _apiFormatAuto = true;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var tipTextStyle = AthenaTextStyle.caption.copyWith(
      color: colors.textSecondary,
      height: 1.5,
    );
    var keyVisibilityToggle = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _obscureKey = !_obscureKey),
      child: Icon(
        _obscureKey
            ? LucideIcons.eye
            : LucideIcons.eyeOff,
        size: 18,
        color: colors.border,
      ),
    );
    var children = [
      AthenaFormTileLabel.large(title: 'API Key'),
      SizedBox(height: 12),
      AthenaInput(
        controller: keyController,
        obscureText: _obscureKey,
        suffix: keyVisibilityToggle,
      ),
      SizedBox(height: 16),
      AthenaFormTileLabel.large(title: 'API Url'),
      SizedBox(height: 12),
      AthenaInput(controller: urlController),
      SizedBox(height: 20),
      AthenaFormTileLabel.large(title: 'API Format'),
      SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          AthenaTagButton.small(
            selected: _apiFormatAuto,
            onTap: () => setState(() => _apiFormatAuto = true),
            child: const Text('Auto'),
          ),
          for (final format in ApiFormat.values)
            AthenaTagButton.small(
              selected: !_apiFormatAuto && _apiFormat == format,
              onTap: () => setState(() {
                _apiFormatAuto = false;
                _apiFormat = format;
              }),
              child: Text(format.label),
            ),
        ],
      ),
      SizedBox(height: 8),
      Text(_apiFormatHint(), style: tipTextStyle),
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
      modelViewModel: GetIt.instance<ModelViewModel>(),
    );
    var listViewChildren = [
      labels,
      SizedBox(height: 16),
      _buildModelFormLabel(context),
      SizedBox(height: 12),
      modelListView,
      if (widget.provider.isPreset) SizedBox(height: 16),
      if (widget.provider.isPreset) _buildTip(context),
    ];
    var listView = ListView(
      padding: EdgeInsets.zero,
      children: listViewChildren,
    );
    var columnChildren = [
      Expanded(child: listView),
      _buildSubmitButton(context),
    ];
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
      if (!result.isSuccess) {
        AthenaDialog.error(result.detail ?? result.message);
        return;
      }
      AthenaDialog.success(result.message);
    } catch (e) {
      AthenaDialog.error('Connection error: $e');
    } finally {
      AthenaDialog.dismiss();
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
    if (model.isPreset) return;
    MobileModelFormRoute(model: model).push(context);
  }

  @override
  void initState() {
    super.initState();
    keyController.text = widget.provider.apiKey;
    urlController.text = widget.provider.baseUrl;
    _apiFormat = widget.provider.apiFormat;
    _apiFormatAuto = widget.provider.apiFormatAuto;
    _initializeModels();
  }

  Future<void> _initializeModels() async {
    try {
      await GetIt.instance<ModelViewModel>().initSignals();
    } catch (e) {
      if (mounted) {
        AthenaDialog.error('Failed to load models. Please try again.');
      }
    }
  }

  void openBottomSheet(ModelEntity model) {
    HapticFeedback.heavyImpact();
    var connectTile = AthenaBottomSheetTile(
      leading: Icon(LucideIcons.plugZap),
      title: 'Connect',
      onTap: () => checkConnection(model),
    );
    var children = <Widget>[connectTile];
    if (!model.isPreset) {
      var editTile = AthenaBottomSheetTile(
        leading: Icon(LucideIcons.pencilLine),
        title: 'Edit',
        onTap: () => editModel(model),
      );
      var deleteTile = AthenaBottomSheetTile(
        leading: Icon(LucideIcons.trash2),
        title: 'Delete',
        onTap: () => destroyModel(model),
      );
      children.addAll([editTile, deleteTile]);
    }
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    var padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    AthenaDialog.show(SafeArea(child: padding));
  }

  Future<void> updateProvider() async {
    var viewModel = GetIt.instance<ProviderViewModel>();
    // 手动选择时传 apiFormat，`copyWith` 会把 apiFormatAuto 落成 false；
    // 选 Auto 时传 apiFormatAuto: true，格式值等下次目录同步覆盖。
    var provider = widget.provider.copyWith(
      enabled: true,
      apiKey: keyController.text,
      baseUrl: urlController.text,
      apiFormat: _apiFormatAuto ? null : _apiFormat,
      apiFormatAuto: _apiFormatAuto,
    );
    await viewModel.updateProvider(provider);
  }

  String _apiFormatHint() {
    if (_apiFormatAuto) {
      return 'Follows the format inferred from models.dev during sync.';
    }
    if (_apiFormat == ApiFormat.messages) {
      return 'Messages is not wired up yet — requests fail until it ships.';
    }
    return 'Chosen manually; sync will not overwrite it.';
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

  Widget _buildSubmitButton(BuildContext context) {
    var button = AthenaPrimaryButton(
      onTap: updateProvider,
      child: Center(child: Text('Update')),
    );
    return Padding(padding: const EdgeInsets.all(16), child: button);
  }

  Widget _buildTip(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var tipTextStyle = AthenaTextStyle.caption.copyWith(
      color: colors.border,
      height: 1.5,
    );
    var tipText = Text(
      'See ${widget.provider.name} documentation for more details',
      style: tipTextStyle,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: tipText,
    );
  }
}
