# DLV-09a 糖果王国的 7 间普通房（起点、过道、驿站、收件人之家）

状态：等 ART-02a 合并（要糖果的地形）
基线：`claude/inspiring-ride-zfnn4s`（DSN-05、ART-02a 合并后）→ 分支：`dlv/DLV-09a`（**不要**从 `main` 开：用户决定先不合进 main）
预计：3 小时；超过 4 小时还没做完就停下，把进度写进「交付」交回。
不依赖 DLV-08，可以和它同时做。和雪村的 DLV-07a 改同一份房间文字表和字形：后合并的那包合并后重建字形。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-DLV-09a -b dlv/DLV-09a origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-DLV-09a
```
**交回**（二选一）：
- 能推送：`git push -u origin dlv/DLV-09a`
- 不能推送：`git bundle create DLV-09a.bundle origin/claude/inspiring-ride-zfnn4s..dlv/DLV-09a`，把 `DLV-09a.bundle` 交给用户

只往 `dlv/DLV-09a` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

## 目标
做出 `candy_1` 的 7 间普通房，全部通过 `check-rooms2`，在工作台 `#rooms2/<房间 id>` 能看到糖果的地形。`candy_1` 仍留在 `slices.json` 的 `planned` 里（进开局池是 DLV-09b 的事）。

## 要读的（只读这些）
- [delivery-candy.md](../design/delivery-candy.md) 第 1 节（地形）、第 3 节（怪物）、第 4 节「普通房」表和下面的注意、第 5 节（提示动物）
- [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md) 第 2–6 节、第 8 节（野外地图）
- [DLV-04a.md](DLV-04a.md)：济州普通房的做法（房间文件、文字、字形、检查）
- `content/rooms/jeju/` 的 `jeju_gate`、`jeju_olle`、`jeju_haenyeo_house`、`jeju_home_shore`：样例

## 要做的
1. 新建 `content/rooms/candy/` 下 7 间房：`candy_gate`、`candy_lollipop_lane`、`candy_river_bank`、`candy_sweet_shop`、`candy_home_square`、`candy_home_bakery`、`candy_home_castle`。角色、大小、出入口照第 4 节表，写法照济州的样例。
2. 普通房的左低、左高都要有路线（前一间可能从高口出来）；起点没有左口；收件人之家只开左边。`top_edge` 是天空：地形从下往上长，上面大部分是天空，边界画成自然物（第 8.1、8.3 节）。
3. 怪物不进解谜区：棒棒糖林放蚂蚁大军（路边要有能躲的一格高台子或梯子）；河堤放姜饼人，下层路尽头的小池糖水不在必经的路上。
4. 房间名、提示写进 `content/i18n-rooms2/zh-Hans.json`、`en.json`（`room2.<id>.name` 等，照 DLV-04a），然后 `python3 tools/build-font.py --ext rooms2` 重建字形。
5. 小蜂鸟的 `fed` 照 DLV-04a 给红蜻蜓的做法改成文字键 `dlg.fauna.candy_hummingbird.fed`，中英文写进 `i18n-rooms2`。
6. 每做完一间跑 `node tools/check-rooms2.mjs --only <id>`；全部做完跑 `node tools/check-rooms2.mjs --write`。
7. 和设计不同的地方写进 delivery-candy.md 第 4 节末尾「和设计不同的地方（DLV-09a）」。

## 可改的文件
- 新建：`content/rooms/candy/` 下这 7 个房间文件
- `content/i18n-rooms2/zh-Hans.json`、`en.json`：只加糖果房间和小蜂鸟的键
- `content/catalog/worlds.json`：只改 `candy` 小蜂鸟的 `fed`
- `docs/design/delivery-candy.md`：只加「和设计不同的地方（DLV-09a）」
- 生成文件（用工具生成后提交，不手改）：字形（`workbench/js/core/font-rooms2.js` 等 `build-font.py` 生成的文件）、`content/rooms2-check.generated.json`、`content/export/*`、`workbench/data/*`
- 本文件的状态和「交付」
- （清单之外一律不改。验收和这个清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过）

## 不能碰的文件
- AGENTS.md 2a 的冻结区（上面写明的生成文件除外）：规则代码 `rooms2.js`、`delivery-scene2.js`、`terrain*.js`、`art/**`、`content/i18n/**`
- 已有地图的房间（`content/rooms/` 下除 `candy/` 以外）、`slices.json`（`candy_1` 留在 `planned`）、开局池、`tests/**`、`game/**`
- `docs/status.md`

## 验收（运行什么 → 看到什么）
- `node tools/check-rooms2.mjs --only candy_gate`（7 间逐个）→ 通过
- `node tools/check-rooms2.mjs` → 全部通过，原有房间的结果不变
- `node tools/content.mjs build && node tools/content.mjs check` → 0 错误、0 警告
- 浏览器打开 `workbench/index.html#rooms2/candy_lollipop_lane` → 饼干地形、糖霜顶、蓝天背景；蚂蚁在过道上，不在解谜区

## 检查
边做边跑（只跑这些）：
```bash
node tools/check-rooms2.mjs --only <房间 id>
```
最后跑一次：
```bash
node tools/check-rooms2.mjs --write
node tools/content.mjs build && node tools/content.mjs check   # 0 错误、0 警告
node --test tests/rooms2.test.mjs
node tools/art.mjs build                                       # 0 bumped
```
不要做的：逐个算文件哈希、复制仓库做试验、逐帧比对、为写交付补跑命令（见 process.md 第 10 节）。

## 交付（制作方填写，不超过 40 行）
- 做了什么（每项一句）
- 检查命令各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
