# AUD-00（第二版）主题小调：4 个抓耳的方案，每个配 3 首地图变奏，分开成独立曲子

状态：**等 WB-04（合成器升级）合并后再派**（2026-10-17 重写。第一版已合并但用户不满意：不抓耳；四种味道拼在一个文件里听不出来）
基线：`claude/inspiring-ride-zfnn4s` → 分支：`aud/AUD-00-v2`（**不要**用旧的 `aud/AUD-00` 分支，**不要**从 `main` 开）

**开工**（照抄）：
```bash
git fetch origin
git checkout -b aud/AUD-00-v2 origin/claude/inspiring-ride-zfnn4s
```
**交回**（二选一）：
- 能推送：`git push -u origin aud/AUD-00-v2`
- 不能推送：`git bundle create AUD-00-v2.bundle origin/claude/inspiring-ride-zfnn4s..aud/AUD-00-v2`，把文件交给用户

只往 `aud/AUD-00-v2` 提交；不往别的分支推送，也不合并别的分支。

**预计 2–3 小时**。超过 4 小时还没做完，就停下，把做到哪、卡在哪写进「交付」交回。

## 要读的（只读这些）
0. `audio/presets.json`（WB-04 做的音色预设：古筝、笛子、二胡、木鱼、编钟、伽倻琴、海浪等）和 `docs/packages/WB-04/presets/all.wav`。**配器用这些预设**，让每张地图的乐器一听就不同。
1. [audio.md](../design/audio.md) **第 3.0 节**（这一版的全部要求）和第 1 节的数值表
2. 第一版的源文件 `audio/source/music/theme_a.json`：看音乐源怎么写，格式照它
3. `content/catalog/audio.json` 里 `music_sets` 和 `theme_a` 条目：看怎么登记

其他文件用到再看，不要通读仓库。

## 要做的
1. **作曲**：按 3.0 节的硬要求，自己写 4 段**互相差别大**的主题小调（8 小节）。第一版 A–D 的旋律**不用**，重新写。
   - 动笔前先在交付里用一两句话写清每段的"钩子"是什么：哪个节奏、哪个跳进。
2. **每个方案做 4 首独立曲子**：主题曲、石牢变奏、地府变奏、海女村变奏。每首 32 小节、能循环，各自是一个独立的音乐条目、一个独立的 WAV。4 个方案一共 16 首。
3. **登记**（`content/catalog/audio.json`）：
   - 删掉第一版的曲组 `theme`；
   - 加 4 个曲组 `theme_a`、`theme_b`、`theme_c`、`theme_d`，每组 `world: null`、`slices: []`，候选是这一方案的 4 首：
     - `music:theme_a`：主题曲；
     - `music:theme_a_dungeon`、`music:theme_a_diyu`、`music:theme_a_jeju`；
     - b、c、d 同理。
   - 每首的 `bpm` 按 3.0 节的范围，`name` 写曲名（例如"渡口灯 · 石牢"）；
   - `routes` 不改。
4. **工具**：`tools/content.mjs` 里现在只放行 id 为 `theme` 的曲组，改成放行 id 以 `theme_` 开头的曲组（同样不许被 `routes` 引用）。`tests/audio-content.test.mjs` 里相应的测试跟着改。
5. **生成**：`node tools/audio.mjs build`，再 `node tools/audio.mjs verify` 全部通过。

## 可改的文件
- `content/catalog/audio.json`：只改主题曲组和主题条目
- `tools/content.mjs`：只改主题曲组那一处
- `tests/audio-content.test.mjs`：只改主题曲组的测试
- `audio/source/music/theme_*.json`：新建或改写
- 生成文件：工具生成后提交，不手改
- 本文件的「交付」

## 不能碰的文件
- `audio/approvals.json`（不能自己确认）、`audio/source/sfx/**`、地图音乐 `audio/source/music/{dungeon,diyu,jeju}_*`
- `docs/design/**`、`docs/status.md`、`art/**`、`workbench/js/core/**`、`game/**`

## 检查（只跑这些，各跑一次，最后再整体跑一次）
```bash
node tools/audio.mjs build
node tools/audio.mjs verify
node tools/content.mjs check          # 0 错误；jeju_1 的警告可以有
node --test tests/*.test.mjs
node tests/workbench.e2e.cjs           # 只在最后跑一次
```
- **不要**逐个计算文件哈希来证明没改别的文件：`git diff --stat` 就够了。
- **不要**跑关卡检查、美术构建：这一包不碰它们。
- 测试浏览器找不到时，用本机路径：
  ```bash
  export PLAYWRIGHT_MODULE=/Users/key_/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright
  export PLAYWRIGHT_CHROMIUM_EXECUTABLE='/Users/key_/Library/Caches/ms-playwright/chromium-1217/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing'
  ```

## 交付（制作方填写，控制在 40 行以内）
- 4 个方案：名字、钩子是什么、性格各一句；你推荐哪个、为什么。
- 上面 5 条命令各一行结果。
- `git diff --stat`。
- 遗留问题（没有就写"无"）。
