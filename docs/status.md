# 项目进度

更新：2026-10-15。负责人：设计审核 / 美术 / 工作台 —— Claude；Godot 重构 —— GPT（待启动）。

## 当前阶段

**阶段 R1：设计重整、美术重做与交接准备**（进行中）

| 项 | 状态 |
|---|---|
| 旧项目快照 | 完成：`0fae58c`（`origin/codex/art-ui-polish`），工作树已清理 |
| SDK 事实核实（读源码） | 完成：[sdk-v1.2-verified.md](reference/sdk-v1.2-verified.md) |
| 设计审核与唯一设计 | 完成：[审核记录](audit/2026-10-15-design-audit.md)、[game-design.md](design/game-design.md) GD-2 |
| 第 1 章 7 关规格 | 完成，设计模型检查通过（见下） |
| 美术流程与工作台 | 完成：`tools/art.mjs`（build / approve / import / verify）、`workbench/index.html` |
| 美术候选 | 第一批 28 项已就绪（待确认）：角色、箱子、机关、物品、特效、界面元素、两套地形主题、7 个界面画面 |
| 用户美术确认 | 未开始（需要用户在工作台中查看） |
| GPT 交接提示词 | 未开始 |

## 已实际验证

- `node tools/check-levels.mjs`：M01–M07 的作者解在设计模型中全部通关，且都等于模型求出的最短解。这只是格子规则模型，**不是 SDK 验证**。
- `node tools/art.mjs verify`：28 项导出 PNG 与源数据逐字节一致。
- `node --test tests/art-pipeline.test.mjs`：6/6 通过（全部在临时目录中运行，真实确认记录未被改动）。
- `node tests/workbench.e2e.cjs`（Chromium）：全部通过。覆盖：工作台画面与导出 PNG 逐字节一致；隐藏视图不重绘；编辑刷新后保留并可导出；确认文字含精确版本与哈希；390px 宽度无横向滚动。

## 尚缺

- SDK 样板验证（所有【待验证】项）、实机回放、新手试玩 —— 都要等 Godot 重构后进行。
- 第 2–5 章关卡细化。

## 下一步

Claude：写交接提示词；用户：打开工作台查看并确认第一批美术。
