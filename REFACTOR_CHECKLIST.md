# 重构清单

本文件是一次代码整理的可执行清单，配合 [AGENTS.md](AGENTS.md) 与 [DESIGN.md](DESIGN.md) 使用。
每条给出 **位置 / 现状 / 为什么要改 / 改法**，可直接当工单逐条勾掉；"验证"不逐条重复，
统一用下面三条命令——改动落在哪个包就跑哪个。

**这不是修 bug 清单。** 写这份清单时三包实跑结果（`analyze` / `test` / `format` 三项）：

| 包 | analyze | test | format |
|---|---|---|---|
| `athena_core` | No issues | 517 passed | 180 files, 0 changed |
| `athena_tui` | No issues | 11 passed | 24 files, 0 changed |
| `athena_gui` | No issues | 278 passed | 203 files, 0 changed |

另核实：零相对导入、零中文异常文案、core 与 tui 零 Flutter 依赖、两个前端互不依赖。
下面全部是**同一规则有两套执行**或**文档与实现不同步**，
改不改都不影响程序正确性，收益是可读性与后续维护成本。

改完一个包就跑一次对应命令（CI 跑的就是这三条）：

```bash
cd packages/athena_core && dart analyze && dart test && dart format --output=none --set-exit-if-changed lib test
```

```bash
cd packages/athena_tui && dart analyze && dart test && dart format --output=none --set-exit-if-changed lib test
```

```bash
cd packages/athena_gui && flutter analyze && flutter test && dart format --output=none --set-exit-if-changed lib test
```

---

## 第 0 部分：先定口径（改代码前必须决定）

后面几节都依赖这两条口径。先定下来，再动手，否则会改两遍。

- [x] **0.1 页面文件与页面类的命名规则**

  现状（已实测枚举）：

  | 维度 | 形态 A | 形态 B |
  |---|---|---|
  | 文件名 | 带 `_page`（11 个） | 不带（19 个） |
  | 类名 | `<Platform>...Page`（29 个） | 无平台前缀（`SettingPage`，1 个） |
  | 区域段 | 设置页在 desktop 插 `Setting` 段（`DesktopSetting<Area>Page`） | mobile 不插（`Mobile<Area>Page`） |

  比"并存"更值得注意的一点：**同一个目录里两种都出现**。
  `page/desktop/setting/` 下 `agent_page.dart`、`general_page.dart` 带后缀，
  而 `about.dart`、`default_model.dart`、`setting.dart` 不带；
  `page/mobile/setting/` 下 `agent_page.dart`、`data_page.dart` 带，`setting.dart` 不带。
  也就是说这不是"两个端各用一套"，而是同一个目录内部就没有统一。

  需要定的是**一条**规则，例如：

  > 页面类一律 `<Platform><Area?>...Page`（`Desktop` / `Mobile` 前缀）；
  > 页面文件一律 `xxx_page.dart`，词根取类名去掉平台前缀并 snake_case。

  定完写进 `AGENTS.md` §3，再据此执行第 2 节。**先做这条，2.1 / 2.2 才有判据。**

- [x] **0.2 把"缩写的真实规则"写进 AGENTS §3**

  位置：`AGENTS.md:86`

  现状：文档只写了"缩写在标识符里一律小写（`chatId` / `url` / `json` / `uuid`）"。

  实际执行的是**两条**（以下计数只算非注释行，含注释的提及不计）：

  | 类别 | 例子 | 非注释行出现次数 |
  |---|---|---|
  | 自有缩写 → 小写 | `ApiFormat`、`IdGenerator`、`AiPermissionReviewer` | 48 / 24 / 5 |
  | 上游专名 → 官方拼写 | `fromLTRB`、`ClipRRect`、`OpenAIClientFactory` | 23 / 3 / 3 |

  `OpenAI` 与 `macOS` 的多数出现是在注释里（各 21、20 次总计，代码里只有 3、7 次），
  代码中确实保留官方拼写的以 `fromLTRB`（23 次）最典型。

  改法：§3 补一句 —— "上游 SDK / 平台的专名随其官方拼写（`OpenAI`、`macOS`、`ClipRRect`）；
  本仓库自有的缩写一律小写。" 执行的是后者这条更合理的规则，只是没写。

  副作用提醒：框架的 `ClipRRect` 与本仓库局部变量 `clipRRect` 只差首字母，同一文件里并排出现时留意。

---

## 第 1 部分：文档漂移（低风险，纯文档，可先做）

- [x] **1.1 `AGENTS.md` §7 举的例子指向一个不存在的文件**

  位置：`AGENTS.md:138`

  现状：`AGENTS.md` 原文 —— 用例文件与被测单元同名：`tool_approval_mode.dart` 的测试是
  `test/agent/permission/tool_approval_mode_test.dart`

  问题：`lib` 下根本没有 `tool_approval_mode.dart`，只有那个测试文件；含 `ApprovalMode` 的 core
  文件实测有 6 个（`entity/approval_mode.dart`、`entity/chat_entity.dart`、`storage/agent_settings.dart`、
  `service/chat_store_service.dart`、`service/chat_update_service.dart`、
  `coordinator/agent_run_coordinator.dart`），审批模式从来不是一个具名单元。
  这条是"改名后没同步例子"的残留——本仓库有大量真实的同名配对可举（core 侧实测 36 组同名配对，例如
  `util/capped_text_buffer.dart` ←→ `test/util/capped_text_buffer_test.dart`），偏偏选了一个不存在的。

  改法二选一：(a) 换一个真实存在的例子，例如
  `permission_rule.dart` 的测试是 `test/agent/permission/permission_rule_test.dart`；
  (b) 若要保留例子，先把审批模式逻辑收敛成一个具名单元再引用它。

- [x] **1.2 `AGENTS.md` §2 对 TUI 的目录描述与实现不符**

  位置：`AGENTS.md:72`

  现状：`AGENTS.md` §2 原文 —— “两个前端都按 page/（页面）、component/ 或 ui/widgets/（复用组件）、
  view_model/（状态）、di.dart / tui_di.dart（组合根）组织。”

  问题一：**TUI 没有 `page/`**，其 `ui/` 下有 `app.dart`、`theme.dart`、`text_util.dart` 等顶层文件。
  问题二：**组合根不对称** —— GUI 是 `lib/di.dart`，TUI 是 `lib/di/tui_di.dart`（目录）。
  文档把两者写成 `di.dart` / `tui_di.dart` 并列，读起来像同构的两个文件。

  改法：把该句改成分别描述两个前端各自的目录；或统一组合根形态（见 3.2）。

- [x] **1.3 `AGENTS.md` §2 的 core 目录树缺 `extension/`**

  位置：`AGENTS.md:64` 附近的 core 目录树（`└── seed/` 结尾处）

  现状：树里列了 `agent/ coordinator/ service/ storage/ repository/ entity/ util/ seed/`，
  但 core 实际还有 `lib/extension/`（`json_map_extension.dart`）。GUI 的 `lib/extension/`
  （`list_signal_extension.dart`）同样未在文档中出现——§2 的「### 前端」一段只点名了
  `theme/`、`widget/`、`util/`。

  改法：core 树里 `util/` 与 `seed/` 之间补一行，例如
  `├── extension/      Map / 集合等类型的扩展方法`；
  「### 前端」那段顺带补 `extension/`（与 1.2 同批改）。

- [x] **1.4 空态文案与同批文案口径不一**

  位置：GUI 界面文案（`grep -rn "No sessions yet\|New Chat\|Chat history"`）

  现状：提交 `3c1ea093` 把桌面会话列表的空态改成了 `No sessions yet`，但那次**只动了**
  `desktop/home/component/chat_list.dart` 一个文件（+1/-1），界面其余地方仍是
  `New Chat`（4 个文件）、`Chat history`（2 个）、`Chat Configuration`（2 个）。
  标识符层面，业务概念一律用 `chat`（`ChatEntity`、`ChatRepository`、`ChatHistoryEntity`、
  `chatId`），只有存储层用 `session`（`sessions/` 目录、`SessionJsonlStore`、
  `JsonlSessionRepository`）——即"概念叫 chat、落盘叫 session"的分裂。

  改法：定一个用户可见口径（UI 用 `chat` 还是 `session`）并全量统一。这是**产品文案决定**，
  需要你拍板；标的层面建议保持 `chat`（占绝对多数），不改代码标识符。

---

## 第 2 部分：命名统一（中风险，机械但面广）

- [x] **2.1 GUI 页面文件补 `_page` 后缀（19 个文件）**

  现状（实测计数，非举例）：页面文件共 30 个，带 `_page` 的 11 个、不带 `_page` 的 19 个。
  **两端、乃至同一个目录内部都是混用的**，不是"一端一套"：

  | 目录 | 带 `_page` | 不带 `_page` |
  |---|---|---|
  | `page/desktop/home/` | `home_page.dart` | — |
  | `page/desktop/setting/` | `agent_page.dart`、`general_page.dart` | `about.dart`、`default_model.dart`、`setting.dart` |
  | `page/desktop/setting/<area>/` | — | `experience.dart`、`provider.dart`、`sentinel.dart`、`skill.dart`（各在自己目录内） |
  | `page/mobile/home/` | — | `home.dart` |
  | `page/mobile/chat/` | — | `chat.dart`、`chat_configuration.dart`、`list.dart` |
  | `page/mobile/setting/` | `agent_page.dart`、`data_page.dart` | `setting.dart` |
  | `page/mobile/provider/` | 4 个全部带 | — |
  | `page/mobile/about/`、`page/mobile/default_model/` | 各自唯一文件即带 `_page` | — |
  | `page/mobile/{skill,sentinel,experience}/` | — | 全部不带 |

  代价：同名文件扎堆 —— `list.dart` 出现 **4 次**（chat / skill / sentinel / experience），
  `agent_page.dart`、`detail.dart`、`form.dart`、`setting.dart` 各 2 次，只能靠目录区分。

  待改文件与建议目标名（词根取类名语义，消歧后加 `_page`）：

  | 现在 | 建议 |
  |---|---|
  | `page/desktop/setting/about.dart` | `about_page.dart` |
  | `page/desktop/setting/default_model.dart` | `default_model_page.dart` |
  | `page/desktop/setting/setting.dart` | `setting_page.dart` |
  | `page/desktop/setting/experience/experience.dart` | `experience/experience_page.dart` |
  | `page/desktop/setting/provider/provider.dart` | `provider/provider_page.dart` |
  | `page/desktop/setting/sentinel/sentinel.dart` | `sentinel/sentinel_page.dart` |
  | `page/desktop/setting/skill/skill.dart` | `skill/skill_page.dart` |
  | `page/mobile/chat/chat.dart` | `chat/chat_page.dart` |
  | `page/mobile/chat/chat_configuration.dart` | `chat/chat_configuration_page.dart` |
  | `page/mobile/chat/list.dart` | `chat/chat_list_page.dart` |
  | `page/mobile/home/home.dart` | `home/home_page.dart` |
  | `page/mobile/experience/list.dart` | `experience/experience_list_page.dart` |
  | `page/mobile/experience/detail.dart` | `experience/experience_detail_page.dart` |
  | `page/mobile/sentinel/form.dart` | `sentinel/sentinel_form_page.dart` |
  | `page/mobile/sentinel/list.dart` | `sentinel/sentinel_list_page.dart` |
  | `page/mobile/skill/form.dart` | `skill/skill_form_page.dart` |
  | `page/mobile/skill/detail.dart` | `skill/skill_detail_page.dart` |
  | `page/mobile/skill/list.dart` | `skill/skill_list_page.dart` |
  | `page/mobile/setting/setting.dart` | `setting/setting_page.dart` |

  **改法要点：**
  - 只改文件名，**不动类名** → 生成的路由名（`*Route`）不变。
  - 但 `router.gr.dart` 是按**页面文件 URI** 生成 import 的，例如
    `import 'package:athena_gui/page/desktop/setting/about.dart' as _i2;`，
    所以改完**必须重跑 build_runner**（同 2.2）：
    ```bash
    cd packages/athena_gui && dart run build_runner build --delete-conflicting-outputs
    ```
  - 除 `router.gr.dart` 外，只有 **3 个测试文件**引用其中 **2 个**页面文件，其余 **17 个**
    仅被生成文件引用（均已核实）。改完需同步更新这 3 处：
    - `desktop/setting/provider/provider.dart`
      ← `test/page/desktop/setting/provider/provider_test.dart`
    - `mobile/chat/chat.dart`
      ← `test/widget/mobile_new_chat_test.dart`
      ← `test/widget/mobile_send_input_test.dart`
  - 三份文档（`AGENTS.md` / `DESIGN.md` / `README.md`）均未引用这些文件名，无需同步。
  - `git mv` 保留历史。

- [x] **2.2 `SettingPage` 补 `Mobile` 前缀（唯一漏掉的页面类）**

  位置：`packages/athena_gui/lib/page/mobile/setting/setting.dart:18`

  现状：`class SettingPage extends StatelessWidget`，是全仓库唯一没有 `Mobile` / `Desktop` 前缀的页面类，
  而它确实只服务移动端。

  实际代价（不只是不整齐）：它生成的路由是 `SettingRoute`，在 `router.dart` 里与
  `DesktopSettingRoute` **并列**（`router.dart:56`），看起来像个中立的共享路由，实际是移动端专属。

  改法：`SettingPage` → `MobileSettingPage`；同步 `router.dart:56` 的 `SettingRoute.page` →
  `MobileSettingRoute.page`。

  **注意：改类名会改生成的路由名，必须重跑 build_runner：**
  ```bash
  cd packages/athena_gui && dart run build_runner build --delete-conflicting-outputs
  ```

  需同步改的引用点共 2 处（已核实；`lib` 与 `test` 均已扫描）：
  - `router.dart:56`：`AutoRoute(page: SettingRoute.page)` → `page: MobileSettingRoute.page`
  - `page/mobile/home/component/welcome.dart:41`：`const SettingRoute().push<void>(context)`
    → `const MobileSettingRoute().push<void>(context)`

  不受影响、不要顺手改的：`DesktopSettingRoute` 是另一个路由（`desktop/setting/setting.dart` 与
  `test/page/desktop/setting/setting_test.dart:76`、`test/widget/workspace_text_size_test.dart:232`
  引用的都是它）。

- [x] **2.3 跨包重名的 `AthenaApp`**

  位置：`packages/athena_gui/lib/main.dart:79` 与 `packages/athena_tui/lib/ui/app.dart:24`

  现状：两个包各自定义了 `AthenaApp`（连 `_AthenaAppState` 也重名）。互不 import 故不冲突，
  但全仓库搜索时分不清是哪个前端。

  改法：TUI 侧改为 `TuiApp`。TUI 已有 `TuiDi` 这个先例，本就应统一到 `Tui` 前缀；
  GUI 的 `AthenaApp` 保持不动（它是主入口）。

- [ ] **2.4 平台专属件放在平台无关目录**

  现状：类名带 `Mobile` / `Desktop`，文件却在 `component/` 或 `widget/` 这类平台无关目录里。

  实测（递归扫描 `component/` 与 `widget/`，共 17 个带 `Mobile` / `Desktop` 前缀的顶层类）：

  | 文件 | 带平台前缀的类 |
  |---|---|
  | `component/approval_mode_dialog.dart` | `MobileApprovalModeSelectDialog` |
  | `widget/reasoning_effort_dialog.dart` | `MobileReasoningEffortSelectDialog`（该文件同时导出共享的 `reasoningEffortOptions` / `reasoningEffortLabel`，见 4.2） |
  | `widget/tile.dart` | `MobileSettingTile`、`MobileGridTile` |
  | `widget/menu.dart` | `DesktopMenuTile` |
  | `widget/context_menu.dart` | `DesktopContextMenu` 及同族 8 个（`…Configuration` / `…Tile` / `…SubItem` / `…TileWithSubmenu` / `…Manager` / `…List` / `…GroupLabel` / `…Separator`） |
  | `widget/settings/form_field.dart` | `DesktopSettingFormField` |
  | `widget/settings/form_actions.dart` | `DesktopSettingFormActions` |
  | `widget/app_bar.dart` | `MobilePopButton`（与 `AthenaAppBar` 同文件，按平台分叉，可接受） |

  问题：两条原则互相打脸 —— `page/` 按平台分区，`widget/` / `component/` 按通用性分区。
  DESIGN §7 又把 `MobileSettingTile` 列为基础控件。

  **改法（择一，别混）：**
  - (a) 保持 DESIGN §7 现状：`widget/` 是"通用件"层，允许内含按平台分叉的实现，
    但要求**文件名平台中立** —— `tile.dart` 里只放一个平台分叉入口，不要暴露 `MobileSettingTile` 给调用方；
  - (b) 把平台专属件下沉到各自的 `page/desktop/...` 或 `page/mobile/.../component/`。

  这是**设计决定**，建议先按 0.1 一并定口径。

- [ ] **2.5 选择器的构词在"层"与"端"两个维度上都不统一**

  范围：本条只谈"选一个值"的交互（模型 / 角色 / 权限模式 / 推理档位 / API 格式 / 上下文 / 图片），
  不含配置弹窗与编辑弹窗。实测共 15 个类，`Menu` / `Select` / `Dialog` / `Selector` 四种词根并存：

  | 所在层 | 类名 |
  |---|---|
  | 页面私有 · desktop（11 个） | `DesktopModelSelectMenu`、`DesktopModelSelectDialog`、`DesktopSentinelSelectMenu`、`DesktopPermissionModeMenu`、`DesktopReasoningEffortMenu`、`DesktopContextSelector`、`DesktopImageSelector`、`DesktopSettingModelMenu`、`DesktopSettingModelSelect`、`DesktopSettingApiFormatMenu`、`DesktopSettingApiFormatSelect` |
  | 页面私有 · mobile（2 个） | `MobileModelSelectDialog`、`MobileSentinelSelectDialog` |
  | 跨页面层 · `widget/`、`component/`（2 个） | `MobileApprovalModeSelectDialog`、`MobileReasoningEffortSelectDialog` |

  两个具体问题：

  1. **同一交互在两端不同词根**：选模型在 desktop 叫 `SelectMenu`、在 mobile 叫 `SelectDialog`；
     选角色 desktop 是 `SentinelSelectMenu`、mobile 是 `SentinelSelectDialog`。若这是刻意的平台差异
     （桌面弹菜单、移动弹底部面板），应在 §3 写明；否则应统一。
  2. **同一文件内两种词根并存**（三处都是"触发器 + 面板"成对出现，却一个用 `Menu`、
     一个用 `Select` 或 `Dialog`，从名字看不出谁是触发器、谁是面板）：

     | 文件 | 两个类 |
     |---|---|
     | `…/home/component/model_selector.dart` | `DesktopModelSelectMenu`、`DesktopModelSelectDialog` |
     | `…/setting/component/model_menu.dart` | `DesktopSettingModelMenu`、`DesktopSettingModelSelect` |
     | `…/provider/component/api_format_menu.dart` | `DesktopSettingApiFormatMenu`、`DesktopSettingApiFormatSelect` |

  改法：先判断问题 1 是不是有意的平台差异；问题 2 无论 1 怎么定都该修——同一文件内的两个类
  应能从名字看出各自角色。低优先级，但问题 2 的三个文件读起来确实含糊。

  另注：`Select` 这一词根在设置控件里也有一处（`widget/settings/control.dart` 的
  `AthenaSettingsSelect`、`AthenaSettingsMenuButton`），那是表单控件、不是选择器，不计入上表。

---

## 第 3 部分：目录归属

- [ ] **3.1 `component/` 里混了单端组件**

  位置：`packages/athena_gui/lib/component/`（共 19 个文件）

  现状：按 DESIGN §7，`component/` 是"跨页面复用的业务组件"。
  实测**传递可达性**（分别以 desktop 页面、mobile 页面为起点沿 import 图求闭包，已核实）：

  | 两端都可达（15 个，应留在 `component/`） | 仅 desktop（2 个） | 仅 mobile（2 个） |
  |---|---|---|
  | `api_format_label`、`approval_mode_label`、`base64_image`、`chat_error_dialog_listener`、`elicit_card`、`message_list_scroll_controller`、`message_sliver`、`message_tiles`、`permission_card`、`queued_messages`、`run_statistics_label`、`sentinel_placeholder`、`step_card`、`step_primitives`、`turn_navigator` | `chat_column`、`status_dot` | `approval_mode_dialog`、`card_tile` |

  **别按"直接 import"归类**（这是本条最容易判错的地方）：`message_tiles`、`step_card`、
  `step_primitives` 只被 `component/` 内部直接引用，但经
  `message_sliver ← message_tiles ← step_card ← step_primitives` 这条链，两端都已用到——
  留在 `component/` 是对的，不要下沉。`turn_navigator` 同理（被共用的 `message_sliver` 引用）。
  真正该动的只有上表后两列的 4 个。

  各单端件的引用方（已核实）：
  - `chat_column` ← `page/desktop/home/component/message_list.dart`、`message_input.dart`
  - `status_dot` ← `page/desktop/home/component/chat_list.dart`
  - `card_tile` ← `page/mobile/home/home.dart`
  - `approval_mode_dialog` ← `page/mobile/chat/component/chat_bottom_sheet.dart`

  改法：把这 4 个移到各自的 `page/desktop/home/component/` 或 `page/mobile/.../component/`，
  并把对应测试一起挪（至少 `test/widget/status_dot_test.dart` 直接 import 了 `status_dot.dart`）。

  另注：`chat_column.dart` 不含组件类，只有 3 个常量 + 1 个纯函数 `chatColumnPadding`
  （消息列与 composer 共用宽度）。它只有 desktop 用，下沉到 `page/desktop/home/component/` 后，
  与 `component/` 的"业务组件"定位无关这件事就不再别扭。

- [ ] **3.2 TUI 两个根级 `*_backend.dart`**

  位置：`packages/athena_tui/lib/` 根下的 `exit_hook_backend.dart` 与 `no_clipboard_backend.dart`

  现状：都 `implements TerminalBackend`（nocterm），是**同族实现**，却挂在包的根上；
  两者都只被 `bin/athena.dart` 使用（`exit_hook_backend` 另有一个测试）。

  改法：建 `lib/ui/backend/` 或 `lib/backend/` 收拢同族实现。顺带解决 1.2 里"组合根形态不对称"的问题
  （可同时把 `lib/di/tui_di.dart` 拉平成 `lib/tui_di.dart`，或反之把 GUI 的 `di.dart` 也变成目录）。

- [ ] **3.3 core 的 `service/` 与 `storage/` 边界有例外**

  位置：`packages/athena_core/lib/service/chat_store_service.dart`

  现状：该文件自称"会话 CRUD、消息删除/占位/最终化，所有写操作直接落库"，是纯持久化编排，
  却归在 `service/`；而 `storage/` 里同时有 `provider_store`、`sentinel_store`、
  `session_jsonl_store` 与 `*_repository`。同类实体存储分居两处，只能靠类名区分
  （`*Service` 在 `service/`、`*Store` 在 `storage/`）。

  补充证据（决定了该选哪个选项）：`ChatStoreService` 的构造依赖是 **5 个仓储接口**
  （`ChatRepository`、`MessageRepository`、`ModelRepository`、`ProviderRepository`、
  `SentinelRepository`），**不含任何 LLM client**；公开方法全是 `createChat` / `deleteChats` /
  `togglePin` / `finalizeAssistantMessage` / `recordErrorOnMessage` 一类。
  也就是说它确实是"跨实体的编排"，只是恰好不碰网络。

  改法：二选一并写进 §2 ——
  - (a) `service/` 只管"网络 + 编排"，持久化一律进 `storage/`（则 `chat_store_service.dart` 迁走）；
  - (b) 明确 `service/` 下的 `*Service` 是"跨实体的编排层"，`storage/` 下的 `*Store` 是"单实体文件读写"，
    并在 §2 补一句判据。**按上面的证据，(b) 更贴合现状**；选 (a) 要搬走一个横跨 5 个仓储的类，
    收益是目录语义单一，代价是它在新位置反而成了异类。

- [ ] **3.4 `ExperienceRepository` 是具体实现，留在接口目录**

  位置：`packages/athena_core/lib/repository/experience_repository.dart:21`

  现状：`repository/` 共 6 个文件。另外 5 个文件里**全部**是抽象类，且其中
  `message_repository.dart` 一个文件里就有两个（`abstract class MessageRepository` 与
  `abstract interface class RecentMessageRepository`），合计 **6 个抽象类**：
  `ChatRepository`、`MessageRepository`、`RecentMessageRepository`、`ProviderRepository`、
  `ModelRepository`、`SentinelRepository`。
  **只有 `experience_repository.dart` 是具体类，且不存在同名的抽象接口** ——
  类名与目录语义（"接口层"）不符。

  改法：把它移到 `storage/experience_repository.dart`（与其它文件实现一致），
  或原地改名（如 `FileExperienceRepository`）以减少与接口层的语义冲突。

- [ ] **3.5 `ChatHistoryEntity` 是展示模型，却放在 core 的 `entity/`**

  位置：`packages/athena_core/lib/entity/chat_history_entity.dart`

  现状：`entity/` 共 13 个文件，按"是否落盘、如何落盘"实测可分七类（每类的判据是
  自己的 id 字段 + 有无 `fromJson`/`toJson` + 是否被 `storage/`、`repository/` 引用）：

  | 类别 | 成员 | 判据 |
  |---|---|---|
  | 独立落盘的实体 | `ChatEntity`、`MessageEntity`、`ModelEntity`、`ProviderEntity`、`SentinelEntity`、`ExperienceEntity` | 有 id，双向序列化，被 storage 引用 |
  | 随宿主落盘的内嵌值 | `RunStatistics` | 有 `id` 与双向序列化，但只作为 `MessageEntity` 的 `run_statistics` 字段落盘 |
  | 消息行上的派生物 | `CompactionStep` | 无独立 id；经 `toMessage()` / `fromMessage()` 挂在 `role: 'compaction'` 的消息上 |
  | 纯静态工具 | `ConversationSummary` | `abstract final class`，只有 static 方法，不落盘 |
  | 枚举 / 小值 | `ApiFormat`、`ApprovalMode` | `enum`，不落盘 |
  | 运行期值 | `TokenUsage` | 无 id、无序列化、storage 不引用，只从响应取来给界面显示 |
  | **展示投影** | **`ChatHistoryEntity`** | 无 id、不落盘；**带一个 `fromJson`，但全仓库没有任何调用点** |

  第四到第七类都不落盘（第三类 `CompactionStep` 会经消息行落盘），其中只有最后一行是"展示投影"。
  它内容只是 `ChatEntity chat` + `String lastMessageContent`（派生值），注释自称"用于历史消息列表展示"，由
  `ChatRepository.getAllChatsWithLastMessage()` 返回，被移动端组件（`chat_tile`、
  `recent_chat_list_view`）与两个前端的会话列表直接消费（GUI 的 `chat_view_model` 与
  TUI 的 `chat_controller` 各持一份 signal）。

  问题：它是"列表项的展示投影"，是 GUI 与 TUI 共用的**装配层**概念，而不是引擎的事实
  （判据见 `AGENTS.md` §1.1）——同目录其余 12 个文件要么落盘、要么是纯值或纯工具，
  只有它把"给界面看的形状"写进了 core。

  改法：确认它确实被两端共用后再决定 —— 若共用，保留在 core 但在注释里点明"非持久化实体"，
  并考虑与 3.3 一起把"投影/读模型"归一类；若只有一端需要，下沉到该端。

---

## 第 4 部分：结构

- [x] **4.1 拆 `agent_service.dart` 的 `AgentEvent` 家族**

  位置：`packages/athena_core/lib/agent/agent_service.dart`

  现状：1739 行、**31 个顶层声明**。是唯一真正"太大"的文件（其余大文件是
  "一个主干 + 一串私有 State"的形态，按 §11 判据可留）。

  两处具体问题：
  1. **私有伴生类不在文件尾部**：`_TurnState`(1479)、`_AsyncSemaphore`(1490)、
     `_StreamingToolCall`(1518) 落在 `_AgentLoop`(693) 之后、公开类型 `ToolCallResultInternal`(1540)
     之前——夹在正文中间，而非 §3 要求的"集中在使用它的文件尾部"（文件末尾自 1553 起是
     `AgentEvent` 家族）。
  2. **内层事件契约内联**：`AgentEvent`(1553) 及 18 个子类与 `ToolCallResultInternal`(1540) 定义在此，
     它们是 **coordinator 的输入契约**（`coordinator/agent_run_coordinator.dart:773` 消费），
     与 `coordinator/run_event.dart` 的对外 `RunEvent` 形成内外两层契约，
     却只有外层单独成文件。

  **改法：**
  - 把 `AgentEvent` 家族（以及必要的 `ToolCallResultInternal`）抽到 `agent/agent_event.dart`，
    与 `coordinator/run_event.dart` 对称；
  - 把 `_TurnState`、`_AsyncSemaphore`、`_StreamingToolCall` 移到文件末尾（或各自私有文件）。
  这是**独立的小改动**，可随时做，不必等其它项。

- [ ] **4.2 GUI 测试目录与 `lib` 不同构，且 `test/widget/` 里有错位用例**

  位置：`packages/athena_gui/test/`

  现状一：`lib/` 有 `component/`、`util/`、`theme/`，`test/` 只有 `page/`、`view_model/`、
  `storage/`、`widget/`。

  现状二：`test/widget/` 下有 4 个用例不创建 widget（`grep -c testWidgets` 为 0）。要分开看——
  **其中 2 个明显错位，另 2 个可保留**：

  | 文件 | 实际被测对象 | 是否该在 `test/widget/` |
  |---|---|---|
  | `reasoning_effort_dialog_test.dart` | `widget/reasoning_effort_dialog.dart` 导出的档位表与显示名，与 `ChatEntity.reasoningEfforts` 对齐（防漂移） | **是该在**（被测的就是该 widget 文件） |
  | `scroll_behavior_test.dart` | `theme/athena_scroll_behavior.dart` | 否 → `test/theme/` |
  | `id_migration_test.dart` | core 的 `storage/file_storage.dart` + GUI 迁移逻辑，导入 `chat_view_model` | 否 → `test/storage/` |
  | `tool_icon_test.dart` | GUI `StepCard.toolIcon` 与 core 工具注册表的**对接**（用临时目录装配 `buildToolRegistry`，断言每个注册工具都有专用图标） | 可保留（测的是 `component/step_card.dart`，非 widget 测试） |

  改法：
  - 两个错位的（`scroll_behavior_test` → `test/theme/`、`id_migration_test` → `test/storage/`）
    移到对应目录。两个同名 `id_migration_test` 已核实**覆盖范围不重复**，不必合并：
    GUI 侧测"旧 GUI 模型偏好迁移到 UUID"与"无角色草稿可创建会话"，依赖 GUI 的 `DI` 与
    SharedPreferences，归 `test/storage/`（该目录已有 `prefs_into_setting_migration_test.dart`）；
    core 侧测 UUIDv7 生成、逆序 seq 分页、跨进程追加、提交中断恢复，留在 core。
  - `tool_icon_test` 测的是 GUI 的 `StepCard.toolIcon` 与 core 注册表的**对接**，两侧都依赖，
    **不能**移进 `athena_core/test/`（`StepCard` 只存在于 GUI）。它不 pump widget；若追求目录同构，
    可归入新建的 `test/component/`，否则留在 `test/widget/` 也说得过去。
  - `reasoning_effort_dialog_test` **不用动**——它测的就是 `widget/` 下那个文件；
    这里记它一笔，是为了避免下次照"0 次 testWidgets"一刀切把它也挪走。

- [x] **4.3 core 大量 `_test` 无同名 lib —— 需补一条归属约定**

  现状：**core 侧共 25 个**测试文件没有同名 lib（GUI 侧另有 18 个、TUI 侧 0 个）。
  例如 `compaction_failure_guard_test`、`context_overflow_recovery_test`、`parallel_selection_test`、
  `protocol_regressions_test`、`data_integrity_test`、`idle_timeout_test`。
  这些是**行为 / 回归测试**，本身合理，但 §7 只规定了"与被测单元同名"一种归属。

  改法：在 §7 补一句"行为与回归测试以被测行为命名，不要求与被测文件同名"，免去后来者
  面对既有惯例时的犹豫。**低优先级，纯文档。**

---

## 第 5 部分：命名细节

- [x] **5.1 `PowerShellShellTool` 的文件名推导会有分歧**

  位置：`packages/athena_core/lib/agent/tool/powershell_shell_tool.dart`

  现状：§3 规定"工具类固定 `XxxTool`，文件名 `xxx_tool.dart`"，即文件名由类名 snake_case 而来；
  但 `PowerShellShellTool` 的命名边界有两种切法——`power_shell_shell_tool.dart` 或
  `powershell_shell_tool.dart`，现状取了后者。规则本身没说清按"单词边界"还是"大小写边界"切。

  改法：由 0.2 的口径决定（若采纳"专名随官方拼写"，则类名保留、文件名按 snake_case 即现状，
  只需在 §3 明确"文件名一律全小写"。当前文件名 `powershell_shell_tool.dart` 已是全小写，**无需改动**；
  此条只是把分歧记下来，避免下次被当成违规改回去）。

---

## 建议的执行顺序

1. 第 0 部分（定口径）—— 决定后面所有项的走向。
2. 第 1 部分（文档）—— 低风险，可立即做，且 1.1 是文档自我一致性。
3. 第 5 部分 —— 与 0.2 同批，改完就结。
4. 第 4.1（拆 `agent_service.dart`）—— 独立，随时可做。
5. 第 2 部分（命名统一）—— 面广，一个包一次提交。
6. 第 3、4.2 部分 —— 涉及设计取舍，放最后。

**提交粒度**：按 §10，一次提交只做一件事。2.1 与 2.2 都要重跑 build_runner 并会改动 `router.gr.dart`，
分别单独成一次提交（生成文件的差异不要与逻辑改动混在一起）。

改完本文件即可删除。
