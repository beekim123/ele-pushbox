# ART-02a 糖果王国美术①：主题地形、背景、装饰和两只提示动物（6 项）

状态：待派（DSN-05 合并后）
基线：`claude/inspiring-ride-zfnn4s`（DSN-05 合并后）→ 分支：`art/ART-02a`（**不要**从 `main` 开：用户决定先不合进 main）
预计：3 小时；超过 4 小时还没做完就停下，把进度写进「交付」交回。
和 ART-02b、ART-02c、DLV-08 互不依赖，可以同时做；DLV-09a 等本包合并。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-ART-02a -b art/ART-02a origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-ART-02a
```
**交回**（二选一）：
- 能推送：`git push -u origin art/ART-02a`
- 不能推送：`git bundle create ART-02a.bundle origin/claude/inspiring-ride-zfnn4s..art/ART-02a`，把 `ART-02a.bundle` 交给用户

只往 `art/ART-02a` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

## 目标
做出糖果王国的主题 `theme.candy`（地形图案 `candy`、背景 `candy`、生态）、3 项装饰和两只提示动物，共 6 项第 1 版资产（status `review`），并在 `worlds.json` 的 `candy` 填上 `theme`、`hint_fauna`、`ambient_exclude`。做完在工作台「资产与动画」页能看到这 6 项，内容检查全绿。

## 要读的（只读这些）
- [delivery-candy.md](../design/delivery-candy.md) 第 1 节（主题与画风）、第 5 节（提示动物）、第 6 节里 ART-02a 的 6 行、第 7 节第 1–3、15 条
- [art-direction.md](../design/art-direction.md)：调色板、尺寸规定、第 8 节（规则材料的画法）
- [art-pipeline.md](../design/art-pipeline.md)：新资产怎么登记、版本和确认记录
- `workbench/js/core/terrain-jeju.js`：照它的做法写 `terrain-candy.js`
- `content/catalog/worlds.json` 的 `jeju`：`theme` / `hint_fauna` / `ambient_exclude` 的写法

## 要做的
1. 新建 `workbench/js/core/terrain-candy.js`：照 `terrain-jeju.js` 包装 `PB.terrain.drawTerrain` / `drawBackground`，只接管岩石图案 `candy` 和背景 `candy`（设计第 1 节：苏打饼干、夹心饼干墙、巧克力块、威化饼干条、粉色和薄荷糖霜顶；蓝天、奶油云、蛋糕城堡、巧克力河）。颜色只取决于材料、像素哈希和相邻格，能缓存；背景任意宽度都能画，位置按 `x − x0` 连续。
2. **规则材料（土、裂石、沙、水，连同块的描边）的画法必须和 `terrain.js` 一样**：直接交给 `terrain.js` 画，不另画；冰（冰糖块）也照原来的画法。水格保持蓝色，巧克力河只画在背景里（第 7 节第 1 条 A）。饼干不画裂纹（第 7 节第 2 条）。
3. 新资产 6 项（尺寸、动作照第 6 节）：`theme.candy`（生态里放三项装饰和 `fauna.candy_hummingbird`）、`deco.candy_lollipop_tree`、`deco.candy_mint_bush`、`deco.candy_frosting_flower`、`fauna.candy_lamb`、`fauna.candy_hummingbird`。
4. `content/catalog/worlds.json` 的 `candy`：把 `theme` 的 `null` 换成 `"theme.candy"`，在 `status` 后面加下面两项（键的顺序照 `jeju`；整个文件保持 1 格缩进，和 `JSON.stringify(…, null, 1)` 的输出一样）：
```json
"hint_fauna": [
 {"id": "candy_lamb", "name": "棉花糖小羊", "asset": "fauna.candy_lamb", "snack": "奶糖", "look": "站在下一步要用的东西旁边低头啃糖霜", "near": "走近时它小跑过去，冲着那个东西摇尾巴、点头", "fed": "咩地叫一声，头顶冒出一句提示"},
 {"id": "candy_hummingbird", "name": "小蜂鸟", "asset": "fauna.candy_hummingbird", "look": "停在下一步要去的地方", "near": "走近时飞过去，在目标上方悬停", "fed": "只帮小羊带路：喂零食要找小羊"}
],
"ambient_exclude": ["fauna.candy_hummingbird"]
```
5. 对照图放 `docs/packages/ART-02a/`：全部 6 项的总览；主题地形和背景一张，里面把饼干和规则的土、裂石、沙、水、冰并排画（给用户判断第 7 节第 2 条）；一间模拟房间（棒棒糖林 `candy_lollipop_lane` 的草图，没有验证过）。
6. 共同规定：
- 新资产全部是第 1 版，status `review`；**不能自己确认**（确认记录条数不变），等用户看。
- `workbench/index.html`、`tools/art.mjs` 只追加，不改已有的行。新字体文件（如果有）要同时进三处字体清单（process.md 第 10 节）。
- 调色板 ENDESGA 32（只用 art-direction 里的代码），`z` 描边，面朝右画；人物、动物、怪物 8 fps 以内，装饰 4 fps 以内（特效除外）。
- 已确认的资产不能改；要改就另做新编号，写进交付。

## 可改的文件
- 新建：`workbench/js/core/terrain-candy.js`；这 6 项资产在 `art/source/` 下的源文件（写法照 art-pipeline.md）；`docs/packages/ART-02a/*.png`
- `workbench/index.html`、`tools/art.mjs`：只追加
- `content/catalog/worlds.json`：只动 `candy` 的 `theme`、`hint_fauna`、`ambient_exclude`
- 生成文件（用工具生成后提交，不手改）：`tools/art.mjs build` 生成的 `art/export/*`、`art/history/*`，`content/export/*`、`workbench/data/*`
- 本文件的状态和「交付」
- （清单之外一律不改。验收和这个清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过）

## 不能碰的文件
- `art/approvals.json`（确认记录：不能自己确认）
- AGENTS.md 2a 的冻结区：已确认的资产；`workbench/js/core/` 下除新建的 `terrain-candy.js` 以外的文件（`terrain.js`、`terrain-diyu.js`、`terrain-jeju.js`、`delivery-scene2.js`、`rooms2.js` 等）；`content/i18n/**`
- ART-02b、ART-02c 的资产；`content/rooms/**`、`slices.json`、`tests/**`、`game/**`
- `docs/status.md`

## 验收（运行什么 → 看到什么）
- `node tools/content.mjs build && node tools/content.mjs check` → 0 错误、0 警告（不再有 `worlds/candy` 缺资产的错误）
- `node tools/art.mjs build` → 只多了本包的 6 项（第 1 版、`review`）；0 bumped；确认记录条数和改前一样
- 浏览器打开 `workbench/index.html#assets/theme.candy` → 用代表场景地图画出饼干地形、糖霜顶、夹心饼干墙、巧克力块和背景；规则材料和其他主题画得一样（「场景」页看不到新主题是已知问题，同济州）
- `#assets/fauna.candy_lamb`、`#assets/fauna.candy_hummingbird` 和三项装饰 → 动作都能播放

## 检查
边做边跑（只跑这些）：
```bash
node tools/art.mjs build
node tools/content.mjs check
```
最后跑一次：
```bash
node tools/content.mjs build && node tools/content.mjs check   # 0 错误、0 警告
node tools/art.mjs build                                       # 只多本包 6 项；0 bumped；确认记录条数不变
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
