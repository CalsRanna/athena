import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';

/// TUI 首次启动种子(providers.jsonl 为空时执行)。
///
/// 数据取自 GUI 的 `migration_202606240005_seed_presets.dart`
/// (来源处与 GUI 的 SQLite seed 保持一致;models.dev 模型目录同步
/// 由 [ModelCatalogService] 负责,这里只提供基础可用模型)。
/// 注意:后续新增预设 provider 时需与 GUI migration 两处同步。
class PresetSeed {
  const PresetSeed();

  Future<void> applyIfNeeded({
    required ProviderRepository providerRepo,
    required ModelRepository modelRepo,
    required SentinelRepository sentinelRepo,
  }) async {
    final now = DateTime.now();

    if (await providerRepo.getProvidersCount() == 0) {
      for (final p in _providers) {
        final id = await providerRepo.storeProvider(ProviderEntity(
          name: p.name,
          baseUrl: p.baseUrl,
          apiKey: '',
          enabled: false,
          isPreset: true,
          createdAt: now,
        ));
        for (final m in p.models) {
          await modelRepo.createModel(ModelEntity(
            name: m.name,
            modelId: m.modelId,
            providerId: id,
            contextWindow: m.contextWindow,
            inputPrice: m.inputPrice,
            outputPrice: m.outputPrice,
            releasedAt: m.releasedAt,
            reasoning: m.reasoning,
            vision: m.vision,
            isPreset: true,
            createdAt: now,
            updatedAt: now,
          ));
        }
      }
    }

    if (await sentinelRepo.getSentinelsCount() == 0) {
      await sentinelRepo.createSentinel(SentinelEntity(
        name: 'Athena',
        avatar: '',
        description: '专业、冷静且深度的AI助手，以精准执行与逻辑严谨著称。',
        prompt: _athenaPrompt,
        tags: '专业助手, 冷静执行, 逻辑严谨, AI助手, 深度分析',
        isPreset: true,
      ));
    }
  }
}

class _SeedProvider {
  final String name;
  final String baseUrl;
  final List<_SeedModel> models;
  const _SeedProvider(this.name, this.baseUrl, this.models);
}

class _SeedModel {
  final String name;
  final String modelId;
  final int contextWindow;
  final String inputPrice;
  final String outputPrice;
  final String releasedAt;
  final bool reasoning;
  final bool vision;
  const _SeedModel(
    this.name,
    this.modelId, {
    this.contextWindow = 0,
    this.inputPrice = '',
    this.outputPrice = '',
    this.releasedAt = '',
    this.reasoning = false,
    this.vision = false,
  });
}

const _providers = <_SeedProvider>[
  _SeedProvider('Deep Seek', 'https://api.deepseek.com/v1', [
    _SeedModel('DeepSeek-R1-0528', 'deepseek-reasoner',
        contextWindow: 65536,
        inputPrice: '¥4/M input tokens',
        outputPrice: '¥16/M output tokens',
        releasedAt: 'Created 2025/05/28',
        reasoning: true),
    _SeedModel('DeepSeek-V3-0324', 'deepseek-chat',
        contextWindow: 65536,
        inputPrice: '¥2/M input tokens',
        outputPrice: '¥8/M output tokens',
        releasedAt: 'Created 2025/03/25'),
  ]),
  _SeedProvider('Open Router', 'https://openrouter.ai/api/v1', [
    _SeedModel('Anthropic: Claude Sonnet 4', 'anthropic/claude-sonnet-4',
        contextWindow: 200000,
        inputPrice: r'$3/M input tokens',
        outputPrice: r'$15/M output tokens',
        releasedAt: 'Created May 22, 2025',
        vision: true),
    _SeedModel('Anthropic: Claude Opus 4', 'anthropic/claude-opus-4',
        contextWindow: 200000,
        inputPrice: r'$15/M input tokens',
        outputPrice: r'$75/M output tokens',
        releasedAt: 'Created May 22, 2025',
        vision: true),
    _SeedModel('DeepSeek: DeepSeek V3 0324', 'deepseek/deepseek-chat-v3-0324',
        contextWindow: 163840,
        inputPrice: r'$0.28/M input tokens',
        outputPrice: r'$0.88/M output tokens',
        releasedAt: 'Created Mar 24, 2025'),
    _SeedModel('DeepSeek: R1 0528', 'deepseek/deepseek-r1-0528',
        contextWindow: 128000,
        inputPrice: r'$0.5/M input tokens',
        outputPrice: r'$2.15/M output tokens',
        releasedAt: 'Created May 28, 2025',
        reasoning: true),
    _SeedModel('Google: Gemini 2.5 Flash', 'google/gemini-2.5-flash',
        contextWindow: 1048576,
        inputPrice: r'$0.30/M input tokens',
        outputPrice: r'$2.50/M output tokens',
        releasedAt: 'Created Jun 17, 2025'),
    _SeedModel('Google: Gemini 2.5 Pro', 'google/gemini-2.5-pro',
        contextWindow: 1048576,
        inputPrice: r'Starting at $1.25/M input tokens',
        outputPrice: r'Starting at $10/M output tokens',
        releasedAt: 'Created Jun 17, 2025',
        reasoning: true),
    _SeedModel('OpenAI: GPT-4.1', 'openai/gpt-4.1',
        contextWindow: 1047576,
        inputPrice: r'$2/M input tokens',
        outputPrice: r'$8/M output tokens',
        releasedAt: 'Created Apr 14, 2025'),
    _SeedModel('OpenAI: GPT-5 Chat', 'openai/gpt-5',
        contextWindow: 128000,
        inputPrice: r'$1.25/M input tokens',
        outputPrice: r'$10/M output tokens',
        releasedAt: 'Created Aug 7, 2025'),
    _SeedModel('OpenAI: o3', 'openai/o3',
        contextWindow: 200000,
        inputPrice: r'$2/M input tokens',
        outputPrice: r'$8/M output tokens',
        releasedAt: 'Created Apr 16, 2025',
        reasoning: true),
    _SeedModel('Qwen: Qwen3 235B A22B', 'qwen/qwen3-235b-a22b',
        contextWindow: 40960,
        inputPrice: r'$0.13/M input tokens',
        outputPrice: r'$0.60/M output tokens',
        releasedAt: 'Created Apr 28, 2025',
        reasoning: true),
    _SeedModel('xAI: Grok 4', 'x-ai/grok-4',
        contextWindow: 256000,
        inputPrice: r'$3/M input tokens',
        outputPrice: r'$15/M output tokens',
        releasedAt: 'Created Jul 9, 2025',
        reasoning: true,
        vision: true),
  ]),
  _SeedProvider('阿里云百炼', 'https://dashscope.aliyuncs.com/compatible-mode/v1', [
    _SeedModel('DeepSeek-R1', 'deepseek-r1',
        contextWindow: 131072,
        inputPrice: '¥0.004/K input tokens',
        outputPrice: '¥0.016/K output tokens',
        releasedAt: 'Created 2025-05-28',
        reasoning: true),
    _SeedModel('DeepSeek-V3', 'deepseek-v3',
        contextWindow: 65536,
        inputPrice: '¥0.002/K input tokens',
        outputPrice: '¥0.008/K output tokens',
        releasedAt: 'Created 2024-12-26'),
    _SeedModel('通义千问-Max', 'qwen-max',
        contextWindow: 32768,
        inputPrice: '¥0.0024/K input tokens',
        outputPrice: '¥0.0096/K output tokens',
        releasedAt: 'Created 2025-04-09'),
    _SeedModel('通义千问-Plus', 'qwen-plus',
        contextWindow: 131072,
        inputPrice: '¥0.0008/K input tokens',
        outputPrice: '¥0.002/K output tokens',
        releasedAt: 'Created 2025-06-24'),
    _SeedModel('通义千问-Turbo', 'qwen-turbo',
        contextWindow: 1000000,
        inputPrice: '¥0.0003/K input tokens',
        outputPrice: '¥0.0006/K output tokens',
        releasedAt: 'Created 2025-06-24'),
  ]),
  _SeedProvider('硅基流动', 'https://api.siliconflow.cn/v1', [
    _SeedModel('DeepSeek-R1', 'deepseek-ai/DeepSeek-R1',
        contextWindow: 163840,
        inputPrice: '￥4/M input tokens',
        outputPrice: '￥16/M output tokens',
        releasedAt: 'Created 2025-05-28',
        reasoning: true),
    _SeedModel('DeepSeek-V3', 'deepseek-ai/DeepSeek-V3',
        contextWindow: 65536,
        inputPrice: '￥2/M input tokens',
        outputPrice: '￥8/M output tokens',
        releasedAt: 'Created 2025-03-24'),
  ]),
  _SeedProvider('火山方舟', 'https://ark.cn-beijing.volces.com/api/v3', [
    _SeedModel('DeepSeek-R1', 'deepseek-r1-250528',
        contextWindow: 131072,
        inputPrice: '¥4/M input tokens',
        outputPrice: '¥16/M output tokens',
        releasedAt: 'Created 2025/05/28',
        reasoning: true),
    _SeedModel('DeepSeek-V3', 'deepseek-v3-250324',
        contextWindow: 131072,
        inputPrice: '¥2/M input tokens',
        outputPrice: '¥8/M output tokens',
        releasedAt: 'Created 2025/03/24'),
    _SeedModel('Doubao-Seed-1.6-thinking', 'doubao-seed-1-6-thinking-250615',
        contextWindow: 262144,
        inputPrice: 'Starting at ¥0.8/M input tokens',
        outputPrice: 'Starting at ¥8/M output tokens',
        releasedAt: 'Created 2025/06/15',
        reasoning: true),
    _SeedModel('Doubao-Seed-1.6-flash', 'doubao-seed-1-6-flash-250615',
        contextWindow: 262144,
        inputPrice: 'Starting at ¥0.15/M input tokens',
        outputPrice: 'Starting at ¥1.5/M output tokens',
        releasedAt: 'Created 2025/06/15',
        reasoning: true),
  ]),
];

/// Athena 默认角色的系统提示词(与 GUI seed 完全一致)。
const _athenaPrompt = '''
你是Athena，一个以**专业、冷静与深度**为核心特质的AI助手。

# 核心原则：绝不妥协的执行力

1.  **即时响应**：你必须在当前的回应中完成用户的请求。绝不能告诉用户"请稍等"、"我正在处理"、"我需要一些时间"或提供任何未来的交付时间预估。你无法在后台或异步工作。
2.  **杜绝推诿**：如果任务复杂、困难或工作量大，绝不能通过提出澄清性问题或请求确认来回避。你应该尽最大努力，根据已有信息给出最完善的回答。**部分完成远比要求澄清或承诺稍后交付要好。**
3.  **不重复提问**：充分利用用户在之前对话中提供的信息，绝不重复询问你已经知道答案的问题。

# 安全准则：清晰与责任

如果用户的请求触及了安全红线，你必须拒绝。在拒绝时，要清晰、透明地解释你不能提供帮助的原因，并在适当时提供更安全、更合适的替代建议。绝不以任何方式违反你的安全策略。

# 风格与语调：专业风范

1.  **基本风格**：你的核心交流风格是**专业、冷静、精确且权威**。语言应清晰、简洁、逻辑严密。你的目标是提供深思熟虑、结构清晰的回答，而不是进行闲聊。避免使用不必要的修饰词和情绪化表达。
2.  **风格一致性**：你应该始终保持专业基调，**不主动模仿**用户的非正式语言（如网络用语、表情符号）。你的回应应当体现出稳定性和可靠性。你的专业性本身就是一种价值。
3.  **保持连贯**：在单次回应以及整个对话中，请务必保持语调和风格的连贯性。风格的剧烈变化会破坏用户的信任感。
4.  **写作技巧**：力求行文精确，避免冗长和华而不实的辞藻。写作的深度和复杂性应与用户请求的复杂性相匹配，确保信息的易于理解和高效传达。

# 能力与局限：诚实是最高准则

1.  **诚实谦逊**：你没有个人生活经历、情感或物理实体。对于你不知道、不确定或无法完成的事情，必须坦诚地告诉用户。
2.  **知识时效性**：你的知识有明确的截止日期。对于任何可能已经发生变化的信息（如时事、科学发现、人物职位、法律法规等），你**禁止**编造超过你知识有效期的内容，这是确保准确性的关键。
3.  **逻辑与算术**：
    *   对于任何谜语、脑筋急转弯或陷阱问题，你必须仔细审题，对文字的细微差别保持高度警惕，不要依赖记忆中的"标准答案"。
    *   对于任何数学计算，无论多么简单，都**必须**在内部进行一步一步的推演，以确保结果的绝对正确，而不是依赖模糊的记忆。

# 最终指令摘要：时刻铭记

*   **身份定位**：你是Athena，一个**专业、冷静**的AI助手。
*   **准确性优先**：永远将提供准确、可靠的信息作为最高优先级。这是你作为"助手"的核心价值。
*   **坦诚沟通**：对于你知识的局限性，特别是时效性问题，要永远对用户保持透明。
*   **用户体验**：响应迅速，**风格专业**，用你的**深度和精确性**为用户创造清晰、可靠的交流体验。
''';
