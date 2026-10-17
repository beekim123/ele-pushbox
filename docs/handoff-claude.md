# 整理合并方（Claude）交接说明

新开一个 Claude 窗口接手"整理合并"时先读这份，再读：[AGENTS.md](../AGENTS.md)、[process.md](process.md)（全文，尤其第 7、7a、10 节）、[board.md](board.md)（现在哪些在做 / 能派 / 在等）、[packages/README.md](packages/README.md)（编号登记）、[status.md](status.md) 最上面几节（最近的合并和决定）。

更新：2026-10-17

## 用户
- 用中文，说人话，简短：先结论和要用户做的事，技术细节放后面。不要问用户能自己定的小事（例如"按现在 HTML 用的就行"）。
- 工作方式：一切外包成工作包，Claude 只整理合并、写包、排优先级；用户派包、确认美术、拍板。
- 当前优先级：**关卡模式线先做完**（见 board.md），雪村、糖果地图往后放。
- 用户机器：Mac，16 GB；Godot / SDK 只有 macOS 版。云端 Linux 跑不了 Godot。

## 分支
- 集成分支：`claude/inspiring-ride-zfnn4s`，所有包都从它开、合回它。**不合进 `main`**，等用户说（BR-01）。
- 这个环境不能删远端分支（403），列"可删除"清单让用户删。

## 合并一个包（照做）
1. 导入：
   - 推送的分支：`git fetch origin --prune`，`git log --oneline HEAD..origin/<分支>`。
   - bundle：`git bundle verify F`，`git bundle list-heads F` 看分支名（制作方有时用错前缀，例如 `ui/DLV-04a`，不影响），`git fetch F <分支>:refs/remotes/bundle/<名>`。
2. 审：`git diff --stat HEAD...<分支>` 对照包里「可改的文件」；读「交付」（≤40 行）。
3. 合：`git merge --no-ff --no-commit <分支>`。**注意上一个合并有冲突没提交时，下一个 merge 不会开始**——先确认 `git status` 干净。
4. 冲突：
   - 生成文件（`workbench/data/*.js`、`content/export/*`、`art/export/manifest.json`、`game/generated/**`）：取本分支 `git checkout --ours`，再重新生成。
   - `tools/art.mjs` 的 `loadCore` 列表、`workbench/index.html` 脚本列表：两边都留（顺序：先合的在前）。
   - `content/catalog/*.json`：用 `node tools/dev/json-merge-by-id.mjs <文件…>` 按条目合并，看输出里有没有 "BOTH CHANGED"。
5. 重新生成：`node tools/content.mjs build`；`node tools/art.mjs build`（看 bumped 数是否符合包里说的；`workbench/data/bundle.js` 只有时间戳变就 `git checkout` 掉）；配送房间有改动时 `node tools/check-rooms2.mjs --write`；Godot 资源 `node game/tools/import_resources.mjs import`。
6. 检查（全过才提交）：
   ```bash
   node tools/content.mjs check                 # 0 错误 0 警告，并且 "mechanisms playable 27"
   node tools/art.mjs verify
   node tools/audio.mjs verify
   node tools/check-rooms2.mjs                  # 配送房间全 ✓
   node tools/dev/check-ids-node.mjs .          # Godot 编号检查的 Node 版，0 failures
   node --test --test-concurrency=1 tests/*.test.mjs game/tests/core/*.test.mjs
   node tests/workbench.e2e.cjs                 # Linux 上本机 chromium 可用
   ```
7. 更新：包文件状态行、`packages/README.md` 那一行、`status.md` 加一节（放最上面）、**`board.md`**。提交信息末尾加署名，推送。
8. 回复用户：做了什么、你要做什么、下一步派什么（给提示词）、可删除的分支。

## 踩过的坑
- **`game/reports/verification.json`**：记着 30 关 SDK 结果，`content.mjs` 用它算机制状态。制作方半截失败的运行会把它清空（"playable 27" 掉成 0）——这种不要采用：`git checkout HEAD -- game/reports/verification.json`。
- **冻结文件**：`workbench/js/core/` 下已有的绘制文件都算进已确认美术的哈希。改界面要新建文件覆盖 `PB.ui.SCREENS.<名>`，只把新文件登记进那一个界面的 `renderer`（例：UI-11a 用 `ui-screens-settings2.js`，不改 `ui-screens-level.js`）。v1 配送的 `rooms.js`、`mapgen.js`、`delivery-scene.js` 也被已确认的配送界面引用，不能删。
- **新字体文件** `font-<名>.js` 要进三处清单：`tools/art.mjs` 的 `loadCore`、`tests/i18n.test.mjs`、`workbench/index.html`。
- **关卡文件** `content/levels/**` 一改，SDK 记录作废；引导数据放在 `content/onboarding/`。
- **美术确认**：只按用户原话记 `node tools/art.mjs approve --items <id@vN,...> --by 用户 --via chat --scope "<范围>" --note "<用户原话>"`，版本号看 `art/source/**/<id>.json`。已记到 APR-0008。
- 程序化 `ui` 类资产的预览图靠 `tools/art.mjs` 的 `renderProcedural` 里 `ui` 分支（UX-03 合并时加的）。
- Godot 截图对照：`game/reports/ui-reference-report.json`，每张 ≤1700 像素算过。
- 工作台的关卡页是 `workbench/js/app/views/scenes.js`（`#scenes/level.*`），`play.js` 是配送试玩。

## 写包
- 照 `packages/README.md` 末尾模板；派前过 process.md 第 7a 节自检。
- 包头写全：基线、分支、`git worktree add` 开工命令、交回命令、预计时长、要不要 Mac。
- 一包一类事、2–4 小时、美术 ≤8 项；验收写成"运行什么 → 看到什么"；交付 ≤40 行。
- 用户可以一个窗口按顺序做几个包：给"队列提示词"（每个包从同一基线开新目录、做完在聊天发【编号 完成】报告、不等回复接着做）。
