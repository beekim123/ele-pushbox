# 交接提示词：重构《箱途 / Cratebound》Godot 游戏本体

> **状态：暂停（2026-10-15 用户决定："目前暂时还不要开始做"）。** 已按 GD-3 修订：游戏分为关卡模式、地狱模式、配送模式，本次只做**关卡模式**。用户说开始后，再把「你的任务」到文末交给开发方。美术 75 项全部已由用户确认（`APR-0001`、`APR-0002`，见 `art/approvals.json`）。
>
> 使用方法：把下面「你的任务」到文末的全部内容交给开发方（GPT / Codex）。它可以独立使用，不依赖任何聊天记录。

---

## 你的任务

你负责重构横版推箱解谜游戏的 Godot 本体（现名《箱途 / Cratebound》，新名待用户从 `docs/design/naming.md` 中挑选）。主角是一名什么都送的配送员；游戏有三个模式（`docs/design/vision.md`）。**本次只做关卡模式**：每关只演示一个机制（SDK 机制或游戏层机制），地图都很简单；它同时是新机制的试验场和 SDK 的回归测试。分两个阶段：

- **阶段一**：按新的设计规格从零建一个干净的 Godot 工程，用真实 SDK 做出**基础组 7 关（M01–M07）+ 全套菜单**的可玩闭环，并自动生成验证报告。
- **阶段二**：按关卡计划 `content/catalog/groups.json`，逐组细化并实现水、爆破、反应与气体、冷与热四个组（共 20 关），每组交设计审核。

地狱模式和配送模式只有设计稿，**不在本次范围**。玩法设计、美术、HTML 工作台和交付工具由另一位负责人（Claude）负责，美术已经用户确认。你的职责是实现和验证，阶段二还要把概念卡细化成具体关卡。你**不**重新设计玩法规则、**不**画美术、**不**改动已确认的美术数据和设计目录。

## 0 硬性规则（每一条都必须遵守）

1. **可以彻底重构。** 旧实验项目的代码、目录、测试、冻结规则都不需要兼容，新工程从零写。
2. **只用已确认的美术。** 正式画面只能使用 `art/export/manifest.json` 中 `approved` 不为空的条目，PNG 的 SHA-256 必须与 `approved.png_sha256` 一致。不得自行换图、改画、重画，也不得回退到旧实验素材。
3. **已确认美术的冻结区，不得修改**（改了会让内容哈希变化，确认失效，发布构建无法通过）：
   - `art/source/**`、`art/approvals.json`、`art/history/**`、`art/export/approved/**`；
   - `workbench/js/core/` 下的 `raster.js`、`sprites.js`、`font-data.js`、`terrain.js`、`ambient.js`、`env.js`、`matter.js`、`scene.js`、`ui.js`、`i18n.js`、`tilemodel.js`：它们是主题、材料、机关与界面的绘制规则，也是你移植时的规格；
   - `content/i18n/zh-Hans.json`、`content/i18n/en.json`：已确认界面的文字；
   - `content/catalog/**`：模式、机制组、关卡计划、机制目录（设计负责人维护）。关卡计划需要调整时（例如某关在 SDK 中做不出可靠效果），写进「给设计负责人的问题」。
   发现上述文件有错误时，不要自己改，写进 `docs/status.md` 的「给设计负责人的问题」。需要**新增**界面文字（游戏内提示、错误信息等）时，放进新文件 `content/i18n-extra/<语言>.json`，两种语言都要写，并在 status 中列出新增的键。
4. **缺少的资产不要自己画。** 第 2–5 章的机关、材料着色和特效已在工作台中画好（第 4 节「第 2–5 章美术候选」），照着它们实现，不要另画；用户确认之前它们只能在开发构建中当占位（显示占位标记）。工作台里也没有的资产，把名称、尺寸、帧数、用途写进 status 的「待美术」清单，开发期间可以用纯色方块加文字标签作临时替身，但必须明显标出"占位"；发布构建遇到占位或未确认资产必须报错退出。
5. **关卡必须用真实 SDK 验证。** 每关都要在 Godot headless 中用真实 SDK 回放作者解并通关。设计模型（`tools/check-levels.mjs`）和 HTML 演示都不能代替。
6. **测试可以按新规格重建，但不能靠删除必要验证来掩盖问题。** 旧报告、旧安装包和旧测试成绩都不能证明新项目通过。
7. **验证结论必须如实。** 没运行过的写"未运行"；失败就贴出输出；模型推演和 HTML 动画不能说成"已验证"。
8. **资源预算**（用户机器 16 GB 内存）：全机最多 2 个耗资源任务、2 个计算 worker，默认单 worker；数值库线程数设为 1；启动计算前检查其他进程；不要在后台堆叠任务；结束时清理自己启动的进程。
9. **每次工作结束都更新 `docs/status.md`**：完成了什么、当前阶段、实际验证了什么、还缺什么、下一步由谁做。
10. **游戏和工作台读同一份数据**：Godot 只从 `content/export/content-manifest.json` 读取模式、组和关卡顺序，并用其中的 `sha256` 校验每个关卡规格文件；`node tools/content.mjs check` 必须没有错误。每次运行 headless 测试都写 `game/reports/verification.json`（格式见 `docs/design/workbench.md` 第 4 节）并提交，工作台据此显示每关、每个机制的验证状态。

## 1 项目位置与旧内容隔离

- 仓库：`https://github.com/beekim123/ele-pushbox`，基于分支 `claude/inspiring-ride-zfnn4s` 工作（或用户指定的后续分支）。用户本机的工作副本在 `/Users/key_/Desktop/CURRGO/pushbox-demo`。
- **决定：在本仓库内原地重构，新 Godot 工程放在 `game/`**（`game/project.godot`）。仓库根目录不放 Godot 工程文件。
- 旧实验项目完整保存在提交 `0fae58c`（分支 `codex/art-ui-polish`）与 `main`，**只作参考，不得复制回工作树**。查看旧的 SDK 接入写法时：

```sh
git show 0fae58c:pushbox/scripts/session.gd     # 逐 tick 结算、静止判定、快照撤销
git show 0fae58c:pushbox/scripts/board.gd       # 格子分类、箱子写入、浮箱、闸门
git show 0fae58c:pushbox/scripts/level_loader.gd
git show 0fae58c:pushbox/content/default/materials.json
```

旧代码中经过实测的做法（唤醒休眠水体、箱子逐格写回）可以参考，但要按新规格重写。不要带回旧的整局预演、六主题 36 关结构和代码生成美术。

## 2 有效文档（按优先级）

1. `docs/design/vision.md`：总纲（三个模式、路线图）。`docs/design/game-design.md`：**玩法规则与关卡模式（GD-3）**，包括格子规则、材料、机关、关卡模式的组与关卡、系统、界面和验证分层。
2. `content/catalog/`：关卡计划（`groups.json`）、机制目录（`mechanisms.json`）等；`content/levels/lab/basics/M01–M07.json`：基础组 7 关的完整规格（地图、背包、作者解、三级提示、常见误解、SDK / 游戏层分工、验收条目），`chapter` 字段是主题键 `dungeon`。
3. `docs/reference/sdk-v1.2-verified.md`：逐条核对源码的 SDK 事实，以及由此得出的工程约束。
4. `docs/design/art-pipeline.md`：美术交付规则，包括 manifest、确认状态、导入设置和参考图对照。
5. `docs/design/art-direction.md`：美术规范，第 6 节生态、第 7 节多语言、第 8 节主题地形、第 9 节环境效果。
6. `docs/design/asset-inventory.md`：资产清单，以及尚未制作的资产。
7. `docs/audit/2026-10-15-design-audit.md`：审核的问题与决定，用来理解"为什么"。
8. SDK：`third_party/ele-sdk/`（macOS arm64 动态库与许可证）；源码在 `https://github.com/beekim123/ele-base-cpp` 提交 `dacb93e`，接口见 `api/godot-1.2.txt`、`sdk/INTEGRATION.md`。
9. HTML 工作台 `workbench/index.html`：双击即可打开，能看到总览、各组关卡与机制的状态、所有已确认美术、六个主题与第 2–5 组的代表场景、各关的格子模型推演和中英文界面。实现时随时拿它对照（`docs/design/workbench.md`）。

**明确不做**：地狱模式、配送模式（只有设计稿）；关卡模式中的俯视、跳跃、敌人、倒计时、整局预演模拟、星级评分；前 5 组不使用气压、粒子、刚体、电路、温度相变冰桥（设计第 5、9 节，以后按 6.7 进实验组）。音效与音乐尚无素材：设置里的音量滑杆先保留并保存数值，不要自己找素材。

## 3 游戏结构与实现要求

### 3.1 工程结构（建议，可调整，调整后在 status 中说明）

```
game/
  project.godot            # 320×180 视口，整数缩放（stretch mode viewport + integer），最近邻，默认窗口 1280×720
  bin/                     # 引用 third_party/ele-sdk 的动态库（复制或配置 gdextension 路径，写进 README）
  scripts/core/            # 纯规则：关卡规格解析、格子分类、动作合法性、游戏层状态（不依赖节点，便于 headless 测试）
  scripts/sim/             # SDK 封装：EleWorld、profile / 材料、命令提交、逐 tick 结算、静止判定、快照
  scripts/render/          # 地形与背景着色、生态、环境效果、精灵、HUD
  scripts/ui/              # 大厅、章节轮播、关卡选择、暂停、设置、提示、过关、规则卡
  scripts/i18n/            # 读取 content/i18n 与 content/i18n-extra，注册到 TranslationServer
  content/                 # 材料、反应、profile（按组）；关卡清单读 content/export/content-manifest.json，规格读仓库的 content/levels/
  tools/import_art.*       # 从 art/export 导入已确认美术（见第 4 节）
  tests/                   # headless 测试与参考图对照；每次运行写 game/reports/verification.json
```

### 3.2 规则

严格实现设计第 4 节：支撑与下落、水平移动的优先级、登阶、梯子、挖取、倒沙、压板与门、目标灯。`workbench/js/core/tilemodel.js` 是这些规则的参考实现。用 Godot 实现后，对每关作者解逐步比较游戏层局面（人物、箱子、格子类别、背包、门），与模型推演的结果对照。凡是 SDK 物理导致结果不同的地方，记录下来，以 SDK 结果为准，并写进 status 交给设计负责人调整关卡。

### 3.3 SDK 接入

- 世界 320×192、`cell_scale = 1`、`threads = 1`、`auto_step = false`；1 格 = 16×16 cell；关卡最大 20×10 格，居中放在 20px 高的 HUD 条下方。
- 基础组 profile 只启用 `cells`。材料至少包括：`empty`、`bedrock`（static，抗爆 65535）、`packed_earth`（static，tag `diggable`）、`sand`（powder）、`crate`、`iron_crate`、`gate`（static）。后续各组按设计第 6.1 节逐组加入求解器。
- 结算按设计 3.3：逐 tick 推进；连续 4 tick 静止才算结束；上限 1200 tick 或 16 轮，触顶报异常。动画每帧 4 tick，可快进。温度类装置使用固定阶段（Godot 侧读不到 thermal 是否还在活动）。
- 格子分类：一格 256 个 cell 中，某一类别 ≥128 个即归为该类。
- 箱子是游戏层实体，同时以 16×16 个 static cell 写入 SDK。移动、挖取、倒沙、门开关都是"清除 + 写入"。按设计 3.4，禁止搬运正在燃烧、带寿命或温度异常的材料。
- 倒沙使用画笔模式 2（只写空格或流体格），不要覆盖箱子。
- 有水的关卡：开闸或箱子离开后，按旧 v0.3 的做法唤醒相邻水体（重写水体中的一个 cell）。
- 撤销：每个动作前 `save_snapshot`，同时保存游戏层状态 JSON；最多 200 步；按住 Z 连续撤销。重开读取开局快照，重开本身也算一步撤销。

### 3.4 系统与界面

- 按设计第 7、8 节实现：撤销、重开、三级提示（含"演示"和"回到正确位置"）、跳关与规则卡、观察模式（按住 Tab）、目标高亮（只按规则计算，不运行模拟）、存档（`user://progress.json`，先写临时文件再改名，带 `version`）、引导。
- 界面：大厅、章节（地图）轮播、关卡选择、局内 HUD、暂停、设置、提示面板、过关、规则卡。布局、元素、配色以已确认的 `ui.screen.*` 和参考图 `art/export/reference/<界面>.<语言>.png` 为准。具体要求：
  - **大厅**：背景、地面、生态和环境效果随玩家当前所在组的主题切换；右侧小场景（矿工推箱、高台出口旗）；菜单项带图标，面板宽度随文字伸缩。
  - **章节轮播**：当前地图是中间大卡（主题小景、徽章、章号、进度或锁），两侧依次缩小，外侧再压暗一级；下方依次是名称、页码指示（当前为长条）、左右键、说明栏。←→ 或点击两侧卡片切换，切换时滑动约 1 秒（带缓动）。地图数量不限：16 张以内显示页码点，更多时显示"当前 / 总数"。规格见 `workbench/js/core/ui.js` 中的 `chapters` 与 `slotAt`。
  - **设置**：语言、音乐、音效、窗口放大、环境效果（全部 / 只要光照 / 关闭）、显示网格、开放全部关卡、重看引导。
- 键位：方向键 / WASD 移动；Shift + 方向挖；Ctrl + 方向倒沙；B + 方向放炸药（第 3 组起）；Z 撤销；R 重开；H 提示；按住 Tab 观察；Esc 暂停。鼠标：左键点相邻格挖，右键点相邻格倒，拖动炸药图标放置；指针使用 `ui.cursor`。

### 3.5 多语言

- 界面文字只能来自 `content/i18n/*.json`（简体中文、英文）和你新增的 `content/i18n-extra/*.json`，用 TranslationServer 加载（可以写脚本转成 CSV 或 .po，但源文件只有这一份）。占位符 `{name}` 要正确替换，不拼接句子。
- 游戏名取 `game.title`；关卡标题、一句话发现、三级提示取 `level.<编号>.title / discovery / hint.<n>`。
- 界面用 Container（HBox / VBox / Margin）加最小、最大宽度搭建，不按像素硬编码文字位置。段落自动换行（中文按字、英文按词，标点不出现在行首），单行文字超出时显示省略号。
- 开发构建中检测文字溢出并输出日志。测试要覆盖：中、英两种语言下所有界面零溢出（规则同 `tools/art.mjs` 中的 `textIssues`）。
- 字体：`third_party/fonts/fusion-pixel-12px/`，12px，最近邻，关闭抗锯齿与 hinting。工作台用同一字体预先渲染了字形，Godot 直接用字体文件；两者若有像素差异，记录到 art-pipeline 第 7 节。

### 3.6 主题、生态与环境效果

- 六个主题：`theme.dungeon` 幽暗石牢（第 1 组 基础）、`theme.ruins` 黄金神庙（第 2 组 水）、`theme.cave` 幽光晶窟（第 3 组 爆破）、`theme.forest` 迷雾古森（第 4 组 反应与气体）、`theme.sky` 云端圣域（第 5 组 冷与热）、`theme.cosmos` 深空星站（第 6 组 实验）。阶段一只有第 1 组有关卡，但大厅和章节轮播会用到全部六个主题，所以六个都要实现。界面上仍显示"第 N 章"。
- **地形不是贴图。** 把 `terrain.js` 的规则移植成着色器，使用同一个 `h32` 位置哈希和同样的邻格规则。每个主题有不同的基岩图案：`brick` 砖墙、`block` 砂岩大石块、`rough` 岩洞、`grass` 草皮褐土、`cloud` 云朵（圆角）、`panel` 舱板加警示条。参数取自主题资产的 `params`。夯土与裂岩**自带方块轮廓**（外圈深色、左上亮边），这是辨识规则，必须保留。
- 推荐渲染做法：一个着色器同时采样 SDK 的两块瓦片纹理（世界宽 320，只有两块），避免 256 格接缝处读不到邻格（EXT-10）；不可行时，读取 `get_material_ids` 生成整张材料纹理。沙、水的颗粒颜色使用 SDK 的随机颜色位。
- **生态**（`ambient.js`，美术规范第 6 节）：植物按开局布局放置，位置不随局面变化。会动的小动物每关最多 1 只，由 `seedOf(关卡编号)` 和各自的 `chance` 决定（`pickMover` 的 `sparse` 模式）；大厅与章节卡用 `one` 模式。
- **环境效果**（`env.js`，美术规范第 9 节）：光照只作用于背景层（在地形与实体之前绘制），地形、箱子、人物、机关的颜色不变。天气每关最多一种，稀疏、低对比，画在实体之上、HUD 之下；关卡可用规格字段 `weather` 指定，不写就用主题默认。设置中的三档要实际生效。
- 所有运动都是整数、按 tick 计算，可以照抄公式。

## 4 美术集成（已确认，正式使用）

- 开工先运行：`node tools/art.mjs build && node tools/art.mjs verify`（Node 18+，无依赖），确认输出以 `verify ok` 开头、`build` 没有 `bumped`、`content: 0 error(s)`。之后只读取 `art/export/manifest.json`，每项是否可用看 `approved` 与 `current_is_approved`。
- 已确认清单（`APR-0001`，全部 v1，界面布局 v2 见 `APR-0002`）：
  - 角色：`char.miner`（21 帧：待机、走、推、爬、挖、倒、落、胜利；以后可能改画成配送员，届时会有新版本和新的确认）
  - 物件：`obj.crate_wood`、`obj.crate_iron`
  - 机关：`mech.door`、`mech.plate`、`mech.link_symbol`、`mech.socket`、`mech.socket_lit`、`mech.exit_flag`、`mech.ladder`
  - 物品：`item.sandbag`、`item.bomb`
  - 特效：`fx.land_dust`、`fx.dig_bits`、`fx.goal_spark`
  - 界面元素：`ui.icons`、`ui.menu_icons`、`ui.theme_emblem`、`ui.goal_lamp`、`ui.keycap`、`ui.panel`（九宫格）、`ui.cursor`、`ui.target`、`ui.class_icon`
  - 小动物（9）：`fauna.dungeon_bat`、`fauna.dungeon_rat`、`fauna.ruins_scarab`、`fauna.cave_moth`、`fauna.forest_bird`、`fauna.forest_butterfly`、`fauna.sky_dove`、`fauna.sky_cloudling`、`fauna.cosmos_drone`
  - 植物与装饰（10）：`deco.dungeon_moss`、`deco.dungeon_torch`、`deco.ruins_vine`、`deco.ruins_lotus`、`deco.cave_mushroom`、`deco.cave_crystal`、`deco.forest_flower`、`deco.forest_grass`、`deco.sky_flower`、`deco.cosmos_sprout`
  - 主题（程序化，6）：`theme.dungeon`、`theme.ruins`、`theme.cave`、`theme.forest`、`theme.sky`、`theme.cosmos`
- 已确认清单（`APR-0002`，第 2–5 组与界面）：
  - 材料（程序化）：`material.chapter2_5`，规则在 `workbench/js/core/matter.js` 的 `SHADE`：碎石、引信、酸液、软岩 A / A′（同一刻纹）、硬岩、轻烟、沉雾、菌塞、木栅、冰；
  - 第 2 组：`mech.lift`（台面 + 导轨）、`mech.button`、`mech.bin`（内衬）、`mech.bin_gauge`（0–4 + 满）、`fx.splash`、`fx.ripple`（水上木箱下沉 3 px 并画波纹）；
  - 第 3 组：`fx.explosion`（32×32，锚点居中）、`fx.rubble`；第 3、5 组：`fx.fire`；
  - 第 4 组：`mech.lever`、`mech.vine`（根 / 茎 / 顶）、`fx.fizz`；
  - 第 5 组：`mech.torch`、`mech.frost_vent`、`mech.heat_vent`、`fx.frost`；
  - 观察模式：`ui.rule_icon`（上浮、下沉、可燃、可酸蚀、冰、慢速粉末）；
  - 界面布局（程序化，8，v2）：`ui.screen.lobby`、`chapters`、`levels`、`pause`、`hint`、`complete`、`settings`、`rulecard`（与 v1 逐像素相同）。
  - 机关和材料的画法（摆放位置、作用区虚线框、开关连线、收集斗刻度计算、水上木箱）按 `matter.js` 的 `drawDevices`、`floating`、`drawObserve`，与美术规范第 11 节一致。每组的整体效果见工作台「场景」页「第 2–5 章代表场景」和 `art/export/reference/chapter.<主题>.png`。
- 写导入脚本 `game/tools/import_art.*`：
  - 只复制 `approved.png`（`art/export/approved/<id>@v<N>.png`），并校验 `png_sha256`；
  - 按 manifest 生成 SpriteFrames / AtlasTexture。图集是横向条带，第 i 帧位于 `x = i × 帧宽`；锚点、动画帧序、fps、是否循环、九宫格边距都取自 manifest，不在游戏里另行定义；
  - 导入设置：Filter Nearest，关闭 mipmap，无损；
  - 程序化资产（主题、界面）没有可直接使用的贴图：主题读取 `params` 由着色器和脚本绘制；界面按参考图用 Control 实现。
- **对照验证**：在 Godot 中把以下画面渲染到 320×180 视口并截图，与 `art/export/reference/` 中的同名 PNG 逐像素比较：
  - M01–M07 的开局状态，**关闭环境效果**，对照 `level.M0x.png`；
  - 六个主题的代表场景（地图见 `scene.js` 中的 `SHOWCASE`），对照 `showcase.<主题>.png`，默认环境效果，第 0 帧；
  - 各界面的中、英文版本，对照 `<界面>.<语言>.png`；
  - 阶段二：四个章节代表场景（地图见 `matter.js` 中的 `SHOWCASES`，含插图用的 `preview` 与 `fx` 状态），对照 `chapter.<主题>.png`，默认环境效果，第 0 帧。

  沙、水只比较颜色集合。差异必须写进 `docs/design/art-pipeline.md` 第 7 节并说明原因，不能用"差不多"代替。

## 5 实施顺序与首个可玩闭环

1. **工程骨架**：`game/` 能启动、能加载 SDK；320×180 整数缩放窗口；单 worker。
2. **SDK 样板测试**（先于关卡），每项都要有测试和结果记录：
   - (a) 靠墙倒一袋沙，邻格溢出量 < 128 cell；
   - (b) 挖掉夯土后，上方的夯土不掉落；
   - (c) 箱子逐格写入、移动后材料守恒；
   - (d) 基础组材料下静止判定稳定；
   - (e) 快照撤销后，游戏层局面与 SDK 局面完全一致。
3. **核心规则 + 结算**：headless 回放 M01–M07 作者解全部通关，并与设计模型逐步对照；测试结束写出 `game/reports/verification.json`，工作台「模式与关卡」页能看到 M01–M07 的 SDK 验证状态。
4. **美术导入、地形着色器、主题**：六个主题全部实现；参考图逐像素对照。
5. **首个可玩闭环（第一个里程碑）**：大厅 → 章节轮播 → 关卡选择 → M01–M07 可玩。包括 HUD、撤销、重开、三级提示、观察、目标高亮、过关、存档、设置（含语言、环境效果）、暂停、规则卡、生态与环境效果。中、英文都可用。
6. **性能与打包**：见第 6 节；macOS arm64 可以双击启动。
7. 阶段一的里程碑通过后，进入阶段二（第 5b 节）。

**阶段一里程碑的完成标准**：第 6 节表格中除"新手试玩"外的每一项都有可重复运行的命令和通过的结果；`node tools/art.mjs verify` 仍然通过；`docs/status.md` 写明运行方式、验证结果、已知差异和待办。

## 5b 阶段二：关卡模式第 2–5 组

按组的顺序做：第 2 组 水（黄金神庙）→ 第 3 组 爆破（幽光晶窟）→ 第 4 组 反应与气体（迷雾古森）→ 第 5 组 冷与热（云端圣域）。第 6 组实验（深空星站）现在没有关卡，**不做**；它的主题已在大厅和章节轮播中实现，保持"未开放"。原第 2–5 章概念卡中的组合关（W06、Q05、Q06、G07、F05、F06）已移入地狱模式候选池，**不做**。

每一组都按下面的流程走（详见设计 6.4–6.7）：

1. **SDK 样板先行**：为本组每种机制做最小场景并写成测试，先验证概念卡里的【待验证】项和阶段长度。关卡模式的关卡本身就很小，样板通过后通常可以直接扩成关卡。各组要验证的内容：
   - **第 2 组**：开闸后唤醒水体；木箱浮起、铁箱下沉的游戏层规则；一袋沙能抬高多少水位；U 形管两侧液面拉平；升降台受阻时拒绝移动；收集斗计数与锁存。
   - **第 3 组**：`explode(格中心, 20, 8000)` 的崩落结果与十字高亮一致；隔墙爆破；引信燃烧时长与固定阶段；碎石（`move_chance`）结算时长不触顶。
   - **第 4 组**：酸蚀只作用于同标签岩石、不留残渣；轻烟上浮、沉雾下沉，进入收集斗的计数；菌塞寿命到期后释放；藤梯的根部水量判定。
   - **第 5 组**：火盆点燃木栅的固定阶段、燃烧不蔓延到不该烧的地方；冷凝 / 热喷口当 tick 转换水与冰（`stride = 1`）；爆炸点燃半径一半内的可燃物；冰无自然融化。
2. **细化关卡规格**：按关卡计划（`content/catalog/groups.json`）、概念卡和设计 6.5 的格式与图例，写 `content/levels/lab/<组>/<编号>.json`（组目录：`water`、`blast`、`react`、`thermal`），`mode`、`group`、`mechanisms` 必须与计划一致，`node tools/content.mjs check` 没有错误。关卡文字写进 `content/i18n-extra/zh-Hans.json` 和 `en.json`。遵守 6.6 的难度预算：每关只演示一个机制，作者解约 4–12 步、不超过 16 步，不超过 20×10 格，不要求精确时机。某关在 SDK 中做不出可靠效果时，写进「给设计负责人的问题」，由设计负责人调整计划。
3. **实现机关与材料**：材料、反应、profile 写进 `game/content/`；机关按设计 6.5 的 `devices` 定义实现，状态要进入撤销快照和存档。
4. **真实 SDK 验证**：每关作者解通关，连续回放 3 次结果一致，每一步可撤销，结算不触顶；记录 tick 数与截图。
5. **交审核**：每完成一组，把规格清单、验证结果（验证报告）、截图和问题写进 `docs/status.md` 的「给设计负责人的问题」，等审核通过再做下一组。审核前，这些关卡只在"开放全部关卡"设置下可以进入。
6. **美术**：本组的美术都已确认（第 4 节 `APR-0002`），按第 4 节导入。唯一还缺的是"放置炸药"的人物动作，可暂用"倒"的动作，并写进 status 的「待美术」清单。

**阶段二每组的完成标准**：本组 SDK 样板测试全部通过；验证报告中本组每关都验证通过；全部关卡作者解在真实 SDK 中通关并可重复；撤销与存档覆盖新机关状态；中、英文关卡文字齐全且零溢出；设计负责人审核通过。

## 6 验证（每项都要有可重复运行的命令和记录下来的结果）

| 类别 | 内容 |
|---|---|
| 规则单元测试 | 设计第 4 节每条规则至少一个正例、一个反例（推箱链被拒、两格高登不上、梯子格不下落、门内有物不关闭等） |
| SDK 样板 | 第 5 节第 2 步的 (a)–(e) |
| 关卡回放 | M01–M07（阶段二起包括各组全部关卡）作者解在真实 SDK 中通关；同一关连续回放 3 次，游戏层局面与 `get_state_hash()` 序列都一致；每一步撤销后局面恢复 |
| 设计模型对照 | 每步游戏层局面与 `tilemodel.js` 推演一致，不一致处有记录和原因 |
| 界面 | 键盘可完成全部流程；鼠标点击区域与画面一致；窗口缩放保持整数倍；存档损坏时能恢复；语言切换即时生效；中、英文所有界面零溢出 |
| 美术 | 发布构建只含已确认资产（哈希校验）；参考图逐像素对照结果（写进验证报告的 `references`）；`node tools/art.mjs verify` 通过 |
| 内容一致性 | Godot 只从 `content-manifest.json` 读关卡清单并校验规格哈希；`node tools/content.mjs check` 无错误；验证报告与本次提交一起更新 |
| 生态与环境 | 同一关每次进入的植物、小动物完全相同；环境效果三档切换生效；光照不改变实体像素（关闭与开启时比较实体区域） |
| 性能 | 60 fps；结算期间单帧主线程耗时 ≤ 4 ms（记录峰值，含环境效果）；撤销 ≤ 100 ms；内存峰值有记录 |
| 新手试玩 | 由用户组织，你不能代替；你只需要提供可运行的构建 |

## 7 启动、交付与记录

- 启动：在仓库根目录提供 `run.sh` 和 `Run Game.command`，找到 Godot 4.7.2（可用环境变量 `PUSHBOX_GODOT_BIN` 覆盖）后运行 `game/`。测试入口为 `tools/run-tests.*`，默认单 worker。
- 交付内容：`game/` 工程；测试与结果日志（放在 `game/tests/results/`，或在 status 中写明位置）；验证报告 `game/reports/verification.json`；更新后的 `docs/status.md`；新增文字键清单；待美术清单；已知限制与跨渲染器差异。
- 已知限制：SDK 只有 macOS arm64 动态库（Godot 4.7.2，macOS 15.6+）；其他平台需要重新编译 SDK（`third_party/ele-sdk/prepare_sdk.sh.legacy` 是旧构建脚本，仅供参考）。
- 进度记录：只写 `docs/status.md`。玩法与美术问题写进其中的「给设计负责人的问题」，不要直接改设计文档和冻结区文件。
