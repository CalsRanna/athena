import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/storage/storage_maintenance.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/util/byte_size.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/page/desktop/setting/component/panel.dart';
import 'package:athena_gui/page/desktop/setting/component/row.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:url_launcher/url_launcher.dart';

/// 桌面端 Data：数据目录、存储清理与重置。
@RoutePage()
class DesktopSettingDataPage extends StatefulWidget {
  const DesktopSettingDataPage({super.key});

  @override
  State<DesktopSettingDataPage> createState() => _DesktopSettingDataPageState();
}

class _DesktopSettingDataPageState extends State<DesktopSettingDataPage> {
  final viewModel = GetIt.instance<SettingViewModel>();

  StorageUsage? _usage;
  var _loadingUsage = true;

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final dataDirectory = GetIt.instance<FileStorage>().root.path;
    return AthenaSettingsPane(
      children: [
        AthenaSettingsSection(
          first: true,
          title: 'Data',
          children: [
            AthenaSettingsRow(
              label: 'Data folder',
              description: dataDirectory,
              control: AthenaSecondaryButton.small(
                onTap: () => _openFolder(dataDirectory),
                child: const Text('Show in folder'),
              ),
            ),
            AthenaSettingsRow(
              label: 'Rewind snapshots',
              description: _usage == null
                  ? 'Calculating…'
                  : '${_sizeSummary(_usage!.rewindSnapshotCount, _usage!.rewindSnapshotBytes)}. '
                        'Recovery points created before each rewind.',
              descriptionMaxLines: 3,
              control: AthenaSecondaryButton.small(
                onTap: _hasRewindSnapshots ? _clearRewindSnapshots : null,
                child: const Text('Clear…'),
              ),
            ),
            AthenaSettingsRow(
              label: 'Tool outputs',
              description: _usage == null
                  ? 'Calculating…'
                  : '${_sizeSummary(_usage!.toolOutputCount, _usage!.toolOutputBytes)}. '
                        'Saved long tool results; clearing makes them unreadable '
                        'from old messages.',
              descriptionMaxLines: 3,
              control: AthenaSecondaryButton.small(
                onTap: _hasToolOutputs ? _clearToolOutputs : null,
                child: const Text('Clear…'),
              ),
            ),
          ],
        ),
        AthenaSettingsSection(
          title: 'Danger zone',
          children: [
            AthenaSettingsRow(
              label: 'Reset Athena',
              description:
                  'Deletes every session, provider, model and Sentinel on this '
                  'device and restores all settings to their defaults.',
              control: AthenaSecondaryButton.small(
                onTap: _handleReset,
                child: Text(
                  'Reset…',
                  style: TextStyle(color: colors.dangerText),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openFolder(String path) async {
    final ok = await launchUrl(Uri.directory(path));
    if (!ok && mounted) AthenaDialog.error('Unable to open $path');
  }

  bool get _hasRewindSnapshots =>
      !_loadingUsage && (_usage?.rewindSnapshotCount ?? 0) > 0;

  bool get _hasToolOutputs =>
      !_loadingUsage && (_usage?.toolOutputCount ?? 0) > 0;

  String _sizeSummary(int count, int bytes) =>
      '$count ${count == 1 ? 'file' : 'files'} · ${formatByteSize(bytes)}';

  Future<void> _loadUsage() async {
    StorageUsage usage;
    try {
      usage = await GetIt.instance<StorageMaintenance>().measure();
    } catch (_) {
      usage = const StorageUsage();
    }
    if (!mounted) return;
    setState(() {
      _usage = usage;
      _loadingUsage = false;
    });
  }

  Future<void> _clearRewindSnapshots() async {
    final confirmed = await AthenaDialog.confirm(
      'Delete all rewind snapshots? They are the recovery points used to '
      'restore earlier conversation states. This cannot be undone.',
      dismissible: false,
    );
    if (!mounted || confirmed != true) return;
    await _runCleanup(
      action: () => GetIt.instance<StorageMaintenance>().clearRewindSnapshots(),
      successMessage: (count) =>
          'Deleted $count rewind ${count == 1 ? 'snapshot' : 'snapshots'}',
      failureMessage: 'Unable to clear rewind snapshots',
    );
  }

  Future<void> _clearToolOutputs() async {
    if (GetIt.instance<ChatViewModel>().streamingChatIds.value.isNotEmpty) {
      AthenaDialog.info('Stop running sessions before clearing tool outputs.');
      return;
    }
    final confirmed = await AthenaDialog.confirm(
      'Delete all saved tool outputs? Stop running sessions in GUI and TUI '
      'first. Long tool results referenced by old messages will no longer be '
      'readable. This cannot be undone.',
      dismissible: false,
    );
    if (!mounted || confirmed != true) return;
    await _runCleanup(
      action: () => GetIt.instance<StorageMaintenance>().clearToolOutputs(),
      successMessage: (count) =>
          'Deleted $count tool ${count == 1 ? 'output' : 'outputs'}',
      failureMessage: 'Unable to clear tool outputs',
    );
  }

  Future<void> _runCleanup({
    required Future<int> Function() action,
    required String Function(int count) successMessage,
    required String failureMessage,
  }) async {
    int? deleted;
    var failed = false;
    AthenaDialog.loading();
    try {
      deleted = await action();
    } catch (_) {
      failed = true;
    } finally {
      AthenaDialog.dismiss();
    }
    await _loadUsage();
    if (!mounted) return;
    if (failed) {
      AthenaDialog.error(failureMessage);
    } else {
      AthenaDialog.success(successMessage(deleted!));
    }
  }

  Future<void> _handleReset() async {
    final confirmed = await AthenaDialog.confirm(
      'Reset Athena and permanently delete all local data and settings?',
      dismissible: false,
    );
    if (!mounted || confirmed != true) return;
    await _runDataOperation(
      // 经 ChatViewModel 包一层：先停掉运行中的对话，清空后刷新会话列表
      action: () =>
          GetIt.instance<ChatViewModel>().runDataReset(viewModel.resetData),
      successMessage: 'Athena has been reset',
      cancelledMessage: 'Reset cancelled',
      failureMessage: 'Unable to reset Athena',
    );
  }

  Future<void> _runDataOperation({
    required Future<bool> Function() action,
    required String successMessage,
    required String cancelledMessage,
    required String failureMessage,
  }) async {
    bool? success;
    var failed = false;
    AthenaDialog.loading();
    try {
      success = await action();
    } catch (_) {
      failed = true;
    } finally {
      AthenaDialog.dismiss();
    }
    if (!mounted) return;
    if (failed) {
      AthenaDialog.error(failureMessage);
    } else if (success == true) {
      AthenaDialog.success(successMessage);
    } else {
      AthenaDialog.info(cancelledMessage);
    }
  }
}
