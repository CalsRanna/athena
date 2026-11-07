/// 经验系统的引导提示词。
///
/// 设计原则：避免 prompt 膨胀。这里只放一行极简提示（~30 token），每次对话
/// 注入，告知 Agent 能记录与检索经验；具体用法由工具 description 承载。
///
/// 这里**只有经验**：技能的创建与角色提示词的改写是用户的编辑权，不属于
/// Agent 的自主能力。技能仍可由用户手写并通过 `skill` 加载，角色仍可由用户
/// 在设置里编辑。
abstract final class ExperiencePrompt {
  /// 极简提示：始终注入，几乎不占 token 预算，仅告知能力的存在。
  static const String hint =
      '你有经验工具：experience_learn、experience_recall。'
      '每个任务开始时会注入尚未归档的经验参考；需要支持性上下文或标签时，'
      '调用 experience_recall。'
      '仅保存有证据且能跨任务复用的经验，临时状态和单次排错默认不记录。'
      '私有经验自动限定于会话选择的项目，通用偏好可跨项目使用。'
      '经验默认按角色隔离，仅对通用用户偏好或沟通风格使用 scope="shared"。';
}
