# AUD-01 全游戏通用一套音效候选

状态：待派（WB-02 已于 2026-10-17 合并进 `claude/inspiring-ride-zfnn4s` @ `72d0605`，可以派）
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
