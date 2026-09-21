import 'dart:io';

import 'package:athena_core/storage/id_allocator.dart';
import 'package:athena_core/storage/json_array_model_repository.dart';
import 'package:athena_core/storage/json_array_sentinel_repository.dart';
import 'package:athena_core/storage/jsonl_session_repository.dart';
import 'package:athena_core/storage/user_settings_store.dart';
import 'package:athena_core/storage/yaml_provider_repository.dart';
import 'package:path/path.dart' as p;

/// 本地文件持久化的目录布局与仓储装配。GUI 与 TUI 共享同一根目录。
///
/// 布局(root 默认 `~/.athena/`,移动端由装配层传 Application Support):
/// ```
/// root/
///   sessions/{chatId}.jsonl   # 一个对话一个文件:首行会话元数据 + 消息行
///   models.json               # 模型列表(JSON 数组)
///   sentinels.json            # 角色列表(JSON 数组)
///   meta.json                 # 自增 id 计数(key 为文件/目录路径)
///   setting.yaml              # provider 配置(含 API key)与 TUI 默认模型
///   models_dev_cache.json     # models.dev 目录缓存
///   tool_outputs/             # 工具长输出(内容寻址)
/// ```
///
/// 文件永远是唯一真相;将来若需全文检索,索引应作为可删除可重建的缓存,
/// 不反向持有数据。
class FileStorage {
  FileStorage({required this.root, File? settingFile})
    : settingFile = settingFile ?? File(p.join(root.path, 'setting.yaml')) {
    idAllocator = IdAllocator(metaFile);
    sessionRepository = JsonlSessionRepository(
      sessionsDir: sessionsDir,
      idAllocator: idAllocator,
    );
    modelRepository = JsonArrayModelRepository(
      file: modelsFile,
      idAllocator: idAllocator,
    );
    sentinelRepository = JsonArraySentinelRepository(
      file: sentinelsFile,
      idAllocator: idAllocator,
    );
    userSettings = UserSettingsStore(file: this.settingFile);
    providerRepository = YamlProviderRepository(store: userSettings);
  }

  final Directory root;

  /// provider 配置文件;默认 `root/setting.yaml`,TUI 测试可单独指定。
  final File settingFile;

  Directory get sessionsDir => Directory(p.join(root.path, 'sessions'));
  File get modelsFile => File(p.join(root.path, 'models.json'));
  File get sentinelsFile => File(p.join(root.path, 'sentinels.json'));
  File get metaFile => File(p.join(root.path, 'meta.json'));
  File get catalogCacheFile => File(p.join(root.path, 'models_dev_cache.json'));
  Directory get toolOutputsDir => Directory(p.join(root.path, 'tool_outputs'));

  late final IdAllocator idAllocator;

  /// 同一实例同时承担 ChatRepository 与 MessageRepository:对话与其消息
  /// 同生命周期,删对话即删文件。
  late final JsonlSessionRepository sessionRepository;
  late final JsonArrayModelRepository modelRepository;
  late final JsonArraySentinelRepository sentinelRepository;
  late final UserSettingsStore userSettings;
  late final YamlProviderRepository providerRepository;

  /// 启动时加载:目前只有 provider 需要预读 yaml 到内存。
  Future<void> load() => providerRepository.load();

  /// 是否已有业务数据(会话/模型/角色任一存在)。
  ///
  /// 从旧存储导入时据此判断目标是否为空。
  Future<bool> hasData() async {
    if (await modelsFile.exists() || await sentinelsFile.exists()) return true;
    if (!await sessionsDir.exists()) return false;
    await for (final entity in sessionsDir.list()) {
      if (entity is File && entity.path.endsWith('.jsonl')) return true;
    }
    return false;
  }

  /// 清空全部业务数据(会话、模型、角色、id 计数、provider),不动
  /// 目录缓存与工具输出。调用方随后应重新执行种子。
  Future<void> reset() async {
    if (await sessionsDir.exists()) {
      await sessionsDir.delete(recursive: true);
    }
    for (final file in [modelsFile, sentinelsFile, metaFile]) {
      if (await file.exists()) await file.delete();
    }
    await providerRepository.deleteAllProviders();
  }
}
