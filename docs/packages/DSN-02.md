# DSN-02 声音设计：一套音效 + 每张地图的背景音乐（只写设计和工作包）

状态：待做（用户 2026-10-17 决定）
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
