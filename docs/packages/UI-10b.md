# UI-10b 通用风格 G2：配送界面（三滚轮、零食、小地图、提示气泡、看全图）

状态：**等 UI-10a 合并后再派**（要用 UI-10a 做的公共组件 `ui-common.js`）。可以和 UI-10c 同时做。
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
- 7 个界面各一句
- 上面「最后跑一次」各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
