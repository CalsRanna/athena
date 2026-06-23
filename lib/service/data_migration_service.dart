import 'dart:convert';

import 'package:athena/database/database.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';

/// 数据导入/导出与迁移服务。
///
/// 负责将 Provider/Model/Sentinel 序列化为 JSON、从 JSON 反序列化导入、
/// 重整悬空的 chat 引用、以及数据库重置。
///
/// 文件 I/O 和文件选择 UI 由上层（ViewModel）负责。
class DataMigrationService {
  final ProviderRepository _providerRepo;
  final ModelRepository _modelRepo;
  final SentinelRepository _sentinelRepo;
  final ChatRepository _chatRepo;

  DataMigrationService({
    required ProviderRepository providerRepo,
    required ModelRepository modelRepo,
    required SentinelRepository sentinelRepo,
    required ChatRepository chatRepo,
  })  : _providerRepo = providerRepo,
        _modelRepo = modelRepo,
        _sentinelRepo = sentinelRepo,
        _chatRepo = chatRepo;

  /// 将 Provider/Model/Sentinel 序列化为 JSON 字符串。
  /// 文件写入由上层负责。
  Future<String> exportToJson() async {
    final providers = await _providerRepo.getAllProviders();
    final models = await _modelRepo.getAllModels();
    final sentinels = await _sentinelRepo.getAllSentinels();

    final data = {
      'providers': providers.map((p) => p.toJson()).toList(),
      'models': models.map((m) => m.toJson()).toList(),
      'sentinels': sentinels.map((s) => s.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 从 JSON 字符串导入数据。
  ///
  /// [chatModelId] 用于重整导入后悬空的 chat.model_id 引用。
  Future<bool> importFromJson(
    String json, {
    required int chatModelId,
  }) async {
    final data = jsonDecode(json) as Map<String, dynamic>;

    // 先清空本地数据，避免同 ID 不同名导致关联错误
    await _modelRepo.deleteAllModels();
    await _providerRepo.deleteAllProviders();

    if (data['providers'] != null) {
      final list = data['providers'] as List;
      final providers = list
          .map((j) => ProviderEntity.fromJson(j as Map<String, dynamic>))
          .toList();
      await _providerRepo.importProviders(providers);
    }

    if (data['models'] != null) {
      final list = data['models'] as List;
      final models = list
          .map((j) => ModelEntity.fromJson(j as Map<String, dynamic>))
          .toList();
      await _modelRepo.importModels(models);
    }

    if (data['sentinels'] != null) {
      final list = data['sentinels'] as List;
      final sentinels = list
          .map((j) => SentinelEntity.fromJson(j as Map<String, dynamic>))
          .toList();
      await _sentinelRepo.importSentinels(sentinels);
    }

    await reconcileChatModelReferences(chatModelId);

    return true;
  }

  /// 扫描所有会话，将 model_id 指向已不存在模型的会话重置为 [preferredModelId]
  /// （若有效），否则取第一个可用模型。
  /// 扫描所有会话，将悬空的 model_id 引用重置。
  Future<void> reconcileChatModelReferences(int preferredModelId) async {
    final models = await _modelRepo.getAllModels();
    final validIds = models.map((m) => m.id).whereType<int>().toSet();
    if (validIds.isEmpty) return;

    final defaultId = validIds.contains(preferredModelId)
        ? preferredModelId
        : validIds.first;

    final chats = await _chatRepo.getAllChats();
    for (final chat in chats) {
      if (!validIds.contains(chat.modelId)) {
        await _chatRepo.updateChat(chat.copyWith(modelId: defaultId));
      }
    }
  }

  /// 重置数据库（清空所有表并重新迁移 + 预设）。
  Future<void> resetDatabase() async {
    await Database.instance.reset();
  }
}
