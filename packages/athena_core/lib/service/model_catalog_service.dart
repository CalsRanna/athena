import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/preset/model_catalog_config.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;

/// 从 https://models.dev/api.json 同步预设 provider 的模型元数据。
///
/// 替代旧的手工硬编码 migration(seed_presets / update_*_models / add_*_provider):
/// 模型名称、上下文窗口、价格、发布日期、reasoning/vision 标志全部来自
/// models.dev 权威数据源,不再手工维护。
///
/// 行为:
/// - [syncIfNeeded] 在 TTL(默认 7 天)内直接跳过,避免每次启动拉取 3.2MB
/// - 拉取成功 → 写本地缓存 → 同步 DB(新模型插入、已有模型更新元数据、
///   下架模型删除,仅删除未被 chat 引用的 preset 模型)
/// - 拉取失败 → 降级用上次缓存数据同步;无缓存(首次失败)→ 跳过,下次启动重试
///
/// 家族去重:models.dev 每个 provider 收录同一模型家族的多个版本
/// (如 claude-sonnet-4.5/4.6/5、gemini-2.5-flash/3.6-flash)。
/// 同步时对每个模型家族(按 [familyKey] 分组)只保留 release_date 最新的
/// 一个,老版本自动从本地库清理(未被 chat 引用时)。尺寸规格
/// (8b/70b/235b 等)保留在家族键中,不同尺寸视为不同家族。
class ModelCatalogService {
  ModelCatalogService({
    required ModelRepository modelRepository,
    required ProviderRepository providerRepository,
    required ChatRepository chatRepository,
    http.Client? httpClient,
    String? cacheFilePath,
    Directory? cacheDir,
    Duration cacheTtl = const Duration(days: 7),
    Duration fetchTimeout = const Duration(seconds: 15),
  }) : _modelRepository = modelRepository,
       _providerRepository = providerRepository,
       _chatRepository = chatRepository,
       _httpClient = httpClient,
       _cacheFilePath = cacheFilePath,
       _cacheDir = cacheDir,
       _cacheTtl = cacheTtl,
       _fetchTimeout = fetchTimeout;

  static const _cacheFileName = 'models_dev_cache.json';
  static const _catalogUrl = 'https://models.dev/api.json';

  /// 发布时间下限:只同步 release_date >= 此值(ISO 字符串比较)的模型。
  /// release_date 缺失或格式不完整(如 '2025-04')的模型不满足条件,剔除。
  @visibleForTesting
  static const kMinReleaseDate = '2026-01-01';

  /// 推理模型开关:true 时仅同步 reasoning = true 的模型。
  @visibleForTesting
  static const kReasoningOnly = true;

  final ModelRepository _modelRepository;
  final ProviderRepository _providerRepository;
  final ChatRepository _chatRepository;
  final http.Client? _httpClient;
  final String? _cacheFilePath;
  final Directory? _cacheDir;
  final Duration _cacheTtl;
  final Duration _fetchTimeout;

  /// 同步模型目录并返回统计。TTL 内直接返回空结果(除非 [force]);
  /// 过期则拉取 → 缓存 → 同步,失败降级缓存。
  ///
  /// [force] 用于用户手动触发(设置页"同步"按钮):忽略 TTL 强制拉取。
  Future<CatalogSyncResult> syncIfNeeded({bool force = false}) async {
    try {
      final cachePath = await _resolveCachePath();
      final cached = await _readCache(cachePath);
      final needFetch = force ||
          cached == null ||
          !isCacheFresh(cached.fetchedAt, ttl: _cacheTtl);
      if (!needFetch) {
        LoggerUtil.d('Model catalog: cache fresh, skip sync');
        return const CatalogSyncResult();
      }

      final data = await _fetchCatalog();
      await _writeCache(cachePath, data, DateTime.now());
      final result = await applyCatalog(data);
      LoggerUtil.i('Model catalog: synced from models.dev');
      return result;
    } catch (e) {
      LoggerUtil.w('Model catalog sync failed: $e, falling back to cache');
      try {
        final cachePath = await _resolveCachePath();
        final cached = await _readCache(cachePath);
        if (cached != null) {
          final result = await applyCatalog(cached.data);
          LoggerUtil.i('Model catalog: synced from cached data');
          return result;
        }
        LoggerUtil.w('Model catalog: no cache available, skipped');
      } catch (e2) {
        LoggerUtil.w('Model catalog fallback sync failed: $e2');
      }
      return const CatalogSyncResult();
    }
  }

  /// 把 models.dev 目录数据同步到本地数据库(幂等,可重复执行),返回统计。
  ///
  /// 对每个 [modelCatalogConfig] 配置:
  /// 1. 按名字查找 preset provider,不存在则创建
  /// 2. 按 include/exclude 白名单筛选模型 → reasoning 过滤([reasoningOnly])
  ///    → 发布时间过滤([kMinReleaseDate]) → 家族去重(每家族只留
  ///    release_date 最新的一个),逐模型插入或更新
  /// 3. 清理下架模型:白名单外、reasoning 过滤淘汰、家族去重淘汰的老版本,
  ///    若未被 chat 引用则删除
  @visibleForTesting
  Future<CatalogSyncResult> applyCatalog(Map<String, dynamic> catalog) async {
    var createdProviders = 0;
    var createdModels = 0;
    var updatedModels = 0;
    var removedModels = 0;

    for (var config in modelCatalogConfig) {
      final providerJson = catalog[config.sourceId];
      if (providerJson is! Map<String, dynamic>) continue;
      final modelsJson = providerJson['models'];
      if (modelsJson is! Map<String, dynamic>) continue;

      final selected = latestPerFamily(
        filterByReleaseDate(
          filterReasoning(
            selectModels(
              modelsJson,
              include: config.include,
              exclude: config.effectiveExcludes,
            ),
            reasoningOnly: config.reasoningOnly,
          ),
        ),
      );
      if (selected.isEmpty) continue;

      // ---- provider:匹配已有,不存在则创建 ----
      var provider = await _providerRepository
          .getPresetProviderByName(config.localName);
      final providerId = provider?.id ??
          await _providerRepository.storeProvider(
            ProviderEntity(
              name: config.localName,
              baseUrl: config.localBaseUrl,
              apiKey: '',
              enabled: false,
              isPreset: true,
              createdAt: DateTime.now(),
            ),
          );
      if (provider == null) {
        createdProviders++;
        LoggerUtil.i(
          'Model catalog: created provider ${config.localName} (id=$providerId)',
        );
      }

      // ---- 模型:存在则更新元数据,不存在则插入 ----
      for (var entry in selected.entries) {
        final modelJson = entry.value;
        if (modelJson is! Map<String, dynamic>) continue;

        final existing = await _modelRepository
            .getModelByModelIdAndProviderId(entry.key, providerId);
        final mapped = mapModel(entry.key, modelJson, providerId);
        if (existing == null) {
          await _modelRepository.createModel(mapped);
          createdModels++;
        } else {
          await _modelRepository.updateModel(mapped.copyWith(id: existing.id));
          updatedModels++;
        }
      }

      // ---- 清理下架模型(保留被 chat 引用的) ----
      final keepIds = selected.keys.toSet();
      final all = await _modelRepository.getModelsByProviderId(providerId);
      for (var model in all) {
        if (!model.isPreset || keepIds.contains(model.modelId)) continue;
        final chatCount = await _chatRepository.getChatCountByModelId(model.id!);
        if (chatCount > 0) continue;
        await _modelRepository.deleteModel(model.id!);
        removedModels++;
        LoggerUtil.i(
          'Model catalog: removed ${config.localName}/${model.modelId}',
        );
      }
    }

    return CatalogSyncResult(
      createdProviders: createdProviders,
      createdModels: createdModels,
      updatedModels: updatedModels,
      removedModels: removedModels,
    );
  }

  // ---------------------------------------------------------------------------
  // 缓存与拉取
  // ---------------------------------------------------------------------------

  Future<String> _resolveCachePath() async {
    if (_cacheFilePath != null) return _cacheFilePath;
    final dir = _cacheDir ?? Directory.systemTemp;
    return '${dir.path}/$_cacheFileName';
  }

  Future<Map<String, dynamic>> _fetchCatalog() async {
    final client = _httpClient ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse(_catalogUrl))
          .timeout(_fetchTimeout);
      if (response.statusCode != 200) {
        throw HttpException('models.dev returned HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('models.dev response is not a JSON object');
      }
      return decoded;
    } finally {
      if (_httpClient == null) client.close();
    }
  }

  Future<_CachedCatalog?> _readCache(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) return null;
      final fetchedAt = raw['fetched_at'];
      final data = raw['data'];
      if (fetchedAt is! num || data is! Map<String, dynamic>) return null;
      return _CachedCatalog(
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(fetchedAt.toInt()),
        data: data,
      );
    } catch (e) {
      LoggerUtil.w('Model catalog: failed to read cache: $e');
      return null;
    }
  }

  Future<void> _writeCache(
    String path,
    Map<String, dynamic> data,
    DateTime fetchedAt,
  ) async {
    await File(path).writeAsString(
      jsonEncode({
        'fetched_at': fetchedAt.millisecondsSinceEpoch,
        'data': data,
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // 纯函数:字段映射与筛选(便于单测)
  // ---------------------------------------------------------------------------

  /// 缓存是否仍新鲜(未超过 TTL)。
  @visibleForTesting
  static bool isCacheFresh(
    DateTime fetchedAt, {
    Duration ttl = const Duration(days: 7),
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    return reference.difference(fetchedAt) < ttl;
  }

  /// 把价格格式化为 '$X/M input tokens',去除多余尾零:
  /// 2 → '$2/M input tokens',0.14 → '$0.14/M input tokens'。
  @visibleForTesting
  static String formatPrice(Object? value) {
    if (value is! num) return '';
    var s = value.toStringAsFixed(4);
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
    return '\$$s/M input tokens';
  }

  /// glob 通配符匹配(仅支持 `*`,可匹配任意字符)。
  @visibleForTesting
  static bool globMatch(String pattern, String value) {
    final rx = '^${pattern.split('*').map(RegExp.escape).join('.*')}\$';
    return RegExp(rx).hasMatch(value);
  }

  /// 按 include(空 = 全部)/exclude 白名单筛选模型,exclude 优先级更高。
  @visibleForTesting
  static Map<String, dynamic> selectModels(
    Map<String, dynamic> models, {
    List<String> include = const [],
    List<String> exclude = const [],
  }) {
    return {
      for (final entry in models.entries)
        if ((include.isEmpty || include.any((p) => globMatch(p, entry.key))) &&
            !exclude.any((p) => globMatch(p, entry.key)))
          entry.key: entry.value,
    };
  }

  /// 推理模型过滤:仅保留 `reasoning == true` 的模型。
  ///
  /// 必须在家族去重之前执行:reasoning 是"能力"维度,先按能力过滤再
  /// 按家族取最新,保证家族里留下的是最新的推理版。
  @visibleForTesting
  static Map<String, dynamic> filterReasoning(
    Map<String, dynamic> models, {
    bool reasoningOnly = kReasoningOnly,
  }) {
    if (!reasoningOnly) return models;
    return {
      for (final entry in models.entries)
        if (entry.value is Map<String, dynamic> &&
            entry.value['reasoning'] == true)
          entry.key: entry.value,
    };
  }

  /// 发布时间过滤:仅保留 release_date >= [minDate](ISO 字符串比较)的模型。
  ///
  /// 缺失 release_date 或格式不完整('2025-04' 等前缀较短)的模型
  /// 无法确认发布时间,一并剔除。同样须在家族去重之前执行。
  @visibleForTesting
  static Map<String, dynamic> filterByReleaseDate(
    Map<String, dynamic> models, {
    String minDate = kMinReleaseDate,
  }) {
    if (minDate.isEmpty) return models;
    return {
      for (final entry in models.entries)
        if (entry.value is Map<String, dynamic> &&
            entry.value['release_date'] is String &&
            (entry.value['release_date'] as String).compareTo(minDate) >= 0)
          entry.key: entry.value,
    };
  }

  /// 模型家族键:把 modelId 中的"版本信息"归一化,同家族的版本得到
  /// 相同键,不同家族/不同规格得到不同键。
  ///
  /// 规则(对 modelId 去掉 provider 前缀后的部分):
  /// - 代际数字与日期戳剥离:`qwen3-14b` → `qwen-14b`、`claude-sonnet-4.6`
  ///   → `claude-sonnet`、`deepseek-chat-v3-0324` → `deepseek-chat`、
  ///   `gpt-4o-2024-05-13` → `gpt-o`、`glm-4.5v` → `glm-v`
  /// - 尺寸规格保留(数字后跟 `b` 不剥):`qwen3-8b` → `qwen-8b` 与
  ///   `qwen3-235b-a22b` → `qwen-235b-a22b` 视为不同家族,各留最新
  /// - 状态后缀并入主族:`DeepSeek-V3.2-Exp` → `deepseek-v`(与 V3 同族,
  ///   由 release_date 决定留谁)
  /// - `_` 归一为 `-`,连字符折叠,小写输出
  @visibleForTesting
  static String familyKey(String modelId) {
    var s = modelId.split('/').last.replaceAll('_', '-');
    // 实验版后缀并入主族,让 release_date 决定去留
    s = s.replaceAll(RegExp(r'-exp$', caseSensitive: false), '');
    // 剥除代际/日期数字段(v?N[.N][-N...],v 大小写均可);
    // 数字后跟 b 的是尺寸规格不剥
    s = s.replaceAll(RegExp(r'[vV]?\d+(?:[.-]\d+)*(?!\d*b)'), '');
    // 归一化连字符
    s = s.replaceAll(RegExp(r'-{2,}'), '-').replaceAll(RegExp(r'^-|-$'), '');
    return s.toLowerCase();
  }

  /// 家族去重:对每个 [familyKey] 分组,组内只保留 release_date 最新的
  /// 一个模型。返回与原输入同构的 id → json 映射。
  ///
  /// 排序依据:release_date(ISO 日期,字典序即时间序)。无 release_date
  /// 的模型视为较旧;release_date 相同时保留先出现的(输入顺序稳定)。
  @visibleForTesting
  static Map<String, dynamic> latestPerFamily(
    Map<String, dynamic> models,
  ) {
    final latest = <String, (String, Map<String, dynamic>)>{};
    for (final entry in models.entries) {
      // 与 filterReasoning / filterByReleaseDate 一致:非 Map 值跳过
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      final key = familyKey(entry.key);
      final current = latest[key];
      if (current == null || _isNewerThan(value, current.$2)) {
        latest[key] = (entry.key, value);
      }
    }
    return {for (final entry in latest.values) entry.$1: entry.$2};
  }

  /// a 是否比 b 新(release_date 比较;缺失视为旧,相同保留先出现者)。
  static bool _isNewerThan(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final ra = a['release_date'];
    final rb = b['release_date'];
    if (ra is String && rb is String) {
      return ra.compareTo(rb) > 0;
    }
    // 仅一方有日期:有日期者更新(目录数据普遍带日期,缺失多为旧条目)
    return ra is String && rb is! String;
  }

  /// models.dev 模型 JSON → [ModelEntity](models 表字段映射)。
  ///
  /// 映射关系:limit.context → context_window;cost.input/output →
  /// input_price/output_price;release_date → released_at;reasoning →
  /// reasoning;attachment(附件能力) → vision。
  @visibleForTesting
  static ModelEntity mapModel(
    String modelId,
    Map<String, dynamic> json,
    int providerId, {
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final limit = json['limit'];
    final cost = json['cost'];
    final released = json['release_date'];

    final contextWindow = limit is Map<String, dynamic> && limit['context'] is num
        ? (limit['context'] as num).toInt()
        : 0;
    return ModelEntity(
      name: json['name'] is String ? json['name'] as String : modelId,
      modelId: modelId,
      providerId: providerId,
      contextWindow: contextWindow,
      inputPrice: formatPrice(cost is Map<String, dynamic> ? cost['input'] : null),
      outputPrice:
          formatPrice(cost is Map<String, dynamic> ? cost['output'] : null),
      releasedAt:
          released is String && released.isNotEmpty ? 'Released $released' : '',
      reasoning: json['reasoning'] == true,
      vision: json['attachment'] == true,
      isPreset: true,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }
}

class _CachedCatalog {
  final DateTime fetchedAt;
  final Map<String, dynamic> data;

  _CachedCatalog({required this.fetchedAt, required this.data});
}

/// 一次目录同步的统计结果,供 UI 展示摘要(如"新增 X provider、更新 Y 模型")。
class CatalogSyncResult {
  final int createdProviders;
  final int createdModels;
  final int updatedModels;
  final int removedModels;

  const CatalogSyncResult({
    this.createdProviders = 0,
    this.createdModels = 0,
    this.updatedModels = 0,
    this.removedModels = 0,
  });
}
