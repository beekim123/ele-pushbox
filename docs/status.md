# 项目进度

更新：2026-10-15。负责人：设计审核、美术、工作台 —— Claude；Godot 重构 —— GPT（**暂停**，等用户说开始）；美术确认与方向决定 —— 用户。

## 当前阶段

**R1d：GD-4 设计扩展（Claude）已完成，等用户决定。** 英文名定为 PORTITOR；开发顺序改为关卡模式 → 配送模式 → 地狱模式（用户原话中的"闯关"即配送模式）。新增万界渡口世界观、地区、收件人、货物与缘分组合、怪物、道具、增益、属性养成、徽章、加急令、随机事件；配送模式改为网格实时。主角重新设计为"斗笠灯笈"摆渡人，候选美术已在工作台。Godot 重构（R2）**仍然暂停**，等用户说开始。

| 项 | 状态 |
|---|---|
| 旧项目快照 | `0fae58c`（`origin/codex/art-ui-polish`），SDK、字体与许可证在 `third_party/` |
| SDK 事实核实 | 完成（阅读源码，未编译运行）：[sdk-v1.2-verified.md](reference/sdk-v1.2-verified.md) |
| 设计 | GD-4：[总纲](design/vision.md)、[规则与关卡模式](design/game-design.md)、[配送模式](design/mode-delivery.md)、[地区](design/worlds.md)、[角色](design/characters.md)、[局外养成](design/progression.md)、[地狱模式](design/mode-hell.md)、[名称](design/naming.md) |
| 设计数据 | `content/catalog/`：24 个地区、47 位收件人、36 种货物、19 个缘分组合、46 种怪物、20 种道具、10 种增益、8 项属性、18 枚徽章、14 个事件、54 个机制（其中 28 个为提议） |
| 美术 | 75 项已确认（`APR-0001`、`APR-0002`）；**待确认**：新主角 `char.portitor`（21 帧）；`char.portitor_alt` 是备选概念草图，不进游戏 |
| 工作台 | 「设计数据」页可以看全部新目录；「场景」页可以切换主角预览 |
| 交接 | [gpt-refactor-prompt.md](handoff/gpt-refactor-prompt.md)：已按关卡模式修订，状态"暂停" |

## 已实际验证（云端 Linux 环境）

- `node tools/art.mjs verify`：77 项导出 PNG 与源数据逐字节一致；确认记录完整；8 个界面中英文零溢出；内容检查无错误。
- `node tools/content.mjs check`：0 错误、0 警告。新增的检查：收件人的地区和喜欢的货物、缘分组合的货物和收件人、怪物的地区、地区的主题和机制、机制的来源都必须存在。
- `node --test tests/content.test.mjs tests/art-pipeline.test.mjs`：11/11 通过（临时目录）。
- `node tests/workbench.e2e.cjs`（Chromium）：全部通过，新增检查：主角预览只在场景页替换主角，离开后恢复已确认的矿工；新目录页面加载无报错。
- 35 张旧参考图与改动前逐字节相同（新主角没有进入导出图）。
- `check-levels`：M01–M07 结果不变。

## 未验证 / 尚缺

- 没有运行 Godot 与 SDK（本环境是 Linux，SDK 只有 macOS arm64 版本）。
- 配送模式只有设计稿：网格实时与 SDK 的配合、房间切换、怪物、生成器都要先做技术样板。
- 新地区、收件人、怪物、货物都还没有美术；24 个地区专属机制只是提议，要先进关卡模式实验组验证。
- 中文名未定；名称重名只做了网页初筛。
- 新手试玩未进行。

## 下一步

1. **用户**：
   - 从 [名称候选](design/naming.md) 中选中文名（推荐《万物摆渡人》，备选《渡界人》）；
   - 在工作台看新主角（「资产」页 `char.portitor`，「场景」页"主角"下拉框选"摆渡人（候选）"），确认或提修改意见；
   - 确认配送模式改为网格实时（[总纲](design/vision.md) 第 3 节）。
2. **Claude**：按用户的决定改名、换主角（会让 8 个界面生成新版本，一次确认完），把 `char.miner` 改做收件人"老矿工"。
3. **用户**：说开始后，把 [交接提示词](handoff/gpt-refactor-prompt.md) 交给 GPT，做关卡模式（R2）。
4. **之后**：配送模式第 1 层先做技术样板（[配送模式](design/mode-delivery.md) 第 14 节）。

## 给设计负责人的问题

（GPT 在此记录玩法、美术或冻结区文件的问题；当前为空。）
