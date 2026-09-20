import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_gui/page/desktop/home/component/model_selector.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/settings_panel.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 桌面端默认模型设置。
///
/// 旧版这里是「Agent / Topic Naming / Sentinel Metadata Generation」二阶导航，
/// 现在改成同一内容区的三个分区，每个分区一行「说明 + 下拉选择」。
@RoutePage()
class DesktopSettingDefaultModelPage extends StatefulWidget {
  const DesktopSettingDefaultModelPage({super.key});

  @override
  State<DesktopSettingDefaultModelPage> createState() =>
      _DesktopSettingDefaultModelPageState();
}

class _DesktopSettingDefaultModelPageState
    extends State<DesktopSettingDefaultModelPage> {
  late final SettingViewModel settingViewModel;

  @override
  void initState() {
    super.initState();
    settingViewModel = GetIt.instance<SettingViewModel>();
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      return AthenaSettingsPane(
        children: [
          AthenaSettingsSection(
            first: true,
            title: 'Agent',
            children: [
              AthenaSettingsRow(
                label: 'Agent Model',
                description: 'Model designated for new chat',
                control: _ModelSelect(
                  model: settingViewModel.chatModelId.value,
                  onChanged: settingViewModel.updateChatModelId,
                ),
              ),
            ],
          ),
          AthenaSettingsSection(
            title: 'Topic Naming',
            children: [
              AthenaSettingsRow(
                label: 'Topic Naming Model',
                description: 'Model designated for automatic naming topic',
                control: _ModelSelect(
                  model: settingViewModel.chatNamingModelId.value,
                  onChanged: settingViewModel.updateChatNamingModelId,
                ),
              ),
            ],
          ),
          AthenaSettingsSection(
            title: 'Sentinel Metadata',
            children: [
              AthenaSettingsRow(
                label: 'Sentinel Metadata Generation Model',
                description:
                    'Model designated for generating sentinel name, '
                    'description, avatar, and tags',
                control: _ModelSelect(
                  model: settingViewModel.sentinelMetadataGenerationModelId.value,
                  onChanged:
                      settingViewModel.updateSentinelMetadataGenerationModelId,
                ),
              ),
            ],
          ),
        ],
      );
    });
  }
}

/// 模型下拉：外观是 Claude 的 select 控件，点开的是既有的模型选择弹层。
class _ModelSelect extends StatelessWidget {
  final int? model;
  final void Function(int)? onChanged;
  const _ModelSelect({this.model, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AthenaSettings.controlColumnWidth,
      child: AthenaSettingsSelect(
        label: _buildLabel(context),
        onTap: showModelSelectorDialog,
      ),
    );
  }

  void handleSelect(ModelEntity model) {
    AthenaDialog.dismiss();
    onChanged?.call(model.id!);
  }

  void showModelSelectorDialog() {
    AthenaDialog.show(
      DesktopModelSelectDialog(onTap: handleSelect),
      barrierDismissible: true,
    );
  }

  String _buildLabel(BuildContext context) {
    if (model == null || model == 0) return 'No Model';
    final modelViewModel = GetIt.instance<ModelViewModel>();
    final providerViewModel = GetIt.instance<ProviderViewModel>();
    final modelEntity = modelViewModel.models.value
        .where((m) => m.id == model)
        .firstOrNull;
    if (modelEntity == null) return 'No Model';
    var modelName = modelEntity.name;
    final aiProvider = providerViewModel.providers.value
        .where((p) => p.id == modelEntity.providerId)
        .firstOrNull;
    var providerName = aiProvider?.name ?? '';
    if (providerName.isEmpty) return modelName;
    return '$modelName | $providerName';
  }
}
