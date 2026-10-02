import 'dart:io';

import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/id_generator.dart';
import 'package:athena_core/storage/storage_id_migration.dart';
import 'package:athena_core/storage/jsonl_session_repository.dart';
import 'package:athena_core/storage/models_into_providers_migration.dart';
import 'package:athena_core/storage/provider_files_migration.dart';
import 'package:athena_core/storage/provider_model_repository.dart';
import 'package:athena_core/storage/provider_store.dart';
import 'package:athena_core/storage/sentinel_files_migration.dart';
import 'package:athena_core/storage/sentinel_store.dart';
import 'package:athena_core/storage/user_settings_store.dart';
import 'package:athena_core/storage/yaml_provider_repository.dart';
import 'package:athena_core/storage/yaml_sentinel_repository.dart';
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
///   .storage_version          # 格式版本与旧模型 ID 映射（GUI 偏好迁移用；
///                            # 旧名 storage_version.json 启动时改名过来）
///   backups/ids-v1/            # 首次 UUID 迁移前的原始数据备份
///   setting.yaml              # 用户配置:两个前端共用(GUI 与 TUI 的界面偏好
///                            # + core 的 brave API key)
///   permissions.json          # 权限规则(GUI 与 TUI 共用,可手工编辑)
///   providers/{id}.yaml        # 一个 provider 一个文件：provider 配置(含 API key)
///                            # + 它名下的模型（`models:` 段）
///   sentinels/{id}.yaml        # 一个角色一个文件
///   models.json.migrated      # 旧的整体模型表，已并入 providers/；只作留档
///   sentinels.json.migrated   # 旧的整体角色表，同上
///   models_dev_cache.json     # models.dev 目录缓存
///   tool_outputs/             # 工具长输出(内容寻址)
///   background_tasks/         # 运行中的后台任务(按属主进程记账,供孤儿清理)
///   .locks/                   # 跨进程锁文件:镜像上面各数据文件的相对路径,
///                            # 内容为空,只做互斥(见 [LockRegistry])
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
    : settingFile = settingFile ?? File(p.join(root.path, 'setting.yaml')),
      locks = LockRegistry(root) {
    idGenerator = const IdGenerator();
    sessionRepository = JsonlSessionRepository(
      sessionsDir: sessionsDir,
      locks: locks,
      idGenerator: idGenerator,
    );
    userSettings = UserSettingsStore(file: this.settingFile, locks: locks);
    providerStore = ProviderStore(directory: providersDir, locks: locks);
    providerRepository = YamlProviderRepository(
      store: providerStore,
      idGenerator: idGenerator,
    );
    // 模型存在所属 provider 的文件里：仓储与 provider 共用同一个 Store
    modelRepository = ProviderModelRepository(
      store: providerStore,
      idGenerator: idGenerator,
    );
    sentinelStore = SentinelStore(directory: sentinelsDir, locks: locks);
    sentinelRepositoryImpl = YamlSentinelRepository(
      store: sentinelStore,
      idGenerator: idGenerator,
    );
    sentinelRepository = sentinelRepositoryImpl;
  }

  final Directory root;

  /// 锁文件仓库:所有跨进程锁的落点都在 `root/.locks/` 下,见 [LockRegistry]。
  final LockRegistry locks;

  /// 用户配置文件;默认 `root/setting.yaml`,两个前端共用同一份。
  final File settingFile;

  /// 权限规则文件(GUI 与 TUI 共用,可手工编辑;见 `PermissionStore`)。
  ///
  /// 它由这里给出而不是让权限模块自己拼 `$HOME`:换了数据根(移动端、TUI 的
  /// `--data-dir`)之后仍然要写进同一个根,否则规则会落到真实主目录去。
  File get permissionsFile => File(p.join(root.path, 'permissions.json'));

  Directory get sessionsDir => Directory(p.join(root.path, 'sessions'));
  Directory get providersDir => Directory(p.join(root.path, 'providers'));
  Directory get sentinelsDir => Directory(p.join(root.path, 'sentinels'));

  /// 旧的整表模型文件;新布局下只作为迁移来源与留档(`.migrated`)。
  File get modelsFile => File(p.join(root.path, 'models.json'));

  /// 旧的整表角色文件;同上。
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
  late final ModelRepository modelRepository;
  late final SentinelRepository sentinelRepository;
  late final UserSettingsStore userSettings;
  late final ProviderStore providerStore;
  late final YamlProviderRepository providerRepository;
  late final SentinelStore sentinelStore;
  late final YamlSentinelRepository sentinelRepositoryImpl;

  /// 启动升级保留的模型身份映射，供 GUI 的旧 SharedPreferences 迁移。
  Map<String, String> legacyModelIds = {};

  Future<void> load() async {
    legacyModelIds = await StorageIdMigration(
      root: root,
      settingFile: settingFile,
      locks: locks,
    ).run();
    // 整数 id 已在上一步转换完毕,这里只把 setting.yaml 的 providers 段摊成
    // 独立文件(见 [ProviderFilesMigration]),顺序不可颠倒。
    await ProviderFilesMigration(
      settingFile: settingFile,
      providersDir: providersDir,
      locks: locks,
    ).run();
    // provider 已成为一个一个文件之后,模型才知道该并进哪个文件;两条迁移都
    // 依赖上一步的整数 id 转换结果。
    await ModelsIntoProvidersMigration(
      modelsFile: modelsFile,
      providerStore: providerStore,
      locks: locks,
    ).run();
    await SentinelFilesMigration(
      sentinelsFile: sentinelsFile,
      sentinelStore: sentinelStore,
      locks: locks,
    ).run();
    await providerRepository.load();
  }

  /// 清空全部业务数据(会话、模型、角色、provider),不动
  /// 目录缓存与工具输出。调用方随后应重新执行种子。
  ///
  /// provider 走仓储的逐个删除而不是删掉 `providers/` 整个目录:目录里还有
  /// 迁移标记 `.version`,删目录会把标记一起清掉,下次启动会重新尝试
  /// (已无 providers 段的)迁移。
  ///
  /// 同样不动 `.locks/`:另一实例可能正持着里面的锁,删掉会让互斥静默失效
  /// (见 [LockRegistry])。
  Future<void> reset() async {
    if (await sessionsDir.exists()) {
      await sessionsDir.delete(recursive: true);
    }
    for (final file in [metaFile]) {
      if (await file.exists()) await file.delete();
    }
    // 模型随 provider 文件消失,所以清 provider 就等于清模型
    await providerRepository.deleteAllProviders();
    for (final sentinel in await sentinelStore.list()) {
      await sentinelStore.delete(sentinel.id!);
    }
  }
}
