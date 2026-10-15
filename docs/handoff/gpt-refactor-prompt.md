# 交接提示词：重构《箱途 / Cratebound》Godot 游戏本体

> **状态：交接草稿（美术尚待用户确认）。** 生成时间 2026-10-15。截至目前，`art/approvals.json` 中没有任何确认记录，因此**所有美术都只能作为占位使用**。用户确认后，由 Claude 更新本文件第 4 节和 `docs/status.md`，把状态改为"可集成正式美术"。在此之前，你可以完成全部不依赖正式美术的工作（见第 6 节）。
>
> 下面是直接交给开发方（GPT / Codex）的完整提示词，可以独立使用，不依赖任何聊天记录。

---

## 你的任务

你负责重构横版推箱解谜游戏《箱途 / Cratebound》（旧名「推箱子：沙与水」）的 Godot 本体：按新的设计规格从零构建一个干净的 Godot 工程，用真实 SDK 做出第 1 章 7 关的可玩闭环，并为后续章节留好结构。设计、美术和工作台已经由另一位负责人（Claude）完成；你的职责是实现与验证，**不是**重新设计玩法或重画美术。

### 0 硬性规则（每一条都必须遵守）

1. **可以彻底重构**。旧实验项目的代码、目录、测试、冻结规则都不需要兼容；新工程从零写。
2. **正式美术只能使用用户确认的版本**：即 `art/export/manifest.json` 中 `approved` 不为空的条目，且 PNG 的 SHA-256 与 `approved.png_sha256` 一致。不得自行换图、改画、重画，也不得回退到旧实验素材。
3. **缺少已确认资产时**：可以加载 `current.preview` 作为占位，继续不依赖它的工作；但必须在画面上标出"占位"（例如角落里的小标记，可在设置中关闭），并在 `docs/status.md` 中列出。**占位不得当作最终素材**，发布构建遇到未确认资产必须报错退出。
4. **关卡必须用真实 SDK 验证**：每关都要在 Godot headless 中用真实 SDK 回放作者解并通关。设计模型（`tools/check-levels.mjs`）和 HTML 演示都不能代替。
5. **旧测试可以按新规格重建，但不能通过删除必要验证来掩盖问题。** 旧报告、旧安装包和旧测试成绩都不能证明新项目通过。
6. **验证结论必须如实**：没有运行过的就写"未运行"；失败就贴出输出。不得把占位美术、模型推演或 HTML 动画说成已完成或已验证。
7. **资源预算**（用户机器为 16 GB 内存）：全机最多 2 个耗资源任务、2 个计算 worker，默认单 worker；数值库线程数设为 1；启动计算前检查其他进程；不要在后台堆叠任务；结束时清理自己启动的进程。
8. 每次工作结束都更新 `docs/status.md`：完成了什么、当前阶段、实际验证了什么、还缺什么、下一步由谁做。

### 1 项目位置与旧内容隔离

- 仓库：`https://github.com/beekim123/ele-pushbox`，在开发分支 `claude/inspiring-ride-zfnn4s` 上工作（或用户指定的后续分支）。用户本机的工作副本位于 `/Users/key_/Desktop/CURRGO/pushbox-demo`（用户机器）。
- **决定：在本仓库内原地重构，新 Godot 工程放在 `game/` 目录**（`game/project.godot`）。仓库根目录不再放 Godot 工程文件，避免与 `art/`、`workbench/`、`docs/` 混在一起。
- 旧实验项目完整保存在提交 `0fae58c`（分支 `codex/art-ui-polish`）与 `main`，**只作参考，不得复制回工作树**。需要查看旧的 SDK 接入写法时：

```sh
git show 0fae58c:pushbox/scripts/session.gd     # 逐 tick 结算、静止判定、快照撤销
git show 0fae58c:pushbox/scripts/board.gd       # 格子分类、箱子写入、浮箱、闸门
git show 0fae58c:pushbox/scripts/level_loader.gd
git show 0fae58c:pushbox/content/default/materials.json
```

旧代码里经过实测的做法（例如唤醒休眠水体的变通方法、箱子逐格写回）可以参考，但要按新规格重写；旧的整局预演、六主题、36 关结构都不要带回来。

### 2 有效文档（按优先级）

1. `docs/design/game-design.md` —— **唯一有效的玩法设计（GD-2）**：规则、章节、系统、界面、验证分层
2. `content/levels/ch1-mine/M01–M07.json` —— 第 1 章 7 关的完整规格：地图、背包、作者解、三级提示、常见误解、SDK / 游戏层分工、验收条目
3. `docs/reference/sdk-v1.2-verified.md` —— 逐条核对源码的 SDK 事实，以及由此得出的工程约束
4. `docs/design/art-pipeline.md` —— 美术交付规则：manifest、确认状态、导入设置、参考图对照
5. `docs/design/art-direction.md`、`docs/design/asset-inventory.md` —— 美术规范与资产清单
6. `docs/audit/2026-10-15-design-audit.md` —— 本轮审核的问题与决定（解释"为什么"）
7. SDK：`third_party/ele-sdk/`（macOS arm64 动态库与许可证）；源码 `https://github.com/beekim123/ele-base-cpp` 提交 `dacb93e`，接口见 `api/godot-1.2.txt`、`sdk/INTEGRATION.md`

**明确不做**：俯视章节、跳跃、实时敌人、倒计时、挑战 / 地狱模式、整局预演模拟、星级评分；主线中不使用气压、粒子、刚体、电路、温度相变冰桥（见设计第 5、9 节）。

### 3 游戏结构与实现要求

**3.1 工程结构（建议，可以调整，但要在 status 中说明）**

```
game/
  project.godot               # 320×180，整数缩放（stretch mode viewport + integer），最近邻
  bin/ → 引用 third_party/ele-sdk（复制动态库或配置 gdextension 路径；记录在 README）
  scripts/core/               # 纯规则：level 规格解析、格子分类、动作合法性、游戏层状态（无节点依赖，便于 headless 测试）
  scripts/sim/                # SDK 封装：EleWorld 创建、profile / 材料、命令提交、逐 tick 结算、静止判定、快照
  scripts/render/             # 地形着色器（移植 workbench/js/core/terrain.js）、精灵与 HUD
  scripts/ui/                 # 大厅、章节、关卡选择、暂停、设置、提示、过关、规则卡
  content/                    # 材料、反应、profile（按章节）；关卡直接读取 content/levels/*.json
  tests/                      # headless 测试
```

**3.2 规则**：严格实现设计第 4 节（支撑与下落、水平移动的优先级、登阶、梯子、挖取、倒沙、压板与门、目标灯）。`workbench/js/core/tilemodel.js` 是这些规则的参考实现：用 Godot 实现后，对每关作者解逐步比较"游戏层局面"（人物、箱子、格子类别、背包、门）与模型推演的结果。凡是 SDK 物理导致结果不同的地方，记录下来，以 SDK 结果为准，并通知设计负责人调整关卡。

**3.3 SDK 接入**

- 世界 320×192、`cell_scale = 1`、`threads = 1`、`auto_step = false`；1 格 = 16×16 cell；关卡最大 20×10 格，居中放置在 HUD 条下方。
- 第 1 章 profile 只启用 `cells`。材料至少包括：`empty`、`bedrock`（static，抗爆 65535）、`packed_earth`（static，tag `diggable`）、`sand`（powder）、`crate`、`iron_crate`、`gate`（static）。后续章节按设计第 6.1 节的表格逐章加入求解器。
- 结算：按设计 3.3 实现，即逐 tick 推进、连续 4 tick 静止判定、上限 1200 tick / 16 轮、触顶报异常。动画播放速度为每帧 4 tick，可快进。温度类装置使用固定阶段（Godot 侧读不到 thermal 是否仍在活动）。
- 格子分类：每格 256 个 cell 中某一类别 ≥128 即归为该类。
- 箱子：游戏层实体，同时以 16×16 个 static cell 写入 SDK；移动时先清除旧格再写新格。挖取、倒沙、门开关都是"清除 + 写入"。按设计 3.4，禁止搬运燃烧、带寿命或温度异常的材料。
- 倒沙使用画笔模式 2（只写空格或流体格），不要覆盖箱子。
- 有水的关卡：开闸或箱子离开后，按旧 v0.3 的做法唤醒相邻水体（重写水体中的一个 cell），否则液压求解器看不到新空出的格。
- 撤销：每个动作前 `save_snapshot`，同时保存游戏层状态 JSON；上限 200 步；按住 Z 连续撤销。重开读取开局快照，重开本身也算一步撤销。

**3.4 系统与界面**：按设计第 7、8 节实现撤销、重开、三级提示（含"演示"与"回到正确位置"）、跳关与规则卡、观察模式（按住 Tab）、目标高亮（只按规则计算，不运行模拟）、存档（`user://progress.json`，先写临时文件再改名）、引导，以及大厅、章节选择、关卡选择、暂停、设置、过关界面。界面的布局、字号和颜色以 `art/export/preview/ui.screen.*.png` 为准，用 Control 节点实现；文字使用 `third_party/fonts/fusion-pixel-12px/`，最近邻渲染，关闭抗锯齿与 hinting。

**3.4a 多语言**：界面文字只能来自 `content/i18n/*.json`（简体中文、英文），用 Godot 的 TranslationServer 加载（可以写脚本转成 CSV 或 .po，但源文件只有这一份）。界面用 Container（HBox / VBox / Margin）与最小、最大宽度搭建，不按像素硬编码文字位置；Label 开启按词或按字自动换行，单行文字超出时显示省略号。开发构建中检测溢出并输出日志，测试要覆盖中、英两种语言下所有界面都不溢出（参考 `tools/art.mjs` 中的 `textIssues`）。界面参考图有中、英两版：`art/export/reference/<界面>.zh-Hans.png`、`.en.png`。

**3.5 键位**：方向键 / WASD 移动；Shift + 方向挖；Ctrl + 方向倒沙；B + 方向放炸药；Z 撤销；R 重开；H 提示；按住 Tab 观察；Esc 暂停。鼠标：左键点相邻格挖，右键点相邻格倒，拖动炸药图标放置。

### 4 美术集成

- **已确认的资产（生成本文件时）**：无。开始工作时先运行 `node tools/art.mjs build && node tools/art.mjs verify`，再读取 `art/export/manifest.json` 确认最新状态。用户可能在你工作期间确认新的版本。
- 写一个导入脚本（GDScript 或 Python 均可），读取 manifest：
  - 对 `approved` 不为空的条目：复制 `approved.png`，校验 `png_sha256`，生成 SpriteFrames / AtlasTexture，帧尺寸、锚点（底边中心对齐格子底边）、动画帧序、fps、是否循环、九宫格边距都取自 manifest；
  - 对未确认的条目：开发构建使用 `current.preview` 并显示占位标记；发布构建报错。
  - 导入设置：Filter Nearest，关闭 mipmap，无损压缩。
- **地形**：不要用贴图。把 `workbench/js/core/terrain.js` 的规则移植成着色器，必须使用同一个 `h32` 哈希和同样的邻格规则；主题参数取自 `theme.*` 资产的 `params`；章节对应的主题见设计第 6.1 节；植物与小动物按 `workbench/js/core/ambient.js` 与美术规范第 6 节摆放和驱动。推荐做法：用一个着色器同时采样 SDK 的两块瓦片纹理（世界宽 320，只有两块），以避免 256 格接缝处读不到邻格（EXT-10）；不可行时，可以改为读取 `get_material_ids` 生成整张材料纹理。沙、水的颗粒颜色使用 SDK 的随机颜色位。
- **对照验证**：在 Godot 中把 `showcase.<主题>`（六个主题各一张，地图见 `workbench/js/core/scene.js` 中的 `SHOWCASE`）和 M01–M07 的开局状态渲染到 320×180 视口并截图，与 `art/export/reference/` 中的同名 PNG 逐像素比较。沙、水只比较颜色集合。差异必须写进 `docs/design/art-pipeline.md` 第 7 节，不能用"差不多"代替。

### 5 未确认或缺失资产

- 未确认：使用占位，按第 0 节第 3 条执行，并在 status 中列出"使用占位的资产及版本"。
- 缺失（见 `docs/design/asset-inventory.md` 第 2 节，主要是第 2–5 章内容）：**不要自己画**。把需求（名称、尺寸、帧数、用途）写进 status 的"待美术"清单，由 Claude 制作候选、用户确认后再集成。开发期间可以用纯色方块加文字标签作临时替身，并明显标出。

### 6 实施顺序与首个可玩闭环

1. **工程骨架**：`game/` 工程能启动；SDK 能加载；320×180 整数缩放窗口；单 worker。
2. **SDK 样板测试**（先于关卡）：(a) 靠墙倒一袋沙，邻格溢出量 < 128 cell；(b) 夯土挖掉后上方夯土不掉落；(c) 箱子逐格写入、移动后材料守恒；(d) 静止判定在第 1 章材料下稳定；(e) 快照撤销后游戏层局面与 SDK 局面完全一致。每项都要有测试和结果记录。
3. **核心规则 + 结算**：实现第 4 节规则与 3.3 结算；headless 回放 M01–M07 作者解全部通关，并与设计模型逐步对照。
4. **首个可玩闭环**（第一个里程碑）：大厅 → 章节选择 → 关卡选择 → M01–M07 可玩（HUD、撤销、重开、三级提示、观察、目标高亮、过关、存档、设置、暂停、规则卡）。美术使用已确认版本或带标记的占位。
5. **美术集成与对照**：导入脚本、地形着色器、参考图逐像素对照。
6. **性能与打包**：见第 7 节；macOS arm64 可双击启动。
7. 之后的章节（第 2–5 章）要等设计负责人按第 1 章规格细化关卡后再做。不要自行设计关卡。

### 7 验证（每项都要有可重复运行的命令和记录下来的结果）

| 类别 | 内容 |
|---|---|
| 规则单元测试 | 设计第 4 节每条规则至少一个正例、一个反例（推箱链被拒、两格高登不上、梯子格不下落、门内有物不关闭等） |
| SDK 样板 | 第 6 节第 2 步的 (a)–(e) |
| 关卡回放 | M01–M07 作者解在真实 SDK 中通关；同一关连续回放 3 次，游戏层局面与 `get_state_hash()` 序列都一致；每一步撤销后局面恢复 |
| 设计模型对照 | 每步游戏层局面与 `tilemodel.js` 推演一致，不一致处有记录和原因 |
| 界面 | 键盘可完成全部流程；鼠标点击区域与画面一致；窗口缩放保持整数倍；存档损坏时能恢复 |
| 美术 | 发布构建只含已确认资产（哈希校验）；参考图逐像素对照结果 |
| 性能 | 60 fps；结算期间单帧主线程耗时 ≤ 4 ms（记录峰值）；撤销 ≤ 100 ms；内存峰值有记录 |
| 新手试玩 | 由用户组织，你不能代替；你只需要提供可运行的构建 |

### 8 启动、交付与记录

- 启动：在仓库根目录提供 `run.sh`（或 `Run Game.command`），找到 Godot 4.7.2（`PUSHBOX_GODOT_BIN` 可覆盖）后运行 `game/`。测试入口为 `tools/run-tests.*`，默认单 worker。
- 交付：`game/` 工程、测试与结果日志（放在 `game/tests/results/` 或 `docs/status.md` 中引用的位置）、更新后的 `docs/status.md`、使用占位的资产清单、待美术清单、已知限制。
- 已知限制：SDK 只有 macOS arm64 动态库（Godot 4.7.2，macOS 15.6+）；其他平台需要重新编译 SDK（`third_party/ele-sdk/prepare_sdk.sh.legacy` 为旧构建脚本，仅供参考）。
- 进度记录位置：`docs/status.md`（唯一的进度入口）。玩法问题写进 status 的"给设计负责人的问题"一节，不要直接改 `game-design.md`。
