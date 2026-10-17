# DLV-06 配送 v2 回合规则支持冰面滑行、冷凝、化冰

状态：待派（DSN-04 合并后；不依赖美术，和 ART-01a/b/c 可以同时派；和 DSN-05 拆出的 DLV-08 改同一批文件，**不同批派**）
基线：`claude/inspiring-ride-zfnn4s`（DSN-04 合并以后）→ 分支：`dlv/DLV-06`（**不要**从 `main` 开；派之前 Claude 确认 DSN-04 已合并，基线换了就照新基线改下面两段命令）
预计：3–4 小时；超过 5 小时还没做完就停下，把进度写进「交付」交回。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-DLV-06 -b dlv/DLV-06 origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-DLV-06
```
**交回**（二选一）：
- 能推送：`git push -u origin dlv/DLV-06`
- 不能推送：`git bundle create DLV-06.bundle origin/claude/inspiring-ride-zfnn4s..dlv/DLV-06`，把 `DLV-06.bundle` 交给用户

只往 `dlv/DLV-06` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

设计依据：
- [delivery-polar.md](../design/delivery-polar.md) 第 4 节（哪几间房用哪种机制、「必需滑行」的做法）、第 5 节零食包装、第 7 节第 2、8、9、10 条
- [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md) 第 1 节（必需机制）、第 2 节（房间格式、翻转）、第 8.3 节
- 关卡模式的验证关 F07、F02、F03、F09（`content/levels/lab/thermal/`），插件 `workbench/js/core/mech/ice_slide.js`、`freeze.js`、`melt.js`

会碰的共享文件：`workbench/js/core/rooms2.js`、`workbench/js/core/delivery-scene2.js`、`tools/check-rooms2.mjs`、`tests/rooms2.test.mjs`（只加测试）
允许换版本的美术：无（`art.mjs build` 必须 0 bumped）

## 目标
v2 房间能写规则的冰、冷气口 `frost_vent`、热气口 `heat_vent`（写法和关卡模式一样），`check-rooms2` 的作者解、提示、翻转、"必需"检查都认它们；工作台配送 v2 画面能画出来。这包和 DLV-07a 都合并以后，DLV-07b 就能做雪村的 7 间机关房。

## 现状（DSN-04 只看了插件开头的说明，没查 `rooms2.js`）
- `ice_slide`：横着推的箱子，脚下是冰就一直滑；可以滑出冰面、停在第一格干地上；人不滑。插件用共享的 `action` / `done` 钩子，一推就是一步、一次撤销。
- `freeze`：装置 `frost_vent` 开着时喷一下，把格子里的水变成冰；不会自己化。
- `melt`：装置 `heat_vent` 开着时把冰变成水；之后照普通水的规则下落、流动、存进沟里。
- DLV-05 已经让 `check-rooms2.mjs` 加载跷跷板、阵风插件，并在 `rooms2.js` 里接了 `setup` / `afterAction` / `solid`；DLV-05 的交付和 `tests/rooms2.test.mjs` 里的 4 间测试房是现成的写法样板。

## 要做的
1. `check-rooms2.mjs` 加载 `mech/ice_slide`、`mech/freeze`、`mech/melt`（或者和工作台一样加载全部插件）。先确认已有 36 间房的结果（`content/rooms2-check.generated.json`）一字不变。
2. `rooms2.js`：
   - 推箱子走插件的 `action` / `done` 钩子：滑行经过压板、碰到门和别的箱子、滑出冰面掉进坑，和关卡模式一样；一推一步、一次撤销；
   - 冷气口、热气口和它们的开关照验证关的写法；化冰流出的水交给 v2 的水（下落、流动、存进沟里），不一致的地方照 `melt.js` 的顺序补上，写进交付；
   - `variant()` 翻转房间时一起翻冷气口、热气口的位置和范围（`x' = W − 1 − x`，有宽度的 `x' = W − x − w`），有方向的 `L` ↔ `R`；
   - `FREEZABLE` 加 `ice_slide`、`freeze`、`melt`：冻结滑行时推一下只走一格，冻结冷凝 / 化冰时气口不喷。同步改 delivery-puzzle-rules 第 1 节里列"能冻结的机制"的那一句；
   - `validate` 检查气口的字段（位置在房间里、范围合法、开关存在），写错时报错，不要等插件运行时才报。
3. 提示：小驯鹿、雪鹀的提示步骤照常写目标格，不加新的动作名。
4. 画法（`delivery-scene2.js`）：
   - 冰照关卡模式的画法（规则材料，`terrain.js`）；冷气口、热气口画 `mech.frost_vent` / `mech.heat_vent`，动作照资产的 `usage`；开关照关卡模式。
   - `BANDED` 加 `polar`（多屏房间背景按屏行重复，art-direction 第 6 节）。
   - HUD 和气泡里的零食图标：雪村画 `item.snack_polar` 的 `default`。这个资产由 ART-01c 做，还没合并时退回 `item.snack` 的默认画法，不报错。
   - 热汤罐变凉、手套湿透这些实时规则留给 DLV-01；这里只按回合画。

## 要读的（只读这些）
- AGENTS.md、docs/process.md
- `workbench/js/core/rooms2.js`、`tilemodel-runtime.js`、`mech/ice_slide.js`、`mech/freeze.js`、`mech/melt.js`、`delivery-scene2.js`
- `tools/check-rooms2.mjs`、`tests/rooms2.test.mjs`、`tests/tilemodel-plugin.test.mjs`
- [DLV-05.md](DLV-05.md) 的「交付」；验证关 F07、F02、F03、F09 的规格（装置参数照抄）

## 可改的文件
- `workbench/js/core/rooms2.js`、`workbench/js/core/delivery-scene2.js`
- `tools/check-rooms2.mjs`
- `tests/rooms2.test.mjs`（只加测试，不改已有的预期）
- `docs/design/delivery-puzzle-rules.md` 第 1 节"能冻结的机制"那一句
- 生成文件：用工具重新生成后提交，不手改

验收和这个清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 不能碰的文件
- AGENTS.md 2a 的冻结区：`tilemodel.js`、`tilemodel-runtime.js`、`mech/*.js`、`terrain*.js`、已有的美术源文件和确认记录
- `content/rooms/**`（DLV-07a / 07b 做）、`content/catalog/**`、`content/levels/**`
- `docs/status.md`、`game/**`

## 检查
边做边跑（只跑这些）：
```bash
node --test tests/rooms2.test.mjs
node tools/check-rooms2.mjs
```
最后跑一次：
```bash
node tools/content.mjs check       # 0 错误；DLV-07a 已合并时允许 1 条 polar_1「规划中」警告
node tools/check-rooms2.mjs        # 已有 36 间房的结果与改前相同
node tools/check-levels.mjs        # 结果不变
node tools/art.mjs build           # 0 bumped
node --test tests/*.test.mjs
node tests/workbench.e2e.cjs
```
测试按本机资源预算单 worker 执行（`--test-concurrency=1`）。不要做的：逐个算文件哈希、复制仓库或试导入 bundle、逐帧比对、为写交付补跑命令（process.md 第 10 节）。

## 验收
- `node --test tests/rooms2.test.mjs` → 新加的 5 间测试房全过（直接写在测试里，不放进 `content/rooms/`）：
  - F07、F02、F03、F09 改写成 4 间 v2 房：作者解能通关，步数和关卡模式的最短解一致（不一致就照 DLV-05 的做法写进交付）；
  - 第 5 间是滑行 + 化冰（温泉冰坝的草图：木箱滑到冰坝前当台阶，踩上去开热气口，冰坝化开后再推一下，木箱滑进坑里）：作者解能通关；
  - 左右翻转后作者解（`L` ↔ `R`）仍能通关；冻结房间用到的 `ice_slide` / `freeze` / `melt` 任一种后无解；
  - 气口字段写错时 `validate` 报错；
  - 用 `delivery-scene2.js` 画这 5 间房不报错，气口的格子调用了 `mech.frost_vent` / `mech.heat_vent` 的画法（只检查调用，不截图比对）。
- `node tools/check-rooms2.mjs` → 已有 36 间房和 300 个种子全部通过，输出和改前一样。

## 交付（制作方填写，不超过 40 行）
- 做了什么（每项一句）
- 检查命令各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
