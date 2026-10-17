# DLV-08 v2 回合规则支持软糖弹跳和冰糖化（bounce、melt）

状态：待派（DSN-05 合并后）
基线：`claude/inspiring-ride-zfnn4s`（DSN-05 合并后）→ 分支：`dlv/DLV-08`（**不要**从 `main` 开：用户决定先不合进 main）
预计：3 小时；超过 4 小时还没做完就停下，把进度写进「交付」交回。
不依赖美术包，可以和 ART-02a、ART-02b、ART-02c 同时做。**不要和 DLV-06（雪村的规则支持）同时派**：两包改同一批文件，一个合并后再派另一个。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-DLV-08 -b dlv/DLV-08 origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-DLV-08
```
**交回**（二选一）：
- 能推送：`git push -u origin dlv/DLV-08`
- 不能推送：`git bundle create DLV-08.bundle origin/claude/inspiring-ride-zfnn4s..dlv/DLV-08`，把 `DLV-08.bundle` 交给用户

只往 `dlv/DLV-08` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

设计依据：[delivery-candy.md](../design/delivery-candy.md) 第 4 节「软糖和烤炉的注意」、第 7 节第 4–6、14 条。
会碰的共享文件：`workbench/js/core/rooms2.js`、`workbench/js/core/delivery-scene2.js`、`tools/check-rooms2.mjs`、`tests/rooms2.test.mjs`（只加测试）。
允许换版本的美术：无。

## 目标
配送 v2 的回合规则（`rooms2.js`）和检查工具支持关卡模式已有的两种机制：软糖 `bounce`（落上去被弹高）和烤炉化冰 `melt`（烤炉开着时冰糖化成水，水照水的规则流）。做完以后，糖果王国的 6 间机关房（DLV-09b）能写、能被 `check-rooms2` 检查；原有房间的结果不变。

## 现状
- 关卡模式的实现在 `workbench/js/core/mech/bounce.js`、`melt.js`；v2 回合规则还不认这两种装置，`FREEZABLE` 里也没有。
- DLV-05 给跷跷板、阵风做过同样的事：照它的做法（加载插件、setup / afterAction、实心钩子、`variant()` 翻转、`FREEZABLE`、`validate`、画法）。

## 要读的（只读这些）
- [DLV-05.md](DLV-05.md)：整篇，照它的做法和验收
- `workbench/js/core/mech/bounce.js`、`melt.js`：完整读，规则以它们为准
- `workbench/js/core/rooms2.js`：DLV-05 加跷跷板 / 阵风的那几段
- [delivery-candy.md](../design/delivery-candy.md) 第 4 节「软糖和烤炉的注意」、第 5 节「零食包装」、第 7 节第 4–6、14 条
- [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md) 第 1–2 节

## 要做的
1. **先查（开工第一步）**：关卡模式里用到 `bounce`、`melt` 的关有没有验证过（`content/catalog/mechanisms.json` 里这两项的状态、用到它们的关、`content.mjs check` 提到的验证报告）。有验证过的关 → 照它们的装置配置做测试房；**查不到 → 停下，把查到的写进交付交回**（设计第 7 节第 14 条 B），不要自己发明配置。
2. `tools/check-rooms2.mjs`：加载 `mech/bounce.js`、`mech/melt.js`（照 DLV-05 加载跷跷板、阵风的做法）。
3. `rooms2.js`，软糖 `{type: "bounce", at: [x, y], height}`（照 `mech/bounce.js`）：
   - 软糖本身是实心的；走上去不弹，同一列从至少高一格的地方真的落下来（人或箱子）才弹，弹起 `height` 格；路被挡就不弹；每一步最多弹一次；同一次结算里落回去，除非人被梯子接住。
   - 落在软糖上不算摔、不扣心（设计第 7 节第 4 条 A）；关卡模式另有说法就照关卡模式，写进交付。
4. `rooms2.js`，烤炉 `heat_vent`（`area: [x, y, w, h]`，照 `mech/melt.js`）：开着的时候 `area` 里的冰变成水，水再照水的模型往下落、往两边铺（第 6 条 A）；怎么开（扳杆、压板或别的）照关卡模式的接法（第 5 条），查清写进交付。
   - room/2 格式里如果还没有冰格，加一个字符，同时写进 delivery-puzzle-rules.md 第 2 节的字符表；冰不能挖（只有土和沙能挖），查清写进交付。
5. 两种装置都加进 `FREEZABLE`：冻结后（软糖不弹、烤炉不开）"必需"它的房间要没有解。
6. `variant()` 左右翻转：`bounce.at` 的 x → `W − 1 − x`；`heat_vent.area` 的 x → `W − x − w`。
7. `validate`：`at` 在房间里、`height` 是正整数；`area` 在房间里、`w`、`h` 是正整数；不合法时报错（照 DLV-05 的报错写法）。
8. `delivery-scene2.js` 画法（不依赖美术包）：
   - 软糖、烤炉口、热气用 `mech.candy_jelly`、`mech.candy_oven_vent`、`fx.candy_heat`（ART-02c）；资产还没有时画占位（照 DLV-05 的占位做法）。
   - 把 `candy` 加进 `BANDED`（多屏房间的背景竖向每屏重复一次）。
   - 零食图标按地区选：`candy` 用 `item.snack_candy`，没有时退回 `item.snack`（济州的接法照旧）。
   - 提示动物喂零食那一下：小羊的动作叫 `bleat`（济州小马是 `neigh`），照济州的接法加；资产没有时照现有的占位。
   - 冰格照关卡模式里冰的画法。
9. `delivery-puzzle-rules.md` 第 1 节「必需能冻结的机制」那一句加上软糖、烤炉。
10. 可以在 delivery-candy.md 第 4 节末尾加一小段「DLV-08 查到的」：验证关是哪几关、烤炉怎么开、落在软糖上算不算摔、冰的字符。

## 可改的文件
- `workbench/js/core/rooms2.js`、`workbench/js/core/delivery-scene2.js`、`tools/check-rooms2.mjs`
- `tests/rooms2.test.mjs`：只加测试，不改已有测试的预期
- `docs/design/delivery-puzzle-rules.md`：只改第 1 节那一句、第 2 节字符表（加冰时）
- `docs/design/delivery-candy.md`：只在第 4 节末尾加「DLV-08 查到的」
- 本文件的状态和「交付」
- （清单之外一律不改。验收和这个清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过）

## 不能碰的文件
- AGENTS.md 2a 的冻结区（上面写明的三个文件除外）：`workbench/js/core/tilemodel*.js`、`workbench/js/core/mech/*.js`（关卡模式的规则，照着用，不改）、`art/**`、`content/i18n/**`
- `content/rooms/**`、`content/catalog/**`、`game/**`
- `docs/status.md`

## 验收（运行什么 → 看到什么）
- `node --test tests/rooms2.test.mjs` → 新加的测试全部通过，至少包括：
  - 把关卡模式验证过的 `bounce`、`melt` 关搬成 v2 测试房（照 DLV-05 搬 G09 等的做法）：作者解能过；左右翻转后也能过；冻结 `bounce` / `melt` 后没有解。
  - 软糖：走上去不弹；从高一格落下弹 `height` 格；头顶被挡不弹；被梯子接住；不扣心；箱子落上去弹起再落回、停在软糖上。
  - 烤炉：开着时 `area` 里的冰变成水并往下流，`area` 外的冰不变；关着时不化。
  - `validate` 对坏参数报错；画法在有资产和没资产时都能画（占位）。
- `node tools/check-rooms2.mjs` → 原有房间全部通过，和改前一样
- `node tools/check-levels.mjs` → 和改前一样（关卡模式不受影响）

## 检查
边做边跑（只跑这些）：
```bash
node --test tests/rooms2.test.mjs
node tools/check-rooms2.mjs
```
最后跑一次：
```bash
node tools/content.mjs build && node tools/content.mjs check   # 0 错误、0 警告
node tools/check-rooms2.mjs                                    # 全部通过，和改前一样
node tools/check-levels.mjs                                    # 和改前一样
node --test tests/*.test.mjs
PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/local/bin/chromium node tests/workbench.e2e.cjs   # Linux 要设这个变量，macOS 不用
```
不要做的：逐个算文件哈希、复制仓库做试验、逐帧比对、为写交付补跑命令（见 process.md 第 10 节）。

## 交付（制作方填写，不超过 40 行）
- 做了什么（每项一句）
- 检查命令各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
