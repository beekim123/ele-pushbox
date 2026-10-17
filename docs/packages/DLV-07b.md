# DLV-07b 极地雪村：7 间机关房，雪村进开局抽签

状态：等 DLV-06、DLV-07a 合并（和 DSN-05 拆出的 DLV-09b 改同一批文件，**不同批派**）
基线：`claude/inspiring-ride-zfnn4s`（DLV-06、DLV-07a 合并以后）→ 分支：`dlv/DLV-07b`（**不要**从 `main` 开；派之前 Claude 确认两包已合并，基线换了就照新基线改下面两段命令）
预计：3–4 小时；超过 5 小时还没做完就停下，把进度写进「交付」交回。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-DLV-07b -b dlv/DLV-07b origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-DLV-07b
```
**交回**（二选一）：
- 能推送：`git push -u origin dlv/DLV-07b`
- 不能推送：`git bundle create DLV-07b.bundle origin/claude/inspiring-ride-zfnn4s..dlv/DLV-07b`，把 `DLV-07b.bundle` 交给用户

只往 `dlv/DLV-07b` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

## 目标
做出雪村的 7 间机关房：`polar_lake`、`polar_crevasse`、`polar_hotspring`、`polar_fishing`、`polar_icefall`、`polar_icepath`、`polar_icedam`，全部通过 `check-rooms2`；然后把雪村（`polar_1`）放进正式地图和开局抽签。做完后工作台「配送」菜单会自动出现「雪村」。

## 要读的（只读这些）
- [delivery-polar.md](../design/delivery-polar.md) 第 4 节（这 7 间的想法、教的顺序、「必需滑行」的做法、DLV-07a 写的「和设计不同的地方」）、第 7 节第 8、9 条
- [DLV-06.md](DLV-06.md) 的「交付」：冰、冷气口、热气口在 v2 里怎么写；`tests/rooms2.test.mjs` 里 DLV-06 加的 5 间测试房就是现成的写法样板（第 5 间就是温泉冰坝的草图）
- [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md) 第 1 节（必需机制）、第 6 节（地图表和统计）
- [DLV-04b.md](DLV-04b.md) 的「要做的」第 3、4 条（济州进开局抽签的做法）
- 关卡 F07、F02、F03、F09 的规格（装置参数照抄）

## 要做的
1. 7 间房写进 `content/rooms/polar/<id>.json`，角色、大小、`needs` / 教 / 必需、出入口照设计第 4 节的表；装置照验证关，温泉冰坝照 DLV-06 的第 5 间测试房。
   - 冰川裂缝、温泉的 `needs` 写 `["ice_slide"]`，保证第一间教总是冰湖。
   - 「必需滑行」：冻结 `ice_slide` 以后房间要解不开。设计里用"人站在压板上门才开，箱子自己滑过门"；换别的做法也行，写进交付。作者解要多试几种走法，确认没有一格一格推过去的捷径。
2. 房名、提示文字加进 `content/i18n-rooms2/` 两张表，再跑 `python3 tools/build-font.py --ext rooms2`。
3. 13 间都通过以后，照 DLV-04b 的做法：
   - `polar_1` 从 `slices.json` 顶层 `planned` 移进 `entries`（放在 `jeju_1` 后面），删掉 `todo` 字段；`planned` 空了就删掉（DSN-05 的 `candy_1` 还在里面就留着）；
   - `delivery_pool.pool.maps` 加 `{"slice": "polar_1", "weight": 1}`；
   - 看 300 个种子的统计：需要时调 `polar_1.layout` 的 `cols` / `rows`；确认冰湖总是第一间教，转折房和教过的机制对得上；
   - 房间里有箱子落水浮沉的，`polar_1.mechanisms` 加 `float_sink`；
   - 更新 `delivery-puzzle-rules.md` 第 6 节的地图表和统计、`delivery-polar.md` 开头的状态和第 4 节「和设计不同的地方（DLV-07b）」。
4. 放进 `entries` 后，内容检查里"polar_1 规划中"的警告会消失。

已知的坑：
- `mapgen2.js` 不能改：抽签不认「教」房间的 `needs`、或者第一间教不是冰湖，就写进交付，不自己改规则。
- 温泉冰坝没有关卡模式的验证关，余量没人试过，作者解要多试几种走法。

## 可改的文件
- 新建：`content/rooms/polar/` 下这 7 个文件
- `content/i18n-rooms2/zh-Hans.json`、`en.json`：只加这 7 间的键
- `content/catalog/slices.json`：只动 `polar_1`、`planned`、`delivery_pool`
- `docs/design/delivery-puzzle-rules.md`（只改第 6 节地图表和统计）、`docs/design/delivery-polar.md`（开头的状态、第 4 节「和设计不同的地方（DLV-07b）」）
- 测试里写死地图列表的两处预期，加上雪村（交付里写明）：
  - `tests/rooms2.test.mjs` 里写死地图 id 列表的那处（DLV-04b 加过 `"jeju_1"`）→ 加 `"polar_1"`；
  - `tests/workbench.e2e.cjs` 的 `wantMenu`：「配送」组 `"海女村"` 后面加 `"雪村"`（照 `entries` 的顺序）。
  其他测试不改。
- 生成文件：`workbench/js/core/font-rooms2.js`、`content/rooms2-check.generated.json`、`content/export/*`、`workbench/data/*.js`，用工具生成后提交，不手改
- 本文件的状态和「交付」

验收和这个清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 不能碰的文件
- DLV-07a 做的 6 间房（有问题写进交付）
- `rooms2.js`、`mapgen2.js`、`delivery-scene2.js`、`tilemodel*.js`、`mech/*.js`：规则不够用就写进交付，不自己改
- 冻结区（AGENTS.md 2a）、`docs/status.md`、`game/**`

## 检查
边做边跑（只跑这些）：
```bash
node tools/check-rooms2.mjs --only <房间id>
```
最后跑一次：
```bash
node tools/check-rooms2.mjs --write     # 0 失败；300 个种子里每张地图都抽到、都能生成
node tools/content.mjs check            # 0 错误、0 警告
node --test tests/*.test.mjs
node tools/art.mjs build                # 0 bumped
node tests/workbench.e2e.cjs
```
不要做的：逐个算文件哈希、复制仓库做试验、为写交付补跑命令（process.md 第 10 节）。

## 验收
- `node tools/check-rooms2.mjs --write` → 13 间雪村房每种翻转 × 每条路线都通过；300 个种子里雪村和原有的地图都抽到，雪村每局第一间教都是冰湖。
- `node tools/content.mjs check` → 0 错误、0 警告。
- 打开工作台「配送」→ 菜单出现「雪村」；点开能看到 13 间房；试玩一间机关房，冰面滑行、冷气口、热气口能用，按 `H` 喂零食有提示气泡。

## 交付（制作方填写，不超过 40 行）
- 做了什么（每间房一句：怎么解）
- 检查命令各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
