# 项目进度

更新：2026-10-15。Godot 开发：GPT；设计、美术、工作台与技术审核：Claude；美术确认与新手试玩：用户。

## 当前阶段与交付状态

**R2 阶段一功能候选已交付；正式里程碑未通过，阶段二未开工。**

- 开发分支 `codex/portitor-stage1`，基线 `9248ea1`（`claude/inspiring-ride-zfnn4s`），工程在 `game/`。候选、设计审核、用户验收分别记录，不能将作者解通过视为所有验收通过。
- M01–M07 的真实 SDK 作者解、菜单闭环、六主题、生态/环境、中英界面、提示/演示/回退、观察/高亮、规则卡、存档与设置已实现并验证。
- 阶段一仍受两项阻挡：**M06 规格中的替代解未找到路线，SDK 未运行；当前界面 v4 与气泡未确认，候选 UI 仍有逐像素差异**。设计负责人尚未审核本候选；新手试玩未运行。
- 只复制当前确认的 70 项美术。冻结区无改动，没有自行批准资产。程序化界面和气泡明确显示“占位”；正式发布门禁实际拒绝需要的 10 个未确认编号。
- macOS arm64 开发候选已生成，并从仓库外临时目录分别通过 headless 与原生窗口的启动、真实 SDK M01 建立及退出检查（两次 exit 0，无引擎错误）。这不等于新手试玩或完整打包版作者解回放。

## 运行、复验与打包

- Finder 双击 `builds/PORTITOR-Stage1-Candidate.app`；也可双击根目录 `Run Game.command` 或执行 `./run.sh`。
- 源工程启动器要求 Godot **4.7.2**，可用 `PUSHBOX_GODOT_BIN` 覆盖。本机实查路径：`/Users/key_/Desktop/CURRGO/ele-proj/zips/Godot.app/Contents/MacOS/Godot`。
- 本机实测：macOS 15.6.1、Apple M3、arm64；SDK v1.2.0 `dacb93e`，动态库 SHA-256 与 `third_party/ele-sdk/build-metadata.json` 匹配。
- 完整串行回归：`tools/run-tests.sh --gpu`。本轮 **22 项中 21 项通过**，唯一未通过的 suite 是 `levels` 中的 M06 替代解验收，命令整体 exit 1，如实保留。
- 打包：`tools/package-macos.sh`；独立包启停：`python3 game/tools/smoke_package.py`。实际 PCK SHA-256：`d16340c7a8a1fe1053d2e78674557382c50b0d4a6542c2a81c54a8c52add030d`。
- 本机官方模板只有 universal 二进制；先导出、再用 `lipo` 留 arm64，并保留扩展声明对应的 `Contents/Frameworks/bin/` 目录。导出时的 x86_64 SDK 缺失警告与最终 arm64 包分开记录，实际启停已验证。包带 SDK/字体许可证。
- 美术门禁：`node game/tools/import_resources.mjs release`（当前预期 exit 1）；内容：`node tools/content.mjs check`；美术：`node tools/art.mjs verify`。
- 平台限制：目前只有 macOS arm64 SDK，最低 macOS 15.6；其他平台、Godot 版本和渲染驱动均**未运行**。

## 本轮实际验证

正式证据：[verification.json](../game/reports/verification.json)。run_id：`20261015T142519338531Z-64756`。源码开跑/结束 SHA 相同：`f4fe4e24d7018a78701ead8dbce554b5d425fe151d2f84551ab354f4d947be0c`；`source_changed=false`、`run_incomplete=false`、`milestone_complete=false`。

| 项目 | 实际结果 |
|---|---|
| SDK 样板 a–e | 全通过；靠墙倒沙目标 220 cell、溢出 36；上方夯土保持 256；箱子守恒；连续 4 tick 静止；快照恢复完整 61440 cell 与哈希 |
| 规则与生命周期 | 155 项通过；包含正反例、同步/分帧完整哈希序列、无安全扫描的移动、真实 JSON 写入失败、部分快照退出清理 |
| 七关作者解 | 各真实 SDK 回放 3 次通关；每步模型局面、全部 tick 哈希序列一致；逐步撤销恢复；结算不触顶 |
| 关卡验收 | 1534 断言中 1533 通过；仅 `M06.alternative.sdk_verified` 未通过。该替代路线 SDK **未运行**，不是作者解失败 |
| 六主题与七关开局 | CPU 规则、六主题地形 GPU、六主题 SHOWCASE、七关 SDK 开局静态区域均 0 像素差异；SDK x=256 接缝检查通过 |
| 动态沙 | 真实 256 个沙 cell；颜色集合与 SDK 随机颜色位映射均 0 错误；未用 HTML 物理代替 |
| 界面 | 中英 8 屏、42 个关卡提示层级零溢出；物理 Enter/S/Down 流程、倍率重启应用、演示/回退、观察禁操作、退出清理通过；气泡正文实际可见，受阻反馈不改 moves/SDK |
| UID、导入与存档 | 713 个导入 UID 的 a/b/c 检查通过；坏存档备份与恢复、未知段保留、原子存档、导入/发布行为检查通过 |
| 报告证据保护 | 13 个隔离 fixture 通过：不复用旧成功、必须有新文件/完成标记、源码突变失效、全机计算预算耗尽拒启、任务间重查 |
| 普通模式性能 | 六主题各 30 帧预热 + 120 个真实绘制间隔，以及七关全部作者动作/撤销；峰值 **3.317 ms**，撤销 **7.719 ms**；六主题最低 **63.929 fps**，严格 4 ms / 100 ms / 60 fps 门禁通过 |
| 无上限容量 | 单独报告，通过；峰值 1.034 ms；不拿它替代普通模式成绩 |
| 内存 | macOS 实际进程峰值物理占用 **225.8 MiB**，包含冷加载/预热；不是只报引擎 heap |
| 内容与美术 | `content check/build`: 0 errors / 0 warnings；`verify ok: 83 assets, 4 approval records`；工作台已重建读取本轮报告，原始 id-map 未改；4 个机制的派生状态由工具更新，未手填目录 |
| 独立开发包 | headless / macOS 窗口两次实际启停通过；正式发布仍被美术门禁阻止；新手试玩**未运行** |

性能边界：`performance.json` 测的是 SDK 动作准备/推进与实际 WorldView（含完整环境），**HUD、场景冷构建不在该 benchmark 内**；短截图中的 FPS/Control 构建耗时另存原始数据，不作为持续性能成绩或全应用帧耗时的通过证明。

本轮性能修复保留全部检查：安全扫描每次最多 64 cell；SDK 快照与游戏 JSON 分帧，关闭后读回 JSON 核对，两者成功才应用动作；物理结束后的分类/游戏规则另帧执行，快进不合并这些阶段。每帧仍推进最多 4 个物理 tick、连续 4 个静止 tick 才结束，1200 tick/16 轮上限不变。旧/新调度的七关全部局面、tick 数与 3 次完整哈希序列一致，见 `game/reports/settle-scheduling-equivalence.json`（保留本次改动前基线 `game/tests/results/settle-before-scheduling.json`）。绘制上限 64，动画仍为 60 Hz 整数 tick；缓存只复用实际不变的 CPU 图层，每帧保留真实 SDK 纹理绑定。

所有计算串行、SDK threads=1、Godot worker pool=1、数值库线程=1；各测试前检查其他计算进程。原始日志/报告在 `game/tests/results/`，截图在 `game/reports/shots/`；历史失败日志保留供审核，不冒充本轮通过。

## 界面逐像素差异与原因

每幅 320×180，共 57600 像素；下表均为实测差异数，**没有声明 UI 与参考图完全一致**。

| 界面 | 中文 | 英文 |
|---|---:|---:|
| lobby | 178 | 225 |
| chapters | 88 | 483 |
| levels | 61 | 721 |
| pause | 491 | 656 |
| settings | 151 | 197 |
| hint | 5877 | 5822 |
| complete | 923 | 916 |
| rulecard | 471 | 782 |

- 气泡/尾巴采用明确标记的纯色占位，未使用未确认 PNG；这是 hint 差异的主要来源。八屏当前 v4 亦待确认；候选标记、真实 HUD/进度以及原生字体与工作台字形的差异保留待审核。
- 设置截图固定 1× 获取 320×180 像素，与参考中的自动倍率文字不同，也计入差异。
- 章节参考画面显示前两组开放，截图仅使用可视 fixture 对齐这项展示；实际游戏始终只开放基础组。水组按权威 manifest 显示 9 关，参考图旧计数 7 未照抄。fixture 不算 SDK 解锁/验证。
- 文字区域由 Margin/HBox/VBox Container 管理，宽度按文字实测并限制；图形区域按 320×180 参考几何定位。实际热切换语言、保存倍率恢复、左右边缘气泡锚点和正文绘制顺序都已回归。

## 给设计负责人的问题

1. **M06 替代解矛盾**：规格要求“沙压板、箱作台阶”可通关。未改动的 `tilemodel.js` 穷尽 979 个可达状态，未找到同时沙压 `[5,5]`、箱在右侧台阶 `[10,4]` 且通关的状态。复现：`node game/tools/export_model.mjs --m06-alternative`，结果 `game/tests/levels/M06-alternative.generated.json`（found=false、complete=true）。这是设计模型证据；没有可回放路线，替代解 SDK 未运行。请 Claude 核对路线或修正规格，GPT 不改玩法来绕过验收。
2. **美术确认**：manifest 当前确认 70/83。八屏 v4 未确认（历史 approved v3 不能套用）；`ui.bubble`、`ui.bubble_tail`、`ui.emote`、`ui.screen.dialogue` 无确认；`char.portitor_alt` 是草稿且不进游戏。需要 Claude 整理版本/哈希、用户确认后，GPT 再接正式样式与重做像素对照。候选通过不代表美术或正式发布通过。
3. **界面 UID 路径**：权威 id-map 是 `res://ui/screens/`，architecture 要 `presentation/ui/screens/`。已生成薄包装以保留权威映射，实际控件在 presentation。请 Claude 统一后续规范。
4. **新增文字 UID**：`tools/content.mjs` 未导出已授权 `i18n-extra` 的 text uid。游戏导入器仅对真实新增键补充生成映射，保留 source/origin；原 id-map 不改。请 Claude 将 extra 键正式纳入导出工具，GPT 随后去除这项临时兼容。
5. **阶段外机制**：id-map 全部 74 个机制路径存在；本轮只注册并实现 6 个基础机制，其余 68 个是显式未实现骨架，没有开放或宣称验证。水组须等阶段一审核后再实现。
6. **压板绘制规则**：冻结 `scene.js` 仅将人物/箱子绘制为压板按下，没计沙。当前按该规则移植；沙仍在真实规则中开门，但压板帧可能显示抬起。请 Claude 统一绘制规格，GPT 不改冻结文件。
7. **交接旧表述**：portal/bridge 已在 APR-0004 确认，本轮按实际 manifest 处理；旧文字仍称候选，建议 Claude 统一。其他平台和完整应用（含 HUD/冷界面构建）性能未在本次 WorldView benchmark 中建立通过结论，请技术审核按上述范围评估。

## 新增文字与待美术

开发文字仅在 `content/i18n-extra/{zh-Hans,en}.json`：`dev.placeholder`、`dev.pending_art`、`error.runtime`、`hint.restart`、`hud.controls`，以及 `extra.rule.{push,ladder,pour,plate_door,fall}.{name,text}`，共 15 键/语言，来自既定规则。未改已确认 i18n。

| 待确认资产 | 规格与用途 | 当前处理 |
|---|---|---|
| 八个 `ui.screen.*` v4 | 320×180 程序化布局；大厅、章节、选择、暂停、设置、提示、过关、规则卡 | 已确认元素搭建候选，显著占位，发布拒绝 |
| `ui.bubble` v1 | 12×12、3 帧、九宫格边距 4；角色提示正文 | 纯色占位，10px 字体、4 行、逐字显示 |
| `ui.bubble_tail` v1 | 7×6、2 帧、锚点 [3,0]；指向说话人 | 纯色占位，跟随真实锚点并处理边缘/上下布局 |

没有新画素材。emote/完整对话系统本轮未用；对话数据、触发器、委托未实现。音量仅保存，未找音频素材。

## 下一步与执行人

1. **Claude，最近可执行的一步**：审核本分支候选、M06 替代解证据、UI 差异与 UID 临时兼容；核对或修正规格，整理待确认资产的明确版本/哈希，把审核结论写回本文件。
2. **用户，按 Claude 提供的版本/哈希**：确认既有 UI/气泡候选；之后组织新手试玩。当前不需要你重新授权开发或立即试玩。
3. **GPT，收到设计/美术结果后**：补 M06 指定路线的真实 SDK 验收，接入确认后的气泡/界面，解决审核项并重跑阶段一；阶段一审核通过后再进入阶段二 W01–W05、W07–W10。

需要跨聊天交接时，请在**现有 Claude 设计负责人聊天**发送以下内容（开发方没有获得代发消息授权）：

> 请审核 `codex/portitor-stage1` 的阶段一候选，先完整阅读 `docs/status.md` 与 `game/reports/verification.json`。请先处理 M06 替代解规格矛盾，审核界面像素差异和 UID 临时兼容，并整理 UI v4/气泡的待确认版本与哈希；将具体审核结论与下一步写回 `docs/status.md`。阶段一尚未正式通过，先不要开始阶段二。
