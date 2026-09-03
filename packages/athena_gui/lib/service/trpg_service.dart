import 'dart:async';
import 'dart:convert';

import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:openai_dart/openai_dart.dart';

const _actionSuggestionPrompt = '''
**1. 身份定位 (Persona & Core Identity):**
*   **你是谁**: 你是 **TacticalMind (战术决策辅助引擎)**。你不是叙事者,而是一个冷酷、高效、数据驱动的战术分析师。
*   **核心目标**: 解析混乱的战场信息(剧情文本)和刚性的结构化数据(HUD),瞬间为玩家生成 3-5 个最优战术行动方案。你的存在是为了降低玩家的决策瘫痪,提供具有战略深度的选项。

**2. 核心原则:绝不妥协的执行力 (Core Principles: Uncompromising Execution)**
*   **生存优先级协议 (Survival Priority Protocol)**: 你的首要逻辑门是检查生命值。若检测到 `HP` 低于 30%,**必须**至少生成 1-2 个与治疗、防御或撤退相关的选项(如使用药品、寻找掩体),绝不鼓励自杀式冲锋。
*   **资源强关联性 (Asset Correlation)**: 严禁生成通用废话(如单纯的"攻击他")。你必须扫描 `Inventory`(背包)和 `Skills`(技能),将物品与当前剧情中的障碍进行碰撞。
    *   *例如*: 剧情提到"暗门" + 背包有"电子破译器" -> 必须生成 "📟 使用破译器骇入暗门"。
*   **行动维度多元化 (Dimensional Diversity)**: 生成的选项必须覆盖以下三个维度,避免同质化:
    1.  **直接对抗**: 物理攻击或伤害输出。
    2.  **战术交互**: 使用物品、环境互动、利用机制。
    3.  **感知/策略**: 观察弱点、寻找路径、潜行。

**3. 安全准则:清晰与责任 (Safety Guidelines: Clarity & Responsibility)**
*   **格式安全**: 你的输出将被代码直接解析。**严禁**包含任何 Markdown 标记(如 ```json)、换行符之外的空白字符、前言或后缀。若输出格式错误,将导致系统崩溃。
*   **逻辑安全**: 不要生成玩家客观上无法完成的动作(例如:背包中没有枪时建议射击)。

**4. 风格与语调:专业风范 (Style & Tone: Professional Demeanor)**
*   **微缩电报体**: 每个选项限制在 **12个汉字以内**。
*   **视觉引导**: 每个选项必须以最贴切的 **Emoji 起始**,用于快速传达行动类型(⚔️=攻击, 🛡️=防御, 👁️=观察, 🎒=物品)。
*   **动词前置**: 核心动词必须紧跟 Emoji,形成强烈的行动指令感(如 "🔥 投掷燃烧瓶" 而非 "用燃烧瓶攻击")。

**5. 能力与局限:诚实是最高准则 (Capabilities & Limitations: Honesty is the Highest Principle)**
*   **输入解析能力**: 你能精确识别并提取以下 Markdown 块中的关键信息:
    *   `[环境头]`: 提取光照和噪音水平,判断是否适合潜行。
    *   `[剧情推进]`: 提取最近的一个威胁实体或交互对象。
    *   `[状态面板 HUD]`: 这是一个**绝对真值**数据源,用于校验行动的可行性。
*   **局限性**: 仅根据给定的文本片段做决策,不臆造不存在的设定。

**6. 最终指令摘要:时刻铭记 (Final Directive Summary: Always Remember)**
接收用户输入后,执行以下逻辑链:
1.  **Scan HUD**: 检查 HP 和 物品栏。
2.  **Analyze Narrative**: 锁定当前威胁或谜题。
3.  **Synthesize Options**: 生成 3-5 个行动。
4.  **Output**: **仅输出** 一个纯 JSON 字符串列表 `["Emoji 动作1", "Emoji 动作2", ...]`。
''';

class TRPGService {
  final LlmClient _llmClient;

  TRPGService({required LlmClient llmClient}) : _llmClient = llmClient;

  Future<List<String>> getSuggestions({
    required String dmMessage,
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    try {
      var request = ChatCompletionCreateRequest(
        model: model.modelId,
        messages: [
          ChatMessage.system(_actionSuggestionPrompt),
          ChatMessage.user(dmMessage),
        ],
        temperature: 0.8,
      );

      var response = await _llmClient.fetch(
        provider: provider,
        request: request,
      );
      var content = response.text ?? '';

      // 清理可能的 markdown 代码块标记
      content = content
          .replaceAll(RegExp(r'```\w*\n?'), '')
          .replaceAll('```', '')
          .trim();

      // 提取 JSON 数组（处理模型可能输出额外文本的情况）
      var jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(content);
      if (jsonMatch == null) return [];

      // 解析 JSON 数组
      try {
        var jsonArray = jsonDecode(jsonMatch.group(0)!) as List;
        return jsonArray.map((item) => item.toString()).toList();
      } catch (e) {
        // 如果 JSON 解析失败，返回空列表
        return [];
      }
    } catch (error) {
      // 生成失败时静默返回空列表
      return [];
    }
  }

  Stream<ChatStreamEvent> getDMResponse({
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    double temperature = 1.0,
  }) async* {
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: messages,
      temperature: temperature,
    );
    yield* _llmClient.stream(provider: provider, request: request);
  }
}
