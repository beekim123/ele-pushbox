# UI-10a 通用风格 G2：公共组件 + 8 个关卡类界面

状态：待派（UI-10 按 process.md 2.1 拆出的第一包；UI-10b、UI-10c 要用这一包做的公共组件，所以这包先做）
基线：`claude/inspiring-ride-zfnn4s` → 分支：`ui/UI-10a`（**不要**从 `main` 开）
预计：3–4 小时；超过 5 小时还没做完就停下，把进度写进「交付」交回。

**开工**（照抄）：
```bash
git fetch origin
git checkout -b ui/UI-10a origin/claude/inspiring-ride-zfnn4s
```
**交回**（二选一）：
- 能推送：`git push -u origin ui/UI-10a`
- 不能推送：`git bundle create UI-10a.bundle origin/claude/inspiring-ride-zfnn4s..ui/UI-10a`，把 `UI-10a.bundle` 交给用户

只往 `ui/UI-10a` 提交；不往别的分支推送，也不合并别的分支。

## 目标
用户选定了通用风格 **G2 深蓝圆角**（[UI-09](UI-09.md)）。这一包：
1. 把 G2 的组件整理成正式的公共组件文件 `workbench/js/core/ui-common.js`，供后面的 UI-10b、UI-10c 用；
2. 用它把 8 个关卡类界面换成 G2：选章 `chapters`、选关 `levels`、设置 `settings`、暂停 `pause`、提示 `hint`、规则卡 `rulecard`、对话 `dialogue`、过关 `complete`。

## 要读的（只读这些）
- `workbench/js/core/ui-generic.js`：G2 的调色、组件、样板图（照它画，不改它）
- `workbench/js/core/ui-style.js`：这 8 个界面现在的布局（布局照它，换成 G2 的画法）
- `art/source/screen/ui.screen.pause.json`：界面资产的 `renderer`、`params`、`depends` 怎么写
- 工作台「美术 › 界面风格提案」页，或总览图 `docs/packages/UI-09/G2_深蓝圆角.png`

## 要做的
1. 新文件 `workbench/js/core/ui-common.js`：G2 的面板、标题条、按钮三态、光标、键帽、滑块、开关、标签、说话泡、心里话泡，导出为 `PB.uiCommon`。从 `ui-generic.js` 整理过来，不改 `ui-generic.js`。
2. 新文件 `workbench/js/core/ui-screens-level.js`：这 8 个界面的新画法，通过 `PB.ui.SCREENS` 覆盖同名界面。布局沿用 `ui-style.js`，G2 需要时可以小调。
3. 设置界面**去掉「界面风格」那一行**和右边的预览：游戏界面统一用 G2，四套切换暂停了（UI-07 暂停）。
4. 8 个界面的 `art/source/screen/ui.screen.<id>.json`：`renderer` 换成新文件，`params` 不变或按需小改。
5. `workbench/index.html`、`tools/art.mjs` 的 `loadCore` 末尾**追加**加载 `ui-common.js`、`ui-screens-level.js`。
6. 新文字放新表 `content/i18n-common/zh-Hans.json`、`en.json`；缺字形用 `python3 tools/build-font.py --ext common`（生成 `font-common.js`，同样追加加载）。

已知的坑：
- **不改** `ui-style.js`、`ui-kit.js`、`ui-skins.js`、`ui-generic.js`：前三个参与全部界面和大厅皮肤的哈希，改了会让 16 个界面和 6 套大厅都换版本；
- 关卡里的顶部状态栏画在 `scene.js` 的 `drawHud` 里，是冻结文件，**这包不做**；
- 这 8 个界面现在都还没被确认，换版本没关系，每个只升一版。

## 可改的文件
- 新建：`workbench/js/core/ui-common.js`、`ui-screens-level.js`、`font-common.js`、`content/i18n-common/*.json`
- `art/source/screen/` 下这 8 个文件：`ui.screen.chapters/levels/settings/pause/hint/rulecard/dialogue/complete.json`
- `workbench/index.html`、`tools/art.mjs`：只追加加载
- `tests/`：可以加测试；改已有测试的预期要在交付里写明
- 生成文件：用工具生成后提交，不手改

验收和这个清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 不能碰的文件
- 其他 8 个界面（大厅、配送类）：UI-10b、UI-10c 做
- 冻结区（AGENTS.md 2a）：`art/source/` 里除上面 8 个以外的文件、确认记录、`workbench/js/core/` 已有的绘制文件、`content/i18n/**` 和已有的 `content/i18n-*/**`
- `content/catalog/**`、`content/rooms/**`、`docs/design/**`、`docs/status.md`、`game/**`

## 检查
边做边跑（只跑这些）：用自己的预览脚本出图看；满意了再 `node tools/art.mjs build`，不要每改一笔就 build。
最后跑一次：
```bash
node tools/art.mjs build      # 换版本的只有这 8 个界面，各升一版；确认记录仍是 6 条
node tools/art.mjs verify     # ok，中英文排版 0 个问题
node tools/content.mjs check  # 0 错误
node --test tests/*.test.mjs
node tests/workbench.e2e.cjs
```
不要做的：逐个算文件哈希、复制仓库做试验、逐帧比对（process.md 第 10 节）。

## 验收
- 工作台「确认」页能看到这 8 个界面的新版本，是 G2 风格；
- 6 套大厅皮肤的参考图（`art/export/reference/lobby.*.png`）和改前一样（`git diff --stat` 里没有它们）。

## 交付（制作方填写，不超过 40 行）
- `ui-common.js` 有哪些组件（一行）
- 8 个界面各一句：和原来布局有什么不同
- 上面「最后跑一次」各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
