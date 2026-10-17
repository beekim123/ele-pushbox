# DLV-09b 糖果王国的 6 间机关房，糖果进开局抽签

状态：等 DLV-08、DLV-09a 合并
基线：`claude/inspiring-ride-zfnn4s`（DLV-08、DLV-09a 合并后）→ 分支：`dlv/DLV-09b`（**不要**从 `main` 开：用户决定先不合进 main）
预计：3 小时；超过 4 小时还没做完就停下，把进度写进「交付」交回。
和雪村的 DLV-07b 改同一批文件（`slices.json` 开局池、房间文字表、字形、两处测试预期）：后合并的那包合并后重建。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-DLV-09b -b dlv/DLV-09b origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-DLV-09b
```
**交回**（二选一）：
- 能推送：`git push -u origin dlv/DLV-09b`
- 不能推送：`git bundle create DLV-09b.bundle origin/claude/inspiring-ride-zfnn4s..dlv/DLV-09b`，把 `DLV-09b.bundle` 交给用户

只往 `dlv/DLV-09b` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

## 目标
做出 `candy_1` 的 6 间机关房，13 间全部通过 `check-rooms2` 后，把 `candy_1` 从 `planned` 移进 `entries`、加进开局池；工作台「配送」菜单多一项「糖果王国」，开局抽签能抽到糖果王国。

## 要读的（只读这些）
- [delivery-candy.md](../design/delivery-candy.md) 第 4 节「机关房」表、下面的注意和「DLV-08 查到的」、第 7 节第 4–7 条
- [DLV-08.md](DLV-08.md) 的交付：验证关、烤炉怎么开、冰的字符
- [DLV-04b.md](DLV-04b.md)：济州机关房和进开局抽签的做法（300 个种子的统计、测试预期）
- [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md) 第 2–6 节、第 8 节
- `content/rooms/jeju/jeju_neolttwigi.json`、`jeju_pier.json`：机关房的样例

## 要做的
1. 新建 `content/rooms/candy/` 下 6 间房：`candy_jelly`、`candy_oven`、`candy_jelly_step`、`candy_jelly_tower`、`candy_syrup_pool`、`candy_oven_lever`。角色、大小、出入口、`needs` / `teaches` / `requires` 照第 4 节表；软糖、烤炉的配置照 DLV-08 查到的验证关；"必需"的机制冻结后要没有解。
2. 守第 4 节的注意：落到软糖上不超过 2 格；每块要用的软糖头顶有够不着的梯子；左高进来的路线也必须用到机制；化出来的糖水流到不挡路的地方；热气的格子不放在必经的路上（或扳杆能关）。
3. 房间名、提示写进 `content/i18n-rooms2/zh-Hans.json`、`en.json`，然后 `python3 tools/build-font.py --ext rooms2` 重建字形。
4. 13 间全部通过后：把 `candy_1` 从 `slices.json` 顶层 `planned` 移进 `entries`（放在 `jeju_1` 后面），删掉 `todo`；`planned` 空了就删掉；在 `delivery_pool` 的 `pool.maps` 加 `{"slice": "candy_1", "weight": 1}`。
5. 照 DLV-04b 统计 300 个种子：糖果王国被抽到的比例、每局房间数和长度；需要时调 `layout.cols`，结果写进交付。
6. 测试里写死"地图数"的预期要跟着改（DLV-04b 那次要改的两条，外加 04b 漏掉的一条）：`tests/rooms2.test.mjs` 里 v2 地图的集合（约第 185 行，加 `candy_1`）；`tests/workbench.e2e.cjs` 的 `wantMenu` 里「配送」那一组（加「糖果王国」）和地图数的断言（约第 211 行）。只改这几处。
7. 文档：delivery-puzzle-rules.md 第 6 节的地图表加上糖果王国；delivery-candy.md 开头的状态改成"13 间房全部通过"，第 4 节末尾加「和设计不同的地方（DLV-09b）」。
8. 开工时看 ART-02b、ART-02c 合并了没有：没合并时画面用 DLV-08 的占位；如果 `content.mjs check` 因为缺资产报错，停下交回，不要自己补资产。

## 可改的文件
- 新建：`content/rooms/candy/` 下这 6 个房间文件
- `content/i18n-rooms2/zh-Hans.json`、`en.json`：只加糖果机关房的键
- `content/catalog/slices.json`：只动 `candy_1`（从 `planned` 移进 `entries`）和 `delivery_pool` 的 `pool.maps`
- `tests/rooms2.test.mjs`、`tests/workbench.e2e.cjs`：只改上面第 6 步那三处预期
- `docs/design/delivery-puzzle-rules.md`：只改第 6 节的地图表
- `docs/design/delivery-candy.md`：开头的状态、「和设计不同的地方（DLV-09b）」
- 生成文件（用工具生成后提交，不手改）：字形（`build-font.py` 生成的文件）、`content/rooms2-check.generated.json`、`content/export/*`、`workbench/data/*`
- 本文件的状态和「交付」
- （清单之外一律不改。验收和这个清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过）

## 不能碰的文件
- AGENTS.md 2a 的冻结区（上面写明的生成文件除外）：规则代码 `rooms2.js`、`delivery-scene2.js`、`mech/*.js`、`art/**`、`content/i18n/**`
- 已有地图的房间和数据（石牢、地府、海女村）、DLV-09a 的 7 间房（要改先写进交付）、`game/**`
- `docs/status.md`

## 验收（运行什么 → 看到什么）
- `node tools/check-rooms2.mjs` → 全部通过，糖果 13 间都在里面（所有路线和翻转检查）
- `node tools/content.mjs build && node tools/content.mjs check` → 0 错误、0 警告
- `node --test tests/*.test.mjs` → 全部通过
- e2e → 通过，「配送」菜单里有「糖果王国」
- 浏览器打开 `workbench/index.html#rooms2/candy_jelly` → 软糖、梯子、高口；走上软糖不弹，从台阶落下去被弹起
- 300 个种子的统计 → 写进交付

## 检查
边做边跑（只跑这些）：
```bash
node tools/check-rooms2.mjs --only <房间 id>
```
最后跑一次：
```bash
node tools/check-rooms2.mjs --write
node tools/content.mjs build && node tools/content.mjs check   # 0 错误、0 警告
node --test tests/*.test.mjs
PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/local/bin/chromium node tests/workbench.e2e.cjs   # Linux 要设这个变量，macOS 不用
node tools/art.mjs build                                       # 0 bumped
```
不要做的：逐个算文件哈希、复制仓库做试验、逐帧比对、为写交付补跑命令（见 process.md 第 10 节）。

## 交付（制作方填写，不超过 40 行）
- 做了什么（每项一句）
- 检查命令各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
