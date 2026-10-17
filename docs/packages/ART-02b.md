# ART-02b 糖果王国美术②：4 位收件人的角色和滚轮头像（8 项）

状态：待派（DSN-05 合并后）
基线：`claude/inspiring-ride-zfnn4s`（DSN-05 合并后）→ 分支：`art/ART-02b`（**不要**从 `main` 开：用户决定先不合进 main）
预计：2.5 小时；超过 4 小时还没做完就停下，把进度写进「交付」交回。
和 ART-02a、ART-02c、DLV-08 互不依赖，可以同时做。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-ART-02b -b art/ART-02b origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-ART-02b
```
**交回**（二选一）：
- 能推送：`git push -u origin art/ART-02b`
- 不能推送：`git bundle create ART-02b.bundle origin/claude/inspiring-ride-zfnn4s..art/ART-02b`，把 `ART-02b.bundle` 交给用户

只往 `art/ART-02b` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

## 目标
做出糖果王国 4 位收件人（小孩、面包师、冰淇淋车老板、糖果公主）的角色动画和滚轮 / 结算头像，共 8 项第 1 版资产（status `review`）；小孩已有就沿用，这批就是 6 项。做完在工作台「资产与动画」页能看到。

## 要读的（只读这些）
- [delivery-candy.md](../design/delivery-candy.md) 第 1 节「取材注意」、第 2 节（收件人）、第 6 节里 ART-02b 的 5 行
- [art-direction.md](../design/art-direction.md)：调色板、尺寸规定
- [art-pipeline.md](../design/art-pipeline.md)：新资产怎么登记、版本和确认记录
- 济州收件人的资产（`char.haenyeo`、`avatar.haenyeo`）：照它们的尺寸、动作和头像构图

## 要做的
1. 先在 `art/` 里查 `char.kid`、`avatar.kid` 有没有：有就不重画（和乡下地图共用，已确认的不能改），写进交付；没有就按第 6 节画。
2. 新资产（尺寸、动作照第 6 节）：`char.baker`、`char.ice_cream_vendor`（带小冰淇淋车，24 × 20，`ring` 是摇铃）、`char.candy_princess`（16 × 20）、需要时 `char.kid`；`avatar.baker`、`avatar.ice_cream_vendor`、`avatar.candy_princess`、需要时 `avatar.kid`（24 × 24）。
3. 糖果公主照「取材注意」：普通肤色、棕色双丸子头、粉色裙子、一顶小王冠；不画粉皮肤粉头发，不照迪士尼公主和泡泡糖公主。金色只占几个像素（大块亮黄 `k` / `l` 留给主角）。
4. 对照图放 `docs/packages/ART-02b/`：全部角色和头像的总览一张，加一张站在饼干地面上的样子（地形用占位色即可，不依赖 ART-02a）。
5. 共同规定：
- 新资产全部是第 1 版，status `review`；**不能自己确认**（确认记录条数不变），等用户看。
- `workbench/index.html`、`tools/art.mjs` 只追加，不改已有的行。新字体文件（如果有）要同时进三处字体清单（process.md 第 10 节）。
- 调色板 ENDESGA 32（只用 art-direction 里的代码），`z` 描边，面朝右画；人物、动物、怪物 8 fps 以内，装饰 4 fps 以内（特效除外）。
- 已确认的资产不能改；要改就另做新编号，写进交付。

## 可改的文件
- 新建：这几项资产在 `art/source/` 下的源文件（写法照 art-pipeline.md）；`docs/packages/ART-02b/*.png`
- `workbench/index.html`、`tools/art.mjs`：只追加（需要时）
- 生成文件（用工具生成后提交，不手改）：`tools/art.mjs build` 生成的 `art/export/*`、`art/history/*`，`content/export/*`、`workbench/data/*`
- 本文件的状态和「交付」
- （清单之外一律不改。验收和这个清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过）

## 不能碰的文件
- `art/approvals.json`（确认记录：不能自己确认）
- AGENTS.md 2a 的冻结区：已确认的资产（包括已有的 `char.kid`、`avatar.kid`）、`workbench/js/core/**`、`content/i18n/**`
- `content/catalog/**`（收件人的数据 DSN-05 已经写好）、ART-02a、ART-02c 的资产、`tests/**`、`game/**`
- `docs/status.md`

## 验收（运行什么 → 看到什么）
- `node tools/art.mjs build` → 只多了本包的新资产（第 1 版、`review`）；0 bumped；确认记录条数和改前一样
- `node tools/content.mjs build && node tools/content.mjs check` → 0 错误、0 警告
- 浏览器打开 `workbench/index.html#assets/char.candy_princess` 等 → 每个动作都能播放；头像 24 × 24 清楚

## 检查
边做边跑（只跑这些）：
```bash
node tools/art.mjs build
```
最后跑一次：
```bash
node tools/content.mjs build && node tools/content.mjs check   # 0 错误、0 警告
node tools/art.mjs build                                       # 只多本包的新资产；0 bumped；确认记录条数不变
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
