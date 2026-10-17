# 给 AI 协作者的规则

适用于本仓库内的所有自动化协作者（Claude、GPT / Codex 等）。用户在对话中给出的最新指示优先于本文件。

0. **分工：一切外包，Claude 只做整理合并**（2026-10-17 用户决定；流程细则见 `docs/process.md`，所有协作者都要读）：
   - **用户**：把工作包派给制作方；确认美术（只有用户能确认）；在包里列出的问题上拍板。
   - **制作方**（任何 AI，包括另开的 Claude 窗口）：一次只做一个包，按 `docs/process.md` 开分支、跑全套检查、填包的「交付」、推送或打 bundle 交回。不改 `docs/status.md`，不合并进 `main`，不删分支，不自己取新包编号。
   - **设计也外包**：接设计包（`DSN-*`）的制作方写设计文档和 `content/catalog/**`，并把功能拆成新的工作包（编号用包里预留的）。
   - **Claude（整理合并）**：导入交回的分支或 bundle，按 `docs/process.md` 第 7 节核对范围、编号、冻结区和美术确认，合进 `main`，重新生成，更新 `docs/status.md`，排下一批，做分支清理。Claude 不重做制作方的工作，也不写游戏 / 工作台 / 工具代码（一两行的明显修正和合并冲突除外）；不通过就写明原因，列进下一批。
   - **工作包**放在 `docs/packages/<编号>.md`，格式和编号登记见 `docs/packages/README.md`。一个包一次会话能做完；同一批的包不改同一个非追加的共享文件。
   - 美术同样外包：制作方画候选，**只有用户能确认**；Claude 只按用户在对话里的原话，用 `node tools/art.mjs approve` 记录。
1. **唯一设计来源**：总纲见 `docs/design/vision.md`；玩法规则与关卡模式以 `docs/design/game-design.md` 为准，其他模式以各自的 `docs/design/mode-*.md` 为准；各种清单（模式、机制组与关卡计划、机制、物品、货物等）以 `content/catalog/` 为准；美术以 `docs/design/art-direction.md`、`docs/design/art-pipeline.md` 为准。不要依据快照 `0fae58c` 中的旧文档、旧测试或旧报告来做决定。
2. **美术确认门槛**：游戏只能使用 `art/approvals.json` 中由用户确认过、且版本与哈希都匹配的资产（确认记录 `APR-0001`–`APR-0006`；主角是 `char.portitor`；已确认 108 项，其中 `APR-0006` 是配送切片的 26 项；概念草图 `char.portitor_alt` 不进游戏。以 `art/export/manifest.json` 的 `current_is_approved` 为准）。不得自行批准，不得把默认选中、测试通过、旧版通过或"风格已认可"当作确认。缺少的资产可以用明显标出的占位，但占位不能视为最终素材。
2a. **已确认美术的冻结区**：`art/source/**`、`art/approvals.json`、`art/history/**`、`art/export/approved/**`、`workbench/js/core/` 下的绘制文件、`content/i18n/*.json` 都参与内容哈希，改动会让确认失效。只有在用户要求、且有工作包明确写了允许改哪些文件时才能改，改完重新走确认流程；开发方新增界面文字写进 `content/i18n-extra/`。新一批界面的文字和字形放自己的文件（`content/i18n-<名>/`、`font-<名>.js`），不改上面这些（`docs/design/art-pipeline.md` 第 2 节）。
2b. **设计目录**：`content/catalog/**` 由设计负责人维护（现在是接设计包 `DSN-*` 的制作方，按包里写明的条目改）。关卡规格放在 `content/levels/<模式>/<组>/`，其中的 `mode`、`group`、`mechanisms` 必须与关卡计划一致；每次提交前 `node tools/content.mjs check` 必须没有错误。机制和关卡的状态由数据算出（规格、设计模型、`game/reports/verification.json`、美术确认），不手写。
3. **改动已确认的资产**会生成新版本，并回到待确认状态；不能覆盖已确认的版本（工具会自动把旧版本存入 `art/history/`）。
4. **自动化测试使用隔离数据**：测试不得写入 `art/approvals.json` 与 `art/source/`，应使用临时目录。
5. **验证必须如实**：设计模型检查（`tools/check-levels.mjs`）不等于 SDK 验证；HTML 动画不等于物理结果；旧测试成绩不能证明新项目通过。
6. **资源预算**（用户机器 16 GB）：同时最多 2 个耗资源任务、默认单 worker；数值库线程设为 1；启动计算前检查其他进程；结束时清理自己启动的进程。
6a. **编号与结构**：每个资源用全局编号 `空间:编号` 引用，以工作台数据为准（`docs/design/ids.md`）；Godot 工程的目录和分层按 `docs/design/architecture.md`。
7. **进度记录**：制作方把结果写进自己包的「交付」；Claude 每次合并后更新 `docs/status.md`：完成了什么、当前阶段、实际验证了什么、还缺什么、下一步派哪些包。
