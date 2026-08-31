import 'package:athena_core/agent/evolution/sentinel_history_store.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/repository/sentinel_repository.dart';

/// 回滚 sentinel 的工具：从 [SentinelHistoryStore] 的快照恢复旧态。
///
/// 与 `sentinel_evolve` 配套，使角色演进可撤销——一次失败的进化
/// 不再只能靠再一次进化来"打补丁"。
///
/// 回滚前会先保存当前态的快照（回滚同样可回滚）。
class SentinelRevertTool implements Tool {
  @override
  ExecutionMode get executionMode => ExecutionMode.sequential;
  @override
  bool canExecuteParallel(Map<String, dynamic> args) => false;
  /// 内置 sentinel 的名称（与 SentinelEvolveTool 约定一致）。
  static const builtinSentinelName = 'Athena';

  final SentinelRepository _repository;
  final SentinelHistoryStore _historyStore;
  final void Function()? _onChanged;

  SentinelRevertTool({
    required SentinelRepository repository,
    required SentinelHistoryStore historyStore,
    void Function()? onChanged,
  })  : _repository = repository,
        _historyStore = historyStore,
        _onChanged = onChanged;

  @override
  ToolRisk get risk => ToolRisk.dangerous;

  @override
  String get name => 'sentinel_revert';

  @override
  String get description =>
      'Revert a sentinel (system prompt / role definition) to a previous '
      'snapshot, undoing one or more sentinel_evolve changes. '
      'Use this when:\n'
      '- A sentinel evolution turned out worse and should be rolled back\n'
      '- You want to undo a rename or restore an earlier role definition\n'
      'The current state is saved as a snapshot before reverting, so the '
      'revert itself can be reverted. Always explain what you reverted to '
      'and why.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'sentinel_name': {
            'type': 'string',
            'description':
                'The name of the sentinel to revert. Use the exact name as '
                'shown in the sentinel list.',
          },
          'snapshot_id': {
            'type': 'string',
            'description':
                'ID of the snapshot to restore (omit to restore the most '
                'recent snapshot). Snapshot IDs are shown in sentinel_evolve '
                'change reports and in the history listing.',
          },
          'reason': {
            'type': 'string',
            'description':
                'Why this revert is needed. This is recorded in the history '
                'snapshot for future reference.',
          },
        },
        'required': ['sentinel_name'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args, {void Function(String)? onUpdate}) async {
    final sentinelName = args['sentinel_name'] as String;
    final snapshotId = args['snapshot_id'] as String?;
    final reason = args['reason'] as String? ?? '';

    // 查找当前 sentinel
    final original = await _repository.getSentinelByName(sentinelName);
    if (original == null) {
      return 'Error: Sentinel "$sentinelName" not found. '
          'Check the name spelling. Available sentinels can be listed in the '
          'settings.';
    }

    // 确定目标快照：显式指定或取最近一条
    String targetId;
    if (snapshotId != null && snapshotId.isNotEmpty) {
      targetId = snapshotId;
    } else {
      final metas = await _historyStore.list(sentinelName);
      if (metas.isEmpty) {
        return 'Error: No history snapshots found for "$sentinelName". '
            'Revert is only possible after at least one sentinel_evolve '
            'change.';
      }
      targetId = metas.first.id;
    }

    final target = await _historyStore.load(sentinelName, targetId);
    if (target == null) {
      return 'Error: Snapshot "$targetId" not found or corrupt. '
          'Use a snapshot_id listed in the history.';
    }

    try {
      // 回滚目标中包含改名：旧名被其他 sentinel 占用则拒绝
      if (target.name != original.name) {
        final conflict = await _repository.getSentinelByName(target.name);
        if (conflict != null && conflict.id != original.id) {
          return 'Error: Cannot revert to snapshot "$targetId": another '
              'sentinel named "${target.name}" already exists.';
        }
      }

      // 回滚前保存当前态快照（回滚同样可回滚）
      await _historyStore.save(
        original.name,
        original,
        reason: 'pre-revert state (revert reason: $reason)',
      );

      // 从快照恢复（保留当前 id 与 isPreset；名字跟随快照 = 撤销改名）
      final restored = original.copyWith(
        name: target.name,
        description: target.description,
        prompt: target.prompt,
        avatar: target.avatar,
        tags: target.tags,
      );
      await _repository.updateSentinel(restored);
      _onChanged?.call();

      final changeNote = _buildReport(
        snapshotId: targetId,
        originalName: sentinelName,
        restoredName: restored.name,
        reason: reason,
        originalPrompt: original.prompt,
        restoredPrompt: restored.prompt,
      );
      return 'Sentinel reverted successfully!\n'
          'Restored "$sentinelName" to snapshot "$targetId".\n\n'
          '$changeNote\n\n'
          'The changes take effect immediately in the current chat.';
    } catch (e) {
      return 'Error reverting sentinel: $e';
    }
  }

  String _buildReport({
    required String snapshotId,
    required String originalName,
    required String restoredName,
    required String reason,
    required String originalPrompt,
    required String restoredPrompt,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('## Revert Report');
    buffer.writeln();
    buffer.writeln('**Restored to snapshot:** $snapshotId');
    if (originalName != restoredName) {
      buffer.writeln('**Name:** $originalName → $restoredName');
    }
    if (reason.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('**Reason:**');
      buffer.writeln(reason);
    }
    buffer.writeln();
    buffer.writeln('**Changes:**');
    buffer.writeln('- Prompt length: ${originalPrompt.length} → '
        '${restoredPrompt.length} chars');
    return buffer.toString();
  }
}
