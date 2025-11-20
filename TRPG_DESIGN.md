# TRPG 模块设计文档

## 1. 整体架构

### 1.1 设计目标
- 独立的TRPG系统，不复用ChatViewModel逻辑
- 单页面实现（无页面跳转），所有交互在 `trpg_page.dart` 完成
- MVP版本：用户能完整玩一局TRPG游戏

### 1.2 架构分层
```
┌─────────────────────────────────────┐
│  UI Layer (trpg_page.dart)          │
│  - 游戏初始化界面                    │
│  - 游戏进行界面                      │
│  - 状态展示                          │
└─────────────────────────────────────┘
            ↓↑
┌─────────────────────────────────────┐
│  ViewModel Layer                     │
│  - TRPGViewModel                     │
│  - 管理游戏状态 (Signals)            │
│  - 处理AI交互                        │
└─────────────────────────────────────┘
            ↓↑
┌─────────────────────────────────────┐
│  Repository Layer                    │
│  - TRPGGameRepository                │
│  - TRPGMessageRepository             │
└─────────────────────────────────────┘
            ↓↑
┌─────────────────────────────────────┐
│  Database Layer (SQLite)             │
│  - trpg_games 表                     │
│  - trpg_messages 表                  │
└─────────────────────────────────────┘
```

---

## 2. 数据库设计

### 2.1 表结构

#### `trpg_games` 表
存储TRPG游戏实例（存档）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键，自增 |
| title | TEXT | 游戏标题（自动生成或用户命名） |
| game_style | TEXT | 剧本风格（如"中世纪奇幻"） |
| character_class | TEXT | 角色职业（如"战士"、"法师"） |
| game_mode | TEXT | 游戏基调（如"爽文模式"） |
| current_hp | INTEGER | 当前生命值 |
| max_hp | INTEGER | 最大生命值 |
| current_mp | INTEGER | 当前魔法值/理智值 |
| max_mp | INTEGER | 最大魔法值 |
| inventory | TEXT | 背包物品（JSON字符串） |
| current_quest | TEXT | 当前任务描述 |
| current_scene | TEXT | 当前场景描述 |
| model_id | INTEGER | 使用的AI模型ID |
| created_at | INTEGER | 创建时间戳 |
| updated_at | INTEGER | 更新时间戳 |

#### `trpg_messages` 表
存储游戏消息记录

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键，自增 |
| game_id | INTEGER | 关联的游戏ID |
| role | TEXT | 角色（"dm" 或 "player"） |
| content | TEXT | 消息内容 |
| created_at | INTEGER | 创建时间戳 |

---

## 3. 文件结构

```
lib/
├── entity/
│   ├── trpg_game_entity.dart          # 游戏实体
│   └── trpg_message_entity.dart       # 消息实体
│
├── model/
│   └── action_suggestion.dart         # 行动建议数据类
│
├── repository/
│   ├── trpg_game_repository.dart      # 游戏数据仓库
│   └── trpg_message_repository.dart   # 消息数据仓库
│
├── view_model/
│   └── trpg_view_model.dart           # TRPG视图模型
│
├── service/
│   └── trpg_service.dart              # TRPG AI服务（调用OpenAI API）
│
├── page/mobile/trpg/
│   └── trpg_page.dart                 # 单页面UI（包含所有视图状态）
│
├── database/migration/
│   └── migration_202501200002_add_trpg_tables.dart  # 数据库迁移
│
└── preset/
    └── prompt.dart                    # 需要添加 actionSuggestionPrompt
```

---

## 4. 各层职责

### 4.1 Entity Layer（实体层）
**职责**：纯数据类，与数据库字段一一对应

- `TRPGGameEntity`：游戏存档数据
- `TRPGMessageEntity`：消息数据

**方法**：
- `fromJson()`: 从数据库JSON转换
- `toJson()`: 转换为数据库JSON
- `copyWith()`: 不可变对象更新

### 4.2 Repository Layer（数据仓库层）
**职责**：封装数据库操作，提供CRUD接口

#### `TRPGGameRepository`
```dart
- getAllGames(): 获取所有游戏存档
- getGameById(int id): 根据ID获取游戏
- createGame(TRPGGameEntity): 创建新游戏
- updateGame(TRPGGameEntity): 更新游戏状态
- deleteGame(int id): 删除游戏
```

#### `TRPGMessageRepository`
```dart
- getMessagesByGameId(int gameId): 获取游戏的所有消息
- createMessage(TRPGMessageEntity): 创建新消息
- deleteMessagesByGameId(int gameId): 删除游戏的所有消息
```

### 4.3 Service Layer（服务层）
**职责**：处理AI交互逻辑

#### `TRPGService`
```dart
- sendMessage(messages, model): 发送消息到AI（用于DM响应）
- streamResponse(): 流式接收AI响应
- parseStatusFromResponse(String): 解析HUD状态信息
- generateSuggestions(dmMessage, gameState): 生成行动建议（使用轻量级模型，快速返回）
```

### 4.4 ViewModel Layer（视图模型层）
**职责**：业务逻辑，状态管理，连接UI和数据层

#### `TRPGViewModel`
**状态（Signals）**：
```dart
- currentGame: Signal<TRPGGameEntity?>    // 当前游戏
- messages: ListSignal<TRPGMessageEntity> // 消息列表
- isStreaming: Signal<bool>                // 是否正在生成DM响应
- isGeneratingSuggestions: Signal<bool>    // 是否正在生成行动建议
- currentHP: Signal<int>                   // 当前HP（从AI响应解析）
- currentMP: Signal<int>                   // 当前MP
- inventory: ListSignal<String>            // 背包物品
- currentQuest: Signal<String>             // 当前任务
- suggestedActions: ListSignal<ActionSuggestion> // AI生成的行动建议
```

**方法**：
```dart
- createNewGame(gameStyle, characterClass, gameMode): 创建新游戏
- loadGame(int gameId): 加载游戏存档
- sendPlayerAction(String action): 发送玩家行动
- updateGameStatus(statusData): 更新游戏状态
- generateActionSuggestions(): 生成行动建议（DM消息完成后调用）
```

**数据类**：
```dart
class ActionSuggestion {
  final String emoji;
  final String text;
}
```

### 4.5 UI Layer（界面层）
**职责**：展示UI，接收用户交互

#### `trpg_page.dart` 单页面包含3个视图状态：

**状态1：游戏初始化视图**
```
┌─────────────────────────────────────┐
│        🎮 创建新游戏                 │
├─────────────────────────────────────┤
│  Step 1: 选择剧本风格                │
│  □ 中世纪奇幻  □ 赛博朋克2077       │
│  □ 克苏鲁神话  □ 武侠修仙           │
│  □ 末日废土                         │
├─────────────────────────────────────┤
│  Step 2: 角色设定                    │
│  [输入框: 职业/特长]                │
│  或 [让AI随机生成]                  │
├─────────────────────────────────────┤
│  Step 3: 游戏基调                    │
│  ○ 爽文模式 (简单)                  │
│  ○ 硬核生存 (困难)                  │
│  ○ 解谜悬疑 (策略)                  │
├─────────────────────────────────────┤
│            [开始冒险]                │
└─────────────────────────────────────┘
```

**状态2：游戏进行视图**
```
┌─────────────────────────────────────┐
│  🌐 古老地下城 | 🕒 午夜 | 🎵 紧张  │  ← 场景信息栏
├─────────────────────────────────────┤
│  [消息滚动区域]                      │
│                                     │
│  DM: 你站在一扇生锈的铁门前...      │
│      阴冷的空气让你不寒而栗。       │
│                                     │
│  🎲 检定日志                         │
│  行动：撬锁                          │
│  计算：1d20(14)+3=17 vs DC 15      │
│  结果：✅ 成功                       │
│                                     │
│  Player: 我打开门走进去             │
│                                     │
├─────────────────────────────────────┤
│  📊 状态面板                         │  ← 可折叠
│  ❤️ HP: 85/100                      │
│  💙 MP: 40/50                       │
│  🎒 匕首, 药水x2                    │
│  📜 探索地下城第二层                │
├─────────────────────────────────────┤
│  💡 AI建议行动: (DM消息完成后生成)  │
│  [🚪 推开铁门进入]                  │
│  [🔍 检查门上是否有陷阱]            │
│  [👂 贴近门听里面的动静]            │
├─────────────────────────────────────┤
│  输入行动... [发送➤]                │
└─────────────────────────────────────┘
```

**状态3：游戏暂停/菜单**
```
┌─────────────────────────────────────┐
│            游戏菜单                  │
├─────────────────────────────────────┤
│  [继续游戏]                          │
│  [保存并退出]                        │
│  [结束游戏]                          │
└─────────────────────────────────────┘
```

---

## 5. 数据流设计

### 5.1 创建新游戏流程
```
用户选择游戏设置
    ↓
TRPGViewModel.createNewGame()
    ↓
1. 构建初始系统提示词（dungeonPrompt + 用户选择）
2. 创建 TRPGGameEntity
3. TRPGGameRepository.createGame() → 保存到数据库
4. TRPGService.sendMessage() → 发送初始化消息给AI
    ↓
AI返回开场描述
    ↓
5. 解析响应（提取HUD信息）
6. TRPGMessageRepository.createMessage() → 保存DM消息
7. 更新ViewModel状态（currentGame, messages, HP/MP等）
    ↓
UI更新显示游戏界面
```

### 5.2 玩家行动流程
```
用户输入行动 / 点击快速按钮
    ↓
TRPGViewModel.sendPlayerAction(action)
    ↓
1. 创建 player 消息
2. TRPGMessageRepository.createMessage() → 保存
3. 构建完整对话历史（system + 历史messages + 新action）
4. TRPGService.sendMessage() → 流式调用AI
    ↓
AI流式返回响应
    ↓
5. 逐字更新UI（实时显示）
6. 响应完成后解析HUD
7. 更新游戏状态（HP/MP/背包/任务）
8. TRPGMessageRepository.createMessage() → 保存DM响应
9. TRPGGameRepository.updateGame() → 更新游戏状态
    ↓
UI完成更新
    ↓
10. 调用 TRPGViewModel.generateActionSuggestions()
11. TRPGService.generateSuggestions(dmMessage) → 生成行动建议
    ↓
AI返回3-4个行动选项（JSON格式）
    ↓
12. 更新 suggestedActions 状态
    ↓
UI显示行动建议按钮
```

### 5.3 AI生成行动建议流程
**触发时机**：每次DM消息流式传输完成后自动触发

```
DM消息传输完成
    ↓
TRPGViewModel.generateActionSuggestions()
    ↓
1. 获取最新的DM消息内容
2. 构建建议生成提示词（actionSuggestionPrompt + DM消息 + 当前游戏状态）
3. TRPGService.generateSuggestions() → 调用AI（使用轻量级模型）
    ↓
AI返回JSON格式的行动选项
{
  "suggestions": [
    {"emoji": "🚪", "text": "推开铁门进入"},
    {"emoji": "🔍", "text": "检查门上是否有陷阱"},
    {"emoji": "👂", "text": "贴近门听里面的动静"}
  ]
}
    ↓
4. 解析JSON
5. 更新 suggestedActions: ListSignal<ActionSuggestion>
    ↓
UI展示建议按钮（用户点击 = 快速输入）
```

**用户交互**：
- 点击建议按钮 → 直接作为玩家行动发送
- 忽略建议 → 使用输入框自行输入

### 5.4 HUD解析逻辑
AI响应包含结构化信息，需要正则提取：

```dart
// 示例AI响应
"""
[🌐 场景：古老地下城 | 🕒 时间：午夜 | 🎵 氛围：紧张]

...剧情内容...

---
【📊 状态面板 HUD】
- HP (生命值): 85/100 (轻微擦伤)
- MP/Sanity (资源): 40/50
- Inventory (装备): 等离子手枪, 奇怪的钥匙卡, 绷带(x2)
- Active Quest (当前目标): 潜入服务器机房
"""

// 解析逻辑
RegExp(r'HP.*?(\d+)/(\d+)')       → currentHP, maxHP
RegExp(r'MP.*?(\d+)/(\d+)')       → currentMP, maxMP
RegExp(r'Inventory.*?:(.*?)(?:\n|$)') → inventory
RegExp(r'Active Quest.*?:(.*?)(?:\n|$)') → currentQuest
```

---

## 6. 实现步骤（MVP）

### Phase 1: 数据层 ✅
- [x] 创建 `TRPGGameEntity`
- [x] 创建 `TRPGMessageEntity`
- [ ] 创建 `ActionSuggestion` 数据类
- [ ] 创建数据库迁移文件
- [ ] 在 `database.dart` 中注册迁移
- [ ] 创建 `TRPGGameRepository`
- [ ] 创建 `TRPGMessageRepository`

### Phase 2: 业务层
- [ ] 在 `preset/prompt.dart` 中添加 `actionSuggestionPrompt`
- [ ] 创建 `TRPGService`（调用OpenAI API）
  - [ ] sendMessage() - DM响应生成
  - [ ] generateSuggestions() - 行动建议生成
  - [ ] parseStatusFromResponse() - HUD解析
- [ ] 创建 `TRPGViewModel`
  - [ ] 基础状态管理
  - [ ] generateActionSuggestions() 方法
- [ ] 在 `main.dart` 中注册依赖注入

### Phase 3: UI层
- [ ] 重构 `trpg_page.dart`
  - [ ] 状态枚举（init / playing / paused）
  - [ ] 游戏初始化界面
  - [ ] 游戏进行界面
  - [ ] 消息列表组件
  - [ ] 状态面板组件
  - [ ] AI建议行动按钮组件（动态生成）
  - [ ] 输入框和发送按钮

### Phase 4: 测试与优化
- [ ] 运行 `flutter pub run build_runner build`
- [ ] 测试完整游戏流程
- [ ] 测试行动建议生成功能
- [ ] 修复bug
- [ ] 优化UI体验

---

## 7. 技术细节

### 7.1 依赖注入
在 `main.dart` 中注册：
```dart
GetIt.instance.registerLazySingleton(() => TRPGViewModel());
```

### 7.2 系统提示词组装
```dart
final systemPrompt = PresetPrompt.dungeonPrompt;
final userSetup = '''
1. 剧本风格：${game.gameStyle}
2. 角色设定：${game.characterClass}
3. 游戏基调：${game.gameMode}

请开始游戏！
''';
```

### 7.3 复用现有基础设施
- 使用 `laconic` 数据库库（已有）
- 使用 `signals` 状态管理（已有）
- 使用 `ChatService` 的 OpenAI 调用逻辑（参考）
- 使用 `get_it` 依赖注入（已有）

### 7.4 行动建议生成提示词（actionSuggestionPrompt）
需要在 `lib/preset/prompt.dart` 中添加：

```dart
static const String actionSuggestionPrompt = '''
你是一个TRPG游戏的行动建议生成器。根据DM（游戏主持人）刚刚描述的场景，为玩家生成3-4个合理的行动选项。

## 输入信息
- DM的最新消息：{dm_message}
- 玩家当前状态：HP {current_hp}/{max_hp}, MP {current_mp}/{max_mp}
- 背包物品：{inventory}
- 当前任务：{current_quest}

## 输出要求
1. 生成3-4个行动选项，每个选项包含：
   - emoji: 一个相关的表情符号
   - text: 简短的行动描述（10-20字）
2. 选项应该：
   - 符合当前场景逻辑
   - 提供不同类型的行动（探索、战斗、对话、策略等）
   - 考虑玩家当前状态（低血量时建议谨慎行动）
   - 富有创意但合理
3. 必须以JSON格式返回，不要返回任何其他内容：

{
  "suggestions": [
    {"emoji": "🔍", "text": "行动描述1"},
    {"emoji": "⚔️", "text": "行动描述2"},
    {"emoji": "💬", "text": "行动描述3"}
  ]
}

## 示例

DM消息："你站在一扇生锈的铁门前，门缝中透出微弱的光芒，空气中弥漫着腐朽的气息。"

输出：
{
  "suggestions": [
    {"emoji": "🚪", "text": "推开铁门直接进入"},
    {"emoji": "🔍", "text": "检查门上是否有陷阱"},
    {"emoji": "👂", "text": "贴近门听里面的动静"},
    {"emoji": "🔦", "text": "从门缝观察内部情况"}
  ]
}
''';
```

**使用说明**：
- 调用时机：每次DM消息流式传输完成后
- 使用模型：建议使用轻量级模型（如gpt-4o-mini）以提高响应速度
- 超时处理：如果生成失败，静默失败，不影响游戏继续（用户仍可手动输入）

---

## 8. 未来扩展（非MVP）

- [ ] 存档列表界面
- [ ] 角色卡片详情页
- [ ] 骰子投掷动画
- [ ] 场景背景图
- [ ] 音效/BGM
- [ ] 多角色存档切换
- [ ] 分支剧情回溯
- [ ] 成就系统

---

## 9. 注意事项

1. **不要跳转页面**：所有交互在 `trpg_page.dart` 内通过状态切换完成
2. **HUD必须持久化**：AI每次响应都要解析并更新数据库
3. **流式响应**：用户能看到AI逐字输出
4. **对话历史管理**：每次调用AI都要发送完整历史（system + messages）
5. **错误处理**：AI调用失败时友好提示，不丢失用户输入
6. **行动建议生成**：
   - 使用轻量级模型（如gpt-4o-mini）提高速度
   - 后台异步生成，不阻塞DM消息显示
   - 生成失败时静默失败，不影响游戏继续
   - 每次新的DM消息都重新生成建议（不缓存）
7. **数据库设计**：不使用外键约束，通过应用层逻辑保证数据一致性
