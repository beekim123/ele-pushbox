# UI-10b 通用风格 G2：配送界面（三滚轮、零食、小地图、提示气泡、看全图）

状态：**候选制作完成，技术检查已执行，待整理合并方验收及用户美术确认**（UI-10a 已合并，公共组件 `ui-common.js` 已在基线上）。
基线：`claude/inspiring-ride-zfnn4s`（已包含 UI-10a）→ 分支：`ui/UI-10b`（**不要**从 `main` 开）
预计：3–4 小时；超过 5 小时还没做完就停下，把进度写进「交付」交回。

**开工**（照抄）：
```bash
git fetch origin
git checkout -b ui/UI-10b origin/claude/inspiring-ride-zfnn4s
```
**交回**（二选一）：
- 能推送：`git push -u origin ui/UI-10b`
- 不能推送：`git bundle create UI-10b.bundle origin/claude/inspiring-ride-zfnn4s..ui/UI-10b`，把 `UI-10b.bundle` 交给用户

只往 `ui/UI-10b` 提交；不往别的分支推送，也不合并别的分支。

## 目标
用 G2 公共组件做配送的 7 个界面：
- 改 5 个：
  - 开局台 `reels`：改成**三滚轮**（地图 → 收件人 → 货物），可以重转，显示剩余次数；
  - 商店 `shop`：货架加**零食**（10 金币，库存 3），包装按地图换：石牢小鱼饼干、地府桂花糕、海女村小米糕（`item.snack_jeju`）；
  - 配送顶部状态栏 `delivery_hud`：加零食数和**多屏小地图**（房间 1×1 到 2×2，标出走过的、当前的、收件人方向、驿站）；
  - 配送暂停 `delivery_pause`、放弃确认框 `confirm`：换成 G2。
- 新建 2 个：
  - 提示动物气泡 `ui.screen.hint_animal`：主动物头顶的提示、走近时的方向箭头、喂会飞的动物时显示"喂零食要找猫 / 狗 / 小马"；
  - 看全图 `ui.screen.observe`：多屏房间缩小一半，标出人、出口、怪物、提示动物，写"Tab 返回"。

## 要读的（只读这些）
- `workbench/js/core/ui-common.js`（UI-10a）、`ui-generic.js` 里的三滚轮样板 `reels`
- `workbench/js/core/ui-style.js`：这 5 个界面现在的布局
- `workbench/js/core/delivery-scene2.js`：v2 房间、提示动物怎么画（看全图、小地图要用）
- [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md) 第 4 节（看全图）、第 5 节（提示动物、零食）、第 6 节（三滚轮）

## 要做的
1. 新文件 `workbench/js/core/ui-screens-delivery.js`：这 7 个界面的画法，通过 `PB.ui.SCREENS` 注册或覆盖。
2. 界面里画到的房间一律用 v2 房间（`content/rooms/dungeon/dungeon2_*`、`content/rooms/diyu/*`），不用 v1 的。
3. 5 个现有界面的 `art/source/screen/*.json` 改 `renderer`、`params`；新建 `ui.screen.hint_animal.json`、`ui.screen.observe.json`（照现有界面资产的写法）。
4. `workbench/index.html`、`tools/art.mjs` 末尾**追加**加载新文件。
5. 新文字放新表 `content/i18n-delivery2/`，缺字形用 `python3 tools/build-font.py --ext delivery2`。

已知的坑：
- **不改** `ui-common.js`：UI-10c 同时在用；缺组件就在自己的文件里补，写进交付；
- 不改 `ui-style.js`、`ui-kit.js`、`ui-skins.js`、`delivery-scene2.js`（会让别的资产换版本）。

## 可改的文件
- 新建：`workbench/js/core/ui-screens-delivery.js`、`font-delivery2.js`、`content/i18n-delivery2/*.json`、`art/source/screen/ui.screen.hint_animal.json`、`ui.screen.observe.json`
- `art/source/screen/` 下：`ui.screen.reels/shop/delivery_hud/delivery_pause/confirm.json`
- `workbench/index.html`、`tools/art.mjs`：只追加加载
- `tests/`：可以加测试；改已有测试的预期要在交付里写明
- 生成文件：用工具生成后提交，不手改

验收和这个清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 不能碰的文件
- 其他界面（UI-10a、UI-10c 的）、`ui-common.js`
- 冻结区（AGENTS.md 2a）、`content/catalog/**`、`content/rooms/**`、`docs/design/**`、`docs/status.md`、`game/**`

## 检查
边做边跑：用自己的预览脚本出图看；满意了再 `node tools/art.mjs build`。
最后跑一次：
```bash
node tools/art.mjs build      # 换版本的只有这 5 个界面，新增 hint_animal、observe；确认记录仍是 6 条
node tools/art.mjs verify     # ok，中英文排版 0 个问题
node tools/content.mjs check  # 0 错误
node --test tests/*.test.mjs
node tests/workbench.e2e.cjs
```
不要做的：逐个算文件哈希、复制仓库做试验、逐帧比对（process.md 第 10 节）。

## 验收
- 工作台「确认」页能看到这 7 个界面，是 G2 风格；开局台是三个滚轮；商店有零食。

## 交付（制作方填写，不超过 40 行）
- `reels`：G2 地图 → 收件人 → 货物三滚轮，展示选择、R 重转及剩余次数。
- `shop`：G2 四行货架；零食 10 金币、库存 3，石牢小鱼饼干 / 地府桂花糕 / 海女村小米糕（`item.snack_jeju`）。
- `delivery_hud`：G2 顶栏保留心、货物、金币、沙、背包、时间，新增零食数；小地图按 1×1–2×2 房间占屏绘制，标出已走、当前、驿站和收件人方向。
- `delivery_pause`：独立注册配送暂停，五项菜单使用 G2，关卡暂停入口不变。
- `confirm`：G2 放弃确认框、说明和双按钮，以 v2 房间及 HUD 为背景。
- `hint_animal`：主动物头顶 G2 提示及零食小框、走近方向箭头，展示飞行动物喂食提醒。
- `observe`：v2 2×2 房间精确缩半至 320×160，标出人、出口、怪物、提示动物，显示 Tab 返回。
- 房间取自 `dungeon2_yard`、`dungeon2_station`、`dungeon2_sandpour`、`diyu_fengdu` 的 v2 快照；无 v1 房间。
- 新文字 / 字形：`i18n-delivery2` / `font-delivery2.js`；公共组件不足部分在本文件补了滚轮条、多屏小地图、缩放及全图标记。
- `node tools/art.mjs build`：`build ok: 158 assets, 5 bumped, 98 reference renders, 6 approval records`；中英文排版 0 问题，伪语言 5 条提示。
- `node tools/art.mjs verify`：`verify ok: 158 assets, 6 approval records`。
- `node tools/content.mjs check`：`content: 0 error(s), 1 warning(s)`；基线缺少 `slice:jeju_1` 的音频引用警告未改。
- `node --test --test-concurrency=1 tests/*.test.mjs`：唯一一轮全套 218 项，217 通过、1 项字形入口失败；修复后仅重跑 `tests/i18n.test.mjs`，3/3 通过，未重复全套。
- `node tests/workbench.e2e.cjs`：`all workbench checks passed`；确认页七界面及双语排版检查均通过。
- 测试预期：无放宽 / 删除；`i18n.test.mjs` 加载新字体并增加新表来源断言，保留缺字严格断言；新增 5 项配送界面单测及浏览器检查。
- 范围：仅五个既有界面升版（confirm v2，其余 v3），两个新界面 v1；6 条确认记录保持不变，未自行确认美术。
- 执行中共享目录被其他会话切换分支，已迁至本聊天独立 worktree；共享目录仅清理与迁移副本一致的本包残留，原有 `1.md` 未动。
- 遗留问题：仅基线 `slice:jeju_1` 警告；无新增设计问题。上述为工作台美术候选，未合并 main、未获得本轮美术确认。
- 下一步 / 执行人：用户将本包分支交给 Claude 整理合并聊天；Claude 按流程验收并合并、更新项目进度；用户负责七个界面的美术确认。
