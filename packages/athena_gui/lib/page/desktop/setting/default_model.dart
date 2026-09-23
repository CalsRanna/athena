import 'package:athena_gui/page/desktop/setting/component/model_menu.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/settings/control.dart';
import 'package:athena_gui/widget/settings/panel.dart';
import 'package:athena_gui/widget/settings/row.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 桌面端默认模型设置：一个分区、三行，每行一个下拉。
///
/// 旧版是三个各只有一行的分区，分区标题与行标签互相重复（`Agent` /
/// `Agent Model`）。Claude 的做法是**一个分区放一组同类设置**，这里改成
/// 「Default models」一个分区，三行分别是会话、话题命名、角色元数据。
/// 选了即保存，没有 Save。
@RoutePage()
class DesktopSettingDefaultModelPage extends StatefulWidget {
  const DesktopSettingDefaultModelPage({super.key});

  @override
  State<DesktopSettingDefaultModelPage> createState() =>
      _DesktopSettingDefaultModelPageState();
}

class _DesktopSettingDefaultModelPageState
    extends State<DesktopSettingDefaultModelPage> {
  final settingViewModel = GetIt.instance<SettingViewModel>();
  final modelViewModel = GetIt.instance<ModelViewModel>();

  @override
  void initState() {
    super.initState();
    // 保证下拉里有最新的启用模型（用户可能刚在 Providers 里开了一家）
    modelViewModel.loadEnabledModels();
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final hasModels = modelViewModel.groupedEnabledModels.value.isNotEmpty;
      return AthenaSettingsPane(
        children: [
          AthenaSettingsSection(
            first: true,
            title: 'Default models',
            description:
                'Which model each job starts with. A chat can still switch '
                'models from the composer.',
            children: [
              if (!hasModels)
                const AthenaSettingsEmptyState(
                  icon: LucideIcons.cpu,
                  title: 'No enabled models',
                  hint:
                      'Enable a provider and add an API key under Providers '
                      'to pick default models.',
                ),
              if (hasModels) ...[
                AthenaSettingsRow(
                  label: 'Chat',
                  description: 'Used by new chats and the agent loop.',
                  control: _buildSelect(
                    settingViewModel.chatModelId.value,
                    settingViewModel.updateChatModelId,
                  ),
                ),
                AthenaSettingsRow(
                  label: 'Topic naming',
                  description:
                      'Names a chat after its first exchange. Falls back to '
                      'the chat model.',
                  control: _buildSelect(
                    settingViewModel.chatNamingModelId.value,
                    settingViewModel.updateChatNamingModelId,
                    clearable: true,
                  ),
                ),
                AthenaSettingsRow(
                  label: 'Sentinel metadata',
                  description:
                      'Generates a Sentinel\'s name, description, avatar '
                      'and tags from its prompt.',
                  control: _buildSelect(
                    settingViewModel.sentinelMetadataGenerationModelId.value,
                    settingViewModel.updateSentinelMetadataGenerationModelId,
                    clearable: true,
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    });
  }

  Widget _buildSelect(
    int modelId,
    Future<void> Function(int) onChanged, {
    bool clearable = false,
  }) {
    return SizedBox(
      width: AthenaSettingsControlWidth.wide,
      child: DesktopSettingModelSelect(
        modelId: modelId,
        clearable: clearable,
        onChanged: onChanged,
      ),
    );
  }
}
