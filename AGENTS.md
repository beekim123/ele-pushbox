# 给 AI 协作者的规则

适用于本仓库内的所有自动化协作者（Claude、GPT / Codex 等）。用户在对话中给出的最新指示优先于本文件。

1. **唯一设计来源**：玩法以 `docs/design/game-design.md` 为准，美术以 `docs/design/art-direction.md`、`docs/design/art-pipeline.md` 为准。不要依据快照 `0fae58c` 中的旧文档、旧测试或旧报告来做决定。
2. **美术确认门槛**：游戏只能使用 `art/approvals.json` 中由用户确认过、且版本与哈希都匹配的资产（目前第 1 章与菜单的 57 项 v1 已确认，记录 `APR-0001`；第 2–5 章的 18 项候选和 8 个界面的 v2 待确认，见 `docs/status.md`）。不得自行批准，不得把默认选中、测试通过、旧版通过或"风格已认可"当作确认。缺少的资产可以用明显标出的占位，但占位不能视为最终素材。
2a. **已确认美术的冻结区**：`art/source/**`、`art/approvals.json`、`art/history/**`、`art/export/approved/**`、`workbench/js/core/` 下的绘制文件、`content/i18n/*.json` 都参与内容哈希，改动会让确认失效。只有美术负责人（Claude）在用户要求下修改，并重新走确认流程；开发方新增界面文字写进 `content/i18n-extra/`。
3. **改动已确认的资产**会生成新版本，并回到待确认状态；不能覆盖已确认的版本（工具会自动把旧版本存入 `art/history/`）。
4. **自动化测试使用隔离数据**：测试不得写入 `art/approvals.json` 与 `art/source/`，应使用临时目录。
5. **验证必须如实**：设计模型检查（`tools/check-levels.mjs`）不等于 SDK 验证；HTML 动画不等于物理结果；旧测试成绩不能证明新项目通过。
6. **资源预算**（用户机器 16 GB）：同时最多 2 个耗资源任务、默认单 worker；数值库线程设为 1；启动计算前检查其他进程；结束时清理自己启动的进程。
7. **进度记录**：每次工作结束时更新 `docs/status.md`：完成了什么、当前阶段、实际验证了什么、还缺什么、下一步由谁执行。
