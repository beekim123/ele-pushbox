# 项目进度

更新：2026-10-15。负责人：设计审核、美术、工作台 —— Claude；Godot 重构 —— GPT（待开工）；美术确认 —— 用户。

## 当前阶段

**R1（设计重整、美术重做与交接准备）已完成；下一阶段 R2：GPT 按交接提示词重构 Godot 游戏本体（阶段一：第 1 章 + 全套菜单；阶段二：第 2–5 章关卡）。**

| 项 | 状态 |
|---|---|
| 旧项目快照 | `0fae58c`（`origin/codex/art-ui-polish`），工作树已清理，SDK、字体与许可证在 `third_party/` |
| SDK 事实核实 | 完成（阅读源码，未编译运行）：[sdk-v1.2-verified.md](reference/sdk-v1.2-verified.md) |
| 设计 | [game-design.md](design/game-design.md) GD-2：5 章 33 关 + 扩展章，第 1 章 7 关已细化；六主题；多语言；环境效果 |
| 美术 | **57 项全部由用户确认**（`APR-0001`，2026-10-15，用户在聊天中回复："可以，目前跟美术相关的我都满意了，可以全部标记为通过"） |
| 交接 | **正式版**：[gpt-refactor-prompt.md](handoff/gpt-refactor-prompt.md) |

## 已实际验证（R1，云端 Linux 环境）

- `node tools/check-levels.mjs`：M01–M07 的作者解在设计模型中全部通关，且都等于模型最短解。**这只是格子规则模型，不是 SDK 验证。**
- `node tools/art.mjs verify`：57 项导出 PNG 与源数据逐字节一致；确认记录、已确认 PNG 与历史源数据哈希一致；8 个界面在简中、英文下零文字溢出。
- `node --test tests/art-pipeline.test.mjs`：6/6 通过（在临时目录中运行，真实确认记录未被改动）。
- `node tests/workbench.e2e.cjs`（Chromium）：全部通过，包括浏览器渲染与导出 PNG 逐字节一致、中英文零溢出、隐藏视图不重绘、编辑不丢稿、窄屏无横向滚动。

## 未验证 / 尚缺

- 没有运行 Godot 与 SDK（本环境是 Linux，SDK 只有 macOS arm64 版本）。所有【待验证】项、实机回放、性能都在 R2 中验证。
- 第 2–5 章关卡只有概念卡（交由 GPT 在阶段二细化，格式见设计 6.5、6.6），对应的机关与材料美术尚未制作（[资产清单](design/asset-inventory.md) 第 2 节）。
- 没有音效与音乐素材。
- 新手试玩未进行。

## 下一步

1. **用户**：把 [交接提示词](handoff/gpt-refactor-prompt.md) 中「你的任务」到文末的内容交给 GPT，并让它在本仓库（分支 `claude/inspiring-ride-zfnn4s` 或你指定的新分支）上工作。
2. **GPT**：按提示词第 5 节推进阶段一（第 1 章 + 全套菜单），通过后按第 5b 节逐章做第 2–5 章，每章交审核；每次结束更新本文件。
3. **Claude**：审核 GPT 每章的关卡；制作第 2–5 章缺的机关与材料美术（新候选需用户确认）。

## 给设计负责人的问题

（GPT 在此记录玩法、美术或冻结区文件的问题；当前为空。）
