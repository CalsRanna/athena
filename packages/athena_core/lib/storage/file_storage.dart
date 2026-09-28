import 'dart:io';

import 'package:athena_core/storage/id_generator.dart';
import 'package:athena_core/storage/storage_id_migration.dart';
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
///                            # 消息 responses_state 保存 Responses 推理续接状态
///                            # 消息 messages_state 保存 Messages thinking/signature 及请求前缀指纹
///                            # chat_completions_state 保存兼容端原生推理/拒答；completion_details 保存停止与用量明细
///   models.json               # 模型列表(JSON 数组)
///   sentinels.json            # 角色列表(JSON 数组，旧 avatar 字段读取时忽略)
///   storage_version.json      # 格式版本与旧模型 ID 映射（GUI 偏好迁移用）
///   backups/ids-v1/            # 首次 UUID 迁移前的原始数据备份
///   setting.yaml              # provider 配置(含 API key、API 格式元数据与自动同步开关)与 TUI 默认模型
///   models_dev_cache.json     # models.dev 目录缓存
///   tool_outputs/             # 工具长输出(内容寻址)
///   background_tasks/         # 运行中的后台任务(按属主进程记账,供孤儿清理)
/// ```
///
/// 持久化身份使用 UUIDv7，生成不访问磁盘；消息顺序使用会话内 seq。
/// load 必须在任何仓储读写之前完成，首次升级前关闭所有旧版 GUI/TUI。
/// JSON / YAML 数据文件损坏时,下一次写入前先备份为 `.corrupt-{时间戳}`。
///
/// 文件永远是唯一真相;将来若需全文检索,索引应作为可删除可重建的缓存,
/// 不反向持有数据。
class FileStorage {
  FileStorage({required this.root, File? settingFile})
    : settingFile = settingFile ?? File(p.join(root.path, 'setting.yaml')) {
    idGenerator = const IdGenerator();
    sessionRepository = JsonlSessionRepository(
      sessionsDir: sessionsDir,
      idGenerator: idGenerator,
    );
    modelRepository = JsonArrayModelRepository(
      file: modelsFile,
      idGenerator: idGenerator,
    );
    sentinelRepository = JsonArraySentinelRepository(
      file: sentinelsFile,
      idGenerator: idGenerator,
    );
    userSettings = UserSettingsStore(file: this.settingFile);
    providerRepository = YamlProviderRepository(
      store: userSettings,
      idGenerator: idGenerator,
    );
  }

  final Directory root;

  /// provider 配置文件;默认 `root/setting.yaml`,TUI 测试可单独指定。
  final File settingFile;

  Directory get sessionsDir => Directory(p.join(root.path, 'sessions'));
  File get modelsFile => File(p.join(root.path, 'models.json'));
  File get sentinelsFile => File(p.join(root.path, 'sentinels.json'));

  /// 仅用于识别、清理旧格式，不再写入计数。
  File get metaFile => File(p.join(root.path, 'meta.json'));
  File get catalogCacheFile => File(p.join(root.path, 'models_dev_cache.json'));
  Directory get toolOutputsDir => Directory(p.join(root.path, 'tool_outputs'));

  /// 后台任务孤儿记录目录（进程被强杀后下次启动据此清理遗留进程）。
  Directory get backgroundTasksDir =>
      Directory(p.join(root.path, 'background_tasks'));

  late final IdGenerator idGenerator;

  /// 同一实例同时承担 ChatRepository 与 MessageRepository:对话与其消息
  /// 同生命周期,删对话即删文件。
  late final JsonlSessionRepository sessionRepository;
  late final JsonArrayModelRepository modelRepository;
  late final JsonArraySentinelRepository sentinelRepository;
  late final UserSettingsStore userSettings;
  late final YamlProviderRepository providerRepository;

  /// 启动升级保留的模型身份映射，供 GUI 的旧 SharedPreferences 迁移。
  Map<String, String> legacyModelIds = {};

  Future<void> load() async {
    legacyModelIds = await StorageIdMigration(
      root: root,
      settingFile: settingFile,
    ).run();
    await providerRepository.load();
  }

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

  /// 清空全部业务数据(会话、模型、角色、provider),不动
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
