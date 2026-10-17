# UI-10c 通用风格 G2：结算、失败界面 + 通用大厅

状态：**已合并**（2026-10-17，`ui/UI-10c` @ `a1044b0`；3 个界面待用户确认）。
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
- 结算：G2 深蓝圆角，保留完好度、时间、喜好、小费、拾币、合计和评级；背景使用 v2 房间。
- 失败：G2 深蓝圆角，显示两种失败原因、拾币与保留金额；背景使用 v2 房间，两个操作支持选中切换。
- 通用大厅：独立 `ui.screen.lobby_generic@v1`，固定地府背景，关卡模式／配送／设置／退出和金币；六套原大厅皮肤不变。
- `node tools/art.mjs build`：`build ok: 157 assets, 2 bumped, 96 reference renders, 6 approval records`；仅结算、失败升至 v3；排版 0 问题。
- `node tools/art.mjs verify`：`verify ok: 157 assets, 6 approval records`。
- `node tools/content.mjs check`：`content: 0 error(s), 1 warning(s)`（基线已有 `slice:jeju_1` 音频待引用警告）。
- `node --test --test-concurrency=1 tests/*.test.mjs`：217 tests，217 pass，0 fail，0 skipped。
- `node tests/workbench.e2e.cjs`：`all workbench checks passed`；三项候选可在确认页看到并选择，双语画面与导出一致。
- 现有测试预期改动：无；新增 `ui-screens-result.test.mjs` 四项测试，并在 `workbench.e2e.cjs` 追加确认页、双语 G2 和导出一致性检查。
- 新文字在 `content/i18n-result/`；已有字形覆盖，无需新增字形文件。v2 房间为界面参数内的独立预览样例，未改房间目录。
- 执行记录：共享目录被另一会话切到 `ui/DLV-04b`，首次构建因其未生成 `font-delivery2.js` 中止；已隔离到本包工作目录后仅重跑该失败命令，保留另一包改动。
- 遗留问题：上述基线警告；三个界面仍是待用户美术确认的候选，不代表已正式批准。
- 当前阶段：实现及包内技术检查完成，待整理合并方审核；下一步由用户把 `ui/UI-10c` 交给 Claude 按流程审核合并，再由用户在工作台确认候选。
