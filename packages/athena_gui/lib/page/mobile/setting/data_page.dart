import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_gui/page/mobile/setting/component/section.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:athena_gui/page/mobile/setting/component/setting_tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

@RoutePage()
class MobileDataPage extends StatefulWidget {
  const MobileDataPage({super.key});

  @override
  State<MobileDataPage> createState() => _MobileDataPageState();
}

class _MobileDataPageState extends State<MobileDataPage> {
  final viewModel = GetIt.instance.get<SettingViewModel>();

  @override
  Widget build(BuildContext context) {
    final dataDirectory = GetIt.instance<FileStorage>().root.path;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MobileSettingsSection(
          title: 'Local data',
          description:
              'Sessions, providers, Sentinels and settings are stored on this '
              'device.',
          children: [
            MobileSettingTile(
              leading: const Icon(
                LucideIcons.folder,
                size: AthenaIcon.largeSize,
              ),
              onTap: () => _copyPath(dataDirectory),
              title: 'Data folder',
              subtitle: dataDirectory,
              trailing: 'Copy',
            ),
            MobileSettingTile(
              leading: const Icon(
                LucideIcons.databaseBackup,
                size: AthenaIcon.largeSize,
              ),
              onTap: _handleReset,
              title: 'Reset Athena',
              subtitle:
                  'Delete every session, provider, model and Sentinel on this '
                  'device.',
              trailing: '',
              danger: true,
            ),
          ],
        ),
        const SafeArea(top: false, child: SizedBox(height: AthenaSpace.xxl)),
      ],
    );
    return AthenaScaffold(
      appBar: const AthenaAppBar(title: Text('Data')),
      body: SingleChildScrollView(child: content),
    );
  }

  Future<void> _copyPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (mounted) AthenaDialog.success('Data folder copied');
  }

  Future<void> _handleReset() async {
    final confirmed = await AthenaDialog.confirm(
      'Are you sure you want to reset all data?',
    );
    if (confirmed != true) return;
    AthenaDialog.loading();
    try {
      // 经 ChatViewModel 包一层：先停掉运行中的对话，清空后刷新会话列表
      final success = await GetIt.instance<ChatViewModel>().runDataReset(
        viewModel.resetData,
      );
      if (!mounted) return;
      if (success) {
        AthenaDialog.success('Reset successful');
      } else {
        AthenaDialog.info('Reset cancelled');
      }
    } finally {
      AthenaDialog.dismiss();
    }
  }
}
