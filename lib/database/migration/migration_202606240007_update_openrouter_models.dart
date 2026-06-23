import 'package:athena/database/database.dart';
import 'package:athena/util/logger_util.dart';

/// 更新 OpenRouter 预设模型至最新版本（2026/06）。
///
/// 新增 10 个模型，删除全部 13 个旧预设模型。引用旧模型的 chat 自动迁移到
/// 同系列替代品（详见 _migrationMap）。
class Migration202606240007UpdateOpenRouterModels {
  static const name = 'migration_202606240007_update_openrouter_models';

  /// 旧 model_id → 新 model_id 的 chat 迁移映射
  static const _migrationMap = <String, String>{
    'anthropic/claude-sonnet-4': 'anthropic/claude-sonnet-4.6',
    'anthropic/claude-opus-4': 'anthropic/claude-opus-4.8',
    'anthropic/claude-sonnet-4.5': 'anthropic/claude-sonnet-4.6',
    'deepseek/deepseek-chat-v3-0324': 'deepseek/deepseek-v4-flash',
    'deepseek/deepseek-r1-0528': 'deepseek/deepseek-v4-flash',
    'google/gemini-2.5-flash': 'google/gemini-3.5-flash',
    'google/gemini-2.5-pro': 'google/gemini-3.1-pro-preview',
    'openai/gpt-4.1': 'openai/gpt-5.4-mini',
    'openai/gpt-5': 'openai/gpt-5.4-mini',
    'openai/o3': 'openai/gpt-5.5',
    'meta-llama/llama-4-maverick': 'openai/gpt-5.4-mini',
    'qwen/qwen3-235b-a22b': 'deepseek/deepseek-v4-flash',
    'x-ai/grok-4': 'openai/gpt-5.5',
  };

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      var rows = await laconic.select(
        "SELECT id FROM providers WHERE name = 'Open Router' AND is_preset = 1",
      );
      if (rows.isEmpty) {
        LoggerUtil.i(
          'Migration $name: Open Router provider not found, skipping',
        );
        await laconic.table('migrations').insert([{'name': name}]);
        return;
      }
      var providerId = rows.first.toMap()['id'] as int;
      var now = DateTime.now().millisecondsSinceEpoch;

      // ---- 插入全部新模型 ----
      await _insertModels(providerId, now);

      // ---- 迁移 chat + 删除旧模型 ----
      for (var entry in _migrationMap.entries) {
        var oldModelId = entry.key;
        var newModelId = entry.value;

        var oldRows = await laconic.select(
          'SELECT id FROM models WHERE model_id = ? AND provider_id = ?',
          [oldModelId, providerId],
        );
        if (oldRows.isEmpty) continue;
        var oldId = oldRows.first.toMap()['id'] as int;

        var newRows = await laconic.select(
          'SELECT id FROM models WHERE model_id = ? AND provider_id = ?',
          [newModelId, providerId],
        );
        if (newRows.isEmpty) {
          LoggerUtil.i(
            'Migration $name: target $newModelId not found, skipping $oldModelId',
          );
          continue;
        }
        var newId = newRows.first.toMap()['id'] as int;

        await laconic.statement(
          'UPDATE chats SET model_id = ? WHERE model_id = ?',
          [newId, oldId],
        );

        await laconic.table('models').where('id', oldId).delete();

        LoggerUtil.i(
          'Migration $name: $oldModelId → $newModelId',
        );
      }

      await laconic.table('migrations').insert([{'name': name}]);
      LoggerUtil.i('Migration $name: done');
    });
  }

  // ---------------------------------------------------------------------------
  // 新模型列表
  // ---------------------------------------------------------------------------

  Future<void> _insertModels(int providerId, int now) async {
    // Google
    await _insert(
      'Google: Gemini 3.5 Flash', 'google/gemini-3.5-flash', providerId,
      contextWindow: 1000000,
      inputPrice: r'$1.50/M input tokens',
      outputPrice: r'$9/M output tokens',
      releasedAt: 'Released May 19, 2026',
      reasoning: true, vision: true, now: now,
    );
    await _insert(
      'Google: Gemini 3.1 Pro Preview', 'google/gemini-3.1-pro-preview',
      providerId,
      contextWindow: 1000000,
      inputPrice: r'$2/M input tokens',
      outputPrice: r'$12/M output tokens',
      releasedAt: 'Released Feb 19, 2026',
      reasoning: true, vision: true, now: now,
    );

    // OpenAI
    await _insert(
      'OpenAI: GPT-5.5', 'openai/gpt-5.5', providerId,
      contextWindow: 1000000,
      inputPrice: r'$5/M input tokens',
      outputPrice: r'$30/M output tokens',
      releasedAt: 'Released Apr 25, 2026',
      reasoning: true, vision: true, now: now,
    );
    await _insert(
      'OpenAI: GPT-5.4 Mini', 'openai/gpt-5.4-mini', providerId,
      contextWindow: 400000,
      inputPrice: r'$0.75/M input tokens',
      outputPrice: r'$4.50/M output tokens',
      releasedAt: 'Released Mar 17, 2026',
      vision: true, now: now,
    );

    // Anthropic
    await _insert(
      'Anthropic: Claude Fable 5', 'anthropic/claude-fable-5', providerId,
      contextWindow: 1000000,
      inputPrice: r'$10/M input tokens',
      outputPrice: r'$50/M output tokens',
      releasedAt: 'Released Jun 9, 2026',
      reasoning: true, vision: true, now: now,
    );
    await _insert(
      'Anthropic: Claude Opus 4.8', 'anthropic/claude-opus-4.8', providerId,
      contextWindow: 1000000,
      inputPrice: r'$5/M input tokens',
      outputPrice: r'$25/M output tokens',
      releasedAt: 'Released May 28, 2026',
      reasoning: true, vision: true, now: now,
    );
    await _insert(
      'Anthropic: Claude Sonnet 4.6', 'anthropic/claude-sonnet-4.6',
      providerId,
      contextWindow: 1000000,
      inputPrice: r'$3/M input tokens',
      outputPrice: r'$15/M output tokens',
      releasedAt: 'Released Feb 17, 2026',
      reasoning: true, vision: true, now: now,
    );
    await _insert(
      'Anthropic: Claude Haiku 4.5', 'anthropic/claude-haiku-4.5', providerId,
      contextWindow: 200000,
      inputPrice: r'$1/M input tokens',
      outputPrice: r'$5/M output tokens',
      releasedAt: 'Released Oct 16, 2025',
      reasoning: true, vision: true, now: now,
    );

    // DeepSeek (via OpenRouter)
    await _insert(
      'DeepSeek: DeepSeek V4 Pro', 'deepseek/deepseek-v4-pro', providerId,
      contextWindow: 1000000,
      inputPrice: r'$0.435/M input tokens',
      outputPrice: r'$0.87/M output tokens',
      releasedAt: 'Released Apr 24, 2026',
      reasoning: true, now: now,
    );
    await _insert(
      'DeepSeek: DeepSeek V4 Flash', 'deepseek/deepseek-v4-flash', providerId,
      contextWindow: 1000000,
      inputPrice: r'$0.09/M input tokens',
      outputPrice: r'$0.18/M output tokens',
      releasedAt: 'Released Apr 24, 2026',
      reasoning: true, now: now,
    );
  }

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  Future<void> _insert(
    String name,
    String modelId,
    int providerId, {
    required int contextWindow,
    required String inputPrice,
    required String outputPrice,
    required String releasedAt,
    bool reasoning = false,
    bool vision = false,
    required int now,
  }) async {
    var laconic = Database.instance.laconic;

    var exists = await laconic
        .table('models')
        .where('model_id', modelId)
        .where('provider_id', providerId)
        .count();
    if (exists > 0) return;

    await laconic.table('models').insert([
      {
        'name': name,
        'model_id': modelId,
        'provider_id': providerId,
        'context_window': contextWindow,
        'input_price': inputPrice,
        'output_price': outputPrice,
        'released_at': releasedAt,
        'reasoning': reasoning ? 1 : 0,
        'vision': vision ? 1 : 0,
        'is_preset': 1,
        'created_at': now,
        'updated_at': now,
      },
    ]);
  }
}
