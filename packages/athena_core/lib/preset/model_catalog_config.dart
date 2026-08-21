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

  /// 模型 id 通配符排除列表,优先级高于 [include]。
  /// 空列表 = 使用共享默认排除 [defaultCatalogExcludes](追加在 exclude 前)
  final List<String> exclude;

  /// 仅同步支持推理(reasoning = true)的模型。
  /// 默认 true:预设 provider 面向"常用推理模型",非推理模型不再维护。
  final bool reasoningOnly;

  const CatalogProviderConfig({
    required this.sourceId,
    required this.localName,
    required this.localBaseUrl,
    this.include = const [],
    this.exclude = const [],
    this.reasoningOnly = true,
  });

  /// 生效的排除列表:显式 exclude + 共享默认(默认排除放在前面,
  /// 显式排除可覆盖——glob 匹配只做判断,不要求唯一,顺序无实际影响)
  List<String> get effectiveExcludes => [...defaultCatalogExcludes, ...exclude];
}

/// 共享默认排除:各 provider 通用的变体噪声模型。
///
/// 这些是不同模型形态(preview/image/audio/realtime/免费档/快照/蒸馏版等),
/// 家族去重管不到,必须在筛选时剔除。
const defaultCatalogExcludes = <String>[
  '*-preview*', '*image*', '*audio*', '*video*', '*realtime*', '*:free',
  '*-free*', '*snapshot*', '*distill*', '*customtools*', '*multi-agent*',
  // 别名模型(指向当前版本,如 gpt-5.2-chat-latest / gemini-flash-latest)
  '*-latest',
  // OpenAI codex 专用模型(仅 codex 产品端点可用,通用 API 调不通)
  '*codex*',
];

/// models.dev provider key → 本地预设 provider 配置
///
/// 名单面向"常用推理模型"([CatalogProviderConfig.reasoningOnly] 默认 true):
/// 主流可直连的推理服务商 + Open Router 聚合器。新增 provider 只需在此
/// 加一条配置,include 留空即全量导入其推理模型。
const modelCatalogConfig = <CatalogProviderConfig>[
  // ---- Deep Seek(4 个模型,全导入) ----
  CatalogProviderConfig(
    sourceId: 'deepseek',
    localName: 'Deep Seek',
    localBaseUrl: 'https://api.deepseek.com/v1',
  ),

  // ---- Open Router(聚合器,保留白名单:每模型家族只留最新版,
  // 家族去重由 ModelCatalogService.latestPerFamily 完成) ----
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
      // 特定变体(其余变体由 defaultCatalogExcludes 覆盖)
      'openai/gpt-chat-latest', 'openai/gpt-audio*', 'openai/gpt-oss*',
      'openai/gpt-*-pro', 'openai/o*-pro', // Pro 档需订阅,普通 key 不可用
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
      '*asr*', '*ocr*', '*character*', '*livetranslate*',
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

  // ---- OpenAI(官方直连;models.dev 无 api 字段,base_url 内置覆盖) ----
  CatalogProviderConfig(
    sourceId: 'openai',
    localName: 'OpenAI',
    localBaseUrl: 'https://api.openai.com/v1',
    exclude: [
      'gpt-*-pro', 'o*-pro', // Pro 档需订阅,普通 key 不可用
    ],
  ),

  // ---- Google(官方 OpenAI 兼容端点) ----
  CatalogProviderConfig(
    sourceId: 'google',
    localName: 'Google',
    localBaseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
  ),

  // ---- xAI(官方直连;models.dev 无 api 字段) ----
  CatalogProviderConfig(
    sourceId: 'xai',
    localName: 'xAI',
    localBaseUrl: 'https://api.x.ai/v1',
    exclude: [
      'grok-build*', // build 专用模型,通用 API 不可用
    ],
  ),

  // ---- 月之暗面 Kimi(国内版 base_url,models.dev 是国际版) ----
  CatalogProviderConfig(
    sourceId: 'moonshotai',
    localName: '月之暗面 Kimi',
    localBaseUrl: 'https://api.moonshot.cn/v1',
  ),

  // ---- 阶跃星辰 ----
  CatalogProviderConfig(
    sourceId: 'stepfun',
    localName: '阶跃星辰',
    localBaseUrl: 'https://api.stepfun.com/v1',
  ),
];
