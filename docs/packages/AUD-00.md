# AUD-00 主题小调：4 个方案做成样曲，给用户选

状态：**已合并**（2026-10-17，Claude 核对：范围在包内；合并时把 3 处写死"3 组 × 3 首"的旧测试改成按目录计数；合并后全套检查通过）。候选待用户试听确认。
基线：`claude/inspiring-ride-zfnn4s` → 分支：`aud/AUD-00`（**不要**从 `main` 开：`main` 现在还是旧内容）

**开工**（照抄）：
```bash
git fetch origin
git checkout -b aud/AUD-00 origin/claude/inspiring-ride-zfnn4s
```
**交回**（二选一）：
- 能推送：`git push -u origin aud/AUD-00`
- 不能推送：`git bundle create AUD-00.bundle origin/claude/inspiring-ride-zfnn4s..aud/AUD-00`，把 `AUD-00.bundle` 交给用户

只往 `aud/AUD-00` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

设计依据：[audio.md](../design/audio.md) **第 3.0 节**（主题小调 A–D 的音符、样曲结构、变奏规则）和第 1 节（不刺耳的数值）；声音工具用法见 [WB-02](WB-02.md) 的交付。

会碰的共享文件：
- `content/catalog/audio.json`：只加下面写定的一个曲组和 4 个条目；
- `tools/content.mjs`：只放宽一处，让"主题曲组"可以不属于任何地图；
- 生成文件 `audio/export/manifest.json`、`workbench/data/audio.js`、`content/export/*.json`、`workbench/data/content.js`：只由工具写。

AUD-01（音效）可能同时在做：两边都会改这些生成文件，冲突由 Claude 合并后重新生成。

允许换版本的美术：无（`art.mjs build` 必须 0 bumped）。

## 目标
把 audio.md 第 3.0 节里设计好的 **4 段主题小调（A 渡口灯、B 小信差、C 回家的路、D 钟与浪）** 各做成一首 32 小节的展示样曲：
- 每首同一个速度（84 BPM）；
- 把小调连奏四遍，依次是"原型 → 石牢味 → 地府味 → 海女村味"。

用户在工作台「声音 › 音乐」里试听，选一个。

**音符一个都不能改**：旋律严格照 3.0 节的表；伴奏、和声、配器、节奏变化由你写，但每一遍都必须完整、清楚地听出小调。

## 要做的
1. **设计目录** `content/catalog/audio.json`：
   - `music_sets` 里加一个曲组：
     ```json
     {"id": "theme", "uid": "music:theme", "kind": "music_set", "name": "主题小调", "world": null, "slices": [], "candidates": ["music:theme_a", "music:theme_b", "music:theme_c", "music:theme_d"]}
     ```
   - `entries` 里加 4 个音乐条目：`theme_a`–`theme_d`。字段照已有的 `dungeon_a` 写：
     - `set: "theme"`、`bpm: 84`、`meter: [4, 4]`、`bars: 32`；
     - `name` 分别是 渡口灯、小信差、回家的路、钟与浪；
     - `mode: "C 五声（展示曲含四种色彩）"`；
     - `theme`、`instruments`、`mood`、`difference` 按 3.0 节写；
     - `source: "audio/source/music/theme_<x>.json"`。
   - `routes` **不改**：主题曲组不在游戏里播放，只用来选。
2. **工具**：`tools/content.mjs` 现在要求每个曲组都有 `world`。只改这一处：
   - `id` 为 `theme` 的曲组允许 `world: null`、`slices: []`，并且不能出现在 `routes` 里；
   - 其他曲组的检查照旧。
   - `tests/audio-content.test.mjs` 加两个测试：主题曲组能通过；主题曲组被路由引用时报错。
3. **样曲源文件** `audio/source/music/theme_a.json`–`theme_d.json`：
   - 格式照 WB-02 定的音乐源格式；
   - 32 小节，按 3.0 节的四段结构；
   - 跑 `node tools/audio.mjs build` 生成，`node tools/audio.mjs verify` 必须全部通过（响度、峰值、循环接缝等）。
4. **试听**：在工作台「声音 › 音乐」里能看到"主题小调"一组 4 首，能播放、循环。
5. **不做确认**：4 首都是待确认候选；用户选好后由 Claude 记录。

## 可改的文件
- `content/catalog/audio.json`：只加上面的曲组和 4 个条目
- `tools/content.mjs`：只改主题曲组那一处检查
- `tests/audio-content.test.mjs`：只加测试
- 新建 `audio/source/music/theme_a.json`–`theme_d.json`
- 生成文件：工具重新生成后提交，不手改
- 本文件的状态和「交付」

## 不能碰的文件
- `audio/approvals.json`：不能自己确认
- 其他声音源：`audio/source/sfx/**`（AUD-01 在做）、其他 `audio/source/music/*`
- `docs/design/**`：音符和结构有疑问写进「交付 · 问题」，不要改设计
- 冻结区（AGENTS.md 2a）、`art/**`、`workbench/js/core/**`
- `docs/status.md`、`game/**`

## 验收标准
- [process.md](../process.md) 第 6 节全套检查通过，其中：
  - `node tools/content.mjs check` → 0 错误（`jeju_1` 规划中的警告可以有）；
  - `node tools/audio.mjs build` → 0 错误；
  - `node tools/audio.mjs verify` → ok，4 首主题样曲指标全部通过；
  - `node tools/art.mjs build` → 0 bumped。
- 打开 `workbench/index.html#audio/music`：能看到"主题小调"4 首，能播放；循环一圈接缝没有爆音。
- 交付里：
  - 每首一句话：听起来什么感觉，四段变化分别是怎么做的；
  - 你推荐哪一首、为什么；
  - 给用户确认用的命令（版本号以 build 结果为准）：`node tools/audio.mjs approve ...`（照 WB-02 交付里的写法）；
  - `git diff --stat`。

## 交付（制作方填写）

### 本次交回（2026-10-17，Codex）

- 分支：`aud/AUD-00`；实际开工基线：`df3c466103031505109195729b59dd04038dfbf2`（`origin/claude/inspiring-ride-zfnn4s`）。只提交和推送本分支，未合并其他分支。
- 实现与验收提交：`ac45ce2310e3a1d7e850bad3f95e657d488320b5`；本交付记录随后单独提交。最终交回 tip 的完整 SHA 见交回消息，也可用 `git log -1 --format=%H aud/AUD-00` 核对（交付记录无法在自身内容里预先写入自身提交哈希）。
- 交回方式：远端分支 `origin/aud/AUD-00`；实际 push 结果及最终 tip 在交回消息列明。若推送失败则按包头制作并交回 `AUD-00.bundle`。
- 当前阶段：四首 v1 展示候选已制作，音频指标及真实 WAV 浏览器播放检查通过；**整包技术验收尚未全过**（单测 2 项、e2e 1 项旧固定数量断言失败，见「问题」）。未合并、未正式入库、未取得用户音频质量确认或主题采用确认，也未接入游戏。

#### 四首候选与推荐

每首均为 84 BPM、4/4、32 小节、4,032,000 采样（91.428571 秒）、44,100 Hz 单声道 16-bit PCM WAV，按原型 → 石牢 → 地府 → 海女村每段八小节展示。

- **A《渡口灯》**：上扬再温柔落定，像提灯出门；朴素三角波与正弦低音 → A 羽色彩低八度、轻弱回声 → 圆笛五声短倚音与木点 → 明亮摇摆主旋律、分解伴奏与轻浪声，四种身份仍有清楚的问答句。
- **B《小信差》**：附点短音像小跑送信；清楚的三角波附点原型 → 低八度把短句变成石廊应答 → 圆笛装饰与错拍木点 → 摇摆分解和弦托住轻快旋律，四段保留原来的活泼音高轮廓。
- **C《回家的路》**：宽音程和长音更像摇篮曲；长气息原型 → 低区回声与 A 羽低音 → 温柔圆笛、稀疏倚音与木点 → 明亮前长后短的长句、分解伴奏和浪声，四段都更舒缓。
- **D《钟与浪》**：下行后上扬、最终停在 A，带淡淡思念；钟声般三角波原型 → 低八度悬停回声 → 圆笛与短倚音问答 → 海面摇摆与轻浪声，海女村使用 C/G/F/G/Am/F/G/F 的大调色彩，末尾 A4 落在 F 大调三音并轻收以控制循环接缝。

**推荐 A《渡口灯》**：开头 E–G–A 与后半 A–C–D 的呼应清楚，提灯出发和回落的性格贴合渡界人；四种配器与和声转换后仍容易辨认。这个推荐依据谱面结构和候选制作判断，不代表用户已试听或采用。

#### 实现与旋律核对

- `audio.json` 只追加 `theme` 曲组和 `theme_a`–`theme_d` 四条；原有所有条目、曲组、policy、routes 字段深比较完全相同。主题 `world:null`、`slices:[]`，递归拒绝 `routes` 中引用 `music:theme`，其他曲组原检查保留。
- 四首主旋律音名、数量、顺序均与 3.0 原谱一致；前三遍起点与时值逐音一致，石牢按设计降八度；海女村按 3.0 及本包允许的节奏变化做前长后短，每两拍按 1.25/0.75 分段映射，仍保持每小节四拍和 1/16 拍网格。A/B/C/D 每首四遍共 88/120/72/88 个主旋律音。
- 地府使用单独的弱短倚音轨；没有向音乐 NOTE 偷加不支持的 `slide_to_note`，连续滑音限制见「问题」。海女村另有很轻的低通噪声浪声，所有声音来自仓库内确定性合成器，没有外部采样或服务。
- 每首六轨；计入 release 尾音后最大同时有音高声部 4、总声部 5。最终审阅后将 D 海女村段伴奏从偏 A 小调改成 C/G/F/G/Am/F/G/F 的大调色彩；主旋律不动。D 最后一个 A4 的事件增益从 −1 调到 −5 dB，音高与四拍时值不变；消除首次渲染的接缝超标，没有改渲染器或放宽指标。
- 追加四项隔离测试，覆盖 theme 正常通过、十类路由位置（含嵌套对象/数组）拒绝、theme 字段要求及普通曲组原规则。定向 TDD 实际红灯为 1 pass / 3 fail，最小实现后 4 pass / 0 fail；原测试、helper 和断言没有修改。

#### 实际验收

全部命令串行执行，测试 `--test-concurrency=1`，数值库四项线程变量均为 1。运行前、中断恢复后及长回归期间核对进程；本次只使用一个计算 worker，以 `nice -n 10` 运行正式构建和回归；临时测试浏览器均关闭。

```bash
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1
export PLAYWRIGHT_MODULE=/Users/key_/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright
export PLAYWRIGHT_CHROMIUM_EXECUTABLE='/Users/key_/Library/Caches/ms-playwright/chromium-1217/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing'
```

| 命令 | 实际结果 |
|---|---|
| `node tools/audio.mjs build --baseline-ref origin/claude/inspiring-ride-zfnn4s` | exit 0；首次成功 `4 bumped / 4 changed; 4 source(s)`，编配迭代仍锁定 v1；最终重复构建 `0 bumped / 0 changed; 4 source(s); 未制作 32 音效 + 9 音乐候选; 4 曲组未选定` |
| `node tools/audio.mjs verify` | exit 0；`audio verify: ok; 4 指标通过（不等于用户确认）; 41 未制作; 0 approval record(s)` |
| `node tools/content.mjs check` | exit 0；`content: 0 error(s), 1 warning(s); 52 planned levels, 46 with specs`；唯一警告为已登记的 `slice:jeju_1` 尚未合入 |
| `node tools/check-levels.mjs` | exit 0；全部设计模型通过，末行 `ok W10 author=6 shortest=6 states=39 dead=20` |
| `node tools/check-rooms.mjs` | exit 0；模板演示与 `dungeon_1: 300 seeds` 通过 |
| `node tools/check-rooms2.mjs` | exit 0；各房间路线和 `开局池 delivery_pool：300 个种子` 通过 |
| `node tools/art.mjs build` | exit 0；`build ok: 134 assets, 0 bumped, 94 reference renders, 6 approval records` |
| `node tools/art.mjs verify` | exit 0；`verify ok: 134 assets, 6 approval records` |
| `node --test --test-concurrency=1 tests/*.test.mjs` | **exit 1；194 tests、192 pass、2 fail**；两项固定数量预期冲突详见「问题」，其余全部通过，无 skipped/cancelled |
| `node tests/workbench.e2e.cjs` | **exit 1；115 项通过、1 项失败**：`FAIL music candidates appear as three sets of three`；声音浏览器其余场景通过，原因见「问题」 |
| 本包真实 WAV 浏览器定向核验（临时脚本，不改仓库测试） | exit 0；`PASS music:theme_a/b/c/d real file playback, pause, restart, loop toggle, three wraparounds, stop`；四张待确认卡、每首真实时长约 91.43 秒、0 bindings、无页面错误 |
| 第二次同输入构建后的媒体检查 | 四首 WAV SHA-256 与重建前逐一相同，均 v1、`current_is_approved:false`、`importable:false`；未确认候选没有进入游戏 |

最终 PCM 指标（接缝两项上限均为 0.002，完整指标及全哈希见 `audio/export/manifest.json`）：

| 候选 v1 | RMS dBFS | Peak dBFS | 3 秒窗差 dB | 接缝值差 | 接缝斜率差 |
|---|---:|---:|---:|---:|---:|
| `music:theme_a` | −26.243 | −15.477 | 1.490 | 0.00149536 | 0.00134277 |
| `music:theme_b` | −26.183 | −15.477 | 1.542 | 0.00161743 | 0.00112915 |
| `music:theme_c` | −26.261 | −15.611 | 1.496 | 0.00173950 | 0.00128174 |
| `music:theme_d` | −26.352 | −16.159 | 3.706 | 0.00189209 | 0.00042725 |

最大噪声能量占比约 0.166%（上限 8%），无长静音、削波或直流超标。真实浏览器已验证每首三次回绕；数值和浏览器状态检查不代替用户听感，**未宣称已完成人耳连续三圈及十分钟低音量试听**。未运行 SDK 验证，也不宣称游戏已发声。

#### 确认命令（仅供用户明确确认后由 Claude 执行，本包没有执行）

四首当前均 v1。质量确认和采用主题是两回事；以下是任选对应候选的质量确认命令，`--note` 必须换成用户对该版本/哈希的实际确认原话，不能照抄占位文字制造确认：

```bash
node tools/audio.mjs approve --items music:theme_a@v1 --by 用户 --via chat --note '替换为用户对渡口灯v1及当前哈希的质量确认原话'
node tools/audio.mjs approve --items music:theme_b@v1 --by 用户 --via chat --note '替换为用户对小信差v1及当前哈希的质量确认原话'
node tools/audio.mjs approve --items music:theme_c@v1 --by 用户 --via chat --note '替换为用户对回家的路v1及当前哈希的质量确认原话'
node tools/audio.mjs approve --items music:theme_d@v1 --by 用户 --via chat --note '替换为用户对钟与浪v1及当前哈希的质量确认原话'
```

若用户同时决定“采用哪个为全游戏主题”，在 `workbench/index.html#audio/music` 的主题组选“想用”并下载确认请求（含版本/完整哈希及 `selections.set_uid:music:theme`），把请求及明确“采用”的原话交给 Claude；由 Claude 核对后执行：

```bash
node tools/audio.mjs approve --from-file audio-approval-request.json --by 用户 --via workbench --note '替换为用户对具体版本、哈希的质量确认及采用原话'
```

这只记录主题选择；`routes` 不变，不把展示主题组当作地图播放曲。

#### 范围自查与改动统计

- 本包新建四份音乐源与四个 preview WAV；只追加允许的设计目录条目，最小修改主题曲组检查并追加测试；内容/音频清单和工作台数据完全由工具生成。
- `audio/approvals.json` 字节及 0 条记录不变；`art/approvals.json` 字节及 6 条记录不变。冻结区、开工已有的 `game/**` 和进度文档等共 2,269 个保护/原有文件，前后 SHA-256 全部相同；未提交这些原有工作区改动。
- art build 的 `workbench/data/bundle.js` 唯一变化是生成时间戳，已恢复开工前的完整字节；未提交 `art/**` 或其他包外文件。未修改 `docs/status.md`、`docs/v2/status.md` 或 `game/**`。
- 未改测试旧预期、删测试或放宽断言；与新主题组冲突的三项旧固定数量断言保留并如实报告。

`git diff --stat origin/claude/inspiring-ride-zfnn4s..aud/AUD-00`（与实际基线 `df3c466` 相同；包含随后交付记录）：

```text
<!-- AUD00-STAT-START -->
 audio/export/manifest.json             |  267 ++++-
 audio/export/preview/music/theme_a.wav |  Bin 0 -> 8064044 bytes
 audio/export/preview/music/theme_b.wav |  Bin 0 -> 8064044 bytes
 audio/export/preview/music/theme_c.wav |  Bin 0 -> 8064044 bytes
 audio/export/preview/music/theme_d.wav |  Bin 0 -> 8064044 bytes
 audio/source/music/theme_a.json        | 1477 ++++++++++++++++++++++++++++
 audio/source/music/theme_b.json        | 1681 ++++++++++++++++++++++++++++++++
 audio/source/music/theme_c.json        | 1381 ++++++++++++++++++++++++++
 audio/source/music/theme_d.json        | 1477 ++++++++++++++++++++++++++++
 content/catalog/audio.json             |  130 +++
 content/export/content-manifest.json   |  397 +++++++-
 content/export/id-map.json             |  215 +++-
 docs/packages/AUD-00.md                |  131 ++-
 tests/audio-content.test.mjs           |   76 ++
 tools/content.mjs                      |   10 +-
 workbench/data/audio.js                |    2 +-
 workbench/data/content.js              |    2 +-
 17 files changed, 7239 insertions(+), 7 deletions(-)
<!-- AUD00-STAT-END -->
```

#### 问题

1. **全套检查未全绿：新增主题组后，有三项旧数量断言不再成立，且本包没有改它们的授权。**
   - `tests/audio-content.test.mjs` 原首测试固定要求条目 41、曲组 3、音乐编号域 12；当前真实值为 45、4、17。首次在 `41` 断言失败，另外两个也须同步核对。本包对该文件明确“只加测试”，所以保留原断言。
   - `tests/audio-pipeline.test.mjs:260` 的空目录 CLI 预期 `/32.*9/`，隔离目录从更新后 catalog 得到 32 个缺源音效、13 个缺源音乐候选（包含四个 theme），实际输出正确但旧断言失败；该文件不在可改清单。
   - `tests/workbench.e2e.cjs` 的 `music candidates appear as three sets of three` 固定只接受原来的三组各三首；现在正确的结构应是三组各三首加主题组四首。该文件不在可改清单。
   - 请整理合并方先解决上述测试范围授权冲突，按实际曲组/条目精确更新预期并保留覆盖，再重跑全套；不能把这次 192/194 与 115/116 写成全量通过，也不能通过隐藏 theme 或删除断言求绿。
2. **连续滑音未实现，需确认取舍。** 当前音乐 NOTE 仅支持 `beat/length/note/gain_db`，`slide_to_note` 只允许 SFX。本包不能改渲染器或源格式（会影响其他声音哈希），因此地府段已完成五声圆笛、独立短倚音及木点，但没有真正连续滑音。请用户/设计负责人确定是否接受当前短倚音表达；若必须连续滑音，由整理合并方另行安排允许修改音乐格式和工具的包，再制作候选，不能在本包暗改设计或工具。
3. **待用户听感验收和选主题。** 四首均为未确认候选；不将指标通过、浏览器循环或推荐 A 当作质量/采用确认。人耳接缝三圈及十分钟低音量试听尚待用户完成。`jeju_1` 警告属于登记的规划依赖，未越权修改地图目录。

**下一步及执行人：** 制作方交回 `aud/AUD-00`；Claude（整理合并）先核对本包及三项数量断言的授权范围，安排精确修正并重跑全套，再按 process 第 7 节决定验收/合并并更新正式进度；用户之后在工作台“声音 › 音乐 › 主题小调”试听 A–D，决定连续滑音取舍并选主题，由 Claude 根据原话记录。当前制作方不开始 AUD-01/AUD-02，也不合并或写正式进度。

给用户转交到整理合并聊天的可复制提示词：

> 请核对并接收 `aud/AUD-00`，先处理 `docs/packages/AUD-00.md`「交付 · 问题」列出的三项旧数量断言与包内修改范围冲突，重跑 process 第 6 节全套检查后再决定验收合并；保留四首 v1 为待确认候选，不自行批准。连续滑音限制和用户试听/选主题另按交付记录处理。
