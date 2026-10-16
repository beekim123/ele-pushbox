# LAB-01 合并 Claude 分支并重新导入（交给 GPT）

状态：待做（执行者：GPT）
设计依据：[status.md](../status.md)「审核：GPT 关卡模式阶段一」；AGENTS.md

## 目标
把 `origin/claude/inspiring-ride-zfnn4s`（配送切片设计、美术确认 APR-0005 / APR-0006、文字表读取、工作包）合并进 `codex/portitor-stage1`，解决冲突，重新生成内容数据，Godot 端重新导入美术与编号，测试全部通过。合并后 `codex/portitor-stage1` 作为后续工作包的基线。

## 要读的文件
- 两个分支上的 AGENTS.md（以 Claude 分支的为准：新增第 0 条分工）、`docs/status.md`
- `tools/lib/i18n.mjs`（Claude 分支新增：读入 `content/i18n` 和全部 `content/i18n-*`，包括你的 `content/i18n-extra/`；一个键只能在一张表里）
- `docs/design/art-pipeline.md` 第 2 节（新界面不碰已确认文件的规则）

## 要做的事
1. 在 `codex/portitor-stage1` 上 `git merge origin/claude/inspiring-ride-zfnn4s`（合并提交；不要 rebase、不要强推）。预计 5 个冲突：
   - `tools/content.mjs`、`tools/lib/ids.mjs`：保留 Claude 分支的文字表读取（`loadTextTables`），删掉你那套重复的 `extraTexts` 读取；其余你加的逻辑保留。
   - `docs/status.md`：两边的内容都保留（Claude 的配送切片、审核、分工；你的阶段一记录），按时间整理，补回「给设计负责人的问题」一节。
   - `content/export/id-map.json`、`workbench/data/content.js`：不要手工合并，取任意一边后用工具重新生成。
2. 重新生成：`node tools/art.mjs build`（会顺带重建内容数据）。合并后美术应为 109 项、确认记录 6 条，**0 bumped**。
3. Godot：重新运行美术和内容导入，重新生成 `game/generated/` 与编号常量；原来当作占位的对话气泡（`ui.bubble`、`ui.bubble_tail`、`ui.emote`）和 9 个界面在合并后是已确认的（APR-0005），换成正式美术；配送切片的 26 项（APR-0006）只导入、暂不接入游戏。
4. 跑全部测试（`tools/run-tests.sh` 以及仓库里的 Node 测试），修掉合并引起的问题。
5. 卫生：以后不再把 `game/tests/results/` 的日志提交进仓库（加进 `.gitignore`；已入库的可以删除，报告里需要的结论写进 `game/reports/`）。

## 不能碰的文件
- AGENTS.md 2a 的冻结区（合并带进来的新文件除外，不要修改它们）
- `content/catalog/**`、`content/levels/**` 的内容（合并本身带来的除外；关卡补强另有工作包 LV-02–05）

## 验收标准
- `node tools/art.mjs build` → `build ok: 109 assets, 0 bumped`，`6 approval records`；`node tools/art.mjs verify` → `verify ok`
- `node tools/content.mjs check` → 0 error（包括文字表：`i18n-extra` 与 `i18n-delivery` 没有重复键）
- `node --test tests/*.test.mjs` 全部通过；`node tests/workbench.e2e.cjs` 全部通过（有 Chromium 时）
- Godot 测试全部通过；编号一致性测试通过（id-map 里每个 uid 在游戏路径上都存在、哈希一致）
- 合并后 `git diff origin/claude/inspiring-ride-zfnn4s -- art/` 为空（美术与确认记录以 Claude 分支为准）
- 推送到 `codex/portitor-stage1`，在本文件「交付」一节写明结果

## 交付（执行者填写）
