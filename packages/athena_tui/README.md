# athena_tui

Athena 的终端客户端(TUI),基于 [nocterm](https://pub.dev/packages/nocterm)(Flutter-like 终端 UI 框架),复用 `athena_core` 的 Agent 引擎。

与 GUI 共享同一套核心:完整的 Agent 循环(推理 → 工具调用 → 结果 → 再推理)、16 个工具、三层权限模型、Skill 系统、经验与自我进化。数据与 GUI 共用同一套文件存储(根目录 `~/.athena/`:会话为 JSONL,模型与角色为 JSON,provider 配置与偏好为 setting.yaml),两端可同时运行,读写经跨进程文件锁串行化。

## 运行

```bash
cd packages/athena_tui
dart pub get
dart run bin/athena.dart
```

首次启动自动创建聊天并种子预设 provider 与默认角色。配置 API key:输入 `/providers` 选择 provider,再输入 key 回车即可(留空取消)。也可直接编辑 `~/.athena/setting.yaml` 中 `providers` 段的 `apiKey` 字段。

**模型目录来自 models.dev**:启动时从 https://models.dev/api.json 同步最新模型(名称、上下文窗口、价格、reasoning/vision 标志),缓存 7 天在 `~/.athena/models_dev_cache.json`(与 GUI 共用同一份);TTL 内秒过,过期或首次启动拉取约几秒。内置种子模型仅作离线兜底,同步后即被 models.dev 数据替换/清理。

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
| `/review [on\|off]` | 查看、开启或关闭 AI 自动审核，保存后下一轮生效 |
| `/quit` | 退出 |

权限审批在终端内联提示:`[y] 允许 [n] 拒绝 [a] 总是允许`(总是允许写入 `~/.athena/permissions.json`,与 GUI 共享规则)。

AI 自动审核默认开启，覆盖所有工具类型：原本需要审批的调用先由当前模型的独立请求判断授权。明确 deny 直接拦截，模型主动建议 ask、审核无法确定或失败时转人工；已有规则允许的调用不增加审核请求。自动批准仅限本次调用，不保存为持久授权。

## 架构

```
athena_tui ──→ athena_core(纯 Dart Agent 引擎) ──→ nocterm(终端渲染)
```

- 存储层已移至 `athena_core/lib/storage/`,GUI 与 TUI 共用同一套实现与同一根目录(`file_storage.dart`;锁见 `file_lock.dart` / `serial_lock.dart`);TUI 侧只保留桥接与视图,不再自带 repository 实现
- `lib/bridge/tui_agent_bridge.dart` — 包装 `AgentRunCoordinator`,注入 TUI 的权限回调(镜像 GUI 的 `AgentStreamDelegate`)
- `lib/view_model/chat_controller.dart` — signals 状态 + `RunEvent` 事件流消费(50ms 节流合并流式更新)
- `lib/ui/` — nocterm 组件树:状态栏 / 消息列表(思考折叠、工具卡片)/ 输入区 / 权限条 / 选择弹层

依赖方向严格单向 `athena_tui → athena_core`,不依赖 athena_gui(零 Flutter)。

## 测试

```bash
cd packages/athena_tui
dart analyze       # 零警告
```

存储层单测位于 `packages/athena_core/test/storage/`;TUI 包自身暂无测试套件。

开发热重载:`dart --enable-vm-service run bin/athena.dart`。

## 已知限制

- nocterm 0.8.0 的 ListView 在父级组件树动态变化时会触发元素复用断言,消息列表改用 `SingleChildScrollView + Column`
- 权限审批的"拒绝并记住"(`d`)暂未实现(GUI 也没有此语义)
