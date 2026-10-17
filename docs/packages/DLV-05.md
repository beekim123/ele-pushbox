# DLV-05 配送 v2 回合规则支持跷跷板和阵风

状态：已交回（待 Claude 整理合并；实际济州房画面等 [DLV-04](DLV-04.md) 完成后验收）
基线：`claude/inspiring-ride-zfnn4s`（DSN-01 合并以后）→ 分支：`dlv/DLV-05`（**不要**从 `main` 开；派之前 Claude 确认 DSN-01 已合并，基线换了就照新基线改下面两段命令）

**开工**（照抄）：
```bash
git fetch origin
git checkout -b dlv/DLV-05 origin/claude/inspiring-ride-zfnn4s
```
**交回**（二选一）：
- 能推送：`git push -u origin dlv/DLV-05`
- 不能推送：`git bundle create DLV-05.bundle origin/claude/inspiring-ride-zfnn4s..dlv/DLV-05`，把 `DLV-05.bundle` 交给用户

只往 `dlv/DLV-05` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

设计依据：
- [delivery-jeju.md](../design/delivery-jeju.md) 第 4 节（哪几间房用跷跷板、阵风）、第 7 节待定问题 3、5、6、12
- [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md) 第 1 节（必需机制）、第 2 节（房间格式、翻转）、第 8.3 节
- 关卡模式的验证关 G09、G10（`content/levels/lab/react/`）、F08（`thermal/`）、E06（`experimental/`），插件 `workbench/js/core/mech/seesaw.js`、`gust.js`

会碰的共享文件：`workbench/js/core/rooms2.js`、`workbench/js/core/delivery-scene2.js`、`tools/check-rooms2.mjs`、`tests/rooms2.test.mjs`（只加测试）
允许换版本的美术：无（`art.mjs build` 必须 0 bumped）

## 目标
v2 房间的 `devices` 能写跷跷板 `seesaw` 和阵风 `gust`（写法和关卡模式一样），`check-rooms2` 的作者解、提示、翻转、"必需"检查都认它们；工作台配送 v2 画面能画出来。做完 DLV-04 就能做济州的 6 间机制房。

## 现状（DSN-01 查过）
- 工作台里 `tilemodel-runtime.js` 和全部 `mech/*.js` 插件在 `tilemodel.js` 之后加载，会替换 `PB.tilemodel`。`tools/check-rooms2.mjs` 用 `loadCore(["tilemodel", "rooms2", "mapgen", "mapgen2"])`：`tools/lib/load-core.mjs` 默认会带上 `tilemodel-runtime.js`，但不加载任何 `mech/*.js` 插件。两边要一致。
- `rooms2.act`（`rooms2.js` 第 293 行附近）自己处理每个动作，`finish` 只调 `TM.settle`：
  - 跷跷板的 `settle` 钩子会跟着跑；但开局载重基线要在 `setup` 钩子里记（`tilemodel-runtime.js` 第 166 行的做法），现在 v2 没调。
  - 阵风在 `afterAction` 钩子里（每个动作之后刮一次），v2 没调。
- 跷跷板两端的格子是实心的（插件的 `solid` 钩子）。v2 自己判断落脚和占位的函数（`platformAt`、`free`、`supports`、`floatCellOk`、`deviceCells` 等）要认它，否则人和浮块会穿过跷跷板端点。
- `variant()`（第 181 行）翻转房间时只翻已有的装置：要把 `seesaw` 的 `ends`、`landings`（`x' = W − 1 − x`）和 `gust` 的 `area`（`x' = W − x − w`）、`direction`（`L` ↔ `R`）一起翻。
- `FREEZABLE`（第 42 行）只有 `float_block`、`pole`、`push`、`dig`、`pour`、`lever`，"必需"检查冻结不了跷跷板和阵风。

## 要做
1. `check-rooms2.mjs` 加载 `mech/seesaw`、`mech/gust` 插件（或者和工作台一样加载全部插件）。先确认已有 23 间房的结果（`content/rooms2-check.generated.json`）一字不变。
2. `rooms2.js`：
   - 开局调插件的 `setup`；每个动作的 `finish` 里、`settle` 之前或之后（照 `tilemodel-runtime.js` 的顺序）调 `afterAction`；
   - 落脚、占位判断认插件的 `solid`；
   - `variant()` 翻转 `seesaw`、`gust`；
   - `FREEZABLE` 加 `seesaw`、`gust`：冻结时跷跷板不弹、阵风不刮。同步改 delivery-puzzle-rules 第 1 节里列"能冻结的机制"的那一句；
   - `validate` 检查跷跷板的 `landings` 必须是 `[端点上那格的 x ± 1, 端点上那格的 y − height]`（插件运行时才报错，太晚）。
3. 提示：小马、蜻蜓的提示步骤照常写目标格，不需要新的动作名。
4. 画法（`delivery-scene2.js`）：
   - 跷跷板画 `mech.jeju_seesaw`（每格一帧：两端 `end`，一端落下新载重时这一端 `down`、另一端 `launch`，两端之间 `mid`，正中 `pivot`；16 × 20，锚点在格子底边中点，下面 16 行是格子、板面顶边就是格子顶边，上面 4 行留给翘起的端头；用法见资产的 `usage`），阵风格画 `fx.jeju_gust`（平时 `drift`，刮风那一步 `blow`；向左时镜像）。别的地区以后有自己的图再按地区选。
   - `BANDED` 加 `jeju`（多屏房间背景按屏行重复，art-direction 第 6 节）。
   - HUD 和气泡里的零食图标：现在按地区选 `item.snack` 的 `diyu` / `dungeon` 动作（第 493 行附近）。`item.snack` 已确认，不能加动作，所以济州画 `item.snack_jeju` 的 `default`。
   - 实时的阵风（按时间刮）留给 DLV-01；这里只按回合画。
## 要读的文件
- AGENTS.md、docs/process.md
- `workbench/js/core/rooms2.js`、`tilemodel-runtime.js`、`mech/seesaw.js`、`mech/gust.js`、`delivery-scene2.js`
- `tools/check-rooms2.mjs`、`tests/rooms2.test.mjs`、`tests/tilemodel-plugin.test.mjs`

## 可改的文件
- `workbench/js/core/rooms2.js`、`workbench/js/core/delivery-scene2.js`
- `tools/check-rooms2.mjs`
- `tests/rooms2.test.mjs`（只加测试，不改已有的预期）
- `docs/design/delivery-puzzle-rules.md` 第 1 节"能冻结的机制"那一句
- 生成文件：用工具重新生成后提交，不手改

## 不能碰的文件
- AGENTS.md 2a 的冻结区：`tilemodel.js`、`tilemodel-runtime.js`、`mech/*.js`、已有的美术源文件和确认记录
- `content/rooms/**`（DLV-04 做）、`content/catalog/**`
- `docs/status.md`、`game/**`

## 验收标准（用户 2026-10-17 补充）
- 制作过程中只跑 `node --test tests/rooms2.test.mjs`、`node tools/check-rooms2.mjs`。
- 最后只跑一次以下全套；失败了只重跑失败的命令及受它影响的命令，不为交付说明补跑已确认的结果：
  ```bash
  node tools/content.mjs check       # 0 错误，允许 jeju_1 警告
  node tools/check-rooms2.mjs        # 已有 23 间房的结果与改前相同
  node tools/check-levels.mjs        # 结果不变
  node tools/art.mjs build          # 0 bumped
  node --test tests/*.test.mjs
  node tests/workbench.e2e.cjs
  ```
- 测试按本机资源预算单 worker 执行；不逐个计算文件哈希，不复制仓库或试导入 bundle，不逐帧比对画面。
- Mac 的 E2E 如找不到依赖，使用 `PLAYWRIGHT_MODULE=/Users/key_/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright` 和 `PLAYWRIGHT_CHROMIUM_EXECUTABLE=/Users/key_/Library/Caches/ms-playwright/chromium-1217/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing`；Linux 用 `PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/local/bin/chromium`。
- 新测试（放进 `tests/rooms2.test.mjs`）：把 G09、G10、F08、E06 改写成 4 间 v2 测试房间（直接写在测试里，不放进 `content/rooms/`）：
  - 作者解能通关，步数和关卡模式的最短解一致；
  - 左右翻转后作者解（`L` ↔ `R`）仍能通关；
  - 冻结 `seesaw` 或 `gust` 后无解；
  - `landings` 写错时 `validate` 报错。
- 在 `tests/rooms2.test.mjs` 里用 `delivery-scene2.js` 绘制这 4 间房，不报错；断言跷跷板、阵风格的位置调用了 `mech.jeju_seesaw` / `fx.jeju_gust` 的画法。只检查调用，不做截图比对。测试房间不放进内容目录，工作台实际画面等 DLV-04 做好济州房间后再看。

## 交付（制作方填写）
### 做了什么
- 接入跷跷板、阵风的初始化和回合结算、实体碰撞、翻转、冻结及落点校验。
- 接入济州跳板、阵风、小米糕和分屏背景绘制，保留同回合先弹射后被风清空端点的反馈。
- 追加四间内存测试房及回归测试，覆盖完整原关卡目标、最短解、原作者解、镜像、冻结、提示和绘制调用。
- 按补充说明取消场景页和工作台打开测试房的要求，记录两档检查规则。

### 最后全套检查
- `node tools/content.mjs check`：0 错误，1 条允许的 `jeju_1` 警告。
- `node tools/check-rooms2.mjs`：23 间房及 300 个种子通过，输出与改前逐字相同，既有生成报告未变。
- `node tools/check-levels.mjs`：通过，输出与改前逐字相同。
- `node tools/art.mjs build`：156 assets，0 bumped，94 reference renders，6 条确认记录不变。
- `node --test tests/*.test.mjs`：用 `--test-concurrency=1` 串行执行，213/213 通过。
- `node tests/workbench.e2e.cjs`：使用用户提供的 Mac 环境变量，`all workbench checks passed`。

### 改了哪条测试的预期、为什么
无；只追加测试，已有预期未改。

### 遗留问题
- 基线 G09/G10/F08 原作者解为 13/14/10 步，最短为 12/13/9 步；测试保留原解，并用模型最短路线作等长回放，未改关卡设计。
- 实际济州房画面按补充要求留待 DLV-04；下一步由 Claude 按流程整理合并本包，再由 DLV-04 制作方验收实际房间。
