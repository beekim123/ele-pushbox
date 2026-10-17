# ART-01a 极地雪村美术①：主题地形、背景、装饰和提示动物（7 项）

状态：待派（DSN-04 合并后；和 ART-01b、ART-01c、DLV-06 互不依赖，可以同时派）
基线：`claude/inspiring-ride-zfnn4s`（DSN-04 合并以后）→ 分支：`art/ART-01a`（**不要**从 `main` 开；派之前 Claude 确认 DSN-04 已合并，基线换了就照新基线改下面两段命令）
预计：3 小时；超过 4 小时还没做完就停下，把进度写进「交付」交回。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-ART-01a -b art/ART-01a origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-ART-01a
```
**交回**（二选一）：
- 能推送：`git push -u origin art/ART-01a`
- 不能推送：`git bundle create ART-01a.bundle origin/claude/inspiring-ride-zfnn4s..art/ART-01a`，把 `ART-01a.bundle` 交给用户

只往 `art/ART-01a` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

## 目标
画出雪村的主题 `theme.polar`（新文件 `terrain-polar.js` 画地形图案和背景）、4 种装饰、2 种提示动物，共 7 个第 1 版候选（status `review`），用户能在工作台「确认」页和「资产与动画」页看到、播放。做完 DLV-07a 就能做普通房。

## 要读的（只读这些）
- [delivery-polar.md](../design/delivery-polar.md) 第 1 节（主题与画风、取材注意）、第 5 节（提示动物）、第 6 节「ART-01a」表、第 7 节第 1、2、11、13 条
- [art-direction.md](../design/art-direction.md)：调色板、尺寸规定、第 8 节（规则材料）
- 照着写的样板：`workbench/js/core/terrain-jeju.js`、`art/source/theme/theme.jeju.json`、`art/source/deco/deco.jeju_tangerine_tree.json`、`art/source/fauna/fauna.jeju_pony.json`、`art/source/fauna/fauna.jeju_dragonfly.json`
- [process.md](../process.md) 第 10 节（字体清单的规矩）

## 要做的
1. 新建 `workbench/js/core/terrain-polar.js`：照 `terrain-jeju.js` 包装 `PB.terrain.drawTerrain` / `drawBackground`，只接管岩石图案 `polar` 和背景 `polar`（连同可选的傍晚 `dusk`），画法照设计第 1 节。
   - 颜色只取决于材料、像素哈希、相邻格和离房间底边多远，能缓存。
   - 规则材料（土、裂石、沙、水、冰，连同块的描边）不接管，交给 `terrain.js`，和其他主题一模一样。
   - 雪只画在岩石顶面（几像素的白），不用青色 `s`，不成整格。
2. 新建 `art/source/theme/theme.polar.json`（照 `theme.jeju.json`）：地形图案、背景、生态、环境。生态里要有 4 种装饰和 `fauna.polar_bunting`（DLV-07a 要在 `worlds.json` 写 `ambient_exclude`，内容检查要求它在生态里）；木屋、雪屋每屏最多 1 座；天气默认关，只能选「下雪」。
3. 新建 4 种装饰（`art/source/deco/`）和 2 种提示动物（`art/source/fauna/`），编号、尺寸、动作照设计第 6 节。全部第 1 版、status `review`，调色板 ENDESGA 32，`z` 描边，面朝右；动作 8 fps 以内，装饰 4 fps 以内。
4. `workbench/index.html` 第 139 行 `terrain-jeju.js` 后面加一行 `<script src="js/core/terrain-polar.js"></script>`；`tools/art.mjs` 第 20 行 `loadCore([...])` 里 `"terrain-jeju"` 后面加 `"terrain-polar"`。别的地方不改。
5. 对照图放进 `docs/packages/ART-01a/`：主题地形和背景、傍晚极光、一张模拟房间（`polar_lake` 的草图，没有验证过）、7 项候选总览。
6. 不能自己确认。交付里写出给用户确认用的命令（版本号以 build 结果为准）：
   `node tools/art.mjs approve --items <id@1,...> --by 用户 --via chat --scope "极地雪村美术①" --note "<用户原话>"`

已知的坑：
- 新资产就是第 1 版；已确认的资产、`terrain.js`、`terrain-diyu.js`、`terrain-jeju.js` 都不能改。
- 「场景」页只列写死的主题，看不到 `theme.polar`：在「资产与动画」页 `#assets/theme.polar` 看（同济州第 7 节第 5 条）。
- `delivery-scene2.js` 的 `BANDED` 由 DLV-06 加 `polar`，这里不碰。
- `worlds.json` 的 `theme`、`hint_fauna` 由 DLV-07a 填，这里不碰。
- 这批不画文字，用不到新字体；真要加字体文件，要同时进三处字体清单（process.md 第 10 节）。
- 和设计不一样的地方只写进交付，不改设计文档。

## 可改的文件
- 新建：`art/source/theme/theme.polar.json`、`art/source/deco/` 下 4 个 `deco.polar_*.json`、`art/source/fauna/` 下 `fauna.polar_reindeer.json`、`fauna.polar_bunting.json`（只新建，不改已有的）
- 新建：`workbench/js/core/terrain-polar.js`、`docs/packages/ART-01a/**`（对照图）
- `workbench/index.html`、`tools/art.mjs`：只追加加载 `terrain-polar`（上面第 4 条）
- 生成文件：用 `node tools/art.mjs build` 生成后提交，不手改
- 本文件的状态和「交付」

验收和这个清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 不能碰的文件
- AGENTS.md 2a 冻结区里已有的一切：已有的 `art/source/**`、`art/approvals.json`、`art/history/**`、`art/export/approved/**`、已有的 `workbench/js/core/` 绘制文件（包括 `terrain.js`、`terrain-jeju.js`、`delivery-scene2.js`）、`content/i18n/*.json`
- `content/**`（包括 `worlds.json`）、`docs/design/**`
- ART-01b、ART-01c 的资产；`docs/status.md`、`game/**`
- **不能自己批准美术**，也不能把"测试通过"当作确认

## 检查
边做边跑（只跑这些）：
```bash
node tools/art.mjs build        # 只多出雪村的新候选，0 bumped
```
最后跑一次：
```bash
node tools/art.mjs build        # 0 bumped；新增 7 项；确认记录条数不变
node tools/art.mjs verify       # ok
node tools/content.mjs check    # 0 错误
node --test tests/*.test.mjs
node tests/workbench.e2e.cjs    # 改了 index.html
```
不要做的：逐个算文件哈希、复制仓库做试验、逐帧比对、为写交付补跑命令（process.md 第 10 节）。

## 验收
- `node tools/art.mjs build` → 7 个新候选都是 v1、`review`，0 bumped，确认记录条数和改前一样。
- 打开工作台「确认」页 → 能看到 7 个候选；「资产与动画」页 → 每个动作都能播放。
- 打开 `#assets/theme.polar` → 上面亮蓝天、远处雪山冰川，下面深色雪松林剪影；地形是盖雪的深蓝灰花岗岩，左右两列雪松树丛；规则材料和别的主题画得一样。

## 交付（制作方填写，不超过 40 行）
- 做了什么（每项一句）
- 检查命令各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 和设计不一样的地方、遗留问题（没有写"无"）
- 给用户确认用的命令
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
