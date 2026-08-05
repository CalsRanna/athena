/// models.dev(https://models.dev/api.json)与本地预设 provider 的映射配置。
///
/// [ModelCatalogService] 依据此配置,把 models.dev 的模型目录同步到本地数据库:
/// 模型名称、上下文窗口、价格、发布日期、reasoning/vision 标志全部来自
/// models.dev 权威数据源,不再手工维护。
///
/// 注意:models.dev 的 `api` 字段多为国际版地址(如 alibaba 是 dashscope-intl、
/// minimax 是 api.minimax.io),不能直接用作本地 base_url,必须在此显式覆盖。
///
/// 不在本列表中的 provider(如火山方舟,models.dev 无对应)不受同步影响,
/// 其已有数据保持不动。新增预设 provider 只需在此加一条配置,不再写 migration。
class CatalogProviderConfig {
  /// models.dev 数据中的 provider key(api.json 的顶层键)
  final String sourceId;

  /// 本地 providers 表的 name(用于匹配已有 provider / 创建新 provider)
  final String localName;

  /// 本地 base_url(models.dev 的 api 不可直接用,见上方说明)
  final String localBaseUrl;

  /// 模型 id 通配符白名单(`*` 通配),空列表 = 导入全部模型
  final List<String> include;

  /// 模型 id 通配符排除列表,优先级高于 [include]
  final List<String> exclude;

  const CatalogProviderConfig({
    required this.sourceId,
    required this.localName,
    required this.localBaseUrl,
    this.include = const [],
    this.exclude = const [],
  });
}

/// models.dev provider key → 本地预设 provider 配置
const modelCatalogConfig = <CatalogProviderConfig>[
  // ---- Deep Seek(4 个模型,全导入) ----
  CatalogProviderConfig(
    sourceId: 'deepseek',
    localName: 'Deep Seek',
    localBaseUrl: 'https://api.deepseek.com/v1',
  ),

  // ---- Open Router(每模型家族只留最新版,家族去重由
  // ModelCatalogService.latestPerFamily 完成) ----
  CatalogProviderConfig(
    sourceId: 'openrouter',
    localName: 'Open Router',
    localBaseUrl: 'https://openrouter.ai/api/v1',
    include: [
      'anthropic/claude-*',
      'google/gemini-*',
      'openai/gpt-5*',
      'openai/o3*',
      'openai/o4*',
      'deepseek/*',
      'qwen/qwen3*',
      'x-ai/grok-*',
      'minimax/MiniMax-M*',
    ],
    exclude: [
      // 变体噪音:家族去重只管理"新旧版本",这些是不同模型形态
      // (preview/image/audio/codex 专用版/免费档/快照/别名),不会被去重
      '*-preview*', '*image*', '*customtools*', '*:free', '*multi-agent*',
      'openai/gpt-chat-latest', 'openai/gpt-audio*', 'openai/gpt-oss*',
      'x-ai/grok-build*',
      // qwen 日期快照与 next 实验代(独立家族,去重不覆盖)
      'qwen/qwen3-*-2507', 'qwen/qwen3-next-*',
      // deepseek 蒸馏版与特殊版本(独立家族)
      'deepseek/deepseek-r1-distill*', 'deepseek/deepseek-v3.1-terminus',
    ],
  ),

  // ---- 阿里云百炼(国内版 base_url,models.dev 是国际版) ----
  CatalogProviderConfig(
    sourceId: 'alibaba',
    localName: '阿里云百炼',
    localBaseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    include: [
      'qwen3*',
      'qwen-vl*',
      'qwen-max*',
      'qwen-plus*',
      'qwen-turbo*',
    ],
    exclude: [
      // 专用场景模型(语音/OCR/实时翻译等),不适合通用聊天
      '*realtime*', '*asr*', '*ocr*', '*character*', '*livetranslate*',
      '*-preview*', // 预览版(如 qwen3.6-max-preview)由正式版家族替代
    ],
  ),

  // ---- 硅基流动(国内版 base_url,models.dev 是国际版) ----
  CatalogProviderConfig(
    sourceId: 'siliconflow',
    localName: '硅基流动',
    localBaseUrl: 'https://api.siliconflow.cn/v1',
    include: [
      'deepseek-ai/*',
      'zai-org/GLM-5*',
      'Qwen/*',
    ],
    exclude: [
      'Qwen/Qwen2.5*', // 旧代 Qwen 已由 Qwen3+ 替代
      '*Realtime*',
      'deepseek-ai/DeepSeek-V3.1-Terminus', // 特殊开源版,家族去重不覆盖
    ],
  ),

  // ---- MiniMax(国内版 base_url,models.dev 是国际版) ----
  CatalogProviderConfig(
    sourceId: 'minimax',
    localName: 'MiniMax',
    localBaseUrl: 'https://api.minimaxi.com/v1',
  ),

  // ---- 智谱AI ----
  CatalogProviderConfig(
    sourceId: 'zhipuai',
    localName: '智谱AI',
    localBaseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    include: ['glm-*'],
  ),
];
