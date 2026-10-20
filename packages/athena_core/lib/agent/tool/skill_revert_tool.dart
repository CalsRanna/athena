import 'dart:io';

import 'package:athena_core/agent/evolution/skill_history_store.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/storage/file_lock.dart';

/// 回滚技能到历史版本的只读+写入工具。
///
/// 与 `skill_evolve` 配套：覆盖 SKILL.md 之前会存快照，改坏了能退回去。
/// 与 `sentinel_revert` 的差别在于粒度——技能快照存的是整份 SKILL.md 原文，
/// 回滚即整文件替换，不做字段级合并。
///
/// **回滚本身也会先存快照**，所以回滚同样可回滚。但注意：不指定
/// `snapshot_id` 时取最近一条，连续两次回滚会「退回回滚前」的状态——这是
/// 「回滚可回滚」的必然结果，报告里会写清楚恢复了哪一条。
class SkillRevertTool extends Tool {
  final SkillRegistry _skillRegistry;
  final SkillHistoryStore _historyStore;

  SkillRevertTool({
    required SkillRegistry skillRegistry,
    required SkillHistoryStore historyStore,
  }) : _skillRegistry = skillRegistry,
       _historyStore = historyStore;

  @override
  String get name => 'skill_revert';

  @override
  String get description =>
      'Restore a skill to a previous snapshot, undoing one or more '
      'skill_evolve updates. Use this when an update made things worse. '
      'Omit snapshot_id to restore the most recent snapshot (that is, undo '
      'the last update). Snapshot IDs are returned by skill_evolve and listed '
      'here when you omit the parameter and the skill has history. '
      'The current version is snapshotted before restoring, so a revert can '
      'itself be reverted.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'The exact name of the skill to revert.',
      },
      'snapshot_id': {
        'type': 'string',
        'description':
            'ID of the snapshot to restore (omit to restore the most recent '
            'one). Omit-and-list is the way to discover IDs: calling this '
            'tool without snapshot_id lists history when the newest snapshot '
            'cannot be applied.',
      },
      'reason': {
        'type': 'string',
        'description':
            'Why this revert is needed. Recorded alongside the snapshot of '
            'the state being replaced.',
      },
      'list_only': {
        'type': 'boolean',
        'description':
            'When true, only list available snapshots for this skill without '
            'restoring anything. Use this to find a snapshot_id for an older '
            'version.',
      },
    },
    'required': ['name'],
  };

  @override
  Future<ToolExecutionResult> executeResult(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async {
    final skillName = args['name'] as String;
    final snapshotId = args['snapshot_id'] as String?;
    final reason = args['reason'] as String? ?? '';
    final listOnly = args['list_only'] as bool? ?? false;

    final existing = _skillRegistry.get(skillName);
    if (existing == null) {
      return ToolExecutionResult.error('Error: Skill "$skillName" not found.');
    }
    if (existing.isBuiltin) {
      return const ToolExecutionResult.error(
        'Error: Built-in skills cannot be reverted.',
      );
    }

    final metas = await _historyStore.list(skillName);
    if (listOnly) {
      return ToolExecutionResult.success(_formatHistory(skillName, metas));
    }
    if (metas.isEmpty) {
      return ToolExecutionResult.error(
        'Error: No history snapshots found for "$skillName". '
        'Revert is only possible after at least one skill_evolve update.',
      );
    }

    final targetId = (snapshotId != null && snapshotId.isNotEmpty)
        ? snapshotId
        : metas.first.id;
    final content = await _historyStore.load(skillName, targetId);
    if (content == null) {
      return ToolExecutionResult.error(
        'Error: Snapshot "$targetId" not found or corrupt for "$skillName".\n'
        '${_formatHistory(skillName, metas)}',
      );
    }

    try {
      final currentFile = File('${existing.sourcePath}/SKILL.md');
      // 回滚前先存当前版本：与 sentinel_revert 同口径，回滚也可撤销。
      if (await currentFile.exists()) {
        await _historyStore.save(
          skillName,
          await currentFile.readAsString(),
          reason: 'pre-revert state (revert reason: $reason)',
        );
      }
      await atomicWriteString(currentFile, content);
      _skillRegistry.reloadSkill(skillName, existing.sourcePath);

      final restored = _skillRegistry.get(skillName);
      final meta = metas.firstWhere((m) => m.id == targetId);
      final note = reason.isEmpty ? '' : '\nReason: $reason';
      return ToolExecutionResult.success(
        'Skill "$skillName" restored to snapshot "$targetId" '
        '(${_formatTime(meta.savedAt)}).$note\n'
        'Restored version: ${restored?.description ?? '(unreadable)'}\n'
        'The skill is available now, including in this conversation.\n'
        '${metas.length > 1 ? '${metas.length - 1} earlier snapshot(s) remain; '
                  'pass snapshot_id (or list_only=true) to go further back.' : ''}',
      );
    } catch (e) {
      return ToolExecutionResult.error(
        'Error reverting skill "$skillName": $e',
      );
    }
  }

  String _formatHistory(String skillName, List<SkillSnapshotMeta> metas) {
    if (metas.isEmpty) {
      return 'No history snapshots for "$skillName".';
    }
    final buffer = StringBuffer()
      ..writeln(
        'Snapshots for "$skillName" (newest first, '
        '${metas.length} total):',
      );
    for (final meta in metas) {
      buffer.writeln(
        '- ${meta.id} (${_formatTime(meta.savedAt)})'
        '${meta.reason.isEmpty ? '' : ' — ${meta.reason}'}',
      );
    }
    buffer.writeln('Restore one with skill_revert and that snapshot_id.');
    return buffer.toString();
  }

  String _formatTime(DateTime time) =>
      '${time.year}-${_pad(time.month)}-${_pad(time.day)} '
      '${_pad(time.hour)}:${_pad(time.minute)}';

  String _pad(int n) => n.toString().padLeft(2, '0');
}
