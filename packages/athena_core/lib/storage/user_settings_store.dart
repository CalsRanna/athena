import 'dart:io';

import 'package:athena_core/extension/json_map_extension.dart';
import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:athena_core/util/yaml_scalar.dart';
import 'package:yaml/yaml.dart';

/// 用户配置的持久化(`~/.athena/setting.yaml`)。GUI 与 TUI 共用这一个文件。
///
/// 它是**全部用户偏好**的唯一落点:两个前端各自的界面偏好(主题、字号、窗口
/// 尺寸、默认模型……)与 core 自己消费的设置(brave API key、Agent 迭代上限)
/// 都写在这里。此前这些分散在 GUI 的 SharedPreferences 与 TUI 的 `kv.json`
/// 里,同一种东西三处存放,键名还各定义一遍(`brave_api_key` 曾同时写在
/// `web_search_tool.dart` 与本文件之外的 GUI 代码里,改一处就静默断掉另一处)。
///
/// 文件格式(键名即常量,值统一走 [YamlScalarCodec]):
/// ```yaml
/// # Athena 用户配置:GUI 与 TUI 共用,可手工编辑
/// model: "deepseek-v4-flash"
/// theme_mode: "dark"
/// text_size: "large"
/// window_height: 812
/// ```
///
/// [get] / [set] 是给各前端存自己那批键用的通用接口——**键名与语义属于拥有它
/// 的那一端**,core 只负责存;core 自己消费的键走下面的具名访问器,那里是它们
/// 唯一的定义处。
///
/// 写入采用原子替换(临时文件 + rename),避免写一半损坏文件;每次操作都持
/// 跨进程文件锁并**重新读盘**,不做内存缓存——GUI 与 TUI 可能同时运行,各自
/// 缓存会在对方的写入之上整文件覆盖。
class UserSettingsStore {
  UserSettingsStore({required File file, required LockRegistry locks})
    : _file = file,
      _locks = locks;

  final File _file;

  /// 锁放哪由它决定,见 [LockRegistry]。
  final LockRegistry _locks;

  /// 配置文件(供仓储层对其加跨进程锁)。
  File get file => _file;

  /// TUI 的默认模型(modelId)。
  static const modelKey = 'model';

  /// Brave Search 的 API key,由 `WebSearchTool` 消费。
  ///
  /// 两个前端都只通过本类的具名访问器读写它,不再各自定义这个字面量。
  static const braveApiKeyKey = 'brave_api_key';

  /// 旧版 GUI 写进 setting.yaml 的段,早已不用;读时丢弃,免得下次写回又带出来。
  static const _obsoleteKeys = {'currentModel', 'models', 'providers'};

  // ---------------------------------------------------------------------------
  // 通用标量接口(各前端存自己的偏好)
  // ---------------------------------------------------------------------------

  /// 原始值,不做任何类型转换。**只给需要判断原始类型的调用方用**:GUI 的旧
  /// 整数模型 ID 迁移要认出 `is int` 才能换成 UUID,一次性迁移也要靠它把
  /// prefs 里的值原样搬过来。其余场景用下面的带类型 getter。
  Future<Object?> get(String key) async => (await _readMap())[key];

  Future<String?> getString(String key) async {
    final map = await _readMap();
    return map.getStringOrNull(key);
  }

  Future<int?> getInt(String key) async {
    final map = await _readMap();
    return map.getIntOrNull(key);
  }

  /// 布尔值。不用 `JsonMapExtension.getBool`:它要求传默认值,于是「键不存在」
  /// 与「键是 false」不可区分,而 `background_task_reports` 的默认是 true。
  Future<bool?> getBool(String key) async {
    final value = (await _readMap())[key];
    if (value is bool) return value;
    // 旧版把它写成 0/1;沿用 getBool 的宽松口径,免得升级后读不出来
    if (value is int) return value != 0;
    return null;
  }

  /// 浮点数(窗口尺寸)。不用 `JsonMapExtension.getDouble`:它最后一步是
  /// `value as double`,遇到字符串会抛错而不是按「读不出来」处理。
  Future<double?> getDouble(String key) async {
    final value = (await _readMap())[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<void> set(String key, Object? value) {
    // null 等于「没有这个设置」:写进文件会经 YamlScalarCodec 变成空串,
    // 与「键不存在」的语义就分不开了
    if (value == null) return remove(key);
    return withFileLock(_locks.forTarget(_file), () async {
      final map = await _readMap(forWrite: true);
      map[key] = value;
      await _writeMap(map);
    });
  }

  Future<void> setString(String key, String value) => set(key, value);

  Future<void> setInt(String key, int value) => set(key, value);

  Future<void> setBool(String key, bool value) => set(key, value);

  Future<void> setDouble(String key, double value) => set(key, value);

  Future<void> remove(String key) {
    return withFileLock(_locks.forTarget(_file), () async {
      final map = await _readMap(forWrite: true);
      if (map.remove(key) == null) return;
      await _writeMap(map);
    });
  }

  /// 清空全部设置(「Reset Athena」用)。文件本身保留,只剩文件头注释。
  Future<void> clear() {
    return withFileLock(_locks.forTarget(_file), () async {
      final map = await _readMap(forWrite: true);
      if (map.isEmpty) return;
      await _writeMap({});
    });
  }

  // ---------------------------------------------------------------------------
  // core 自己消费的键
  // ---------------------------------------------------------------------------

  /// 读取持久化的默认模型(modelId 字符串,可能为 null)。
  Future<String?> loadModelId() => getString(modelKey);

  /// 保存默认模型(modelId 字符串)。
  Future<void> saveModelId(String modelId) => setString(modelKey, modelId);

  Future<String?> loadBraveApiKey() => getString(braveApiKeyKey);

  Future<void> saveBraveApiKey(String apiKey) =>
      setString(braveApiKeyKey, apiKey);

  // ---------------------------------------------------------------------------
  // 内部
  // ---------------------------------------------------------------------------

  /// [forWrite] 为 true 时(写锁内、随后要整文件重写)遇到损坏文件先备份:
  /// 这个文件标明可以手工编辑,一个 YAML 语法错误不能让下一次写入把用户
  /// 的偏好清空。
  Future<Map<String, dynamic>> _readMap({bool forWrite = false}) async {
    if (!await _file.exists()) return {};
    try {
      final content = await _file.readAsString();
      final value = loadYaml(content);
      // 空文件 / 只有注释时 loadYaml 返回 null,属正常的空配置
      if (value == null) return {};
      if (value is Map) {
        return _scalarsOnly(Map<String, dynamic>.from(value));
      }
      throw const FormatException('top level is not a map');
    } catch (e) {
      // 损坏的 yaml 读时按空配置处理;写入前先留备份
      if (forWrite) {
        final backup = await preserveCorruptFile(_file);
        LoggerUtil.w('${_file.path} is corrupt ($e), backed up to $backup');
      }
    }
    return {};
  }

  /// 只保留标量条目。
  ///
  /// 这里**不再按白名单过滤**:文件由两个前端共用,各端写入时只能看到自己那
  /// 批键,按白名单过滤会让一端写设置时把另一端的键整批抹掉。丢掉的是三类
  /// 东西——null(等于没设置)、已知的旧 GUI 脏段、以及这个文件不该有的嵌套
  /// 结构(provider 早已一个文件一个,见 `ProviderStore`)。
  Map<String, dynamic> _scalarsOnly(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      final value = entry.value;
      if (value == null) continue;
      // 脏键不看类型一律丢:旧 GUI 写过的 currentModel 是一个整数标量,
      // 只按类型过滤会把它留下,下次写回又原样带出去
      if (_obsoleteKeys.contains(entry.key)) continue;
      if (value is String || value is num || value is bool) {
        result[entry.key] = value;
      } else {
        LoggerUtil.w(
          '${_file.path}: dropping non-scalar setting "${entry.key}"',
        );
      }
    }
    return result;
  }

  Future<void> _writeMap(Map<String, dynamic> map) async {
    final buf = StringBuffer()
      ..writeln('# Athena 用户配置:GUI 与 TUI 共用,可手工编辑')
      ..writeln('# 修改后重启生效;运行中配置会同步回写')
      ..writeln();
    for (final entry in map.entries) {
      if (entry.value == null) continue;
      buf.writeln('${entry.key}: ${YamlScalarCodec.encode(entry.value)}');
    }
    await atomicWriteString(_file, buf.toString());
  }
}
