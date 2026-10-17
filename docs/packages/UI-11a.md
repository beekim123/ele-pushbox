# UI-11a 设置里选大厅皮肤（工作台）

状态：待派（2026-10-17，用户决定）
基线：`claude/inspiring-ride-zfnn4s` → 分支：`ui/UI-11a`（**不要**从 `main` 开：用户决定先不合进 main）
预计：2–3 小时；超过 4 小时 还没做完就停下，把进度写进「交付」交回。
不用 Mac。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-UI-11a -b ui/UI-11a origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-UI-11a
```
**交回**（二选一）：
- 能推送：`git push -u origin ui/UI-11a`
- 不能推送：`git bundle create UI-11a.bundle origin/claude/inspiring-ride-zfnn4s..ui/UI-11a`，把 `UI-11a.bundle` 交给用户

只往 `ui/UI-11a` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

## 用户的决定（2026-10-17）
“皮肤要加回之前设计那个，可以在设置页选择。去掉之前的设定，大厅皮肤跟着当前章节自动换。”

## 目标
1. 设置页加一行「大厅皮肤」，左右键切换 7 个选项：6 套章节皮肤（S1 晶石琉璃、S2 漂浮符文、S3 祥云玉简、S4 梦泡糖霜、S5 藤木萤光、S6 星港舱板）+ 通用大厅（G2）。**默认 S2 漂浮符文**（就是现在一进游戏看到的那套）。
2. 选哪套，大厅就显示哪套的**整张画面**（皮肤 + 它原来配的章节背景），和参考图 `art/export/reference/lobby.<主题>.png`、`lobby_generic.<语言>.png` 一样；**不再**跟着当前章节自动换。
3. 设计文档改成新规则。

## 要读的（只读这些）
- [ui-style.md](../design/ui-style.md) 第 2 节（大厅皮肤）、第 3 节开头「2026-10-17 用户改了决定」
- `workbench/js/core/ui-screens-level.js` 里的 `settings`（现在设置页的画法，只看不改）
- `workbench/js/core/ui-skins.js` 末尾的 `BY_THEME`、`workbench/js/core/ui-screens-result.js` 的 `lobby_generic`（只看）
- `art/source/screen/ui.screen.settings.json`

## 要做的
1. **新文件** `workbench/js/core/ui-screens-settings2.js`：照 `ui-screens-level.js` 的设置页画法，加「大厅皮肤」一行（放在「语言」下面），通过 `PB.ui.SCREENS.settings` 覆盖。
   - 已知的坑：**不要改** `ui-screens-level.js`：它在 8 个已确认界面的确认哈希里，改了 8 个都要重新确认。新文件只登记进 `ui.screen.settings.json` 的 `renderer`，只让设置页换版本。
2. `art/source/screen/ui.screen.settings.json`：`renderer` 加新文件和新文字表，`params` 里加这一行（样张显示默认值 S2）。build 后设置页升一版（v7），**待用户确认**。
3. 新文字（「大厅皮肤」和 7 个皮肤名，中英文）放新表 `content/i18n-ui11/zh-Hans.json`、`en.json`；缺字形跑 `python3 tools/build-font.py --ext ui11`，新的 `font-ui11.js` 要同时进三处字体清单（`tools/art.mjs` 的 `loadCore`、`tests/i18n.test.mjs`、`workbench/index.html`）。
4. `workbench/index.html`、`tools/art.mjs` 末尾追加加载新文件。
5. 工作台「场景」页：大厅那一组照旧列出 6 套 + 通用，不用改。
6. 设计文档 `docs/design/ui-style.md` 第 2 节：把"按当前地图换皮肤"改成"玩家在设置里选，默认 S2，7 个选项"，删掉"S5、S6 不进设置"那句；写上日期和用户原话。

验收和下面「可改的文件」清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 可改的文件
- 新建：`workbench/js/core/ui-screens-settings2.js`、`content/i18n-ui11/*.json`、`workbench/js/core/font-ui11.js`（工具生成）
- `art/source/screen/ui.screen.settings.json`
- `workbench/index.html`、`tools/art.mjs`：只追加；`tests/i18n.test.mjs`：只在字体列表加一项
- `tests/workbench.e2e.cjs`：只在末尾加一条"设置页有大厅皮肤一行"
- `docs/design/ui-style.md`：只改第 2 节
- 生成文件（用工具生成后提交）
- 本文件的状态和「交付」

## 不能碰的文件
- 冻结区（AGENTS.md 2a）：已有的 `workbench/js/core/**` 绘制文件（**特别是 `ui-screens-level.js`、`ui-skins.js`**）、`art/approvals.json`、`content/i18n/**`、已有的 `content/i18n-*/**`
- 其他界面的 `art/source/screen/*.json`、`game/**`、`docs/status.md`

## 检查
边做边跑：`node tools/art.mjs build`（看设置页的样子）
最后跑一次：
```bash
node tools/content.mjs check   # 0 错误
node tools/art.mjs build       # 只有 ui.screen.settings 换版本（v7），确认记录 8 条
node tools/art.mjs verify      # ok，中英文排版 0 问题
node --test tests/*.test.mjs
node tests/workbench.e2e.cjs
```
不要做的：逐个算文件哈希、复制仓库做试验、为写交付补跑命令（process.md 第 10 节）。

## 验收
- `node tools/art.mjs build` → bumped 只有 `ui.screen.settings`。
- 工作台「美术 › 确认」页能看到设置页 v7，有「大厅皮肤 ‹ 漂浮符文 ›」一行。

## 交付（制作方填写，不超过 40 行）
- 做了什么（每项一句）
- 检查命令各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
