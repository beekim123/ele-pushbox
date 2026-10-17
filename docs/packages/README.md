# 工作包

**流程以 [docs/process.md](../process.md) 为准，包按第 9 节「文档要写清楚」的标准写**（2026-10-17 起：一切外包，Claude 只做整理合并）。派包时给制作方的提示词用 process.md 第 8 节的标准提示词，只换包号。

每个包一个文件 `docs/packages/<编号>.md`，一次会话能做完，格式见文末模板。

## 编号登记（要派、在做、等合并的包）

新包先在这里登记再写文件；设计包拆出的新包用这里预留的编号（process.md 第 3 节）。

| 编号 | 内容 | 基线 → 分支 | 会碰的共享文件 | 状态 |
|---|---|---|---|---|
| [DLV-03](DLV-03.md) | 地府顶边、v2 梯顶、配送菜单 | `claude/inspiring-ride-zfnn4s` → `dlv/DLV-03` | `index.html`、`nav.js`、`tools/art.mjs`（追加）、e2e 菜单检查 | **已合并**（2026-10-17） |
| [UX-01](UX-01.md) | 新手引导调研报告 | `claude/inspiring-ride-zfnn4s` → `ux/UX-01` | 无 | **已合并**（2026-10-17） |
| [DSN-01](DSN-01.md) | 第三张配送地图「济州海女村」设计 | `claude/inspiring-ride-zfnn4s` → `dsn/DSN-01` | `content/catalog/*.json`、本表（只加预留行） | **已合并**（2026-10-17），22 项美术候选待用户确认 |
| [DLV-04](DLV-04.md) | 济州海女村的 13 间房（配送 v2 房间数据），做完进开局池 | `claude/inspiring-ride-zfnn4s`（DSN-01、DLV-05 合并后）→ `dlv/DLV-04` | `content/catalog/slices.json`（`jeju_1`、开局池）、`worlds.json`（红蜻蜓的 `fed`）、`content/i18n-rooms2/*.json`、生成文件 | 已拆成 04a / 04b |
| [DLV-04a](DLV-04a.md) | 济州 7 间普通房（起点、过道、驿站、收件人之家） | `claude/inspiring-ride-zfnn4s` → `dlv/DLV-04a` | `i18n-rooms2`、`worlds.json`（红蜻蜓 `fed`） | 已合并（2026-10-17） |
| [DLV-04b](DLV-04b.md) | 济州 6 间机关房，济州进开局抽签 | `claude/inspiring-ride-zfnn4s` → `dlv/DLV-04b` | `i18n-rooms2`、`slices.json` | 已合并（2026-10-17；人工试玩待用户） |
| [DLV-05](DLV-05.md) | v2 回合规则支持跷跷板 / 阵风（济州的 6 间机制房要用） | `claude/inspiring-ride-zfnn4s`（DSN-01 合并后）→ `dlv/DLV-05` | `rooms2.js`、`delivery-scene2.js`、`tools/check-rooms2.mjs`、`tests/rooms2.test.mjs`（只加测试） | **已合并**（2026-10-17） |
| [DSN-02](DSN-02.md) | 声音设计：一套音效 + 每张地图的背景音乐（只写设计和包） | `claude/inspiring-ride-zfnn4s` → `dsn/DSN-02` | 本表（只改下面三行） | **已合并**（2026-10-17） |
| [WB-02](WB-02.md) | 声音流程工具与工作台「声音」菜单；DSN-02 已合并，不用等 DSN-01，可以现在派 | `claude/inspiring-ride-zfnn4s`（DSN-02 合并后，派前核对） → `wb/WB-02` | `tools/content.mjs`、`tools/lib/ids.mjs`、菜单/脚本追加、e2e 追加、生成文件 | **已合并**（2026-10-17） |
| [AUD-01](AUD-01.md) | 全游戏通用 32 项音效候选；依赖 WB-02 合并 | `claude/inspiring-ride-zfnn4s` → `aud/AUD-01` | 仅音效生成结果；与 AUD-02 的汇总生成文件合并后重建 | **已合并**（2026-10-17），待用户试听 |
| [WB-04](WB-04.md) | 合成器升级：拨弦、调频（钟铃木鱼）、锯齿波、颤音、气声、回声混响，音色预设库和试听样本 | `claude/inspiring-ride-zfnn4s` → `wb/WB-04` | `tools/lib/audio.mjs`、`tools/audio.mjs`、生成文件；现有 36 个声音源各升一版 | **已合并**（2026-10-17），试听样本待用户听 |
| [AUD-00](AUD-00.md) | 主题小调第二版：4 个抓耳方案 × 4 首独立曲子（主题曲 + 石牢 / 地府 / 海女村变奏） | `claude/inspiring-ride-zfnn4s` → `aud/AUD-00-v2` | `audio.json`（主题曲组）、`tools/content.mjs`（一处）、生成文件 | 搁置：背景音乐先不做（用户 2026-10-17） |
| [AUD-02](AUD-02.md) | 石牢、地府、海女村音乐各 3 首候选；依赖 WB-02 合并，与 AUD-01 互不依赖 | `claude/inspiring-ride-zfnn4s` → `aud/AUD-02` | 仅音乐生成结果；与 AUD-01 的汇总生成文件合并后重建 | 搁置：背景音乐先不做（用户 2026-10-17） |
| [DSN-03](DSN-03.md) | 新手引导改造设计（用户：UX-01 报告 8 个问题全按建议） | `claude/inspiring-ride-zfnn4s` → `dsn/DSN-03` | `game-design.md`（只改引导相关）、本表（只改下面三行） | **已合并**（2026-10-17） |
| [UX-02](UX-02.md) | 引导的文字和关卡数据：新表 `content/i18n-onboarding/`、字形、第 1 组 7 关加 `onboarding`（DSN-03 拆出） | `claude/inspiring-ride-zfnn4s` → `ux/UX-02` | 新文件 `content/onboarding/basics.json`、`tools/content.mjs`（只加检查）、字形生成文件 | 待派（现在可派） |
| [UX-03](UX-03.md) | 工作台关卡页预览引导；关卡里的 5（+1）项新资产 | `claude/inspiring-ride-zfnn4s`（UX-02 合并后）→ `ux/UX-03` | `play.js`（加开关）、`index.html`、`tools/art.mjs`（追加）、e2e（追加）、生成文件 | 等 UX-02 合并 |
| [UX-04](UX-04.md) | 引导进游戏 ①：备选键、Mac ⌘、鼠标悬停、按设备显示、"开始游戏"、"操作说明" | `claude/inspiring-ride-zfnn4s` → `ux/UX-04` | Godot 输入、大厅、暂停、设置（和 UI-06 同一批界面文件） | 等 UX-02、UX-03、UX-05、UI-06b、UI-06c 合并 |
| [UX-05](UX-05.md) | 引导的 7 个新界面：HUD 标 Z/R/H、规则卡按法、过关"发现"、开始游戏、操作说明、暂停、设置 | `claude/inspiring-ride-zfnn4s`（UX-02 合并后）→ `ux/UX-05` | `index.html`、`tools/art.mjs`（追加）、e2e（追加）；生成文件与 UX-03 合并后重建 | 等 UX-02 合并（可和 UX-03 同时做） |
| [UX-06](UX-06.md) | 引导进游戏 ②：按键提示层、开局心里话、目标发光、因果光、第 1 组房间放大 | `claude/inspiring-ride-zfnn4s` → `ux/UX-06` | Godot 关卡场景、存档 | 等 UX-04 合并 |
| [UX-07](UX-07.md) | 引导进游戏 ③：卡住与死局提醒、第三层提示、规则卡时机、选关目标、过关"发现" | `claude/inspiring-ride-zfnn4s` → `ux/UX-07` | Godot 关卡场景、提示面板、规则卡、选关、过关 | 等 UX-06 合并 |
| DLG-01 | 预留：对话系统第 2 步（dialogue.md 第 3、4 节：对话数据 `content/dialogue/`、`talk` / `near` / `level_idle` 触发、头顶标记、工作台「对话」页）。先由设计包定内容再拆 | — | — | 预留（新手引导 UX 系列之后） |
| [WB-03](WB-03.md) | 配送菜单改短名（开局抽签 / 石牢 / 地府 / 海女村），退役 v1 旧版 | `claude/inspiring-ride-zfnn4s` → `wb/WB-03` | `slices.json`、`nav.js`、`index.html`、e2e | 已结束：菜单已改；v1 代码被已确认界面引用，不删；v1 数据等 DLV-01 后再删 |
| [UI-09](UI-09.md) | 通用界面风格提案：3–4 个风格画在同一组样板界面上，用户选（2026-10-17） | `claude/inspiring-ride-zfnn4s` → `ui/UI-09` | `index.html`（追加）、`nav.js`（「美术」末尾加一项） | **已合并**（2026-10-17），用户选定 G2 深蓝圆角 |
| [UI-10](UI-10.md) | 按选定风格做整套游戏界面 + 配送 v2 界面 + 通用大厅 | `claude/inspiring-ride-zfnn4s` → `ui/UI-10` | `index.html`、`tools/art.mjs`（追加）；15 个界面换版本 | 已拆成 10a / 10b / 10c |
| [UI-10a](UI-10a.md) | G2 公共组件 + 8 个关卡类界面 | `claude/inspiring-ride-zfnn4s` → `ui/UI-10a` | `index.html`、`tools/art.mjs`（追加） | 已合并（2026-10-17，8 屏待用户确认） |
| [UI-10b](UI-10b.md) | G2 配送界面：三滚轮、零食、小地图、提示气泡、看全图 | `claude/inspiring-ride-zfnn4s` → `ui/UI-10b` | `index.html`、`tools/art.mjs`（追加） | 已合并（2026-10-17，界面待用户确认） |
| [UI-10c](UI-10c.md) | G2 结算、失败 + 通用大厅 | `claude/inspiring-ride-zfnn4s` → `ui/UI-10c` | `index.html`、`tools/art.mjs`（追加） | 已合并（2026-10-17，界面待用户确认） |
| [BR-01](BR-01.md) | 分支整理：合进 `main`、打 `v0.3`、删旧分支 | Claude 做 | — | 等第 1 批合并后 |
| [UI-06a](UI-06a.md) | Godot 换 G2（一）：公共组件 + 选章、选关、设置、暂停（Mac 上做） | `claude/inspiring-ride-zfnn4s` → `ui/UI-06a` | `game/presentation/ui/screens/screen.gd` | 已合并（部分通过，余下并进 06b） |
| [UI-06b](UI-06b.md) | Godot 换 G2（二）：补完 06a + 提示、规则卡、对话、过关（Mac 上做） | `claude/inspiring-ride-zfnn4s` → `ui/UI-06b` | `screen.gd`、`bubble.gd`、`capture.gd` | 已合并（2026-10-17） |
| [UI-06c](UI-06c.md) | Godot 大厅 6 套章节皮肤（Mac 上做） | `claude/inspiring-ride-zfnn4s` → `ui/UI-06c` | `screen.gd`、`capture.gd` | 待派（现在可派） |
| [DLV-01](DLV-01.md) | 配送 v2 实时规则（设计模型） | 派前 Claude 按新模板重写 | — | 待重写 |

第 1 批四个包互不冲突，可以同时派：
- DLV-03 只改工作台代码；
- UX-01 只写一份报告；
- DSN-01 改济州的设计文档和设计目录；
- DSN-02 只新建声音的设计文档和 `audio.json`，不碰 DSN-01 改的目录文件。

已用编号（不要重复）：
- `LAB-01`、`LAD-01`
- `LV-01`–`LV-12`
- `UI-01`–`UI-09`、`UI-CHOICE`
- `WB-01`
- `DLV-01`–`DLV-05`
- `UX-01`、`DSN-01`、`DSN-02`、`DSN-03`、`BR-01`
- `UX-02`–`UX-07`（DSN-03 拆出）
- `DLG-01`（预留：对话系统第 2 步）
- `WB-03`、`UI-10`、`UI-10a`–`UI-10c`、`AUD-00`、`WB-04`、`DLV-04a`、`DLV-04b`
- `WB-02`、`AUD-01`、`AUD-02`（预留）

## 以前的分支规则（2026-10-16，BR-01 之后作废）

以前关卡线在 `codex/portitor-stage1`，界面线在 `ui/style-proposals`，配送在 `claude/delivery-redesign*`。这些分支都已合进 `claude/inspiring-ride-zfnn4s`，BR-01 之后只剩 `main`。下面「顺序」一节是历史记录。

## 顺序

**关卡线**（GPT，分支 `codex/portitor-stage1`）：

| 步 | 包 | 说明 |
|---|---|---|
| 1 | [LAB-01](LAB-01.md) | 合并 Claude 分支与 LV-01 分支，重新导入 |
| 2 | [LV-02](LV-02.md)、[LV-03](LV-03.md)、[LV-04](LV-04.md) | 第 3、4、5 章补强（互不依赖） |
| 3 | [LV-05](LV-05.md) | 第 6 章改为跨章组合 |
| 4 | [LV-06](LV-06.md)、[LV-07](LV-07.md)、[LV-08](LV-08.md)、[LV-09](LV-09.md) | 第 3、4、5、6 章在 Godot / SDK 里验证 |
| 5 | [LV-10](LV-10.md) | 按 2026-10-16 设计审核修订重跑 SDK（Q03、Q04、G01、G02、G05、G06、E01、E04 与 F09 占位规则；四组整组重跑） |
| 6 | [LV-11](LV-11.md) | 第二轮修订复验：Q04、G02、E04 与两条英文提示（三组整组重跑） |
| 7 | [LV-12](LV-12.md) | G02 检查条目修正后复验（第 4 章整组） |

**工作台**：[WB-01](WB-01.md) 左侧分类菜单（用户 2026-10-16 要求，排在 UI-05 和配送工作台页面之前）。

**界面线**（只改 HTML 工作台，分支 `ui/style-proposals`）：

| 步 | 包 | 说明 |
|---|---|---|
| 1 | ~~[UI-02](UI-02.md)~~ | 已取消 |
| 2 | ~~[UI-03](UI-03.md)、[UI-04](UI-04.md)~~ | 已取消 |
| 3 | 【用户】[UI-CHOICE](UI-CHOICE.md) | **已选定（2026-10-16）**：UI-02–04 改为对话里的视觉提案，定稿见 [ui-style.md](../design/ui-style.md) |
| 4 | [UI-05](UI-05.md) | 按选定方向重做全部界面美术（HTML 工作台） |
| 5 | 【用户】确认新界面美术，然后 [UI-06](UI-06.md) | 同步到项目：关卡线合进 `main` 之后再合进 `main`，更新 Godot 界面 |
| 6 | [UI-07](UI-07.md)，再【用户】确认 | 另外三套固定界面 + 设置里的「界面风格」（等 UI-05 确认后做；可以排在 UI-06 之前或之后） |
| 4 之后 | [UI-09](UI-09.md)、[UI-08](UI-08.md) | 配送 v2 的界面候选（三滚轮、提示气泡、观察模式、小地图、零食）；工作台「配送 v2」页按新样式接入。都在 UI-05 之后做，互不依赖 |

**配送 v2 线**（设计在分支 `claude/delivery-redesign-next`，规则见 [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md)；由用户安排）：

| 步 | 包 | 说明 |
|---|---|---|
| 1 | [DLV-01](DLV-01.md) | v2 实时规则：浮块推 / 撑篙的时序、游魂、跳跳僵尸、小鬼、提示动物走位，每间房的演示 |
| 2 | [DLV-02](DLV-02.md) | v2 在 Godot 里实现（需要 DLV-01、UI-09 和用户确认的美术；暂不安排） |
| 外观 | [DLV-03](DLV-03.md) | 地府顶边画成天空、v2 梯顶收口、配送菜单按地图列出（工作台；用户 2026-10-17 决定） |

**新手引导**：[UX-01](UX-01.md) 调研与改造建议（只写报告，随时可以做）；用户和设计负责人定方案后，再拆制作包，排在 BR-01 之后、和 UI-06 一起做。

**分支整理**：[BR-01](BR-01.md) 在 DLV-03 之后做：合进 `main`、打 `v0.3`、删旧分支、改分支规则（要有推送权限）。

两条线互不依赖，可以同时做；只会在生成文件上撞车，按共同规则第 2 条重新生成。全部做完后 Claude 一次性汇总审核。已完成：[UI-01](UI-01.md)（调研报告，在 `claude/ui-01-research`）、[LV-01](LV-01.md)（设计模型插件接口，在 `claude/lv-01-model`）。配送切片的实现这次不在计划里（用户说暂时不做）；配送 v2 的两个包也等用户安排。

## 模板

```markdown
# <编号> <一句话标题>

状态：待做 / 进行中 / 已交回 / 已合并 / 退回（原因）
基线：`<基线分支>` → 分支：`<前缀小写>/<编号>`（写实际的基线，不写"默认"）
预计：<2–3 小时>；超过 <4> 小时还没做完就停下，把进度写进「交付」交回。

**开工**（照抄）：
```bash
git fetch origin
git checkout -b <前缀小写>/<编号> origin/<基线分支>
```
**交回**（二选一）：
- 能推送：`git push -u origin <前缀小写>/<编号>`
- 不能推送：`git bundle create <编号>.bundle origin/<基线分支>..<前缀小写>/<编号>`，把 `<编号>.bundle` 交给用户

只往 `<前缀小写>/<编号>` 提交；不往 `<基线分支>`、`main` 或别的分支推送，也不合并别的分支。

## 目标
做完以后能看到、能验证的结果，一两句话。

## 要读的（只读这些）
- 3–5 个文件，写到章节。其他文件用到再看，不要通读仓库。

## 要做的
1. ...
（数据放哪个文件、哪一段写清楚；已知的坑写在这里，例如"新资产就是第 1 版""已确认的 X 不能改，另做 Y"。）

## 可改的文件
- ...（清单之外一律不改。验收和这个清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过）

## 不能碰的文件
- AGENTS.md 2a 的冻结区（除非这里明确写了允许改哪个文件）
- `docs/status.md`
- ...

## 检查
边做边跑（只跑这些）：
```bash
<一两条快命令>
```
最后跑一次：
```bash
<全套里和本包相关的几条>
```
不要做的：逐个算文件哈希、复制仓库做试验、逐帧比对、为写交付补跑命令（见 process.md 第 10 节）。

## 交付（制作方填写，不超过 40 行）
- 做了什么（每项一句）
- 检查命令各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
```
