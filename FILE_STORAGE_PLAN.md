# Athena 统一文件存储与 Agent 历史回顾实施方案

日期：2026-09-12  
状态：待实施；本文确定目标设计与验收条件，尚未修改运行代码。

## 1. 目标与范围

将 GUI（桌面、iOS、Android）和 TUI 的业务持久化统一为文件存储，让 Agent 能主动查阅近期聊天中的原始证据，再更新 Experience、Skill 或 Sentinel。

核心验收场景：用户在一个新会话中说“回顾最近一周的聊天，找出我反复纠正你的问题，并改进你的工作方式”。Agent 能发现相关会话、检索反馈、分页读取原文、引用会话与消息 ID、执行进化，并在应用重启后保留结果。移动端须完成相同流程。

本次设计前提：

- 不迁移旧 SQLite、旧 TUI JSONL 或旧设置；不实现旧格式读取、双写和版本兼容分支。
- 不删除或覆盖设备上既有的旧数据；实现期间使用新的独立数据根，最终切换只影响新实现使用的位置。
- 初期完全移除 GUI 的 SQLite 业务存储；不引入 SQLite 搜索索引、向量数据库或后台服务。
- GUI 与 TUI 在同一台机器上可共用同一数据根；跨设备同步、云端合并和多个设备共同写网络目录不在首期范围。
- 保留现有 Signals、ViewModel、Coordinator 与 Repository 分层，不同时更换状态管理方案。
- GUI 的主题、窗口尺寸等设备 UI 偏好可以继续使用 SharedPreferences；模型选择、Agent 设置等业务配置统一存入文件。
- “不兼容历史版本”指旧应用与旧数据格式；Sentinel 自我进化所需的修改快照继续保留。

## 2. 现状中必须处理的缺口

| 当前实现 | 对新方案的影响 |
|---|---|
| GUI 的 5 个 Repository 使用 SQLite | 需要由两端共用的文件 Repository 替换 |
| TUI 修改消息、会话元数据时重写整个会话 JSONL | 不能直接搬到 GUI；需要改变权威数据的存储粒度 |
| TUI 消息 ID 按会话分配，部分接口只接收消息 ID | 新实现必须保证同一数据根内消息 ID 全局唯一 |
| `ChatMessageConverter` 只组装当前会话，工具集中没有跨会话历史入口 | 文件落盘与 Agent 能查阅历史必须一起交付 |
| `isSensitivePath` 将整个 `.athena` 目录视为敏感路径 | 必须新增有明确访问范围的数据读取入口，不能简单取消整目录保护 |
| Sentinel 当前定义与历史分开存储，历史目录使用可变名称 | 统一按稳定 ID 组织定义和历史，改名不移动历史 |
| `homeDir`、`dataDirectory` 与默认 HOME 路径混用 | 所有存储组件改为显式接收同一组数据路径 |
| `PermissionStore` 自行查找 HOME，GUI 的导出只包含三类配置 | 移动端路径、完整备份和重置均需纳入替换清单 |

代码依据见第 11 节。以上为代码审阅结论，不是性能实测结果。

## 3. 总体架构

保持现有三个 package。新增文件存储实现放在 `athena_core/lib/storage/file/`：它被 GUI 和 TUI 共用，只依赖纯 Dart，不引入 Flutter、SQL、GetIt 或平台目录插件，符合 core 的准入标准。

```text
GUI 页面 / TUI 组件
        ↓
现有 ViewModel / Controller
        ↓
Coordinator / Service / Repository 接口
        ↓
AthenaFileStore（同一进程、同一数据根共享一个实例）
        ├── 文件 Repository 与配置存储
        ├── 文件读写、ID 分配与锁
        └── 历史索引与阅读视图

Agent 的文件工具 → AthenaDataReader → 同一 AthenaFileStore
```

新增组件的职责：

| 组件 | 职责 |
|---|---|
| `AthenaDataPaths` | 由绝对数据根计算业务、控制和缓存路径；不自行读取 HOME |
| `AthenaFileStore` | 初始化、恢复、Repository 组装、共享队列、变更通知、关闭 |
| `AtomicFileWriter` | 同目录临时写入、校验、替换与中断恢复 |
| `StoreLock` / `SessionRunLease` | 短时存储操作锁、单会话运行租约 |
| `FileChatRepository` / `FileMessageRepository` | 实现会话、消息、统计与消息分页 |
| `FileCatalogRepository` | 在同一配置文件内管理 Provider、Model，分别暴露两个接口 |
| `FileSentinelRepository` | Markdown 定义、稳定 ID、版本检查和历史快照 |
| `FileKeyValueStore` | Agent 与业务设置；继续实现现有 `KeyValueStore` 接口 |
| `HistoryIndex` / `AthenaDataReader` | 会话发现、搜索、分页读取以及 Agent 可见范围 |

GUI 的 GetIt 和 TUI 的手工 DI 均由 `AthenaFileStore` 获取实现，不允许 GUI 依赖 TUI 的 storage 目录。现有 Experience、Skill、Permission、ToolOutput 存储接入相同路径与写入基础设施，避免形成第二套目录规则。

## 4. 数据目录与权威来源

默认的新数据根：桌面 GUI/TUI 使用 `<用户主目录>/.athena/store`；移动端使用 `<Application Support>/.athena/store`。测试注入临时目录。桌面启动参数可覆盖数据根，用于测试与独立资料库；数据根与 Agent 操作项目的工作目录是两个概念。

启动时先解析路径，再打开 Store，完成初始化后装配服务与 UI。未取得有效路径时报告初始化错误，不能回退到 `/` 或当前工作目录。

```text
<dataRoot>/
├── store.json                      # 格式标识、资料库 ID、初始化状态
├── config/
│   ├── catalog.json                # providers + models，包括连接配置
│   ├── settings.json               # Agent 设置、默认模型等业务设置
│   └── permissions.json            # 持久化权限规则
├── sessions/
│   └── <chatId>/
│       ├── chat.json                # 标题、关联、统计、创建/更新时间
│       ├── messages/
│       │   └── <messageId>.json     # 一条消息的当前完整状态
│       └── assets/                 # 本会话图片等附件
├── sentinels/
│   └── <sentinelId>/
│       ├── SENTINEL.md              # 当前角色定义
│       └── history/<snapshotId>.json
├── skills/<name>/SKILL.md
├── experiences/                    # 沿用现有逻辑格式与 scope 语义
├── tool_outputs/                   # 可续读的工具输出文件
├── .control/
│   ├── ids.json                    # ID 分配上界；不是可删除缓存
│   ├── store.lock                  # 固定路径锁文件，禁止替换或清理
│   ├── runs/<chatId>.lock           # 会话运行租约
│   ├── dirty/<chatId>.json          # 原件与派生索引更新的恢复标记
│   └── maintenance.lock            # 导入、重置、备份等维护协调
└── cache/
    ├── history/                    # 会话排序、消息定位、时间与摘要索引
    ├── views/                      # 按需生成的 Agent JSONL 阅读视图
    └── models_dev_cache.json
```

权威规则：`sessions`、`sentinels`、配置、技能与经验文件是原始数据；`cache` 可删后重建。阅读视图只能从原始数据生成，不反向覆盖原始文件。`tool_outputs` 不属于普通可随意清空的缓存：备份必须包含被历史引用的输出。

首期保留现有正整数实体 ID，降低对实体、Signals、路由与调用方的无关改动。会话、消息、角色等分别使用资料库级计数器，其中消息计数不能按会话拆分。先持久化预留 ID，再创建实体；允许有空号，不允许重用。`sentinelId == 0` 继续表示显式不使用角色。

`store.json` 只识别新格式，不承担旧格式迁移。只允许在空目录初始化；非空目录缺少格式标识时拒绝自动接管。初始化状态从 `initializing` 提交到 `ready`，中断后只补齐本次初始化未完成的内容。发现未知标识、损坏 ID 文件或重复 ID 时停止相关写入并报告，不能按空库重新分配 ID。备份恢复须包含资料库 ID 和计数器。

## 5. 会话与消息：使用单消息文件，JSONL 用于阅读

### 5.1 为什么采用这一粒度

Athena 会更新 assistant 占位消息、折叠状态、取消状态和 compact 标记。单消息文件可以将写入限制在当前消息；会话标题、统计更新只改 `chat.json`。首期不实现追加事件日志、日志合并、删除标记回放等另一套存储引擎。

每个会话一个 JSONL 的形式保留为按需生成的阅读视图。它适合 Agent 顺序阅读与外部导出，但不作为需要不断重写的唯一原件。此方案的代价是文件数量增加，必须通过第 12 节的真实目录规模测试验证。

### 5.2 消息格式与状态

每个消息文件包含：

- `id`、`chat_id`、`role`、`created_at`、`updated_at`、`revision`。
- `content`、`reasoning_content`、工具调用与结果、附件引用。
- `status`：`streaming`、`completed`、`cancelled`、`error` 或 `interrupted`。
- `compacted`、`expanded` 等现有持久化属性。

时间统一保存 UTC 毫秒，用于时间范围筛选；会话内消息仍按全局递增 ID 排序和使用 `beforeId` 分页，避免设备时钟回拨破坏游标语义。不能将 reasoning 的起止时间替代消息创建时间。为现有 `MessageEntity` 增加消息时间与运行状态，文件 DTO 负责字段编码。

文件中的工具调用和工具结果保存为 JSON 数组；Repository 边界可转换为现有实体使用的 JSON 字符串，避免同时重写 Agent 引擎。原始工具结果和 `modelResult` 的语义保持一致，历史回放继续使用 `modelResult`。

图片保存到会话 `assets`，文件中仅保存相对路径与 MIME 类型。为消息引入结构化附件引用，替换当前持久化消息里的逗号分隔 base64 字符串；尚未发送的图片仍可在 UI 内存暂存。新增附件读取服务：GUI 预览读取本地文件，`ChatMessageConverter` 在真正构建多模态请求时再读取并编码，不在会话列表或历史检索时加载全部图片。保持用户已有的粘贴、预览、发送行为。

### 5.3 写入、更新与删除

- 用户消息确认入库后才启动 Agent；assistant 占位消息继续获得持久化 ID。
- 流式增量留在内存，初始以 2 秒为间隔保存最新完整检查点；队列只保留最新待写版本，不能积压每个 token 的写入。
- 工具结果就绪、迭代结束、正常结束、取消、错误时立即提交状态；这些提交进入同一消息队列，终态不得被较旧检查点覆盖。
- 发起有副作用的工具执行前保存调用声明及待执行状态；如果现有事件流不能形成可等待的保存屏障，增加 Coordinator 注入的异步持久化回调。中断恢复将“已准备但无结果”的调用显示为结果未知，不自动重试。
- 检查点间隔是调优初值，不是断电丢失上限；只有 Store 已确认完成的提交才计入保存保证。
- `updateMessage` 拆分为内容/运行状态更新与展示状态更新；后者只 patch `expanded`，不得把旧 UI 快照中的正文写回。
- `updateChat` 改为持锁的字段 patch；`ChatUpdateService` 的“先读再改”移动到 Repository 锁内。Token 字段只能由 `recordUsage` 修改。
- `recordUsage` 在同一锁内读取最新统计、累加并提交。Coordinator 为用量事件提供稳定的 `runId + iteration + usageOrdinal`；`chat.json` 同一提交记录当前/最近 run 的已应用游标，以确认重复提交。旧 run 的用量事件在 run 收尾后拒绝接收，不靠重读总数猜测本次增量是否已应用。
- `markAsCompacted` 按全局消息 ID 定位；当前“先保存摘要、再标记原消息”的顺序保留。摘要消息同时保存 `compacts_message_ids`，恢复时先按这份目标集合幂等补齐标记，再组装上下文，避免中断后同时重复注入摘要和原文。
- `deleteMessagesByChatId` 仅删除消息与关联阅读缓存，保留会话元数据；`deleteChat` 删除整个会话及附件，两者不能像现有 TUI 一样等价。
- 删除会话先取消其 run、等待写入队列 settle、取得会话租约，再将会话目录移到隔离的删除区，随后清理。写入发现会话已删除必须失败，不能重新建出已删除会话。

单消息文件替换完成即视为消息提交；会话最后消息预览、消息数、最后活动时间属于派生值。消息与派生索引更新之间崩溃时，从原始消息重建，不能因索引落后认定消息不存在。标题、置顶、模型选择、Token 统计等非派生字段仍以 `chat.json` 为准。

修改会话消息前先持久化 `dirty/<chatId>.json`，包含目标消息 ID；原件、派生元数据与索引全部提交后才清除标记。启动和历史列表读取先处理遗留标记，确保消息写入后、索引更新前崩溃的会话仍会出现在近期列表中。目录监听不是这项恢复保证的替代品。

## 6. 可靠性、并发与恢复

### 6.1 文件提交

`AtomicFileWriter` 使用目标同目录的唯一临时文件，写完、flush、关闭、验证后替换目标。不能先删除正式文件再写新文件，也不能让并发写者使用同一个固定 `.tmp` 名称。

关键配置及当前实体保留一份有效前态用于中断恢复；恢复只接受完整且校验通过的正式文件或前态，不把未提交临时文件擅自提升为正式数据。前态文件不得被 Agent 搜索或重复计入消息。

P0 必须在实际支持的 macOS、Windows、Linux、iOS、Android 上验证替换目标已存在、磁盘写失败和进程中断行为。Dart `rename` 文档没有给出所有文件系统上一致的断电持久性承诺，因此本方案不宣称与 SQLite 的断电事务保证等价；若某平台无法满足进程中断恢复验收，先补齐该平台实现再切换。[Dart 文件替换文档](https://api.dart.dev/dart-io/File/rename.html)

### 6.2 进程与会话协调

- 同一进程每个数据根只有一个 Store，所有修改经同一串行队列；不能只依赖每个 Repository 私有的 Future 锁。
- GUI/TUI 跨进程通过固定的侧车锁文件取得短时排他锁；在锁内重新读取原件、执行 patch、提交。存储操作锁不能覆盖网络请求、整个 LLM 生成或长时间全文搜索。
- 所有 Store 读写隔离在一个拥有文件句柄的执行单元中；后台解析可在其他 isolate 执行，但不得独立打开同一控制锁文件。
- Unix 的文件锁是进程级 advisory lock，不能协调同进程 isolate，也不能约束外部编辑器；Windows 的锁又与句柄有关。必须保留进程内队列，并固定锁句柄的管理方式。[Dart 文件锁文档](https://api.dart.dev/dart-io/RandomAccessFile/lock.html)
- 同一会话运行前另取 `SessionRunLease`，持有到 settled。另一个客户端可以查看，但不能同时启动该会话的 Agent 或修改其消息；其他会话可正常运行。
- run 全程或独立的短时数据操作持有共享维护租约；备份、恢复、重置取得排他维护租约。同一进程由 Store 统一引用计数和管理维护锁句柄，避免嵌套调用提前解锁。
- 锁获取失败以有界等待返回“当前会话或存储正在被使用”，不得无限阻塞 UI。获取顺序固定为维护协调 → 会话租约（需要时）→ 存储操作锁，避免逆序嵌套。
- 客户端间变更通知以文件监听加失效检查实现；监听仅加速刷新。重新聚焦窗口、打开页面、读取 Agent 历史前必须重新核对相关文件，不能只相信本进程缓存。

### 6.3 启动恢复

恢复流程先检查格式与控制文件，再检查有未完成标记的实体和索引。单个损坏会话明确显示为无法读取，不把它显示成空会话或悄悄忽略；其他有效会话仍可使用。

发现 `streaming` 消息时先尝试对应会话租约：仍由其他进程持有则保持运行中；没有活跃写者时转为 `interrupted` 并展示已保存内容。首期不自动重新执行工具、不自动续跑先前的请求。

批量数据操作仅承诺文档明确规定的边界，不实现任意跨文件事务。Provider 与 Model 的关联修改在同一个 `catalog.json` 内提交；消息索引可以重建；需要阻止并发 run 的操作使用维护协调。

## 7. Sentinel、配置与预设

### 7.1 Sentinel 文档

`SENTINEL.md` 使用 YAML front matter 保存 `id`、`name`、`description`、`avatar`、`tags`、`is_preset`、`revision`，正文为完整系统提示词。目录名使用 ID，名称变化不影响会话引用和历史位置。

GUI 编辑、TUI 操作、`sentinel_evolve` 和 `sentinel_revert` 共用 Repository 更新入口；快照由这个入口统一保存，移除工具侧重复的独立快照写入。更新需要读取版本；在进化工具的 `sentinel_get` → `sentinel_evolve` 链路中传递预期 revision，发现原件已改变时重新读取并合并，不能覆盖他人修改。

一次进化流程：取得锁并校验原件 → 保存旧态及原因快照 → 提交新定义 → 发送变更通知。快照保存失败则此次修改失败；替换定义失败允许留下一个没有对应成功修改的旧态快照。回滚也保存回滚前快照。

外部编辑只承诺当前定义可被重新加载：解析成功后更新 revision/内容指纹与 UI；解析失败时保留内存中的上一份有效定义并显示文件错误，不能将空提示词保存回去。外部编辑器不遵守 Store 锁；文件化不承诺任意第三方同时写入无冲突。正式自动化写入应调用 Repository 或 evolve 工具。

角色的新定义从下一次顶层发送开始用于上下文构建，正在运行的请求保留启动时的提示词快照。同步修正工具目前“立即作用于当前聊天”的过度笼统提示。

### 7.2 配置与预设

- `catalog.json` 同时保存 Provider 与 Model；批量模型同步在内存形成结果后，一次持锁校验并提交，不能每新增一个模型就重写整个列表。
- ModelCatalogService 保留远端目录同步逻辑，文件缓存路径由客户端注入；同步只能更新目录元数据，保留用户密钥、开关和稳定 ID。
- 预设 Sentinel 与 Provider 的首次初始化由 core 共用 seed 服务完成，GUI/TUI 不再分别维护种子。首次离线也能打开应用并手动配置模型。
- seed 只创建缺失的首次初始化内容，初始化完成后不能因用户删除预设而每次启动重新生成，更不能覆盖已进化的 Sentinel。
- 删除 Provider 同时移除其 Model 配置；已有聊天仍保留引用与历史，由现有 ModelResolver 处理失效模型。删除 Sentinel 后已有聊天显示角色不可用，发送时按无角色处理，不隐式替换为另一个角色。
- Experience 的 private/shared、归档规则保持不变；GUI 与 TUI 共用后，Sentinel ID 字符串须来源于同一资料库 ID 体系。
- API 连接配置、业务设置、权限规则存入私有配置路径，不能出现在 Agent 可读取的历史目录或阅读索引中。

## 8. Agent 发现、检索与读取历史

### 8.1 共用工具接口

扩展 `file_read`，新增 `file_list`、`file_search`，统一引入 `scope`。`scope="athena"` 表示应用数据的逻辑只读视图；桌面原有项目文件能力使用 `scope="workspace"`。移动端只注册或只接受 `athena` 范围，不依赖 Bash、PowerShell、SQLite CLI 或系统 `rg`。

建议首版接口：

| 工具 | `athena` 范围的参数与结果 |
|---|---|
| `file_list` | `path`、`updated_after`、`sentinel_id`、`limit`、`cursor`；默认 20、最大 100 项，按最近会话活动时间排序，返回标题、ID、时间、简短预览与逻辑阅读路径 |
| `file_search` | `path`、`query`、可选时间/角色过滤、`limit`、`cursor`；首期仅子串匹配，默认 20 个命中，返回会话/消息 ID、片段与阅读路径 |
| `file_read` | `path`、`offset`、`limit`、`snapshot_id`；返回稳定分页、是否结束与下一页信息 |

逻辑路径例如 `sessions/42/transcript.jsonl`、`sentinels/3/SENTINEL.md`。这些是工具 API 的路径，不向模型暴露 iOS 容器 UUID 或绝对沙盒路径。工具通过 `AthenaDataReader` 解析，不能简单拼接任意用户参数到真实根目录。

### 8.2 阅读视图与缓存

历史默认展示用户和 assistant 正文、消息时间、状态、ID；压缩过的原始消息仍可读取，system 摘要单独标识，避免与原文重复作为证据。默认省略模型推理、工具参数、完整工具输出和附件二进制。需要工具证据时通过明确的工具结果引用按需续读。

一条阅读记录包含 `chat_id`、`message_id`、`created_at`、`role`、`content`。长消息按最多 2,000 个 Unicode 字符拆为带 `part` 的多条记录，避免一行 JSON 就超过输出预算。单次工具输出初始上限 12,000 字符；截断必须带后续读取信息，不得伪装为完整结果。

阅读视图按需生成到 `cache/views`，附原件指纹和 `snapshot_id`。分页使用同一快照；原件更改时返回快照失效并提供重开入口，不能让行偏移悄悄指向其他消息。源会话删除后旧快照立即失效，不能继续从缓存读到已删除历史。

首次索引扫描读取会话元数据与消息文件名，不加载全部正文；消息定位索引只存 ID → 路径。正文搜索按会话时间筛选后流式处理，并在达到扫描字节/时间预算时返回游标。大库搜索不得在 GUI 主 isolate 同步解码全库；无命中与“尚未扫描完”必须明确区分。

### 8.3 访问范围与进化证据

- 应用数据工具只开放 `sessions` 的阅读视图、Sentinel 定义、允许访问的 Skills/Experiences。Experience 仍遵循当前 Sentinel 的 private/shared 可见性。
- 同一资料库的聊天属于同一用户，允许按任务回顾全部会话；`sentinel_id` 用于缩小检索范围。跨会话阅读不自动改变 Experience 的共享范围。
- 不开放 `config`、`.control`、临时文件、前态备份或任意缓存路径。对 `..`、绝对路径和符号链接越界做真实路径校验；不能把现有 `.athena` 保护规则整体删除。
- 读取工具沿用 readOnly 权限语义；修改角色、经验和技能仍走现有危险工具审批、校验与变更通知，聊天历史不向这些工具开放任意改写。
- 补充稳定的系统提示和 self-evolve 指南，说明目录、工具、时间过滤、分页与证据引用方法。只注入入口说明，不在每次发送时自动塞入全部近期聊天。
- 历史正文作为待分析资料返回；其中曾经出现的指令不能覆盖当前任务。进化说明引用稳定的会话 ID、消息 ID，区分用户明确纠正、重复偏好与单次情境。

端到端示例：`file_list(scope: athena, path: sessions, updated_after: 七天前)` → `file_search` 查找纠正线索 → `file_read` 补足上下文 → `experience_learn`/`skill_evolve`/`sentinel_evolve` → 返回修改原因和来源消息。工具中的时间值由调用方转换为明确的 UTC 时间。

## 9. 移动端落地

GUI 在 Flutter 装配层通过 `path_provider` 获取 Application Support，向纯 Dart Store 注入路径；应用内部数据放持久目录，不能放临时缓存目录。用户主动导出的文件通过系统文件选择/分享流程保存到其选择的位置。[Flutter 文件持久化文档](https://docs.flutter.dev/cookbook/persistence/reading-writing-files)

应用内 Agent 的文件工具在本机 Dart 中执行，只将本次需要的片段作为工具结果提供给模型。读取应用私有文件不要求手机提供终端；Android 访问自己的内部存储也不需要额外的存储权限。[Android 应用文件文档](https://developer.android.com/training/data-storage/app-specific)

移动端具体要求：

1. 生命周期切入后台时尽力提交检查点；正常运行中也按第 5 节保存，不能把数据保存绑定在退出回调上。Flutter 明确说明应用可能收不到终止前通知。[生命周期文档](https://api.flutter.dev/flutter/dart-ui/AppLifecycleState.html)
2. 启动恢复显示已完成消息和最后有效检查点；未完成工具调用标为中断，不能据此断言外部操作没有发生。
3. 首屏仅加载会话元数据与最近 50 条消息，向上滚动分页；聊天正文和图片按需加载。
4. 大规模搜索、索引重建、备份使用后台任务/isolate 与可取消进度，不阻塞动画和输入。
5. 不承诺应用退到后台后持续进行 LLM 自我进化；前台或系统允许执行时运行，中断按统一恢复策略处理。
6. 不把沙盒目录暴露成用户必须手动管理的文件树；通过现有聊天、角色、经验界面和导入导出入口操作。

## 10. 备份、恢复与重置

首期交付新格式完整备份，覆盖会话、附件、角色及历史、技能、经验、业务配置、必要的工具输出和 ID 信息；不包含锁、临时文件与可重建缓存。连接密钥默认不导出，可由用户显式选择包含；导出文件清楚说明是否包含密钥和权限规则。

导出先进入维护状态，阻止新 run 和配置写入，等待现有 run 收尾或由用户停止；取得一致快照后释放业务阻塞，再将快照打包。不能边读不断变化的原件边声称备份一致。

新格式恢复只支持完整资料库恢复，不合并两个资料库的整数 ID。先解包到隔离位置，验证格式、引用、路径、重复 ID 与附件，再在关闭全部 Store 使用者后切换到恢复的数据根；成功前保留原数据根。切换路径由客户端启动配置持久化，移动端只允许应用沙盒内的数据根。跨进程维护锁和切换失败恢复须有测试。

重置是显式的用户操作：停止全部活动写入、关闭 Store、隔离当前数据根、创建新库和预设。不能仅删除 `catalog.json` 或模拟过去的 DROP TABLE 后留下无法解析的业务状态。旧版数据库和旧 TUI 目录始终不属于本次清理目标。

## 11. 代码改动清单

下列链接指向制定方案时的现有文件；新增组件名称是实现目标。

| 位置 | 必要改动 |
|---|---|
| [GUI 启动](/Users/cals/Spare/athena/packages/athena_gui/lib/main.dart:22)、[GUI DI](/Users/cals/Spare/athena/packages/athena_gui/lib/di.dart:208)、[TUI DI](/Users/cals/Spare/athena/packages/athena_tui/lib/di/tui_di.dart:44) | 打开共用 Store、注入统一根目录、关闭旧装配与旧格式迁移 |
| `athena_core/lib/storage/file/`（新增） | 实现路径、锁、可靠写入、文件 DTO、5 个 Repository 适配与 KeyValueStore |
| [消息接口](/Users/cals/Spare/athena/packages/athena_core/lib/repository/message_repository.dart:4)、[会话接口](/Users/cals/Spare/athena/packages/athena_core/lib/repository/chat_repository.dart:8) | 保留核心查询，补齐字段 patch 与稳定分页；同步 Fake Repository 和调用方 |
| [消息实体](/Users/cals/Spare/athena/packages/athena_core/lib/entity/message_entity.dart:3)、[消息转换](/Users/cals/Spare/athena/packages/athena_core/lib/service/chat_message_converter.dart:28) | 消息时间、状态、附件引用与请求时读取 |
| [Coordinator](/Users/cals/Spare/athena/packages/athena_core/lib/coordinator/agent_run_coordinator.dart)、[更新服务](/Users/cals/Spare/athena/packages/athena_core/lib/service/chat_update_service.dart:90) | 检查点、终态写入顺序、run 租约、patch、恢复与删除防竞态 |
| [工具集](/Users/cals/Spare/athena/packages/athena_core/lib/agent/tool/tool_set.dart:33)、[路径检查](/Users/cals/Spare/athena/packages/athena_core/lib/util/path_normalizer.dart:40) | 共用 scoped 文件工具，保留工作区与应用私有配置边界 |
| [进化指南](/Users/cals/Spare/athena/packages/athena_core/lib/agent/evolution/evolution_prompt.dart:26) | 加入历史回顾流程、分页与证据引用，不自动加载所有历史 |
| [Sentinel 进化](/Users/cals/Spare/athena/packages/athena_core/lib/agent/tool/sentinel_evolve_tool.dart:107)、[历史存储](/Users/cals/Spare/athena/packages/athena_core/lib/agent/evolution/sentinel_history_store.dart:35) | 稳定 ID 路径、预期 revision、快照与提交顺序、下轮生效文案 |
| [权限存储](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/permission_rule.dart:293)、Skill/Experience/ToolOutput 存储 | 移除自行拼接 HOME 的路径来源，统一由 Store 注入 |
| [设置 ViewModel](/Users/cals/Spare/athena/packages/athena_gui/lib/view_model/setting_view_model.dart:206)、[导入导出服务](/Users/cals/Spare/athena/packages/athena_gui/lib/service/data_migration_service.dart:17) | 完整备份、恢复、重置，业务设置切到 FileKeyValueStore，UI 偏好保留原方式 |
| GUI 数据库目录、SQLite Repository、TUI 旧 storage/seed | 在新实现验收后删除不再使用的代码与迁移，不保留双后端开关 |
| GUI `pubspec.yaml`、lockfile、README、AGENTS | 移除 `laconic`/`laconic_sqlite` 和过期说明，更新三端架构、工具数量与操作方式 |

## 12. 实施顺序与验收

按以下阶段顺序实施，每个阶段可单独审阅。P0—P6 全部通过后才认为替换完成。实现期间可以在测试中并存旧类，正式运行路径不双写。

| 阶段 | 交付物 | 通过条件 |
|---|---|---|
| P0：验证文件基础 | 路径、临时目录测试、锁与替换原型、规模基准脚本 | 五个平台完成基础文件读写与替换验证；桌面双进程锁有效；中断不把正式文件读成空实体 |
| P1：共享 Store 与配置 | 共用 Store、ID、配置、KeyValue、seed、Sentinel 文件与历史 | 新空库离线初始化；重启 ID 不复用；角色改名后可回滚；GUI/TUI 数据一致；预设不覆盖进化 |
| P2：会话与消息 | 文件 Repository、消息分页、patch、附件、检查点与恢复 | 完整 send/工具/compact/取消/删除/重启路径通过；旧 UI 快照不覆盖正文；不存在跨会话误删或误标记 |
| P3：历史访问与进化 | scoped 文件工具、索引、JSONL 阅读视图、指南 | 新会话能回顾其他近期会话并提供来源；分页无遗漏；移动端不依赖 Shell 完成同样调用链 |
| P4：三端接入 | GUI/TUI 正式切换、生命周期、客户端刷新 | 五平台主要使用流程通过；同机 GUI/TUI 不同会话可运行，同会话第二个 run 被明确拒绝 |
| P5：备份与维护 | 新格式完整备份、恢复、重置 | 恢复到新根后内容、ID、附件一致；失败保留原数据；旧数据目录不被清理；运行中维护可控 |
| P6：清理与文档 | 删除旧数据库/TUI 存储、更新依赖和项目文档 | 业务持久化没有 SQLite 调用；三包静态分析和相关回归测试通过 |

必须覆盖的自动化测试：

- **Repository 契约**：CRUD、会话排序、ID 唯一、Token 独立累加、分页、最新消息、compact 过滤、只删消息/删除会话的不同语义。
- **故障注入**：临时文件写到一半、替换前后中断、配置损坏、ID 损坏、索引滞后、磁盘写失败；均不得把损坏数据当新空库。
- **并发**：两个进程新增消息；标题 patch 与用量累加；GUI 折叠操作与终态提交；删除与延迟检查点；会话租约持有者退出后的恢复。
- **进化**：读取 revision 后被其他客户端修改；快照失败；定义提交失败；改名后回滚；新定义从下一次发送生效。
- **历史工具**：中文/emoji、超长单条消息、跨页游标、原件变化、删除后缓存失效、时间与 Sentinel 过滤、扫描未完成标记、敏感目录与符号链接越界。
- **移动端**：前后台切换、进程终止后恢复、沙盒根一致、文件选择导出、附件重启后显示、无 Shell 的回顾进化流程。

规模验证使用合成数据，不读取开发者真实聊天。至少两档：100 会话 / 10,000 消息，以及 1,000 会话 / 100,000 消息，混合长正文、工具结果和附件。记录硬件、系统、构建模式、冷/热启动、首屏耗时、P95 读写、读取字节数与峰值内存；这些是测试规模，不是已验证的容量承诺。

结构性验收门槛：

1. 修改标题或 Token 统计不读取、重写消息正文；更新一条消息不重写其他消息。
2. 最近 50 条分页只打开所需的消息文件；允许枚举文件名，但不能为分页解析全部历史正文。
3. 会话首屏不读取附件内容；缓存删除后可从权威文件重建。
4. 搜索在预算内可取消、可续读，UI 输入和滚动保持可响应；性能预算在 P0 的基准设备上测定并记录，不能以未测数字承诺性能。
5. “回顾最近一周”测试必须包含多个会话、重复纠正与无关讨论；只读取必要内容、引用实际来源、没有把单次情境误写成全局偏好。

预期主要成本在可靠文件操作、消息更新语义与 Agent 阅读工具；删除 SQL 类本身不是完成标志。若 P0 显示单消息文件在目标手机上的目录规模不可接受，应在 P1 前调整物理布局并重跑基准，不能在正式切换后才补性能设计。

## 13. 完成定义

- GUI、TUI、移动端共用文件格式与 Repository；旧数据库和旧格式不参与新运行流程。
- Agent 能在桌面和移动端从新会话查阅其他会话、获取原始证据并完成自我进化。
- 角色修改、会话写入、取消、compact、删除、并发访问与重启恢复有明确行为及测试证据。
- 文件是唯一权威业务数据；阅读视图和索引可重建，不出现两份都能修改的聊天真相源。
- 完整备份可以恢复到新资料库；不依赖数据库、不依赖移动端终端，也不承诺尚未实现的跨设备同步。
