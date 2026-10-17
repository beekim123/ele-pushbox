# DLV-07a 极地雪村：6 间普通房（起点、喘口气、驿站、收件人之家）

状态：等 ART-01a 合并（要雪村的地形和提示动物资产）
基线：`claude/inspiring-ride-zfnn4s`（ART-01a 合并以后）→ 分支：`dlv/DLV-07a`（**不要**从 `main` 开；派之前 Claude 确认 ART-01a 已合并，基线换了就照新基线改下面两段命令）
预计：2–3 小时；超过 4 小时还没做完就停下，把进度写进「交付」交回。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-DLV-07a -b dlv/DLV-07a origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-DLV-07a
```
**交回**（二选一）：
- 能推送：`git push -u origin dlv/DLV-07a`
- 不能推送：`git bundle create DLV-07a.bundle origin/claude/inspiring-ride-zfnn4s..dlv/DLV-07a`，把 `DLV-07a.bundle` 交给用户

只往 `dlv/DLV-07a` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

## 目标
做出雪村 13 间房里**不用冰、冷凝、化冰的 6 间**，全部通过 `check-rooms2`：
`polar_gate`、`polar_snowfield`、`polar_spruce`、`polar_cabin`、`polar_home_bay`、`polar_home_yard`。
并把 `worlds.json` 里 `polar` 的主题和提示动物补上。另外 7 间机关房和进开局抽签由 [DLV-07b](DLV-07b.md) 做。

## 要读的（只读这些）
- [delivery-polar.md](../design/delivery-polar.md) 第 4 节（这 6 间的想法、出入口和表下的说明）、第 3 节（怪物）、第 5 节（提示动物和目录里的写法）
- [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md) 第 2 节（房间格式）、第 8.3 节（野外地图）
- 照着写的样板：`content/rooms/jeju/jeju_gate.json`、`jeju_olle.json`（喘口气、有怪物）、`jeju_haenyeo_house.json`（驿站）、`jeju_home_shore.json`（收件人之家、有水）
- [DLV-04a.md](DLV-04a.md) 的「要做的」和「交付」（济州普通房的写法）

## 要做的
1. 6 间房写进 `content/rooms/polar/<id>.json`，字段和写法照济州的同类房间；角色、大小、出入口照设计第 4 节的表。
   - 普通房里不放规则的冰（要等 DLV-06）；冰窟窿用规则的水。
   - 企鹅只在 `polar_snowfield`，雪怪只在 `polar_spruce`；两间都要有躲开或对付它们的地方（台阶、梯子、两格深的坑、能推下去的木箱）。
   - 收件人之家照济州写法限定收件人：冰封海湾只给极地渔夫、独角鲸，木屋院子只给驯鹿牧人、雪人。
2. 按第 8.3 节：每屏上面一半以上是天空，第 1 行能空就空；左右边框会自动画成雪松树丛，不用写。
3. 房名、提示文字加进 `content/i18n-rooms2/zh-Hans.json` 和 `en.json`（键照济州：`room2.<id>.name` 等），再跑 `python3 tools/build-font.py --ext rooms2` 补字形。
4. `content/catalog/worlds.json` 的 `polar`：加 `"theme": "theme.polar"`、`hint_fauna`（两种动物，字段和文字照设计第 5 节）、`"ambient_exclude": ["fauna.polar_bunting"]`；两张文字表加 `dlg.fauna.polar_bunting.fed`（中文「只帮小驯鹿带路：喂零食要找小驯鹿」，英文 "I only show the reindeer's way: feed the reindeer."）。
5. **不要**动 `slices.json`：`polar_1` 留在 `planned`，不进开局池。这时内容检查会因为雪村的房间还不全报 1 条"规划中"的警告，这是正常的。
6. 和设计不一样的地方写进 `delivery-polar.md` 第 4 节末尾新加的「和设计不同的地方（DLV-07a）」。

已知的坑：
- `check-rooms2` 会检查 `content/rooms/` 下所有 v2 房间，不管它在不在地图里，新房间一放进去就会被检查。
- 工作台「配送」菜单里暂时没有雪村（`polar_1` 还在 `planned`），要看房间就直接打开 `workbench/index.html#rooms2/polar_gate` 这类网址。
- 木屋、雪屋是按格子哈希摆的装饰（设计第 7 节第 13 条），挡住重要的东西就写进交付，不改画法。
- 驿站卖燕麦饼、沙袋和急救包（`polar_1.station`）；零食图标在 DLV-06 合并前画成默认的 `item.snack`，正常。

## 可改的文件
- 新建：`content/rooms/polar/` 下这 6 个文件
- `content/i18n-rooms2/zh-Hans.json`、`en.json`：只加这 6 间和雪鹀的键
- `content/catalog/worlds.json`：只给 `polar` 加 `theme`、`hint_fauna`、`ambient_exclude`
- `docs/design/delivery-polar.md`：只加第 4 节末尾的「和设计不同的地方（DLV-07a）」
- 生成文件：`workbench/js/core/font-rooms2.js`、`content/rooms2-check.generated.json`、`content/export/*`、`workbench/data/*.js`，用工具生成后提交，不手改
- 本文件的状态和「交付」

验收和这个清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 不能碰的文件
- 另外 7 间机关房（DLV-07b 做）、`content/catalog/slices.json`
- 石牢、地府、济州的房间；`rooms2.js`、`mapgen2.js`、`delivery-scene2.js`、`terrain*.js`、`tilemodel*.js`、`mech/*.js`
- 冻结区（AGENTS.md 2a，包括 `art/**`、`content/i18n/*.json`）、`docs/status.md`、`game/**`

## 检查
边做边跑（只跑这些）：
```bash
node tools/check-rooms2.mjs --only <房间id>
```
最后跑一次：
```bash
node tools/check-rooms2.mjs --write     # 0 失败，石牢、地府、济州的结果和改前一样
node tools/content.mjs check            # 0 错误；允许 1 条 polar_1「规划中」警告
node --test tests/rooms2.test.mjs
node tools/art.mjs build                # 0 bumped
```
不要做的：逐个算文件哈希、复制仓库做试验、为写交付补跑命令（process.md 第 10 节）。

## 验收
- `node tools/check-rooms2.mjs --only polar_gate`（6 间各跑一次）→ 每种翻转 × 每条路线都通过。
- 打开 `workbench/index.html#rooms2/polar_gate` 等 6 间 → 顶上是天空，地形是盖雪的花岗岩，左右边是雪松树丛。
- `node tools/content.mjs check` → 0 错误，只有 1 条 polar_1「规划中」警告。

## 交付（制作方填写，不超过 40 行）
- 做了什么（每间房一句：怎么走、几条路线）
- 检查命令各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
