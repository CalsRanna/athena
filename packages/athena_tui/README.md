# athena_tui

Athena 的终端客户端(TUI),基于 [nocterm](https://pub.dev/packages/nocterm)(Flutter-like 终端 UI 框架),复用 `athena_core` 的 Agent 引擎。

与 GUI 共享同一套核心:完整的 Agent 循环(推理 → 工具调用 → 结果 → 再推理)、13 个工具、三层权限模型、Skill 系统、经验与自我进化。数据独立存储于 `~/.athena/tui/`(JSONL),与 GUI 的 SQLite 互不干扰。

## 运行

```bash
cd packages/athena_tui
dart pub get
dart run bin/athena.dart
```

首次启动自动创建聊天并种子预设 provider 与默认角色。配置 API key:输入 `/providers` 选择 provider,再输入 key 回车即可(留空取消)。也可直接编辑 `~/.athena/tui/providers.jsonl` 的 `api_key` 字段。

**模型目录来自 models.dev**:启动时从 https://models.dev/api.json 同步最新模型(名称、上下文窗口、价格、reasoning/vision 标志),缓存 7 天在 `~/.athena/tui/models_dev_cache.json`;TTL 内秒过,过期或首次启动拉取约几秒。内置种子模型仅作离线兜底,同步后即被 models.dev 数据替换/清理。

## 命令与快捷键

| 输入 | 作用 |
|------|------|
| `Enter` | 发送消息(输入框内) |
| `Esc` | 停止生成 / 关闭弹层 |
| `/new` | 新建聊天 |
| `/list` | 列出聊天 |
| `/switch` | 选择聊天(弹层) |
| `/delete` | 删除当前聊天 |
| `/models` `Ctrl+M` | 选择模型(弹层) |
| `/sentinels` `Ctrl+S` | 选择角色(弹层) |
| `/providers` | 配置 provider API key(弹层选择 → 输入 key) |
| `/json <文本>` | 以 JSON 模式运行 Agent |
| `/help` | 帮助 |
| `/quit` | 退出 |

权限审批在终端内联提示:`[y] 允许 [n] 拒绝 [a] 总是允许`(总是允许写入 `~/.athena/permissions.json`,与 GUI 共享规则)。

## 架构

```
athena_tui ──→ athena_core(纯 Dart Agent 引擎) ──→ nocterm(终端渲染)
```

- `lib/storage/` — 5 个 repository 的 JSONL 实现 + KeyValueStore 文件实现。单写者锁保证 `updateChat` 与 `recordUsage` 并发写同一行不丢数据;`updateChat` 显式保留 token 三列(与核心接口契约对齐)
- `lib/bridge/tui_agent_bridge.dart` — 包装 `AgentRunCoordinator`,注入 TUI 的权限回调(镜像 GUI 的 `AgentStreamDelegate`)
- `lib/view_model/chat_controller.dart` — signals 状态 + `RunEvent` 事件流消费(50ms 节流合并流式更新)
- `lib/ui/` — nocterm 组件树:状态栏 / 消息列表(思考折叠、工具卡片)/ 输入区 / 权限条 / 选择弹层

依赖方向严格单向 `athena_tui → athena_core`,不依赖 athena_gui(零 Flutter)。

## 测试

```bash
cd packages/athena_tui
dart test          # 存储层单测 + testNocterm 组件测试
dart analyze       # 零警告
```

开发热重载:`dart --enable-vm-service run bin/athena.dart`。

## 已知限制

- nocterm 0.8.0 的 ListView 在父级组件树动态变化时会触发元素复用断言,消息列表改用 `SingleChildScrollView + Column`
- 权限审批的"拒绝并记住"(`d`)暂未实现(GUI 也没有此语义)
