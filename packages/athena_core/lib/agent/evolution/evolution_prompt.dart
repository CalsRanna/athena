import 'package:athena_core/agent/skill/skill_loader.dart';

/// Agent 自我进化系统的引导提示词。
///
/// 设计原则：避免 prompt 膨胀。
/// - `hint`：极简提示（~30 token），每次对话注入，告知 Agent 可自我进化
/// - `fullBody`：完整进化指南，作为内置 self-evolve Skill 的 body，按需加载
class EvolutionPrompt {
  EvolutionPrompt._();

  /// 极简提示：始终注入，几乎不占 token 预算，仅告知能力的存在。
  ///
  /// 详细指导通过内置 `self-evolve` skill 按需加载。
  static const String hint =
      'You have self-evolution tools: skill_evolve, experience_learn, '
      'experience_recall, sentinel_evolve, sentinel_revert. '
      'Your complete active memory catalog is injected at the start of each '
      'task — call experience_recall when supporting context or tags matter. '
      'Load the "self-evolve" skill for guidance on when and how to improve yourself. '
      'Experiences are per-Sentinel by default; use scope="shared" only for '
      'universal user preferences or communication style.';

  /// 完整进化指南：仅在 Agent 主动加载 self-evolve skill 时注入。
  ///
  /// 这是内置 Skill 的 body 内容。
  static const String fullBody = '''
You can permanently improve your capabilities through three mechanisms:

### Skill Evolution (`skill_evolve`)
- **Purpose**: Create or update Skills — reusable instruction sets for specific task types
- **When to create**: A task pattern recurs and would benefit from specialized guidance; you discover a workflow that works well
- **When to update**: You find a better approach; existing instructions have gaps or errors
- **Impact**: High — Skills persist across all future conversations

### Experience Learning (`experience_learn` / `experience_recall`)
- **Purpose**: Build long-term memory of lessons, user preferences, and effective patterns
- **Scope rules**:
  - Default: `scope="self"` — only visible to your current Sentinel role
  - Use `scope="shared"` when the lesson describes the user's universal preferences,
    communication style, personal information, or cross-domain patterns that other
    Sentinel roles should also know
  - Do NOT mark tool-specific tricks or domain-specific patterns as shared —
    they are noise to other Sentinels
- **When to record**: User corrects you; you discover a better solution;
  you identify a recurring pattern; you learn user preferences
- **When to recall**: Before starting complex/familiar tasks;
  when context suggests past learnings apply
  (all active lesson summaries are auto-injected at task start — recall
  supporting context and tags when a lesson applies)
- **Format**: Be specific and actionable. Include context, what happened,
  what to do differently. Keep lesson within 500 characters and put supporting
  detail in context
- **Economy**: The stable catalog contains every active lesson summary;
  supporting context and tags load only on explicit recall

### Experience Correction
- When the user corrects an existing experience, use `experience_learn`
  with `action="update"` to revise it or `action="archive"` to retire it.
- Before recording fact-based or time-sensitive conclusions as experiences,
  verify them with web_search — experiences from your own practice alone risk
  reinforcing your own blind spots.

### Sentinel Optimization (`sentinel_evolve` / `sentinel_revert`)
- **Purpose**: Refine your role definition (system prompt) based on usage patterns
- **When to optimize**: Current role has gaps; user feedback indicates misalignment; you find better ways to structure your behavior
- **How**: Analyze what works/doesn't work, update the current sentinel in place (optionally rename it)
- **Rollback**: Every change is snapshotted before writing — a failed
  optimization can be rolled back with `sentinel_revert` (which itself
  is snapshotted, so reverts are reversible too)

### Guidelines
- **Be proactive but conservative**: Act on clear improvements, don't evolve for its own sake
- **Explain your reasoning**: When using evolution tools, tell the user what and why
- **Learn from mistakes**: If corrected, record the lesson
- **Consolidate**: If you accumulate many similar experiences, use skill_evolve to create a skill that encodes the pattern — skills are more token-efficient than many individual experiences
- **Scope discipline**: Keep private experiences private; only share truly universal insights
''';
}

/// 内置 `self-evolve` Skill：代码注册，不来自磁盘。
///
/// 每个前端的装配层都要注册它（GUI 的 `di.dart`、TUI 的 `tui_di.dart`），
/// 定义放这里而不是各写一份，避免描述文案在两处漂移。
const Skill kSelfEvolveSkill = Skill(
  name: 'self-evolve',
  description:
      'Guidance on self-evolution: creating skills, recording '
      'experiences, and optimizing sentinels to improve over time',
  body: EvolutionPrompt.fullBody,
  sourcePath: '(builtin)',
);
