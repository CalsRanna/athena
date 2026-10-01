import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:athena_gui/widget/tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
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
    final children = [
      MobileSettingTile(
        leading: const Icon(LucideIcons.fileOutput, size: AthenaIcon.largeSize),
        onTap: _handleExport,
        title: 'Export',
        trailing: '',
      ),
      MobileSettingTile(
        leading: const Icon(LucideIcons.fileInput, size: AthenaIcon.largeSize),
        onTap: _handleImport,
        title: 'Import',
        trailing: '',
      ),
      MobileSettingTile(
        leading: const Icon(
          LucideIcons.databaseBackup,
          size: AthenaIcon.largeSize,
        ),
        onTap: _handleReset,
        title: 'Reset',
        trailing: '',
      ),
    ];
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return AthenaScaffold(
      appBar: const AthenaAppBar(title: Text('Data')),
      body: column,
    );
  }

  Future<void> _handleExport() async {
    AthenaDialog.loading();
    try {
      final success = await viewModel.exportData();
      if (!mounted) return;
      if (success) {
        AthenaDialog.success('Export successful');
      } else {
        AthenaDialog.info('Export cancelled');
      }
    } finally {
      AthenaDialog.dismiss();
    }
  }

  Future<void> _handleImport() async {
    AthenaDialog.loading();
    try {
      final success = await viewModel.importData();
      if (!mounted) return;
      if (success) {
        AthenaDialog.success('Import successful');
      } else {
        AthenaDialog.info('Import cancelled');
      }
    } finally {
      AthenaDialog.dismiss();
    }
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
