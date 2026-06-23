import 'dart:convert';
import 'dart:io';

import 'package:athena/database/database.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/util/platform_util.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

/// 数据导入/导出与迁移服务。
///
/// 负责将 Provider/Model/Sentinel 导出为 JSON 文件、
/// 从 JSON 文件导入、重整悬空的 chat 引用、以及数据库重置。
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

  /// 导出 Provider/Model/Sentinel 数据到 JSON 文件。返回是否成功。
  Future<bool> exportData() async {
    final providers = await _providerRepo.getAllProviders();
    final models = await _modelRepo.getAllModels();
    final sentinels = await _sentinelRepo.getAllSentinels();

    final data = {
      'providers': providers.map((p) => p.toJson()).toList(),
      'models': models.map((m) => m.toJson()).toList(),
      'sentinels': sentinels.map((s) => s.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final isDesktop = PlatformUtil.isDesktop;
    final path = isDesktop
        ? await FilePicker.platform.saveFile(
            dialogTitle: '选择导出位置',
            fileName: 'athena_export.json',
            type: FileType.custom,
            allowedExtensions: ['json'],
          )
        : await FilePicker.platform.saveFile(
            bytes: Uint8List.fromList(utf8.encode(jsonString)),
            dialogTitle: '选择导出位置',
            fileName: 'athena_export.json',
            type: FileType.custom,
            allowedExtensions: ['json'],
          );
    if (path == null) return false;

    if (isDesktop) {
      final file = File(path);
      await file.writeAsString(jsonString);
    }

    return true;
  }

  /// 从 JSON 文件导入数据。
  ///
  /// [chatModelId] 用于重整导入后悬空的 chat.model_id 引用。
  Future<bool> importData({required int chatModelId}) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择要导入的文件',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return false;

    final path = result.files.single.path;
    if (path == null) return false;

    final file = File(path);
    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

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
