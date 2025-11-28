import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

@RoutePage()
class DesktopSettingAdvancedPage extends StatefulWidget {
  const DesktopSettingAdvancedPage({super.key});

  @override
  State<DesktopSettingAdvancedPage> createState() =>
      _DesktopSettingAdvancedPageState();
}

class _DesktopSettingAdvancedPageState
    extends State<DesktopSettingAdvancedPage> {
  final viewModel = GetIt.instance.get<SettingViewModel>();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AthenaSecondaryButton(
            onTap: _handleExport,
            child: Text('Export'),
          ),
          const SizedBox(height: 16),
          AthenaSecondaryButton(
            onTap: _handleImport,
            child: Text('Import'),
          ),
        ],
      ),
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
}
