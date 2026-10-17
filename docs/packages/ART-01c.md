# ART-01c 极地雪村美术③：怪物、货物和零食（6 项）

状态：待派（DSN-04 合并后；和 ART-01a、ART-01b、DLV-06 互不依赖，可以同时派）
基线：`claude/inspiring-ride-zfnn4s`（DSN-04 合并以后）→ 分支：`art/ART-01c`（**不要**从 `main` 开；派之前 Claude 确认 DSN-04 已合并，基线换了就照新基线改下面两段命令）
预计：2–3 小时；超过 4 小时还没做完就停下，把进度写进「交付」交回。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-ART-01c -b art/ART-01c origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-ART-01c
```
**交回**（二选一）：
- 能推送：`git push -u origin art/ART-01c`
- 不能推送：`git bundle create ART-01c.bundle origin/claude/inspiring-ride-zfnn4s..art/ART-01c`，把 `ART-01c.bundle` 交给用户

只往 `art/ART-01c` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

## 目标
画出雪村的 2 种怪物（企鹅、雪怪）、3 种货物（含损坏状态）和零食图标燕麦饼，共 6 个第 1 版候选（status `review`），用户能在工作台「确认」页和「资产与动画」页看到、播放。机关在雪村的外观不另画（见下面「已知的坑」），所以没有 ART-01d。

## 要读的（只读这些）
- [delivery-polar.md](../design/delivery-polar.md) 第 1 节的「取材注意」和「白色多的地图怎么保证看得清」、第 2 节（货物）、第 3 节（怪物）、第 5 节的零食包装、第 6 节「ART-01c」表、第 7 节第 5、7、10 条
- [art-direction.md](../design/art-direction.md)：调色板、尺寸规定
- 照着写的样板：`art/source/monster/monster.dokkaebi.json`、`monster.seagull.json`、`art/source/cargo/cargo.kite.json`（带损坏状态）、`art/source/item/item.snack_jeju.json`
- [process.md](../process.md) 第 10 节（字体清单的规矩）

## 要做的
1. 新建 `art/source/monster/` 下 `monster.penguin.json`、`monster.yeti.json`，`art/source/cargo/` 下 `cargo.soup_flask.json`、`cargo.mittens.json`、`cargo.ice_lantern.json`，`art/source/item/item.snack_polar.json`。编号、尺寸、动作照设计第 6 节。
2. 全部第 1 版、status `review`，调色板 ENDESGA 32，`z` 描边，面朝右；动作 8 fps 以内。
3. 企鹅的白肚皮、雪怪的白毛要有 `z` 描边和 `u` / `v` 的阴影，放在雪地上也看得清；雪怪憨、可爱，不画獠牙和利爪。
4. 冰灯的灯罩可以用青色 `s`，但只有一小块、带 `z` 描边，和整格的冰分得开。
5. 候选总览图放进 `docs/packages/ART-01c/`。
6. 不能自己确认。交付里写出给用户确认用的命令（版本号以 build 结果为准）：
   `node tools/art.mjs approve --items <id@1,...> --by 用户 --via chat --scope "极地雪村美术③" --note "<用户原话>"`

已知的坑：
- 新资产就是第 1 版；已确认的 `item.snack` 不能改、不能加动作，所以另做 `item.snack_polar`（DLV-06 按地区选）。
- 机关的外观：冰、水用规则材料的画法，冷气口、热气口用关卡模式已确认的 `mech.frost_vent`、`mech.heat_vent`，这次不另画（设计第 7 节第 10 条）。用户改选专属外观时再开 ART-01d。
- 企鹅滑行撞人、雪怪熊抱、热汤罐变凉、手套湿透都是实时规则，DLV-01 之后才用；这里只画动作和损坏状态。
- 这批不画文字，用不到新字体；真要加字体文件，要同时进三处字体清单（process.md 第 10 节）。
- 和设计不一样的地方只写进交付，不改设计文档。

## 可改的文件
- 新建：上面第 1 条的 6 个美术源文件（只新建，不改已有的）、`docs/packages/ART-01c/**`（对照图）
- 生成文件：用 `node tools/art.mjs build` 生成后提交，不手改
- 本文件的状态和「交付」

验收和这个清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 不能碰的文件
- AGENTS.md 2a 冻结区里已有的一切：已有的 `art/source/**`（包括 `item.snack`、`mech.frost_vent`、`mech.heat_vent`）、`art/approvals.json`、`art/history/**`、`art/export/approved/**`、`workbench/js/core/**`、`content/i18n/*.json`
- `workbench/index.html`、`tools/**`、`tests/**`、`content/**`、`docs/design/**`
- ART-01a、ART-01b 的资产；`docs/status.md`、`game/**`
- **不能自己批准美术**，也不能把"测试通过"当作确认

## 检查
边做边跑（只跑这些）：
```bash
node tools/art.mjs build        # 只多出雪村的新候选，0 bumped
```
最后跑一次：
```bash
node tools/art.mjs build        # 0 bumped；新增 6 项；确认记录条数不变
node tools/art.mjs verify       # ok
node tools/content.mjs check    # 0 错误
node --test tests/*.test.mjs
```
不要做的：逐个算文件哈希、复制仓库做试验、逐帧比对、为写交付补跑命令（process.md 第 10 节）。

## 验收
- `node tools/art.mjs build` → 6 个新候选都是 v1、`review`，0 bumped，确认记录条数和改前一样。
- 打开工作台「确认」页 → 能看到 6 个候选；「资产与动画」页 → 怪物每个动作、货物的完好和损坏两种状态都能播放、切换。

## 交付（制作方填写，不超过 40 行）
- 做了什么（每项一句）
- 检查命令各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 和设计不一样的地方、遗留问题（没有写"无"）
- 给用户确认用的命令
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
