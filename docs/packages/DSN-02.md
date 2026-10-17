# DSN-02 声音设计：一套音效 + 每张地图的背景音乐（只写设计和工作包）

状态：已交回（2026-10-17，制作方 Codex；设计候选，待 Claude 范围审核与合并，未做声音制作）
基线：`claude/inspiring-ride-zfnn4s` → 分支：`dsn/DSN-02`（**不要**从 `main` 开：`main` 现在还是旧内容）

**开工**（照抄）：
```bash
git fetch origin
git checkout -b dsn/DSN-02 origin/claude/inspiring-ride-zfnn4s
```
**交回**（二选一）：
- 能推送：`git push -u origin dsn/DSN-02`
- 不能推送：`git bundle create DSN-02.bundle origin/claude/inspiring-ride-zfnn4s..dsn/DSN-02`，把 `DSN-02.bundle` 交给用户

只往 `dsn/DSN-02` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

设计依据：
- `docs/design/vision.md`
- `docs/design/game-design.md` 第 7.5 节（设置里的 `music`、`sfx` 音量）、第 8 节（界面）
- `docs/design/ids.md`：编号空间，已经预留了 `sfx`、`music`
- `docs/design/architecture.md`：Godot 工程里的 `audio/` 目录
- `docs/design/art-pipeline.md`：美术的"源文件 → 生成 → 用户确认"流程，声音照着设计一套
- `docs/design/workbench.md` 第 6 节：工作台页面
- `docs/design/ui-style.md`：大厅按章节换皮肤

会碰的共享文件：`docs/packages/README.md` 登记表，只改 WB-02、AUD-01、AUD-02 三行。**不改** `content/catalog/worlds.json`、`slices.json`：DSN-01 正在改它们。
允许换版本的美术：无（这一包不碰美术，`art.mjs build` 必须 0 bumped）。
预留编号：
- `WB-02`：工作台「声音」菜单与声音流程工具
- `AUD-01`：一套音效
- `AUD-02`：三张地图的背景音乐候选

## 用户的要求（2026-10-17 原话整理）
1. **制作方式**：音效和音乐都用**程序生成的芯片音乐**（sfxr / ZzFX 一类合成音效，ZzFXM / BeepBox 一类音乐数据）。声音的源文件是文字数据，存在仓库里，能追踪版本、能重新生成。不用录音、不用外部 AI 音乐生成器、不用别人的音乐。
2. **风格**：这是一款**休闲游戏**。声音要柔和、不刺耳：
   - 少用尖锐的方波高音和刺耳的噪声；
   - 音量不忽大忽小；
   - 背景音乐能长时间循环也不烦。
3. **音效做一套**：全游戏通用，不按地图分。
4. **背景音乐按地图做**：每张地图一套自己风格的音乐。
   - 现在要做三张：**石牢**（幽暗石牢 / 废弃的符文监狱）、**地府**（地府·酆都）、**海女村**（济州海女村）。
   - 每张至少出 **3 首候选**，让用户试听后选一首。
   - 以后每开一张新地图，就给它做一套。
5. **默认音乐是石牢的**：
   - 还没有自己音乐的地图或章节，一律放石牢的音乐。
   - **大厅**：大厅显示哪张地图（大厅皮肤跟着章节换），就放哪张地图的音乐；那张地图还没有音乐，就放石牢的。
6. **HTML 工作台新开一个菜单，专门管理声音**：
   - 试听全部音效和音乐；
   - 每张地图的候选曲并排比较；
   - 选定后由用户确认；
   - 能看到每张地图现在用的是哪首。

## 目标
写出声音的完整设计，并把制作拆成三个工作包。**这一包只写文档和设计目录，不写代码、不做声音。**

## 要产出
1. **新设计文档 `docs/design/audio.md`**（中文，用户能看懂）：
   1. **风格总则**：把"休闲、不刺耳"写成可检查的规则。例如：
      - 波形以三角波、正弦波、柔和的方波为主，高频噪声限量；
      - 音效的音高上限、最长时长；
      - 响度目标和峰值上限：音效之间、音乐之间响度大致一致，写出数值和测量方法；
      - 音乐的速度范围、循环长度、循环接缝处不能有爆音。
   2. **音效清单**（一套，全游戏通用）：每个音效写编号（`sfx` 空间，例如 `sfx.push`）、什么时候播放、听起来像什么、时长、同一时间最多叫几次（防止连按时叠成噪音）。至少覆盖：
      - 关卡：走（要不要有脚步声请给建议，休闲游戏可以不要）、推箱、箱子落地、爬梯、挖、倒沙、压板按下 / 松开、门开 / 关、目标灯亮、全部灯亮过关、撤销、重开、提示出现、规则卡；
      - 配送：金币、受伤、货物受损、滚轮转动 / 停下、重转、驿站买东西、喂零食、提示动物叫一声、送达；
      - 界面：光标移动、确认、取消 / 返回、打开 / 关闭菜单、不能操作时的提示音、设置里调音量时的试听音。
   3. **音乐清单与规则**：
      - 每张地图一套：`music.dungeon`、`music.diyu`、`music.jeju`，编号规则以你的设计为准，写清楚；
      - 每套至少 3 首候选：每首写主题、乐器（芯片音色）、速度、调式、情绪关键词，以及和另外两张图的区别（石牢：地下、安静；地府：中国民间、夜里、诙谐温暖不吓人；海女村：白天的海边、轻快）；
      - **哪里放哪首**：关卡模式（按章节的主题）、配送（按滚轮抽到的地图）、大厅（按大厅当前显示的地图）、结算等界面（继续放当前音乐还是另有短曲，给建议）；
      - **回退规则**：没有音乐的地图或章节放石牢的；
      - 切换时淡入淡出的时长；
      - 暂停菜单里音乐压低多少。
   4. **源文件格式和流程**：照美术流程写一套声音流程：
      - **源文件**：建议 `audio/source/<sfx|music>/<编号>.json`，存合成参数或曲谱数据，写清字段；
      - **生成**：建议 `node tools/audio.mjs build`，生成 `audio/export/**` 下的 `.wav` 或 `.ogg`；
      - **版本**：源文件改了就升版本；
      - **确认**：只有用户能确认。确认记录**单独放** `audio/approvals.json`，**不要**和 `art/approvals.json` 混在一起（那是冻结文件）；Claude 按用户原话用 `node tools/audio.mjs approve` 记录；
      - 游戏只用确认过的声音，没确认的不进游戏；
      - 交给 Godot 的方式：进 `res://generated/`，按 uid 取。
   5. **工作台「声音」菜单**（写给 WB-02 照着做）：
      - 左侧菜单新开一个分类「声音」，下面至少两页：「音效」「音乐」。可以再加「按地图」：每张地图一行，显示现在用哪首、有几首候选；
      - 音效页：按清单列出，每个能点播放，显示时长、响度、版本、是否已确认；
      - 音乐页：按地图分组，同一张地图的候选并排；能播放、暂停、从头放、循环试听（检查接缝）；显示时长、速度、响度、版本、确认状态；
      - 「设为这张地图的音乐」只是标记"用户想要这首"，真正的确认仍然由用户告诉 Claude 记录；
      - 有总音量、音乐音量、音效音量三个滑块，和游戏设置对应；
      - 写清这一页在工作台菜单里的位置和网址（例如 `#audio/sfx`、`#audio/music`）。
2. **编号**：在 `docs/design/ids.md` 写明 `sfx`、`music` 两个空间的来源文件和游戏路径。真正写进 `tools/lib/ids.mjs` 是 WB-02 的事。
3. **设计目录**：新建 `content/catalog/audio.json`，写音效清单、每张地图对应的音乐编号、默认音乐（石牢）、回退规则。地图和章节用已有的 id 引用（`dungeon_2`、`diyu_1`、`jeju_1`，以及关卡章节或主题的 id）。
   - 改完运行 `node tools/content.mjs check`，必须 0 错误。
   - 如果内容检查不认识这个新文件而报错，就在设计文档里写明，交给 WB-02 让工具支持它；**不要**自己改工具代码。
   - `jeju_1` 这时可能还没进 `slices.json`（DSN-01 在做），引用它报错的话，同样写进交付，不要去改 `slices.json`。
4. **三个工作包**（格式照 `docs/packages/README.md` 的模板，每个包头都要写全基线、分支名、开工和交回命令，按 `docs/process.md` 第 9 节「文档要写清楚」）：
   - **`WB-02` 声音流程与「声音」菜单**：
     - `tools/audio.mjs`（build / verify / approve）；
     - 合成器（音效和音乐数据 → `.wav`，同一份源文件每次生成的结果完全一样）；
     - 工作台「声音」菜单；
     - `ids.mjs` 加 `sfx`、`music`；
     - 内容检查认识 `audio.json`；
     - 测试（用临时目录，不写真的确认记录）。
     - 这个包要先做。
   - **`AUD-01` 一套音效**：按清单做全部音效的源文件，跑 build，在工作台能试听；全部是待确认候选。
   - **`AUD-02` 三张地图的背景音乐**：石牢、地府、海女村各至少 3 首候选，跑 build，在工作台能并排试听、循环无爆音；全部是待确认候选。
   - AUD-01 和 AUD-02 都依赖 WB-02，两者之间互不依赖，可以同时做。包里写明基线是"WB-02 合并之后的分支"，具体分支名由 Claude 派包时补上。
   - 每个包都写清验收标准，例如：
     - `node tools/audio.mjs build` 0 错误；
     - `node tools/audio.mjs verify` 检查响度和峰值在设计范围内；
     - 工作台「声音」页能看到并播放；
     - `node --test`、`node tests/workbench.e2e.cjs` 全部通过；
     - `node tools/art.mjs build` 0 bumped。
5. **登记表**：`docs/packages/README.md` 的登记表里，把 WB-02、AUD-01、AUD-02 三行写上（内容、依赖、状态「待派」）。

## 可改的文件
- 新建：
  - `docs/design/audio.md`
  - `content/catalog/audio.json`
  - `docs/packages/WB-02.md`、`docs/packages/AUD-01.md`、`docs/packages/AUD-02.md`
- 修改：
  - `docs/design/ids.md`：只改 `sfx`、`music` 的说明
  - `docs/design/workbench.md`：第 6 节加「声音」页一行
  - `docs/design/game-design.md`：第 8 节设置那一行，只补"音乐、音效"的说明链接
  - `docs/packages/README.md`：只改 WB-02、AUD-01、AUD-02 三行
  - 本文件的状态和「交付」
- 生成文件：只在 `content.mjs build` 需要时重新生成后提交，不手改。

## 不能碰的文件
- 任何代码：`tools/**`、`workbench/**`、`tests/**`、`game/**`。代码是 WB-02 的事。
- 不做声音：不生成任何 `.wav` / `.ogg`，不建 `audio/` 目录。
- 美术和冻结区（AGENTS.md 2a）：`art/**`、`content/i18n/*.json`。
- `content/catalog/worlds.json`、`slices.json`：DSN-01 正在改它们。
- `docs/status.md`。

## 验收标准
- `node tools/content.mjs check` → 0 错误。如果是因为工具还不认识 `audio.json`，就按上面第 3 条写明原因。
- `node tools/art.mjs build` → 0 bumped；`node --test tests/*.test.mjs` 全部通过。
- `docs/design/audio.md` 五部分齐全：
  - 风格规则有具体数值；
  - 音效清单覆盖上面列的全部场合；
  - 三张地图各写了 3 首候选的方向；
  - 播放与回退规则写清了大厅、关卡、配送三处；
  - 工作台「声音」菜单写清了页面和网址。
- WB-02、AUD-01、AUD-02 三个包写好，包头完整（基线、分支、开工和交回命令），并在 README 登记。
- `git diff --stat` 里的文件都在「可改的文件」清单里。

## 交付（制作方填写）

### 结果与范围

- 完成 `docs/design/audio.md` 五部分：量化风格与测量方法、32 项全游戏音效、三图各 3 首音乐方向、播放/回退/确认流程、工作台三个页面与网址。
- 新增 `content/catalog/audio.json`：32 音效 + 9 候选 + 3 曲组，共 44 个唯一 uid；默认 `music:dungeon`，未确认石牢也没有时静音。列出既有章节/组、配送切片与世界引用；`jeju_1` 的跨包依赖显式记录。
- 拆好 WB-02（工具和菜单）、AUD-01（音效）、AUD-02（音乐），只更新 README 预留的三行。WB-02 先做；两个 AUD 包依赖它合并，基线名称按本包授权由 Claude 派前填写。
- 仅修改本包允许的 10 个设计/目录/工作包文件；不写代码，不生成声音，不创建 audio/，不改 worlds/slices，不批准任何资产。ids、workbench、game-design 只改获准说明/链接。
- 设计引用与包头做过只读交叉审核，已明确 UID 格式、发布基线版本收敛、新质量确认与历史采用分离、草选不等于确认。

### 分支与交回

- 分支：`dsn/DSN-02`。
- 开工基线：`origin/claude/inspiring-ride-zfnn4s`，提交 `87038d701528ad309fb2815b9e7d9f5ec4c28073`；没有从 main 开分支，也未合并其他分支。
- 交回方式：推送 `git push -u origin dsn/DSN-02`；推送结果由最后交回消息核对。

### 实际验证（2026-10-17）

顺序执行，单 worker；数值库线程均设 1。Node `v24.18.0`。沙箱中的 nice 提示 `setpriority: Operation not permitted`，命令仍正常执行；最终浏览器 e2e 在获准的沙箱外使用 nice 运行。完整日志保留在本机 `/tmp/dsn02-checks/`。

| 命令 | 实际结果（均为最终运行退出码 0） |
|---|---|
| `node tools/content.mjs check` | `content: 0 error(s), 0 warning(s); 52 planned levels, 46 with specs; mechanisms playable 27, specified 15, proposed 35; verification report present`；设计定稿后重跑结果相同 |
| `node tools/check-levels.mjs` | 46 条关卡均 `ok`，无失败；结果行如 `ok W10 author=6 shortest=6 states=39 dead=20` |
| `node tools/check-rooms.mjs` | 10 个模板通过；`ok slice dungeon_1: 300 seeds`，v1 演示/翻转通过 |
| `node tools/check-rooms2.mjs` | 23 个模板通过；`✓ 开局池 delivery_pool：300 个种子 地图 {"dungeon_2":151,"diyu_1":149} 房间数 {"7":35,"8":138,"9":105,"10":22}` |
| `node tools/art.mjs build` | `build ok: 134 assets, 0 bumped, 94 reference renders, 6 approval records`；`text layout: 0 issue(s) in shipped locales` |
| `node tools/art.mjs verify` | `verify ok: 134 assets, 6 approval records` |
| `node --test --test-concurrency=1 tests/*.test.mjs` | `tests 151`、`pass 151`、`fail 0`、`cancelled 0`、`skipped 0`、`todo 0`；覆盖全套测试，只限制并发 |
| `node tests/workbench.e2e.cjs`（环境见下） | 76 个 `ok`，最终 `all workbench checks passed` |

e2e 首次原样命令因 `Cannot find module 'playwright'` 未启动测试；随后发现捆绑依赖的默认浏览器版本不在缓存。使用测试原本支持的两个环境变量定位本机现成依赖/浏览器后，完整执行通过，没有安装依赖或改测试：

```bash
PLAYWRIGHT_MODULE=/Users/key_/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright \
PLAYWRIGHT_CHROMIUM_EXECUTABLE=/Users/key_/Library/Caches/ms-playwright/chromium_headless_shell-1217/chrome-headless-shell-mac-arm64/chrome-headless-shell \
OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 \
nice -n 10 node tests/workbench.e2e.cjs
```

附加的本包结构自查：32 sfx / 9 music / 3 曲组、44 uid 唯一；候选归组、源路径、世界与组/主题引用匹配；唯一缺失引用是已登记的 `slice:jeju_1`；新文档本地链接存在，`git diff --check` 无问题。此检查不冒称 WB-02 的完整 audio 校验器。

冻结区 445 个文件和开工前已存在的 60 项工作区改动逐项 SHA-256 与开工快照一致；既有 `docs/v2/status.md` 和 game/generated 等改动保留且不纳入提交。art build 仅造成 `workbench/data/bundle.js` 构建时间变化，已恢复构建前内容，未提交包外生成文件。测试未改任何预期。本次启动的验证进程与浏览器均已退出。

### 交付 · 问题

1. **现有内容检查不读取 audio.json**：`tools/content.mjs` 的 CATALOGS 固定、ids 也未注册音频空间，因此当前 content 0 错误不证明声音目录被工具认可。WB-02 已明确增加 schema/引用/编号与负例测试；本包没有改工具。
2. **`jeju_1` 仍未进入本基线 slices.json**：`world:jeju` 已存在，切片依赖 DSN-01。没有自行补 slices/worlds 或虚构 theme.jeju。Claude 派 WB-02 前先核对并合入 DSN-01；新检查器不能永久忽略 pending_references。
3. **游戏总音量待用户决定**：现存 game-design 7.5 只有 music/sfx。本文把三个滑块中的总音量限定为工作台监听，音乐/音效沿用既有设置语义；未新增游戏持久化字段。是否为游戏加总音量、如何迁移存档需用户另行拍板，不能视为本设计已获得该项授权。
4. **游戏播放接入尚未制作/验收**：三个后续包覆盖工具、工作台和声音候选；Godot 导入、事件映射、实际播放需要 Claude 后续另行拆包。大厅播放消费已有“实际显示地图”的上下文，不替大厅决定地府/济州皮肤。当前没有可试听的声音，也没有用户对音频的确认或地图采用记录。

### 当前阶段与下一步

本包为**设计候选已交回**：现有自动检查通过；尚未 Claude 范围审核/合并，尚未声音制作或用户听感验收。按 process.md 制作方不改 docs/status.md；现有 docs/v2/status.md 也不属于本包可改范围，后续由 Claude 合并时同步进度。

最近可执行一步由用户在 **Claude 整理合并聊天**发送：

> 导入并按 docs/process.md 第7节审核 dsn/DSN-02；只核对范围、编号、冻结区和交付结果。合并后更新进度，先核对 DSN-01 的 jeju_1，再派 WB-02；WB-02 合并后填写 AUD-01/AUD-02 的实际基线并派出。游戏总音量与游戏音频接入另列待决定项。

随后由 Claude 完成审核/合并和派包；WB-02 制作方做工具，AUD-01/AUD-02 制作方做待确认候选，用户最后试听选曲。当前本设计包的制作已结束，不自动开始后续包。

### 提交与差异统计

- 最后制作提交：`38e701c26f4381416eb8e37dd1a3b1924a78d478`。本交付登记再追加一笔普通提交，不 amend；最终交回提交号在交回消息中给出，并可用 `git rev-parse dsn/DSN-02` 查询。
- 以下是该制作提交执行 `git diff --stat origin/claude/inspiring-ride-zfnn4s..dsn/DSN-02` 的实际输出；随后仅追加本节交付元数据，最终仍为相同 10 个允许文件：

```text
 content/catalog/audio.json | 867 +++++++++++++++++++++++++++++++++++++++++++++
 docs/design/audio.md       | 187 ++++++++++
 docs/design/game-design.md |   2 +-
 docs/design/ids.md         |   4 +-
 docs/design/workbench.md   |   1 +
 docs/packages/AUD-01.md    |  95 +++++
 docs/packages/AUD-02.md    |  95 +++++
 docs/packages/DSN-02.md    |  61 +++-
 docs/packages/README.md    |   6 +-
 docs/packages/WB-02.md     | 111 ++++++
 10 files changed, 1423 insertions(+), 6 deletions(-)
```
