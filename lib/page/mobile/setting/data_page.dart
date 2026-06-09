import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';

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
    var children = [
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedFileExport, size: 24),
        onTap: _handleExport,
        title: 'Export',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedFileImport, size: 24),
        onTap: _handleImport,
        title: 'Import',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedDatabaseRestore, size: 24),
        onTap: _handleReset,
        title: 'Reset',
        trailing: '',
      ),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return AthenaScaffold(
      appBar: AthenaAppBar(title: Text('Data')),
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
      final success = await viewModel.resetData();
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
