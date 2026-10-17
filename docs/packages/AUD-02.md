# AUD-02 石牢、地府、海女村各三首音乐候选

状态：待派（WB-02 已于 2026-10-17 合并进 `claude/inspiring-ride-zfnn4s` @ `72d0605`，可以派）
基线：`claude/inspiring-ride-zfnn4s`（已包含 DSN-02、WB-02）→ 分支：`aud/AUD-02`（**不要**从 `main` 开：`main` 现在还是旧内容）。
依赖：WB-02 已合并且全套检查通过；与 AUD-01 互不依赖，可以在全机资源预算内同时制作。不能把未合并的 wb/WB-02 制作分支直接当作基线。

**开工**（照抄）：
```bash
git fetch origin
git checkout -b aud/AUD-02 origin/claude/inspiring-ride-zfnn4s
```
**交回**（二选一）：
- 能推送：`git push -u origin aud/AUD-02`
- 不能推送：`git bundle create AUD-02.bundle origin/claude/inspiring-ride-zfnn4s..aud/AUD-02`，把 `AUD-02.bundle` 交给用户。

只往 `aud/AUD-02` 提交；不往 `main`、`claude/inspiring-ride-zfnn4s`、`wb/WB-02`、上面填入的基线或别的分支推送，不合并别的分支、不 rebase/amend/强推、不删分支。

设计依据：[audio.md](../design/audio.md) 第 1–5 节；`content/catalog/audio.json`。
会碰的共享文件：`audio/export/manifest.json`、`workbench/data/audio.js`、`content/export/id-map.json`、`workbench/data/content.js` 及 content build 重新生成的 `content/export/*.json`；全部只由工具写。与另一声音包在汇总生成文件上的冲突由 Claude 合并后重建，源目录互不相碰。不改 README。
允许换版本的美术：无（art.mjs build 必须 0 bumped）。

## 目标

完成9 首音乐的原创文字源文件与可在工作台试听的 WAV。全部是**待用户确认候选**；不批准、不选定地图正式用曲、不导入游戏。

## 要读的文件

- `AGENTS.md`、`docs/process.md`、本包。
- `docs/design/audio.md` 全文、`content/catalog/audio.json`、`docs/design/ids.md`。
- `docs/packages/WB-02.md` 的最终交付与工具帮助 `node tools/audio.mjs --help`（若工具未实现帮助，读其 usage）。
- `tools/audio.mjs`、`tools/lib/audio.mjs` 的现有字段定义（只读）；`workbench/index.html#audio/music` 的空源页面。

## 要做的事

1. 严格按 audio.json 的九个 kind:music 条目，写 `audio/source/music/dungeon_a.json`、`dungeon_b.json`、`dungeon_c.json`、`diyu_a.json`、`diyu_b.json`、`diyu_c.json`、`jeju_a.json`、`jeju_b.json`、`jeju_c.json`。每张地图三首是不同原创旋律/编排方向，不能只转调或换速度冒充三首。
2. 依 audio.md 第 3 节的各首主题/芯片乐器/BPM/调式，写原创 instruments/tracks/notes；九首均 4/4、32 小节。石牢安静地下；地府是中国民间夜市的诙谐温暖，不吓人；海女村白天海边、轻快。不要引用现成民歌或从外部服务生成歌曲。
3. 用 `build --kind music` 和 `verify --kind music --require-sources` 迭代。音乐全循环 RMS −26±2 dBFS、采样峰值 ≤−9 dBFS；3秒窗动态范围/静音段、噪声/音高/声部和接缝按 audio.md 第 1 节。只调本包音符与合成参数，不改阈值或渲染器。
4. 工作台同图三首并排试听，逐首测试播放/暂停/从头/循环和接缝。每首至少听三圈接缝、再低音量循环 10 分钟，记录实际试听时长、是否爆音/抽吸/疲劳；可依次完成，不要把九首同时播。代理无法输出听觉判断时必须写明数值已测、人工听感未完成，不能把接缝数值通过写成用户已听过。
5. 给用户的每首简短说明写在源文件 name/description 字段与本包交付里，列清与同图另两首的差异。不运行 approve、不改草选为正式选曲；地图正式采用仍等用户在聊天明确确认版本和哈希。

## 可改的文件

- `audio/source/music/*.json`：仅清单中的9 首音乐，不增删 uid。
- `audio/export/preview/music/*.wav`：仅 build 生成；`audio/export/manifest.json`、`workbench/data/audio.js`、`content/export/*.json`、`workbench/data/content.js`：仅工具重新生成，不手改。
- 本包的状态与「交付」。清单外一律不改。

## 不能碰的文件

- `audio/source/sfx/**`、`audio/export/preview/sfx/**`：另一声音包独立制作。
- `audio/approvals.json`、`audio/history/**`、`audio/export/approved/**`：用户确认之前不加任何真实审批、采用或历史文件。
- `tools/**`、`tests/**`、`workbench/**`（仅上列生成 audio.js/content.js 例外）、`game/**`：本包只做数据，不修工具、不改界面、不导入游戏。
- `content/catalog/**`（含 audio/worlds/slices）、`docs/design/**`、`docs/packages/README.md`、其他包、`docs/status.md`、`docs/v2/status.md`：不改变设计或进度。
- `art/**`、`content/i18n/*.json`、`workbench/js/core/**`：冻结区。美术 build 不能产生版本变化。

## 验收标准

### 声音专门验收

```bash
node tools/audio.mjs build --kind music --baseline-ref origin/claude/inspiring-ride-zfnn4s
node tools/audio.mjs verify --kind music --require-sources
node tools/audio.mjs build --kind music --baseline-ref origin/claude/inspiring-ride-zfnn4s
```

预期：本类9 首音乐全部有源与 WAV，verify 0 问题；第二次 build **0 bumped**，同一源的 WAV SHA-256 不变。每次构建锁定同一发布基线（派前填写命令中的实际分支）：工具从该 Git 引用读基线源版本，新源全部恒为 v1，已有且改动的源恒为基线+1；迭代不能累加版本，不手改版本或伪造 hash。若工具不遵守该契约，作为 WB-02 缺陷报告，不能放宽验收。仓库真实 audio/approvals.json 字节及记录数与基线完全一致，所有候选当前确认状态为否。

打开 `workbench/index.html#audio/music`：三组各三首均可播放/暂停/从头/循环；接缝试听三次无数值错误；按地图页仍标“未选定”或原基线的已确认曲，不把候选 a 当成采用。

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

- 分支名、最后提交号、实际基线名/提交号、交回方式（推送 / AUD-02.bundle）。
- build/verify 和全套回归的实际结果行；9 首音乐 uid@vN/hash/时长/RMS/峰值清单（可从 manifest 摘要生成，不手填通过）。
- 逐曲接缝值、三圈与10分钟循环试听记录；三首之间差异说明。必须区分工具数值通过、制作方实际试听、用户确认三个状态。
- `git diff --stat origin/claude/inspiring-ride-zfnn4s..aud/AUD-02`；派前由 Claude 填成实际命令。
- 没改测试预期；若基线失败或工具缺能力，贴命令/错误，不能自行越界修复。
- 问题：没做完、拿不准、需要用户决定的事。下一步由 Claude 核对与合并候选，再让用户在声音页试听；只有用户明确确认后 Claude 才能用 audio approve 记录。
