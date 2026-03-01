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
    final success = await viewModel.exportData();
    AthenaDialog.dismiss();
    if (!mounted) return;
    final message = success ? '导出成功' : '导出已取消';
    AthenaDialog.message(message);
  }

  Future<void> _handleImport() async {
    AthenaDialog.loading();
    final success = await viewModel.importData();
    AthenaDialog.dismiss();
    if (!mounted) return;
    final message = success ? '导入成功' : '导入已取消';
    AthenaDialog.message(message);
  }

  Future<void> _handleReset() async {
    final confirmed = await AthenaDialog.confirm('确定要重置所有数据吗？');
    if (confirmed != true) return;
    AthenaDialog.loading();
    final success = await viewModel.resetData();
    AthenaDialog.dismiss();
    if (!mounted) return;
    final message = success ? '重置成功' : '重置已取消';
    AthenaDialog.message(message);
  }
}
