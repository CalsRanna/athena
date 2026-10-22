import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/storage/storage_maintenance.dart';
import 'package:athena_gui/page/mobile/setting/component/section.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/util/byte_size.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:athena_gui/page/mobile/setting/component/setting_tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
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

  StorageUsage? _usage;
  var _loadingUsage = true;

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

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
        MobileSettingsSection(
          title: 'Storage',
          description:
              'Rewind snapshots and saved tool outputs can be removed to '
              'reclaim disk space.',
          children: [
            MobileSettingTile(
              leading: const Icon(
                LucideIcons.history,
                size: AthenaIcon.largeSize,
              ),
              onTap: _hasRewindSnapshots ? _clearRewindSnapshots : null,
              title: 'Rewind snapshots',
              subtitle: _usage == null
                  ? 'Calculating…'
                  : '${_sizeSummary(_usage!.rewindSnapshotCount, _usage!.rewindSnapshotBytes)}. '
                        'Recovery points created before each rewind.',
              trailing: '',
            ),
            MobileSettingTile(
              leading: const Icon(
                LucideIcons.fileText,
                size: AthenaIcon.largeSize,
              ),
              onTap: _hasToolOutputs ? _clearToolOutputs : null,
              title: 'Tool outputs',
              subtitle: _usage == null
                  ? 'Calculating…'
                  : '${_sizeSummary(_usage!.toolOutputCount, _usage!.toolOutputBytes)}. '
                        'Clearing makes old tool results unreadable.',
              trailing: '',
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
      await _loadUsage();
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
