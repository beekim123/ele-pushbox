# AUD-00 主题小调：4 个方案做成样曲，给用户选

状态：待派（用户 2026-10-17 决定：先定主题小调，再按地图做变奏）
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
