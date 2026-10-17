# DLV-04a 济州海女村：7 间普通房（起点、过道、驿站、收件人之家）

状态：待派（DLV-04 按 process.md 2.1 拆出的前一半）
基线：`claude/inspiring-ride-zfnn4s` → 分支：`dlv/DLV-04a`（**不要**从 `main` 开）
预计：2–3 小时；超过 4 小时还没做完就停下，把进度写进「交付」交回。

**开工**（照抄）：
```bash
git fetch origin
git checkout -b dlv/DLV-04a origin/claude/inspiring-ride-zfnn4s
```
**交回**（二选一）：
- 能推送：`git push -u origin dlv/DLV-04a`
- 不能推送：`git bundle create DLV-04a.bundle origin/claude/inspiring-ride-zfnn4s..dlv/DLV-04a`，把 `DLV-04a.bundle` 交给用户

只往 `dlv/DLV-04a` 提交；不往别的分支推送，也不合并别的分支。

## 目标
做出济州 13 间房里**不用跷跷板、阵风的 7 间**，全部通过 `check-rooms2`：
`jeju_gate`、`jeju_olle`、`jeju_canola`、`jeju_haenyeo_house`、`jeju_home_shore`、`jeju_home_orchard`、`jeju_home_cave`。
另外 6 间机关房由 [DLV-04b](DLV-04b.md) 做；济州进开局抽签也在 DLV-04b。

## 要读的（只读这些）
- [DLV-04.md](DLV-04.md) 的「每间房的要求」表和「要做」第 2、4、5 条
- [delivery-jeju.md](../design/delivery-jeju.md) 第 4 节（这 7 间的想法）、第 5 节（提示动物）
- [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md) 第 2 节（房间格式）、第 8.3 节（野外地图）
- 照着写的样板：`content/rooms/diyu/diyu_gate.json`、`diyu_huangquan.json`、`diyu_teahouse.json`、`diyu_home_yard.json`

## 要做的
1. 7 间房写进 `content/rooms/jeju/<id>.json`，字段和写法照 `content/rooms/diyu/` 的同类房间；出入口按 DLV-04 表格。
2. 按第 8.3 节：每屏上面一半以上是天空，第 1 行能空就空；边框会自动画成石墙和礁石，不用写。
3. 房名、提示文字加进 `content/i18n-rooms2/zh-Hans.json` 和 `en.json`（键照 diyu：`room2.<id>.name` 等），再跑 `python3 tools/build-font.py --ext rooms2` 补字形。
4. 红蜻蜓的喂食台词：`content/catalog/worlds.json` 的 `jeju_dragonfly` 加 `"fed": "只帮小马带路：喂零食要找小马"`；两张文字表加 `dlg.fauna.jeju_dragonfly.fed`（英文 "I only show the pony's way: feed the pony."）。
5. **不要**动 `slices.json`：`jeju_1` 留在 `planned`，不进开局池。这时内容检查会因为济州的房间还不全报 1 条"规划中"的警告，这是正常的。

已知的坑：
- `check-rooms2` 会检查 `content/rooms/` 下所有 v2 房间，不管它在不在地图里，所以新房间一放进去就会被检查；
- 工作台的「配送」菜单里暂时没有海女村（`jeju_1` 还在 `planned`），要看房间就直接打开 `workbench/index.html#rooms2/jeju_gate` 这类网址。

## 可改的文件
- 新建：`content/rooms/jeju/` 下这 7 个文件
- `content/i18n-rooms2/zh-Hans.json`、`en.json`：只加这 7 间和红蜻蜓的键
- `content/catalog/worlds.json`：只给 `jeju_dragonfly` 加 `fed`
- 生成文件：`workbench/js/core/font-rooms2.js`、`content/rooms2-check.generated.json`、`content/export/*`、`workbench/data/*.js`，用工具生成后提交，不手改

验收和这个清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 不能碰的文件
- 另外 6 间机关房（DLV-04b 做）、`content/catalog/slices.json`
- 石牢、地府的房间；`rooms2.js`、`mapgen2.js`、`tilemodel*.js`、`mech/*.js`
- 冻结区（AGENTS.md 2a）、`docs/status.md`、`game/**`

## 检查
边做边跑（只跑这些）：
```bash
node tools/check-rooms2.mjs --only <房间id>
```
最后跑一次：
```bash
node tools/check-rooms2.mjs --write     # 0 失败，地府、石牢的结果和改前一样
node tools/content.mjs check            # 0 错误
node --test tests/rooms2.test.mjs
node tools/art.mjs build                # 0 bumped
```
不要做的：逐个算文件哈希、复制仓库做试验、为写交付补跑命令（process.md 第 10 节）。

## 验收
- 7 间房每种翻转 × 每条路线都通过 `check-rooms2`。
- 打开 `workbench/index.html#rooms2/jeju_gate` 等 7 间，能看到房间画面：顶上是天空。

## 交付（制作方填写，不超过 40 行）
- 每间房一句：怎么走、有什么特点
- 上面「最后跑一次」各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
