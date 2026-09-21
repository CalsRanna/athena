import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/util/logger_util.dart';

/// 一个会话及其全部消息(导入用)。
class SessionSnapshot {
  const SessionSnapshot({required this.chat, required this.messages});

  final ChatEntity chat;
  final List<MessageEntity> messages;
}

/// 从旧存储读出的全量数据(id 为旧存储里的原 id)。
class StorageSnapshot {
  const StorageSnapshot({
    this.providers = const [],
    this.models = const [],
    this.sentinels = const [],
    this.sessions = const [],
  });

  final List<ProviderEntity> providers;
  final List<ModelEntity> models;
  final List<SentinelEntity> sentinels;
  final List<SessionSnapshot> sessions;

  bool get isEmpty =>
      providers.isEmpty &&
      models.isEmpty &&
      sentinels.isEmpty &&
      sessions.isEmpty;
}

/// 把一份 [StorageSnapshot] 按**合并**语义并入 [FileStorage]。
///
/// GUI 的旧 SQLite 库与 TUI 的旧专属目录都可能要并入同一个共享目录,
/// 而目标目录里可能已有另一端写好的数据,所以不能覆盖:
/// - provider 按名字匹配,模型按 (model_id, provider) 匹配,角色按名字
///   匹配;命中则沿用目标端 id(同名 provider 尚无 key 时补上快照里
///   的 key 与启用状态),未命中则优先保留旧 id(未被占用时),否则分配
///   新 id
/// - 预设模型(is_preset)来自 models.dev,目录同步会重建,只并入被快照里
///   某个会话引用的那些,避免把旧存储里早已下架的几百个模型一并带入;
///   用户自建模型全部并入
/// - 会话用重映射后的 model_id / sentinel_id 写入;旧 id 未被占用则沿用,
///   否则分配新 id;消息 id 原样保留(会话内唯一即可)
/// - 每张表都先写"旧 id 空闲"的行、再写"旧 id 冲突"的行:后者分配的
///   新 id 才不会抢走前者本可保留的 id
/// - 目标为空时上述规则退化为"全部保留原 id"
///
/// 可重复执行:已并入的 provider/模型/角色按匹配规则去重,同 id 且同
/// 标题同创建时间的会话跳过。
class StorageMerger {
  const StorageMerger(this.target);

  final FileStorage target;

  Future<void> merge(StorageSnapshot snapshot) async {
    final providerIds = await _mergeProviders(snapshot.providers);
    final referenced = {for (final s in snapshot.sessions) s.chat.modelId};
    final modelIds = await _mergeModels(
      [
        for (final m in snapshot.models)
          if (!m.isPreset || referenced.contains(m.id)) m,
      ],
      providerIds,
    );
    final sentinelIds = await _mergeSentinels(snapshot.sentinels);
    await _mergeSessions(snapshot.sessions, modelIds, sentinelIds);
  }

  Future<Map<int, int>> _mergeProviders(List<ProviderEntity> providers) async {
    final repo = target.providerRepository;
    final ids = <int, int>{};
    final free = <ProviderEntity>[];
    final conflict = <ProviderEntity>[];
    for (final provider in providers) {
      final oldId = provider.id;
      if (oldId == null) continue;
      final byName = await repo.getProviderByName(provider.name);
      if (byName != null) {
        ids[oldId] = byName.id!;
        if (byName.apiKey.isEmpty && provider.apiKey.isNotEmpty) {
          await repo.updateProvider(
            byName.copyWith(apiKey: provider.apiKey, enabled: provider.enabled),
          );
        }
      } else if (await repo.getProviderById(oldId) == null) {
        free.add(provider);
      } else {
        conflict.add(provider);
      }
    }
    for (final provider in free) {
      ids[provider.id!] = await repo.storeProvider(provider);
    }
    for (final provider in conflict) {
      ids[provider.id!] = await repo.storeProvider(
        provider.copyWith(id: null).withoutId(),
      );
    }
    LoggerUtil.i(
      'Merged providers: ${providers.length} in, '
      '${free.length + conflict.length} created',
    );
    return ids;
  }

  Future<Map<int, int>> _mergeModels(
    List<ModelEntity> models,
    Map<int, int> providerIds,
  ) async {
    final repo = target.modelRepository;
    final ids = <int, int>{};
    final free = <ModelEntity>[];
    final conflict = <ModelEntity>[];
    for (final raw in models) {
      final oldId = raw.id;
      if (oldId == null) continue;
      final providerId = providerIds[raw.providerId] ?? raw.providerId;
      final model = raw.copyWith(providerId: providerId);
      final existing = await repo.getModelByModelIdAndProviderId(
        model.modelId,
        providerId,
      );
      if (existing != null) {
        ids[oldId] = existing.id!;
      } else if (await repo.getModelById(oldId) == null) {
        free.add(model);
      } else {
        conflict.add(model);
      }
    }
    for (final model in free) {
      await repo.restore(model);
      ids[model.id!] = model.id!;
    }
    for (final model in conflict) {
      ids[model.id!] = await repo.createModel(
        ModelEntity.fromJson(model.toJson()..remove('id')),
      );
    }
    LoggerUtil.i(
      'Merged models: ${models.length} in, '
      '${free.length + conflict.length} created',
    );
    return ids;
  }

  Future<Map<int, int>> _mergeSentinels(List<SentinelEntity> sentinels) async {
    final repo = target.sentinelRepository;
    final ids = <int, int>{};
    final free = <SentinelEntity>[];
    final conflict = <SentinelEntity>[];
    for (final sentinel in sentinels) {
      final oldId = sentinel.id;
      if (oldId == null) continue;
      final byName = await repo.getSentinelByName(sentinel.name);
      if (byName != null) {
        ids[oldId] = byName.id!;
      } else if (await repo.getSentinelById(oldId) == null) {
        free.add(sentinel);
      } else {
        conflict.add(sentinel);
      }
    }
    for (final sentinel in free) {
      await repo.restore(sentinel);
      ids[sentinel.id!] = sentinel.id!;
    }
    for (final sentinel in conflict) {
      ids[sentinel.id!] = await repo.createSentinel(
        SentinelEntity.fromJson(sentinel.toJson()..remove('id')),
      );
    }
    LoggerUtil.i(
      'Merged sentinels: ${sentinels.length} in, '
      '${free.length + conflict.length} created',
    );
    return ids;
  }

  Future<void> _mergeSessions(
    List<SessionSnapshot> sessions,
    Map<int, int> modelIds,
    Map<int, int> sentinelIds,
  ) async {
    final repo = target.sessionRepository;
    final free = <SessionSnapshot>[];
    final conflict = <SessionSnapshot>[];
    var skipped = 0;
    for (final session in sessions) {
      final raw = session.chat;
      final oldId = raw.id;
      if (oldId == null) continue;
      final existing = await repo.getChatById(oldId);
      if (existing != null &&
          existing.title == raw.title &&
          existing.createdAt == raw.createdAt) {
        skipped++; // 上次中断前已并入
        continue;
      }
      final chat = raw.copyWith(
        modelId: modelIds[raw.modelId] ?? raw.modelId,
        sentinelId: sentinelIds[raw.sentinelId] ?? raw.sentinelId,
      );
      (existing == null ? free : conflict).add(
        SessionSnapshot(chat: chat, messages: session.messages),
      );
    }
    var messages = 0;
    for (final session in free.followedBy(conflict)) {
      // importSession:旧 id 空闲则沿用,已被占用则分配新 id
      await repo.importSession(session.chat, session.messages);
      messages += session.messages.length;
    }
    LoggerUtil.i(
      'Merged sessions: ${sessions.length} in, '
      '${free.length + conflict.length} written ($messages messages), '
      '$skipped skipped',
    );
  }
}

extension on ProviderEntity {
  /// copyWith(id: null) 在可空字段上不生效(null 表示"不改"),走 JSON 去 id。
  ProviderEntity withoutId() => ProviderEntity.fromJson(toJson()..remove('id'));
}
