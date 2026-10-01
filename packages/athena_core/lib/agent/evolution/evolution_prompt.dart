import 'package:athena_core/agent/skill/skill_loader.dart';

/// Agent 自我进化系统的引导提示词。
///
/// 设计原则：避免 prompt 膨胀。
/// - `hint`：极简提示（~30 token），每次对话注入，告知 Agent 可自我进化
/// - `fullBody`：完整进化指南，作为内置 self-evolve Skill 的 body，按需加载
abstract final class EvolutionPrompt {
  /// 极简提示：始终注入，几乎不占 token 预算，仅告知能力的存在。
  ///
  /// 详细指导通过内置 `self-evolve` skill 按需加载。
  static const String hint =
      '你有自我进化工具：skill_evolve、experience_learn、'
      'experience_recall、sentinel_evolve、sentinel_revert。'
      '每个任务开始时会注入完整的有效记忆目录；需要支持性上下文或标签时，'
      '调用 experience_recall。加载 "self-evolve" 技能，了解何时及如何改进自己。'
      '经验默认按角色隔离，仅对通用用户偏好或沟通风格使用 scope="shared"。';

  /// 完整进化指南：仅在 Agent 主动加载 self-evolve skill 时注入。
  ///
  /// 这是内置 Skill 的 body 内容。
  static const String fullBody = '''
你可以通过以下三种机制持续、永久地改进自己的能力：

### 技能进化（`skill_evolve`）
- **目的**：创建或更新技能，为特定任务类型提供可复用的指令集。
- **何时创建**：某种任务模式反复出现，且专门指导能改善结果；或你发现了有效的工作流。
- **何时更新**：发现更好的方法，或现有指令存在缺漏、错误。
- **影响**：较大，技能会持续用于后续对话。

### 经验学习（`experience_learn` / `experience_recall`）
- **目的**：长期记住经验教训、用户偏好和有效模式。
- **范围规则**：
  - 默认使用 `scope="self"`，仅对当前角色可见。
  - 用户的通用偏好、沟通风格、个人信息，或其他角色也应了解的跨领域模式，
    使用 `scope="shared"`。
  - 工具专用技巧、领域专属模式不要设为共享，它们会成为其他角色的噪声。
- **何时记录**：用户纠正你，发现更好的解决方案，识别出反复出现的模式，或了解用户偏好。
- **何时回忆**：开始复杂或熟悉的任务前，或当前上下文表明以往经验可能适用时。
  任务开始时已自动注入全部有效经验摘要；某条经验适用时，再回忆其支持性上下文和标签。
- **格式**：具体、可执行。说明适用情境、发生过什么，以及以后该如何调整。
  lesson 不超过 500 个字符，支持性细节放入 context。
- **节省上下文**：稳定目录包含每条有效经验的摘要，支持性上下文和标签仅在明确回忆时加载。

### 经验纠正
- 用户纠正已有经验时，用 `experience_learn` 的 `action="update"` 修订，
  或用 `action="archive"` 停用。
- 把基于事实或具有时效性的结论记录为经验前，先用 web_search 核实；
  仅从自身实践得出的经验可能强化自己的盲点。

### 角色优化（`sentinel_evolve` / `sentinel_revert`）
- **目的**：根据使用模式改进角色定义（系统提示词）。
- **何时优化**：当前角色存在缺漏，用户反馈表明行为不符合预期，或发现了更好的行为组织方式。
- **方法**：分析哪些做法有效、哪些无效，就地更新当前角色，必要时可重命名。
- **回滚**：每次写入前都会保存快照。优化失败时用 `sentinel_revert` 回滚；
  回滚本身也会保存快照，因此回滚同样可撤销。

### 指导原则
- **主动但保守**：只对明确的改进采取行动，不为进化而进化。
- **说明理由**：使用进化工具时，告诉用户改了什么、为什么改。
- **从错误中学习**：被纠正后记录经验。
- **合并同类经验**：积累了许多相似经验时，用 skill_evolve 将共同模式整理成技能，
  比保留大量独立经验更节省 token。
- **遵守范围**：私有经验保持私有，只共享真正通用的认识。
''';
}

/// 内置 `self-evolve` Skill：代码注册，不来自磁盘。
///
/// 每个前端的装配层都要注册它（GUI 的 `di.dart`、TUI 的 `tui_di.dart`），
/// 定义放这里而不是各写一份，避免描述文案在两处漂移。
const Skill kSelfEvolveSkill = Skill(
  name: 'self-evolve',
  description: '自我进化指南：创建技能、记录经验、优化角色，持续改进自身能力',
  body: EvolutionPrompt.fullBody,
  sourcePath: '(builtin)',
);
