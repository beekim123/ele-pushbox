# 工程结构与扩展机制（有效）

2026-10-15 用户要求：项目代码目录要提前做好管理；以后局外会有商店、养成等系统，局内会加各种新机制，现在就要为可扩展性做准备。本文件是 Godot 工程（`game/`）和本仓库其余部分的结构规则；开发方（GPT）必须照此组织代码，偏离时先写进 `docs/status.md` 的「给设计负责人的问题」。

## 1 目标

1. **加新东西只加文件，不改一堆旧文件**：新机制、新货物、新系统、新模式都有固定的落点和步骤（第 5 节）。
2. **数据驱动**：数值、清单、文字都在 `content/` 和 `art/`，由工作台管理（[ids.md](ids.md)）；代码里不写死编号、路径和数值。
3. **规则可以离开画面测试**：核心规则和机制不依赖场景节点，全部能在 headless 里跑。
4. **工作台和游戏一一对应**：工作台的绘制与设计模型（`workbench/js/core/`）就是游戏对应模块的规格（第 7 节）。

## 2 分层（依赖只能向下）

```
app            启动、场景路由、全局单例（Registry、Events、Save、Settings、Locale）
presentation   画面与界面：地形着色、精灵、特效、生态、环境、界面、对话气泡、音频
modes          模式：lab（关卡）、delivery（配送）、hell（地狱）——把玩法和局外系统组合起来
meta           局外系统：钱包、商店、工坊、徽章、执照、委托、对话、好感、邮票、渡口
gameplay       局内玩法：关卡会话、格子规则、实体、机制（每个机制一个文件）
sim            SDK 封装：EleWorld、材料与 profile、逐 tick 结算、快照
core           纯基础：编号注册表、事件、随机数、存档结构与迁移、数据加载、属性修正
```

- 下层不知道上层存在：`gameplay` 不引用任何界面；`meta` 不直接调用界面，而是发事件，由 `presentation` 订阅后显示。
- `core`、`gameplay`、`meta` 里的类不继承 `Node`（用 `RefCounted` / `Resource`），这样能在测试里直接 new 出来。
- 系统之间不互相调用私有函数：要么通过 `Events` 发消息，要么通过注册表拿到对方公开的接口。

## 3 `game/` 目录

```
game/
  project.godot
  app/                 boot.gd、router.gd、autoload/（registry.gd、events.gd、save.gd、settings.gd、locale.gd）
  core/
    ids/               registry.gd（读 generated/id-map，get(uid) / all(domain)）
    events/            events.gd（全部事件名和参数的唯一清单）
    save/              schema.gd、migrations/v1_to_v2.gd …
    data/              loaders.gd（读 generated/content）
    stats/             stat.gd、modifier.gd（属性 = 基础值 + 修正，带上限，第 4.5 节）
    rng/               rng.gd（带种子，可重放）
  sim/                 ele_world.gd、profiles.gd、materials.gd、settle.gd、snapshot.gd
  gameplay/
    session/           level_session.gd、action.gd、settle_loop.gd、undo.gd、goals.gd
    grid/              grid_state.gd、classify.gd、rules/（support、move、ladder、dig、pour、water）
    entities/          player.gd、crate.gd（以后 monster/）
    mechanics/         mechanic.gd（基类）+ 每个机制一个文件：lever.gd、lift.gd、bin.gd、load_bridge.gd、portal.gd …
  modes/
    lab/  delivery/  hell/          每个模式：controller.gd + 本模式规则
  meta/
    wallet/  shop/  workshop/  badges/  license/  quests/  dialogue/  affinity/  stamps/  hub/
                                    每个系统：service.gd（规则与状态）+ 可选 ui 绑定，状态是存档里的一段
  presentation/
    render/            terrain/（着色器）、themes/、matter/、sprites/、fx/、ambient/、env/
    ui/
      screens/         每个 ui.screen.* 一个场景：lobby.tscn、chapters.tscn、hint.tscn、dialogue.tscn …
      widgets/         panel、button、keycap、bubble（对话气泡）、emote
    audio/
  generated/           只由导入脚本写：ids.gd、id-map.json、art/、themes/、materials/、content/
  tools/               import_art.gd、import_content.gd、check_ids.gd
  tests/               与源码同结构：core/、gameplay/、mechanics/、meta/、sdk/（样板）、levels/（回放）、ui/、refs/（参考图对照）
  reports/             verification.json
```

命名：文件和文件夹小写加下划线；每个脚本一个 `class_name`；机制文件名 = 机制编号（`mechanic:portal` → `gameplay/mechanics/portal.gd`）；界面场景名 = 界面资产名去掉 `ui.screen.`。

## 4 公共机制

### 4.1 编号注册表（Registry）

启动时读 `generated/id-map.json` 和 `generated/content/`。所有资源用 uid 取：`Registry.get("item:sandbag")`、`Registry.all("cargo")`。机制、局外系统、界面在启动时按 uid 注册自己，模式和关卡按 uid 找它们（[ids.md](ids.md)）。

### 4.2 事件（Events）

`core/events/events.gd` 是全部事件的唯一清单，每个事件写明参数。例子：`action_done(action)`、`settle_done(result)`、`level_won(level_uid, moves)`、`delivery_done(cargo_uid, recipient_uid, rating)`、`coins_changed(delta, reason)`、`item_bought(item_uid)`、`dialogue_requested(dialogue_uid)`、`quest_started(quest_uid)`。新系统要监听什么、发出什么，写进自己的设计文档。

### 4.3 存档

一个文件 `user://progress.json`，带 `version`，先写临时文件再改名。每个系统拥有自己的一段（`progress`、`wallet`、`workshop`、`badges`、`license`、`quests`、`dialogue_seen`、`affinity`、`stamps`、`hub`、`settings`），通过 `get_state()` / `set_state()` 读写；不认识的段原样保留。结构变化时加一个迁移脚本，旧存档按版本一步步升级。

### 4.4 机制接口

`gameplay/mechanics/mechanic.gd` 定义每个机制可以实现的钩子，关卡会话按固定顺序调用：

| 钩子 | 什么时候 |
|---|---|
| `setup(spec, session)` | 读关卡规格里属于自己的部分（`devices`、地图字符） |
| `actions()` / `try_action(a)` | 提供或拦截玩家动作（开关的 ↑、挖、倒…） |
| `on_settle_step()` | 结算每一轮（重力、水、桥的载重、传送阵…），返回是否有变化 |
| `goals()` | 提供目标灯（收集斗） |
| `get_state()` / `set_state()` | 撤销快照和存档 |
| `observe()` | 观察模式要显示的信息 |

机制之间不直接调用：顺序由会话决定，数据通过会话的格子状态共享。设计模型 `tilemodel.js` 里的 `settle` 顺序就是这个顺序的规格。

### 4.5 属性与修正

移动间隔、生命、背包格、灯光半径、价格折扣这类数值都用 `Stat`：基础值来自目录（`upgrades.json` 等），再叠加带来源的修正（工坊等级、增益、徽章、加急令），按规则合并并截到上限（例如移动间隔的加成合计最多 35%）。新系统只是"再加一个修正来源"，不需要改用到这个属性的代码。

### 4.6 功能开关

`content/catalog/modes.json` 等目录里的 `status` 和设置里的"开放全部关卡"决定哪些模式、组、系统显示出来；没做完的系统保留代码但不显示，不靠注释掉代码。

## 5 怎么加新东西

| 要加什么 | 步骤（顺序不能反） |
|---|---|
| **新机制** | ① 工作台：`mechanisms.json` 加一条（[game-design.md](game-design.md) 6.7）；② 设计负责人在 `tilemodel.js` 写规则、在 `matter.js` 画法、写一关规格并通过设计模型；③ 美术候选确认；④ 游戏：`gameplay/mechanics/<编号>.gd` + 单元测试 + 关卡回放；⑤ 验证报告 |
| **新内容条目**（货物、收件人、怪物、道具、徽章…） | 只改 `content/catalog/` 和美术；游戏代码不动（行为不同时，就是新机制） |
| **新局外系统**（商店、工坊、委托…） | ① 设计文档 `docs/design/<系统>.md`（数据、事件、存档段、界面）；② 数据目录 `content/catalog/<系统>.json` 和新的编号空间（`tools/lib/ids.mjs`）；③ 界面布局 `ui.screen.<系统>` 在工作台画好并确认；④ 游戏：`meta/<系统>/service.gd` + 存档段 + 事件 + `presentation/ui/screens/<系统>.tscn` + 测试 |
| **新模式** | `modes.json` 加模式、`groups.json` 加组；游戏 `modes/<模式>/controller.gd`，复用 `gameplay` 与 `meta` |
| **新对话、委托** | 只加数据（[dialogue.md](dialogue.md)） |
| **新界面文字** | `content/i18n/`（由美术负责人确认）或开发方的 `content/i18n-extra/` |

## 6 本仓库的目录

| 目录 | 放什么 | 谁维护 |
|---|---|---|
| `docs/design/` | 每个系统一份设计文档（总纲、规则、各模式、地区、角色、养成、对话、编号、本文件…） | 设计负责人 |
| `content/catalog/` | 全部清单数据，一个目录一种东西 | 设计负责人 |
| `content/rooms/<地区>/` | 配送模式的房间模板（`pushbox.room/1`） | 设计负责人 |
| `content/levels/<模式>/<组>/` | 关卡规格 | 设计负责人（以后的批次可由开发方细化，审核后合入） |
| `content/i18n/`、`content/i18n-extra/` | 文字 | 美术负责人 / 开发方 |
| `content/dialogue/`、`content/quests/`（以后） | 对话、委托数据 | 设计负责人 |
| `content/export/` | 生成：`content-manifest.json`、`id-map.json` | 工具 |
| `art/` | 美术源数据、确认记录、导出 | 美术负责人 |
| `workbench/js/core/` | 绘制规则与设计模型（游戏的规格） | 美术 / 设计负责人 |
| `workbench/js/app/views/` | 工作台页面，一个页面一个文件 | 工作台负责人 |
| `tools/`、`tools/lib/` | 构建、检查、导出脚本，一个流程一个入口（`art.mjs`、`content.mjs`、`check-levels.mjs`），公共部分放 `lib/` | 工作台负责人 |
| `tests/` | 流程测试（临时目录）与工作台浏览器测试 | 工作台负责人 |
| `game/` | Godot 工程（第 3 节） | 开发方 |

## 7 工作台与游戏的对应

| 工作台（规格） | 游戏 |
|---|---|
| `tilemodel.js` 的格子规则、水、机关 | `gameplay/grid/`、`gameplay/mechanics/` |
| `terrain.js`、`ambient.js`、`env.js`、`matter.js` | `presentation/render/` |
| `scene.js` 的关卡画面与 HUD | `presentation/render/` + `presentation/ui/widgets/` |
| `ui.js` 的各界面 | `presentation/ui/screens/` |
| `dialogue.js` 的气泡排版 | `presentation/ui/widgets/bubble` |
| `rooms.js`（配送房间模板：口位、翻转、封口） | `modes/delivery/rooms.gd` |
| `mapgen.js`（配送地图生成：随机数与取数顺序都是规格） | `modes/delivery/mapgen.gd`，用 `content/export/delivery-golden.json` 对照 |
| `delivery-scene.js`（配送房间的画法） | `presentation/render/`（实体美术确认后） |
| `content/export/id-map.json` | `generated/` + `core/ids/registry.gd` |

游戏实现与规格不同时，以 SDK 实测为准、记录差异，交设计负责人改规格；不要只改游戏。
