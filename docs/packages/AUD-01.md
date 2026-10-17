# AUD-01 全游戏通用一套音效候选

状态：**已合并**（2026-10-17，Claude 核对：范围在包内；合并后全套检查通过）。候选待用户试听确认。
基线：`claude/inspiring-ride-zfnn4s`（已包含 DSN-02、WB-02）→ 分支：`aud/AUD-01`（**不要**从 `main` 开：`main` 现在还是旧内容）。
依赖：WB-02 已合并且全套检查通过；与 AUD-02 互不依赖，可以在全机资源预算内同时制作。不能把未合并的 wb/WB-02 制作分支直接当作基线。

**开工**（照抄）：
```bash
git fetch origin
git checkout -b aud/AUD-01 origin/claude/inspiring-ride-zfnn4s
```
**交回**（二选一）：
- 能推送：`git push -u origin aud/AUD-01`
- 不能推送：`git bundle create AUD-01.bundle origin/claude/inspiring-ride-zfnn4s..aud/AUD-01`，把 `AUD-01.bundle` 交给用户。

只往 `aud/AUD-01` 提交；不往 `main`、`claude/inspiring-ride-zfnn4s`、`wb/WB-02`、上面填入的基线或别的分支推送，不合并别的分支、不 rebase/amend/强推、不删分支。

设计依据：[audio.md](../design/audio.md) 第 1–5 节；`content/catalog/audio.json`。
会碰的共享文件：`audio/export/manifest.json`、`workbench/data/audio.js`、`content/export/id-map.json`、`workbench/data/content.js` 及 content build 重新生成的 `content/export/*.json`；全部只由工具写。与另一声音包在汇总生成文件上的冲突由 Claude 合并后重建，源目录互不相碰。不改 README。
允许换版本的美术：无（art.mjs build 必须 0 bumped）。

## 目标

完成32 个音效的原创文字源文件与可在工作台试听的 WAV。全部是**待用户确认候选**；不批准、不选定地图正式用曲、不导入游戏。

## 要读的文件

- `AGENTS.md`、`docs/process.md`、本包。
- `docs/design/audio.md` 全文、`content/catalog/audio.json`、`docs/design/ids.md`。
- `docs/packages/WB-02.md` 的最终交付与工具帮助 `node tools/audio.mjs --help`（若工具未实现帮助，读其 usage）。
- `tools/audio.mjs`、`tools/lib/audio.mjs` 的现有字段定义（只读）；`workbench/index.html#audio/sfx` 的空源页面。

## 要做的事

1. 严格按 audio.json 中全部 32 项 `kind:sfx`，在 audio/source/sfx/<id>.json 各写一份 `pushbox.audio/1`。uid、时长、限频与最大实例数不改；时长采用清单值，含 release 尾音，容差只允许 ±1 样本。普通走路按设计静音，不增设 step，不按地图或动物再分套。
2. 音色柔和且可辨别：推/落地区分、压板按下/松开区分、门开/关区分、成功/拒绝区分、受伤/货损区分。animal_hint 是程序合成中音双啾；不用录音或外部采样。音效来自明确的音符/包络/滤波参数，不能编码或嵌入现成 WAV。
3. reel_spin 为可循环的 400 ms 素材，满足音乐同样的接缝阈值；播放器每次最多转声 2000 ms，不能用一段很长的噪声代替。volume_preview 应平稳，用于真实音量回馈。
4. 用 `build --kind sfx` 和 `verify --kind sfx --require-sources` 迭代，每项 RMS −24±2 dBFS、采样峰值 ≤−9 dBFS、其他指标按设计。只调本包源参数，不修改工具、设计或全局混音规则；遇到工具缺能力写问题。
5. 工作台逐个试听并检查 32/32；人工在低音量连续试听一遍，记录刺耳/突变/无法区分情况。检验 UI 快速连按、滚轮停止与取消的限频/释放行为，如工具已有问题只记录，不自行改代码。

## 可改的文件

- `audio/source/sfx/*.json`：仅清单中的32 个音效，不增删 uid。
- `audio/export/preview/sfx/*.wav`：仅 build 生成；`audio/export/manifest.json`、`workbench/data/audio.js`、`content/export/*.json`、`workbench/data/content.js`：仅工具重新生成，不手改。
- 本包的状态与「交付」。清单外一律不改。

## 不能碰的文件

- `audio/source/music/**`、`audio/export/preview/music/**`：另一声音包独立制作。
- `audio/approvals.json`、`audio/history/**`、`audio/export/approved/**`：用户确认之前不加任何真实审批、采用或历史文件。
- `tools/**`、`tests/**`、`workbench/**`（仅上列生成 audio.js/content.js 例外）、`game/**`：本包只做数据，不修工具、不改界面、不导入游戏。
- `content/catalog/**`（含 audio/worlds/slices）、`docs/design/**`、`docs/packages/README.md`、其他包、`docs/status.md`、`docs/v2/status.md`：不改变设计或进度。
- `art/**`、`content/i18n/*.json`、`workbench/js/core/**`：冻结区。美术 build 不能产生版本变化。

## 验收标准

### 声音专门验收

```bash
node tools/audio.mjs build --kind sfx --baseline-ref origin/claude/inspiring-ride-zfnn4s
node tools/audio.mjs verify --kind sfx --require-sources
node tools/audio.mjs build --kind sfx --baseline-ref origin/claude/inspiring-ride-zfnn4s
```

预期：本类32 个音效全部有源与 WAV，verify 0 问题；第二次 build **0 bumped**，同一源的 WAV SHA-256 不变。每次构建锁定同一发布基线（派前填写命令中的实际分支）：工具从该 Git 引用读基线源版本，新源全部恒为 v1，已有且改动的源恒为基线+1；迭代不能累加版本，不手改版本或伪造 hash。若工具不遵守该契约，作为 WB-02 缺陷报告，不能放宽验收。仓库真实 audio/approvals.json 字节及记录数与基线完全一致，所有候选当前确认状态为否。

打开 `workbench/index.html#audio/sfx`：32 项均可播放/停止，字段与清单吻合；走路说明为静音，滚轮循环可停止，不出现未制作条目。

### 全套回归（全部执行，不得只跑声音）

先检查本机其他会话的计算进程，所有命令顺序跑；设置 `OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1`。测试加 `--test-concurrency=1`，覆盖的仍是全部 `tests/*.test.mjs`；全机最多 2 个耗资源任务/计算 worker，不因测试文件多而增加并发。

```bash
node tools/content.mjs check
node tools/check-levels.mjs
node tools/check-rooms.mjs
node tools/check-rooms2.mjs
node tools/art.mjs build
node tools/art.mjs verify
node --test --test-concurrency=1 tests/*.test.mjs
node tests/workbench.e2e.cjs
```

预期：content 0 error；三个设计模型检查全部通过（不等于 SDK 验证）；art build **0 bumped**，`art/approvals.json` 记录数量和字节不变；art verify ok；单元测试和工作台 e2e 全部通过。运行前后核对冻结区和美术版本，不得把意外换版本提交。如果已有包外失败，保留结果、在「交付 · 问题」写明命令、实际错误与影响，不改包外文件或放宽测试。

## 交付（制作方填写）

- 分支名、最后提交号、实际基线名/提交号、交回方式（推送 / AUD-01.bundle）。
- build/verify 和全套回归的实际结果行；32 个音效 uid@vN/hash/时长/RMS/峰值清单（可从 manifest 摘要生成，不手填通过）。
- 逐项限频/试听记录；reel_spin 的接缝结果。必须区分工具数值通过、制作方实际试听、用户确认三个状态。
- `git diff --stat origin/claude/inspiring-ride-zfnn4s..aud/AUD-01`；派前由 Claude 填成实际命令。
- 没改测试预期；若基线失败或工具缺能力，贴命令/错误，不能自行越界修复。
- 问题：没做完、拿不准、需要用户决定的事。下一步由 Claude 核对与合并候选，再让用户在声音页试听；只有用户明确确认后 Claude 才能用 audio approve 记录。

### 本次交回（2026-10-17，Codex）

- 分支：`aud/AUD-01`；实际开工基线：`origin/claude/inspiring-ride-zfnn4s` @ `dd9f9ac5f6180a4726ac843dd8736a5d898b8925`。未合并其他分支，不向基线或 `main` 推送。
- 最后候选实现与验收提交：`13f7470ac60705c4c7f9f370b35e555280416e5f`；随后仅有本包交付记录提交。最终交回 tip 的完整 SHA 在交回消息中给出，可用 `git rev-parse aud/AUD-01` 核对（提交无法在自身内容中写入自己的 SHA）。
- 交回方式：远端分支 `aud/AUD-01`，本交付记录提交后执行 `git push -u origin aud/AUD-01`；实际推送结果与最终 tip 以交回消息为准。若远端不可用，按包头创建并验证 `AUD-01.bundle`，在本节另记结果。
- 当前阶段：32/32 原创文字源和 WAV 候选已制作、技术检查通过，等待 Claude 技术核对及人工听感验收；**未经用户确认、尚未合并或正式入库、未导入游戏**。人工耳听未完成，不能把本包写成全项验收完成。
- 原工作目录存在未提交改动，因此在原生独立 worktree `/Users/key_/.codex/worktrees/aud-01/pushbox-demo` 中制作；原工作目录及其改动保留。

#### 制作结果

- 仅新增清单规定的 32 个 sfx，全部由明确音符、包络、低通参数程序合成；无录音、采样、外部服务或嵌入 WAV；没有 step，没有地图/动物变体。使用正弦/三角音色和轻量低通噪声。
- 成对区别来自音高/节奏：推箱短木咚、落地更低且更宽；压板按下 D3、松开 B2；门开两音上行、门关下行；成功双点上行、拒绝低单点；受伤单下弯、货损三次木质轻抖。animal_hint 是两次原创中音上弯双啾；volume_preview 是持续 C4/G4 双音，固定源强度、无随机响度。
- 全部源总时长与 catalog 精确相等；另读取实际 RIFF 数据区，32/32 PCM 样本数精确等于 `round(44100×duration_ms/1000)`，误差 0 样本。所有候选 v1；32 个 WAV 校验和与 manifest 匹配。
- RMS 范围 -24.001836～-23.998118 dBFS；最高采样峰值 -11.610954 dBFS；全部指标由工具通过。最大噪声能量比例 0.04875262，低于 0.08。

#### 声音专门验收（实际结果）

```text
node tools/audio.mjs build --kind sfx --baseline-ref origin/claude/inspiring-ride-zfnn4s
audio build: 32 bumped / 32 changed; 32 source(s); 未制作 0 音效 + 9 音乐候选; 3 曲组未选定

仅迭代 dig/pour/rule_card 的源参数后，同一锁定基线：
audio build: 0 bumped / 3 changed; 32 source(s); 未制作 0 音效 + 9 音乐候选; 3 曲组未选定

node tools/audio.mjs verify --kind sfx --require-sources
audio verify: ok; 32 指标通过（不等于用户确认）; 0 未制作; 0 approval record(s)

node tools/audio.mjs build --kind sfx --baseline-ref origin/claude/inspiring-ride-zfnn4s
audio build: 0 bumped / 0 changed; 32 source(s); 未制作 0 音效 + 9 音乐候选; 3 曲组未选定
WAV_SHA256_IDENTICAL True count 32
```

重复构建前后逐字节计算 SHA-256，32/32 相同；没有手改版本或 hash。最后再次执行严格 verify，仍为 32 指标通过、0 缺源、0 审批。9 首音乐未制作、3 曲组未选定属于另一包，不是本类缺项。

#### 全套回归（实际结果）

运行前和长测试期间核对本机进程与内存，没有发现其他活跃的构建/测试/音频计算任务；内存 free 34%～38%。全部顺序运行，单 worker，使用 `nice -n 10`；`OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1`。测试并发 1，未删减测试文件。

| 命令 | 实际结果 |
|---|---|
| `node tools/content.mjs check` | exit 0；`content: 0 error(s), 1 warning(s); 52 planned levels, 46 with specs` |
| `node tools/check-levels.mjs` | exit 0；全部通过；末行 `ok W10 author=6 shortest=6 states=39 dead=20` |
| `node tools/check-rooms.mjs` | exit 0；模板/演示通过，`slice dungeon_1: 300 seeds` |
| `node tools/check-rooms2.mjs` | exit 0；房间路线通过，`开局池 delivery_pool：300 个种子` |
| `node tools/art.mjs build` | exit 0；`build ok: 134 assets, 0 bumped, 94 reference renders, 6 approval records`；文字布局 0 issue |
| `node tools/art.mjs verify` | exit 0；`verify ok: 134 assets, 6 approval records` |
| `node --test --test-concurrency=1 tests/*.test.mjs` | exit 0；190 tests、190 pass、0 fail、0 skipped |
| `node tests/workbench.e2e.cjs` | exit 0；116 个 check 全通过；`all workbench checks passed` |

唯一内容警告为基线登记过但尚缺的 `slice:jeju_1`（DSN-01）；没有改变设计、路由或 slices。三个设计模型检查不等于 Godot SDK 验证，本包未做游戏接线。

e2e 使用已有本机运行时，没有安装依赖：

```bash
export PLAYWRIGHT_MODULE=/Users/key_/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright
export PLAYWRIGHT_CHROMIUM_EXECUTABLE='/Users/key_/Library/Caches/ms-playwright/chromium-1217/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing'
```

#### 逐项真实媒体播放与限频记录

先读取空源声音页：32 卡、0 源，明确显示未制作；构建后同页 32 卡均有播放/停止，实际候选媒体可加载，时长/名称/版本/哈希与清单吻合，全部待用户确认。

以下是**自动化真实 HTMLAudioElement 媒体播放**，没有替换成假 Audio：逐项从卡片点击播放，检查 metadata、playing 事件、播放时钟实际推进、同 uid 快速再触发被拒绝、停止后实例释放；32/32 通过、无解码/控制台错误。监听 master=0.2、sfx=0.3，有效增益 `0.2×0.3×10^(-6/20)=0.030071234017636332`，使用真实音量规则。reel_spin 在 1200 ms 播放观察窗口后停止，循环标志为真；这不代表人工连续听满三圈。**自动播放记录不等于制作方人工耳听，也不等于用户听感确认。**

每行 hash、WAV SHA、时长、样本数、RMS、峰值从最终 manifest/媒体实际读取；限频和实例数从未改动的 catalog 读取。限频记录指该 uid 当次播放后立即快连按被拒绝；不将此说成每个边界毫秒值都已穷举验证。

| uid@版本 | 内容 SHA-256 | WAV SHA-256 | 时长 ms / 样本数 | RMS dBFS | Peak dBFS | 间隔 ms / 最大实例 | 真实媒体及限频记录 |
|---|---|---|---:|---:|---:|---:|---|
| `sfx:animal_hint@v1` | `bfc9184545ef532c7852da8ea90fd3663e4087642ddfdd04759fdfe01898c51b` | `a8169a0d7e9ec546743bf7818daa33c9f72d6b3623cd12dc6f72fd691f87ab60` | 380 / 16758 | -24.0018 | -16.9431 | 1500 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:blocked@v1` | `ea73fdf32ab4260c441a1929e347a5518fca9ba49f8fe78d4963b89eca4a29d0` | `ce5ac14c6c7097a076c3566295b865af4bf4e20a644a74b504f5e100f17771a3` | 140 / 6174 | -24.0000 | -15.5667 | 400 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:cargo_damage@v1` | `f6d4f933ad5e4a8f9d9499edb51189e8921355e29a634ac1e7a8d2a9580f2cca` | `f0204ad99be58d6ec5e0fee049229c9427d44b32cf127602affb9f737d9420d7` | 280 / 12348 | -24.0000 | -12.0816 | 280 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:climb@v1` | `e2386633ccd7138d5327315e3abecdf52a1f194d8dc13d4460114dc86f83a0f4` | `52becf1b207e4c52ca0a97a3fcdb1765c90034be93e43ffda10c5c310b3688cf` | 100 / 4410 | -23.9999 | -12.8379 | 350 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:coin@v1` | `228870cf69d649570bade3eb20facce25262101cf95f84978407d83542dcaa1d` | `20628e3477be05b239d62e564ca33fb8bda5515e6f16206c50cf2c16732d79ac` | 220 / 9702 | -24.0000 | -17.0425 | 120 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:crate_land@v1` | `a98fb215e097b682c49e03e7f0bb459db98c159a5c3edbd3a7ebcd8d4ea07272` | `ab27ad107a33ed34f36c5876576058bf8fbe24276adc07a12690289e55859248` | 240 / 10584 | -24.0000 | -12.7743 | 120 / 2 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:delivery_arrive@v1` | `be6f9d4508280ed54b3a9fa368804fda4d7549c93fe95386d4b34981697c3d20` | `574cfe3dfc20d3c4f6455ccf545c201168de60f0f0e5d18fb95e7b745a67fe8e` | 1300 / 57330 | -24.0000 | -14.8274 | 1300 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:dig@v1` | `f8da462199a2a47dfa14caa321ef4bb57f702eebd6fc69ae38d293339c84208b` | `de9ebe661c3c43e1a723e0cf19ddd57f464e2def158e1bed7dcd97d3333c2c6d` | 220 / 9702 | -24.0000 | -13.4083 | 220 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:door_close@v1` | `871d86e56f0f31b75b95f496e78d07585be5d2172ec8af27eb485c3cd7bb4987` | `2656ddd9fdc6e557cd71a5459eaceec44d67142d6f656ad4fcabc30db1113aac` | 260 / 11466 | -24.0000 | -13.6269 | 180 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:door_open@v1` | `ea4905d3839b9750796c291372d456a87008a4102b42e6b9af233c79caeebd4a` | `8328f701fcddb1c986e736791cb74311fa3d7bde683914d00543c10a501f350a` | 280 / 12348 | -24.0000 | -13.1877 | 180 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:feed_snack@v1` | `72fa4cf0523bd92633e0634ff8d288ec2424a8c94e947ac54a4aa119d3c8ad0f` | `7341c7ea3af3e075d005943e52a1b336ba1451624c956cc3696174574a0088ca` | 260 / 11466 | -24.0000 | -15.8580 | 500 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:goal_on@v1` | `956189f16013cbfa0de2e27e5730748fafbd1e44a478af393ff2bd8e7210592d` | `bc023d8418f9cc7233bbb9a18d52f3ffe0ccbdd86ad11626807723f079c28d80` | 350 / 15435 | -24.0000 | -14.9082 | 180 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:hint_show@v1` | `58d3b0b687310bc713ac3c7bd2555d2909952ed907dc699bba2bcd9038094e40` | `510e58308baf19b9c04a36be26a20b20054d0a2a00b42092c0f95e3ab1e46940` | 260 / 11466 | -24.0000 | -16.6499 | 400 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:hurt@v1` | `a502a454c11bc85930331affa3d4536fd71142d721c529fe8232b544dbaec207` | `7fdcff39baa179f81ec7bfc9aead547b895860e7d3039c940be0e893c59991a2` | 350 / 15435 | -24.0000 | -16.5763 | 350 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:level_clear@v1` | `196707de93f5d68967b10ff69f25a300d1ab9ae5e14e791366bbe6e8e115f7df` | `5b33005da67d75288c103e7d543c4fc2c2e3c25b35c8b66579ba4604a936e335` | 1100 / 48510 | -23.9999 | -15.3997 | 1100 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:menu_close@v1` | `2c806b7fb377372e06f689adf6773b5811c245009e0cc2fa55c25aa0b8a73228` | `dc51f0ec44220a0a5cfafc2861f53c05ecf46ce469d96756ff541707d1e6160a` | 160 / 7056 | -24.0000 | -16.2415 | 160 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:menu_open@v1` | `4ea225c347d2666bcc9fa6138b7f4aa748ac022b4c9da2dee77498289f585ee0` | `88f91bf2363dd0a225509a081916b3788da8b43fe0190304975054f45a931c64` | 160 / 7056 | -24.0000 | -15.8497 | 160 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:plate_down@v1` | `2bc7299c44950a4db71511ca124836c0ecd2d52a9327c265f84082a2fcacd233` | `8a7c9ddb84620bac0f36bec5dc22d909f86b42ef3d8733b09b5e2675a8d06372` | 100 / 4410 | -24.0000 | -15.0285 | 120 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:plate_up@v1` | `f0beb65c02b9f5ba89f65074d2c75652e683b2397931a9a458a494fd1b5328a9` | `f39f60378b9c1fb3f1ee9b78aff5aa15ad642caf33801d4284a34682303b9443` | 100 / 4410 | -24.0000 | -14.5868 | 120 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:pour@v1` | `adc690a93d9c21731190d8933357914c5ba9e38659a1bbbfb2623342d8e09425` | `c87d913d5123889bf1b8180df1aca9771d278a0f16124fa8c24c9bc9f0da1b76` | 320 / 14112 | -23.9981 | -13.9063 | 320 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:push@v1` | `4d1aa530a235fd664b4f3a6a0f6a19e31cff26d6ce05803d80d0a39ac9e634ff` | `0759ec84b844d0297bde41eb47048ac4a714d6eb377dd51160a1df2debb9edf5` | 180 / 7938 | -23.9999 | -13.7603 | 180 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:reel_spin@v1` | `bec0cdf3099eb37d69a649f2b54292f13045156a258c872434d27d2a0dfabc34` | `937a71f9645a9d2374eded903619399344e972c781e937c9ae924c204c56ab8b` | 400 / 17640 | -24.0000 | -11.6110 | 400 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:reel_stop@v1` | `2e3c7b8b8788fabcb983f24bef4b841d8eaec2b5b3a5df9e053de6b330ac6292` | `77de55cf81cbb763f63483ee49c18d71d1dcb4b311c70962fdf57350e8f0d868` | 300 / 13230 | -24.0000 | -16.6157 | 300 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:reroll@v1` | `8e40254f0ec0a7cd4c60175bb9ff6c7dc954085f2f63bf73626fdcf9c90eb8c6` | `bf0a83b6e42edc5b8ce31602c562d56ef08fdded770395616957c269c5993799` | 250 / 11025 | -23.9999 | -16.1849 | 500 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:restart@v1` | `c8b464db4907a15465d1312f94d66a7318d0b91ff503d1aaeb0c2892848d00b3` | `cbeb1c7a872b1107a00b8e1818e8c2a674c179116644baec6713835e4f047a1b` | 450 / 19845 | -24.0000 | -15.0001 | 450 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:rule_card@v1` | `e3840e3d6a10efc26ca76bd6303f1018cf493939736a1ee119300febc888df36` | `ff934e6f1c91e40af5ddc10088fbdcdf7455804fa924fe2f895052fa6f3aff62` | 300 / 13230 | -24.0000 | -14.2481 | 400 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:shop_buy@v1` | `f1a9365bfc7bc49e9d95ddf53881e39966a9c9f6cb4fcc7111335ebd22084f7c` | `0b156bec4cf7f8aa6b4eefe4aae3fe58280d5d318ca711213126aa5086d4fb6d` | 300 / 13230 | -24.0000 | -15.7047 | 300 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:ui_back@v1` | `1ee5dcccfd7f7bdf9414213e683f0aeb74b4705321a34a691476da7a154d90b6` | `34c2e0bada19f00ceb37c33764b2f048c90613d09b1e17f6c91b620bef28653b` | 120 / 5292 | -24.0000 | -16.0006 | 120 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:ui_confirm@v1` | `7d56d2c9046320a18478363e14e92c31448bd3d6e60b009ae12957c5f3339b49` | `f7853013c9ee88281afa1bf7a3ff22d0340d4bb25aecbd264da772cecddbb5d2` | 120 / 5292 | -24.0000 | -15.9722 | 120 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:ui_move@v1` | `e864104d1cbda93edc2bcb195d20cbd80c00e7352e64eece14419c9972b59be0` | `10f0a8afb91bc1c8ff7f7323a1c868a3b9842dc00e0a8b95da8d4da3baa86178` | 70 / 3087 | -24.0000 | -13.5914 | 100 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:undo@v1` | `4338c72ad5b4915dffc0008d792390c23914baefb0ae3069319edb0a79e45bc2` | `31ca31ddc48bddffdee626261f9027a6c14f1bbba2f7a54a21f383bd5c1e5826` | 180 / 7938 | -24.0000 | -16.9618 | 180 / 1 | 播放推进、快连按拒绝、停止释放均通过 |
| `sfx:volume_preview@v1` | `d600fae169ec5eb05e5064df054048d8706935d9b50f4bbbdff84430f62cf779` | `4c7f0f1fcd5f0993c53582902938c5d2ce8fa28be4c8cf6ccc5678994882796e` | 500 / 22050 | -24.0000 | -17.3986 | 500 / 1 | 播放推进、快连按拒绝、停止释放均通过 |

附加真实媒体场景合计 42/42 通过（包括上表 32 项）：滚轮释放期间继续占位、停止/待启动取消、2000 ms 上限、音量增益与 master=0/sfx=0/mute 静音、滑块 volume_preview 限频、离页释放。全套 e2e 另覆盖全局 3 实例、优先级和 25 ms 替换释放等隔离播放器场景，不与本包真实 32 项或人工耳听混称。

reel_spin 为 **400 ms / 17640 样本**，两次低木软嗒，loop:true；接缝 `seam_value_delta=0`、`seam_slope_delta=9.1552734375e-05`，均 ≤0.002。实际显式停止约 80.7 ms，释放期间占位；2000 ms 后无存活实例。数值接缝及自动循环通过，人工接缝听感仍未验收。

临时记录器首轮错误地在媒体 emptied 后把 duration/time 覆盖为零，导致附加记录失败；已用单个媒体事件序列复现，修正为保留有效 metadata/最大播放时间并等待实例真正释放，重跑 32 项及所有场景后 42/42 通过。只改 `/private/tmp` 临时脚本，未修改或放宽仓库测试。

#### 范围与冻结区

- 修改仅为本包允许的 32 源、32 WAV、5 个生成汇总文件和本包文档；没有改测试预期。
- 运行前后核对 464 个冻结/审批相关文件：SHA-256 全部相同；其中 `art/approvals.json` 仍为 6 条且字节不变，`audio/approvals.json` 仍为 0 条且字节不变；未产生批准/历史文件，也未制作或改动音乐。
- art build 额外重写的包外 `workbench/data/bundle.js` 已恢复为开工基线原字节；所有允许的汇总文件均由工具生成，没有手改。
- 未改 `tools/**`、`tests/**`、`game/**`、设计目录、catalog、`docs/status.md` 或 `docs/v2/status.md`。按本包明确禁止修改进度文档的规则，下一步和执行人记录于本包。

#### 改动统计

交回后可复现：`git diff --stat origin/claude/inspiring-ride-zfnn4s..aud/AUD-01`。以下在交付记录提交前用 `git diff --stat origin/claude/inspiring-ride-zfnn4s` 取得同一最终文件内容；该统计包括本交付记录：

```text
<!-- AUD01-STAT-START -->
 audio/export/manifest.json                   |  930 ++++++++++++++++++++--
 audio/export/preview/sfx/animal_hint.wav     |  Bin 0 -> 33560 bytes
 audio/export/preview/sfx/blocked.wav         |  Bin 0 -> 12392 bytes
 audio/export/preview/sfx/cargo_damage.wav    |  Bin 0 -> 24740 bytes
 audio/export/preview/sfx/climb.wav           |  Bin 0 -> 8864 bytes
 audio/export/preview/sfx/coin.wav            |  Bin 0 -> 19448 bytes
 audio/export/preview/sfx/crate_land.wav      |  Bin 0 -> 21212 bytes
 audio/export/preview/sfx/delivery_arrive.wav |  Bin 0 -> 114704 bytes
 audio/export/preview/sfx/dig.wav             |  Bin 0 -> 19448 bytes
 audio/export/preview/sfx/door_close.wav      |  Bin 0 -> 22976 bytes
 audio/export/preview/sfx/door_open.wav       |  Bin 0 -> 24740 bytes
 audio/export/preview/sfx/feed_snack.wav      |  Bin 0 -> 22976 bytes
 audio/export/preview/sfx/goal_on.wav         |  Bin 0 -> 30914 bytes
 audio/export/preview/sfx/hint_show.wav       |  Bin 0 -> 22976 bytes
 audio/export/preview/sfx/hurt.wav            |  Bin 0 -> 30914 bytes
 audio/export/preview/sfx/level_clear.wav     |  Bin 0 -> 97064 bytes
 audio/export/preview/sfx/menu_close.wav      |  Bin 0 -> 14156 bytes
 audio/export/preview/sfx/menu_open.wav       |  Bin 0 -> 14156 bytes
 audio/export/preview/sfx/plate_down.wav      |  Bin 0 -> 8864 bytes
 audio/export/preview/sfx/plate_up.wav        |  Bin 0 -> 8864 bytes
 audio/export/preview/sfx/pour.wav            |  Bin 0 -> 28268 bytes
 audio/export/preview/sfx/push.wav            |  Bin 0 -> 15920 bytes
 audio/export/preview/sfx/reel_spin.wav       |  Bin 0 -> 35324 bytes
 audio/export/preview/sfx/reel_stop.wav       |  Bin 0 -> 26504 bytes
 audio/export/preview/sfx/reroll.wav          |  Bin 0 -> 22094 bytes
 audio/export/preview/sfx/restart.wav         |  Bin 0 -> 39734 bytes
 audio/export/preview/sfx/rule_card.wav       |  Bin 0 -> 26504 bytes
 audio/export/preview/sfx/shop_buy.wav        |  Bin 0 -> 26504 bytes
 audio/export/preview/sfx/ui_back.wav         |  Bin 0 -> 10628 bytes
 audio/export/preview/sfx/ui_confirm.wav      |  Bin 0 -> 10628 bytes
 audio/export/preview/sfx/ui_move.wav         |  Bin 0 -> 6218 bytes
 audio/export/preview/sfx/undo.wav            |  Bin 0 -> 15920 bytes
 audio/export/preview/sfx/volume_preview.wav  |  Bin 0 -> 44144 bytes
 audio/source/sfx/animal_hint.json            |   46 ++
 audio/source/sfx/blocked.json                |   37 +
 audio/source/sfx/cargo_damage.json           |   51 ++
 audio/source/sfx/climb.json                  |   44 ++
 audio/source/sfx/coin.json                   |   44 ++
 audio/source/sfx/crate_land.json             |   56 ++
 audio/source/sfx/delivery_arrive.json        |   58 ++
 audio/source/sfx/dig.json                    |   54 ++
 audio/source/sfx/door_close.json             |   44 ++
 audio/source/sfx/door_open.json              |   44 ++
 audio/source/sfx/feed_snack.json             |   55 ++
 audio/source/sfx/goal_on.json                |   44 ++
 audio/source/sfx/hint_show.json              |   44 ++
 audio/source/sfx/hurt.json                   |   38 +
 audio/source/sfx/level_clear.json            |   51 ++
 audio/source/sfx/menu_close.json             |   38 +
 audio/source/sfx/menu_open.json              |   38 +
 audio/source/sfx/plate_down.json             |   37 +
 audio/source/sfx/plate_up.json               |   37 +
 audio/source/sfx/pour.json                   |   54 ++
 audio/source/sfx/push.json                   |   38 +
 audio/source/sfx/reel_spin.json              |   45 ++
 audio/source/sfx/reel_stop.json              |   44 ++
 audio/source/sfx/reroll.json                 |   51 ++
 audio/source/sfx/restart.json                |   51 ++
 audio/source/sfx/rule_card.json              |   53 ++
 audio/source/sfx/shop_buy.json               |   61 ++
 audio/source/sfx/ui_back.json                |   44 ++
 audio/source/sfx/ui_confirm.json             |   44 ++
 audio/source/sfx/ui_move.json                |   37 +
 audio/source/sfx/undo.json                   |   38 +
 audio/source/sfx/volume_preview.json         |   44 ++
 content/export/content-manifest.json         |  930 ++++++++++++++++++++--
 content/export/id-map.json                   | 1058 ++++++++++++++++++++++----
 docs/packages/AUD-01.md                      |  209 ++++-
 workbench/data/audio.js                      |    2 +-
 workbench/data/content.js                    |    2 +-
 70 files changed, 4336 insertions(+), 259 deletions(-)
<!-- AUD01-STAT-END -->
```

#### 问题

1. **制作方人工低音量连续耳听未完成。** 本会话能验证 PCM 和真实浏览器媒体状态，无法诚实代替人的主观听觉。未对“刺耳/突变/成对音效听不出区别”作无问题结论；这些项和循环接缝听感仍需人工检查。所有音效保持待确认，不能因数值/静态/自动播放通过而 approve。
2. **工作台声音页没有“普通走路静音”说明**（源码/页面均无此文案）；也未展示 catalog 的 min_interval_ms/max_instances/trigger 字段。实际 catalog 仍为 walking_sfx:silent、无 step，32 项限频和实例约束从 catalog 与播放器交叉核对；按包限制未改 UI、文字或工具。请 Claude 核对后安排工具/UI 包补文案与字段，随后复查页面验收。
3. **工具只校验源时长不超过清单，没有强制精确相等。** 本包已独立逐项核对清单、源和 WAV 样本数，32/32 误差为 0，因此本次候选不受影响；后续工具包可补严格时长防护。本包未越界修工具。
4. 既有 `slice:jeju_1` 规划警告保留，设计未改；没有其他回归失败。此包不选择正式音乐，不接 Godot 音频。

**下一步及执行人：** 先由 Claude（整理合并）核对 `aud/AUD-01` 的范围、基线、审批/冻结区和以上问题，按 process.md 第 7 节处理候选合并与重新生成，并安排声音页缺口。再由用户在声音页人工低音量连续试听 32 项和滚轮接缝，指出需调整项；只有用户对具体版本/hash 明确确认后，Claude 才能记录 audio approve。当前制作方已完成可执行的候选制作和技术检查，不自行批准或导入游戏。

用户最近可执行的一步：在负责整理合并的 Claude 聊天发送以下文字（无需在制作分支上运行合并）：

> 请接收并技术核对 aud/AUD-01，阅读 docs/packages/AUD-01.md 的交付与问题。32 个 v1 音效候选及全套回归已通过，人工耳听尚未完成，声音页缺“走路静音”说明及部分字段。请按 process.md 第 7 节核对范围、审批和冻结区，处理候选合并与页面缺口，再给我声音页入口完成试听；不要自动批准或导入游戏。
