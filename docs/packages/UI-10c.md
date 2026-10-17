# UI-10c 通用风格 G2：结算、失败界面 + 通用大厅

状态：**待派**（UI-10a 已合并，公共组件 `ui-common.js` 已在基线上）。可以和 UI-10b 同时做。
基线：`claude/inspiring-ride-zfnn4s`（已包含 UI-10a）→ 分支：`ui/UI-10c`（**不要**从 `main` 开）
预计：2–3 小时；超过 4 小时还没做完就停下，把进度写进「交付」交回。

**开工**（照抄）：
```bash
git fetch origin
git checkout -b ui/UI-10c origin/claude/inspiring-ride-zfnn4s
```
**交回**（二选一）：
- 能推送：`git push -u origin ui/UI-10c`
- 不能推送：`git bundle create UI-10c.bundle origin/claude/inspiring-ride-zfnn4s..ui/UI-10c`，把 `UI-10c.bundle` 交给用户

只往 `ui/UI-10c` 提交；不往别的分支推送，也不合并别的分支。

## 目标
1. 配送结算 `settlement`、配送失败 `settlement_fail` 换成 G2；
2. 新建**通用大厅** `ui.screen.lobby_generic`：用在还没有自己皮肤的地图（现在是地府、海女村）。原来按章节换的 6 套大厅皮肤（`ui.screen.lobby`）**不动**。

## 要读的（只读这些）
- `workbench/js/core/ui-common.js`（UI-10a）、`ui-generic.js` 里的通用大厅样板 `lobby`
- `workbench/js/core/ui-style.js`：结算、失败、大厅现在的布局
- `art/source/screen/ui.screen.settlement.json`、`ui.screen.lobby.json`：界面资产怎么写

## 要做的
1. 新文件 `workbench/js/core/ui-screens-result.js`：结算、失败、通用大厅的画法，通过 `PB.ui.SCREENS` 注册或覆盖。通用大厅的菜单项和原大厅一样（关卡模式、配送、设置、退出 + 金币），背景用地府的大厅场景。
2. 结算、失败界面里画到的房间用 v2 房间，不用 v1 的。
3. 改 `ui.screen.settlement.json`、`ui.screen.settlement_fail.json` 的 `renderer`、`params`；新建 `ui.screen.lobby_generic.json`。
4. `workbench/index.html`、`tools/art.mjs` 末尾**追加**加载新文件。
5. 新文字放新表 `content/i18n-result/`，缺字形用 `python3 tools/build-font.py --ext result`。

已知的坑：
- 通用大厅是**新资产**，不要改 `ui.screen.lobby`：改它会让已经做好的 6 套大厅皮肤换版本；
- 不改 `ui-common.js`（UI-10b 同时在用）、`ui-style.js`、`ui-kit.js`、`ui-skins.js`。

## 可改的文件
- 新建：`workbench/js/core/ui-screens-result.js`、`font-result.js`、`content/i18n-result/*.json`、`art/source/screen/ui.screen.lobby_generic.json`
- `art/source/screen/ui.screen.settlement.json`、`ui.screen.settlement_fail.json`
- `workbench/index.html`、`tools/art.mjs`：只追加加载
- `tests/`：可以加测试；改已有测试的预期要在交付里写明
- 生成文件：用工具生成后提交，不手改

验收和这个清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 不能碰的文件
- `ui.screen.lobby` 和其他界面（UI-10a、UI-10b 的）、`ui-common.js`
- 冻结区（AGENTS.md 2a）、`content/catalog/**`、`content/rooms/**`、`docs/design/**`、`docs/status.md`、`game/**`

## 检查
边做边跑：用自己的预览脚本出图看；满意了再 `node tools/art.mjs build`。
最后跑一次：
```bash
node tools/art.mjs build      # 换版本的只有结算、失败两个；新增 lobby_generic；确认记录仍是 6 条
node tools/art.mjs verify     # ok，中英文排版 0 个问题
node tools/content.mjs check  # 0 错误
node --test tests/*.test.mjs
node tests/workbench.e2e.cjs
```
不要做的：逐个算文件哈希、复制仓库做试验、逐帧比对（process.md 第 10 节）。

## 验收
- 工作台「确认」页能看到结算、失败的新版本和通用大厅，是 G2 风格；
- `art/export/reference/lobby.*.png`（6 套大厅皮肤）不在 `git diff --stat` 里。

## 交付（制作方填写，不超过 40 行）
- 3 个界面各一句
- 上面「最后跑一次」各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
