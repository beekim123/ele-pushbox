# 项目进度

更新：2026-10-15。负责人：设计审核、美术、工作台 —— Claude；Godot 重构 —— GPT（**暂停**，等用户说开始）；美术确认与方向决定 —— 用户。

## 当前阶段

**R1f：交给 GPT 前的最后准备（Claude）已完成，等用户确认对话气泡的美术。**

- 用户已确认上一轮的 17 项美术（`APR-0004`）。
- **对话气泡**（[dialogue.md](design/dialogue.md)）：角色说的话放进贴着说话人的气泡，用 10px 小字；关卡提示改成主角说话。气泡外观已在工作台。对话数据、触发器、委托是以后的内容，结构已定。
- **工程结构**（[architecture.md](design/architecture.md)）：Godot 工程分层、目录、注册表、事件、存档分段、机制接口、属性修正，以及"怎么加新机制 / 新系统 / 新模式"的固定步骤。
- **资源编号**（[ids.md](design/ids.md)）：每个资源一个全局编号 `空间:编号`，以工作台为准；`content/export/id-map.json` 写明每个编号在游戏里的路径；工作台新增「编号映射」页。
- 第一批关卡不变：第 1 组 7 关 + 第 2 组 9 关。

Godot 重构（R2）**仍然暂停**，等用户说开始。

| 项 | 状态 |
|---|---|
| 设计 | GD-4.1 + [对话](design/dialogue.md)、[工程结构](design/architecture.md)、[编号](design/ids.md) |
| 关卡 | 16 关有完整规格（M01–M07、W01–W05、W07–W10），全部通过设计模型 |
| 编号 | 698 个资源、16 个编号空间（美术 83、关卡 16、机制 74、文字 160……），全部唯一 |
| 美术 | 已确认记录 `APR-0001`–`APR-0004`；**待确认 12 项**：8 个界面布局 v4（只有提示面板的画面变了：提示改成主角的气泡）、`ui.bubble`、`ui.bubble_tail`、`ui.emote`、`ui.screen.dialogue`（对话样张） |
| 字体 | 12px（菜单、标题）不变；新增 Fusion Pixel 10px（对话气泡，OFL，`third_party/fonts/fusion-pixel-10px/`） |
| 交接 | [gpt-refactor-prompt.md](handoff/gpt-refactor-prompt.md)：已加入工程结构、编号规则、对话气泡；状态"暂停" |

## 已实际验证（云端 Linux 环境）

- `node tools/art.mjs build`：83 项；只有 8 个界面布局换版本（v4），主题、材料、主角保持已确认的版本；`verify ok: 83 assets, 4 approval records`；中英文界面零溢出（含气泡）。
- 参考图：除提示面板外，所有界面、主题、关卡的参考图与上一次提交逐像素相同。
- 12px 字形文件逐字节不变（12px 字形改成"只增不改"：只有 12px 文字真的需要新字时才会变，避免每加一句台词就让全部美术换版本）。
- `node tools/content.mjs build`：0 错误；生成 `content/export/id-map.json`，698 个编号全部唯一。
- `node --test tests/content.test.mjs tests/art-pipeline.test.mjs`：12/12 通过（新增编号测试）。
- `node tests/workbench.e2e.cjs`（Chromium）：全部通过（新增「编号映射」页、对话样张、提示面板的检查）。
- `node tools/check-levels.mjs`：16 关全部 ok（与上次相同）。

## 未验证 / 尚缺

- 没有运行 Godot 与 SDK（本环境是 Linux，SDK 只有 macOS arm64 版本）。
- 设计模型里的水是**整格近似**，不等于 SDK 结果。要在 SDK 里验证的点都写在各关规格的 `checks` 和交接文档 5b 节：箱子进水不删水、木箱上浮的 1.5 格判定、W03 沙子经过井与水渠的交叉口不滑进水渠等。
- 第 3–5 组只有概念卡；其中的新机关（矿车、灯照显形、套娃箱、弹跳蘑菇、跷跷板、冰面滑行、阵风）还没写进设计模型。
- 17 项美术等用户确认。
- 名称没有查商标；新手试玩未进行。

## 下一步

1. **用户**：在工作台「确认」页看对话气泡相关的 12 项（「场景」页 `ui.screen.hint`、`ui.screen.dialogue`），确认或指出问题。
2. **Claude**：用户确认后记录 `APR-0005`，更新交接文档第 4 节的确认清单。
3. **用户**：说开始后，把[交接提示词](handoff/gpt-refactor-prompt.md)交给 GPT：阶段一做第 1 组 + 全套菜单（按 architecture.md 建工程），阶段二做第 2 组。
4. **之后（Claude）**：对话数据格式与渡口居民；下一批关卡（第 3 组）。

## 给设计负责人的问题

（GPT 在此记录玩法、美术或冻结区文件的问题；当前为空。）
