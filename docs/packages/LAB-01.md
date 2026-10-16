# LAB-01 合并 Claude 分支并重新导入（交给 GPT）

状态：部分完成（合并/导入/现行基线测试完成；生成参考图与Claude分支全同的预期不满足，差异待最终审核）
设计依据：[status.md](../status.md)「审核：GPT 关卡模式阶段一」；AGENTS.md

## 目标
把 `origin/claude/inspiring-ride-zfnn4s`（配送切片设计、美术确认 APR-0005 / APR-0006、文字表读取、工作包）合并进 `codex/portitor-stage1`，解决冲突，重新生成内容数据，Godot 端重新导入美术与编号，测试全部通过。合并后 `codex/portitor-stage1` 作为后续工作包的基线。

## 要读的文件
- 两个分支上的 AGENTS.md（以 Claude 分支的为准：新增第 0 条分工）、`docs/status.md`
- `tools/lib/i18n.mjs`（Claude 分支新增：读入 `content/i18n` 和全部 `content/i18n-*`，包括你的 `content/i18n-extra/`；一个键只能在一张表里）
- `docs/design/art-pipeline.md` 第 2 节（新界面不碰已确认文件的规则）

## 要做的事
1. 在 `codex/portitor-stage1` 上先 `git merge origin/claude/inspiring-ride-zfnn4s`，再 `git merge origin/claude/lv-01-model`（LV-01：设计模型插件接口，基于本分支开出）。合并提交；不要 rebase、不要强推。第一次合并预计 5 个冲突：
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


### 改动与验证
- 合并提交：`8a6e126` 合并 `origin/claude/inspiring-ride-zfnn4s`；`0f43ad1` 合并 `origin/claude/lv-01-model`。未 rebase、未强推。
- 冲突以 `loadTextTables` 为唯一文字表入口，Godot 导入器同样使用它；新增 room 资源按源 SHA 导入。未实现的配送界面只保存带 `implementation_available=false` 的资源，不接入玩法。
- 还原冻结 `tilemodel.js`，把 LV-01 扩展模型移到独立 `tilemodel-runtime.js`，Node/浏览器共用；保留插件接口。原因见问题。为后续包增加 `act`、state-aware `ladder`、`afterAction` 挂钩与 `done/displace` 公共接口。
- 使用独立 `font-extra.js` 补开发文字字形；不修改基础文字表和旧绘制文件。已确认气泡/尾巴用正式贴图，界面仅对未确认资产标占位；新 26 项只导入。
- 停止跟踪 `game/tests/results/` 日志，保留 `.gdignore`；结论放 `game/reports/lab01.json`。
- `node tools/art.mjs build`：109 assets / **0 bumped** / 6 approval records；`verify` 通过；内容检查 **0 error / 0 warning**。
- Node 基线 **48/48**（最终全仓 **136/136**），导入器补充测试 **9/9**；Chromium 工作台验收全部通过（本机 Playwright 需指定已有 Chromium 1217）。新增各章代码最终再统一回归。
- 最终完整 `tools/run-tests.sh`：基线导入、核心、SDK、gameplay、levels、991 UID、render、lab、UI及新增提示/矿车/风/隔离载重套件均通过；仅后续E04候选回归与chapters整体验收保留真实失败，命令退出1。M06当前源规格已撤回旧替代解要求，已移除过时测试误阻塞，未改该关规格。不能把全命令说成全绿。
- `docs/status.md` 只在两次合并中保留双方记录（含问题栏），此后不填写制作进度。

### 交付 · 问题
1. **已解决的M06误阻塞**：合入后的当前规格明确“不再要求没有具体回放路线的替代解”；原测试仍硬编码旧承诺。最终核对后已对齐当前规格并复验通过。最初诊断只记录在历史日志，不再作为待设计决定的问题。
2. **LV-01 与配送美术哈希耦合**：配送界面 renderer 列了 `tilemodel.js`，直接使用 LV-01 修改会自动升版 5 个已确认界面。已撤回自动升版，冻结原文件，另设扩展模型文件；冻结源/确认记录/历史/approved PNG 与 Claude 分支逐字节一致。
3. **“art/ 全部与 Claude 分支无 diff”不适用于现有规格差异**：集成分支已有 W01/W09 的合法修正，且多 30 关。重新生成会改变这两张关卡参考图、增加后章参考图和 manifest 条目；已确认资产版本和 PNG 不变。未为消除 diff 覆盖真实规格或伪造生成结果。

### 当前阶段与下一步
基线可供后续插件/关卡制作，保留上述部分完成项。LV-02–09 均已执行并分别记录实际通过/失败/未执行；本轮统一推回集成分支，设计负责人最后审核生成参考图偏差与SDK实测分歧。当前无需用户操作。
