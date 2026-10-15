# 项目进度

更新：2026-10-15。负责人：设计审核、美术、工作台 —— Claude；Godot 重构 —— GPT（**暂停**，等用户说开始）；美术确认与方向决定 —— 用户。

## 当前阶段

**R1e：关卡模式 v2（Claude）进行中。** R1d 已完成：中文名定为《渡界人》（英文 PORTITOR）；主角 `char.portitor` 已由用户确认（`APR-0003`），所有场景和界面换成新主角；配送模式的移动改为"按格移动 + 移动间隔"；地区加入世界各地的文化（15 个新地区，含中国风的地府·酆都）。Godot 重构（R2）**仍然暂停**，等用户说开始。

| 项 | 状态 |
|---|---|
| 旧项目快照 | `0fae58c`（`origin/codex/art-ui-polish`），SDK、字体与许可证在 `third_party/` |
| SDK 事实核实 | 完成（阅读源码，未编译运行）：[sdk-v1.2-verified.md](reference/sdk-v1.2-verified.md) |
| 设计 | GD-4.1：[总纲](design/vision.md)、[规则与关卡模式](design/game-design.md)、[配送模式](design/mode-delivery.md)、[地区](design/worlds.md)、[角色](design/characters.md)、[局外养成](design/progression.md)、[地狱模式](design/mode-hell.md)、[名称](design/naming.md)、[竞品调研](research/2026-10-15-competitors.md) |
| 设计数据 | `content/catalog/`：39 个地区（含 15 个新的文化地区）、82 位收件人、48 种货物、39 个缘分组合、77 种怪物、20 种道具、10 种增益、8 项属性、18 枚徽章、14 个事件、73 个机制（其中 47 个为提议） |
| 美术 | 当前版本已确认 61 项（含主角 `char.portitor`）；**待重新确认 15 项**：6 个主题（v2）、`material.chapter2_5`（v2）、8 个界面布局（v3）——只因换了标题和主角而生成新版本，见下文 |
| 工作台 | 「设计数据 → 地区」可以按文化圈筛选 |
| 交接 | [gpt-refactor-prompt.md](handoff/gpt-refactor-prompt.md)：状态"暂停"；第一批关卡的定义在 R1e 中更新 |

## 待重新确认的 15 项（只有标题和主角变了）

逐像素比较了新旧导出图：

- 6 个主题的预览图（`theme.*`）：只有主角所在的 14×16 像素区域不同（矿工 → 渡界人），地形、生态、光照完全相同。它们的版本变化还有一个原因：字体数据加了"渡"字，所有程序绘制的资产都会因此换版本。
- `material.chapter2_5`：像素完全相同，只因字体数据变化而换版本。
- 8 个界面布局：大厅的标题从"箱途"变成"渡界人"、主角换成渡界人；其他界面只有主角的小区域不同。

在工作台「确认」页能看到这 15 项。确认后，我用 `node tools/art.mjs approve` 记录为 `APR-0004`。

## 已实际验证（云端 Linux 环境）

- `node tools/art.mjs build`：15 项按预期换版本（6 个主题 v2、`material.chapter2_5` v2、8 个界面 v3），之后再构建 0 项变化；`verify ok: 77 assets, 3 approval records`；中英文界面零溢出。
- `node tools/content.mjs check`：0 错误、0 警告（新地区的机制、收件人的地区和喜欢的货物、缘分组合、怪物的地区都交叉检查过）。
- `node --test tests/content.test.mjs tests/art-pipeline.test.mjs`：11/11 通过（临时目录）。
- `node tests/workbench.e2e.cjs`（Chromium）：全部通过，新增"地区按文化圈筛选"的检查。

## 未验证 / 尚缺

- 没有运行 Godot 与 SDK（本环境是 Linux，SDK 只有 macOS arm64 版本）。
- 15 项美术等用户重新确认。
- 新地区、收件人、怪物、货物都还没有美术；47 个提议机制都要先进关卡模式实验组验证。
- 名称只做了网页初筛，没有查商标。
- 新手试玩未进行。

## 下一步

1. **Claude**（进行中）：关卡模式 v2——评估现有关卡组，把 SDK 机制和不需要 SDK 的机制融合成新的关卡组，写好第一批交给 GPT 的关卡规格并用设计模型验证。
2. **用户**：在工作台确认 15 项新版本（或指出问题）。
3. **用户**：说开始后，把 [交接提示词](handoff/gpt-refactor-prompt.md) 交给 GPT。

## 给设计负责人的问题

（GPT 在此记录玩法、美术或冻结区文件的问题；当前为空。）
