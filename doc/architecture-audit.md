# Athena 项目架构审计 — 待处理问题

> 2026-06-24 审计，已修复的问题见末尾。

---

## 🟡 问题四：SettingViewModel 职责过载

**文件**：`lib/view_model/setting_view_model.dart`（~360 行）

SettingViewModel 同时承担三个不相关的职责：

1. **SharedPreferences 设置管理**（窗口尺寸、模型 ID、Brave API Key 等）—— 合理
2. **ChatService 的 RetryConfig 更新**（通过 `updateMaxRetries`）—— 已改为通过 `LlmClient.updateRetryConfig()`
3. **数据库导入/导出 + chat model 引用修正**（`exportData`、`importData`、`reconcileChatModelReferences`）

特别是导入/导出功能涉及 Provider/Model/Sentinel 的批量落库 + 外键修正，更像是 `DataMigrationService` 或 `BackupService` 的职责。

**建议**：将 `exportData()` / `importData()` / `reconcileChatModelReferences()` / `resetData()` 提取到独立的 `DataMigrationService`。

---

## 🟡 问题五：Entity 放置不一致

所有 Entity 类都在 `lib/entity/` 下，除了一个：

```
lib/entity/
  chat_entity.dart
  message_entity.dart
  model_entity.dart
  provider_entity.dart
  sentinel_entity.dart
  summary_entity.dart
  translation_entity.dart
  trpg_game_entity.dart
  trpg_message_entity.dart

lib/repository/
  experience_repository.dart   ← ExperienceEntity 定义在这里 ❌
```

`ExperienceEntity` 定义在 `experience_repository.dart` 内部，而非 `lib/entity/experience_entity.dart`。

**建议**：将 `ExperienceEntity` 提取到 `lib/entity/experience_entity.dart`。

---

## 🟡 问题六：ChatSupportService 是"杂货铺"Service

**文件**：`lib/service/chat_support_service.dart`

职责范围：

- 重命名聊天（AI 流 + 手动）→ `renameChat` / `renameChatManually`
- 更新模型/哨兵/retention/温度 → `updateModel` / `updateSentinel` / `updateRetention` / `updateTemperature`
- Token 使用记录 → `recordUsage` / `incrementTokenTotal`
- 图片保存 → `saveImageFile`
- 消息折叠 → `updateExpanded`
- 解析 Provider → `getProviderForModel`

6 个不同的关注点塞进了一个类。大部分方法只是一个 `_touchChat(chat.copyWith(...))` 的薄封装。`saveImageFile` 做文件系统 IO，与其他纯 DB 操作方法性质不同。

**建议**：拆分成更聚焦的 Service（如 `ChatRenameService`、`ChatConfigService`、`TokenTrackingService`），或将 `saveImageFile` 移出到独立的 `ImageExportService`。

---

## 🟡 问题七：AgentService.run() 单方法承载过多流程步骤

**文件**：`lib/agent/agent_service.dart`

`run()` 是 200+ 行的 `async*` 生成器方法，包含：

- Skill/evolution prompt 注入
- ChatCompletion 请求构建
- 流消费 → text/reasoning/tool_call 事件分发
- Token usage 提取与上报
- Tool call 结果处理（权限检查 + 执行 + 摘要）
- 迭代管理

最内层有 5 级嵌套（`try → for → await for → for → try/catch`）。

**建议**：提取为私有方法：
- `_injectPrompts()` → prompt 注入逻辑
- `_buildCompletionRequest()` → 请求构建
- `_processSingleToolCall()` → 单个 tool call 的权限+执行+摘要流程

---

## 🟢 问题八：重复的"列表更新"模式

几乎所有 ViewModel 中都有这种模式：

```dart
var index = list.value.indexWhere((m) => m.id == entity.id);
if (index >= 0) {
    var copy = List<Entity>.from(list.value);
    copy[index] = entity;
    list.value = copy;
}
```

"find + copy + replace + reassign" 四步模式在项目中出现至少 8 次。

**建议**：提取为 `ListSignal` 的扩展方法：

```dart
extension ListSignalUpdate<T> on ListSignal<T> {
  void updateWhere(bool Function(T) test, T newValue) { ... }
}
```

---

## 🟢 问题九：默认 Sentinel 的创建路径重复

默认 "Athena" Sentinel 在两个地方被定义：

1. `SentinelViewModel.defaultSentinel` computed —— 返回内存中的默认值（无 DB 写入）
2. `SentinelViewModel.getSentinels()` —— 当 DB 为空时写入 "Athena" 到数据库

两处的 "Athena" 定义虽然碰巧一致，但作为重复常量，未来修改时容易遗漏一处。

**建议**：将默认 Sentinel 定义提取为一个 `static const` 工厂或常量，两处共用。

---

## ✅ 已修复

| 问题 | 修复方案 |
|------|---------|
| 问题一：ChatService 被 4 个 Service 绕过 | 创建 `LlmClient`，统一 Headers + 重试 + client 生命周期 |
| 问题二：ViewModel 架构分裂（Delegate vs 传统） | AgentStreamDelegate 改为 Stream 事件；删除 ChatListDelegate / ChatConfigDelegate；ChatViewModel 直接调 Service |
| 问题三：模型/Provider 解析逻辑重复 ×3 | 创建 `ModelResolver`，Summary/Translation/TRPG ViewModel 共用 |
| 问题四：SettingViewModel 职责过载 | 提取 `DataMigrationService`，负责导入/导出/数据迁移/DB 重置 |
