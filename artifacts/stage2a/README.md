# 第二阶段 A：六图 36 关与外部试玩候选

本轮基于阶段 1.5 已验收提交 `6687206`，严格按 2A.1 → 2A.2 → 2A.3 顺序、单 worker 实施。C++ 未修改或重新编译；SDK v1.2.0 的现成接口、JSON 内容配置和确定性 GDScript 完成全部机制。

**交付状态：第二阶段 A 技术试玩候选已完成，24/24 全量脚本通过，macOS 包内验证通过；未推送或正式发布，外部玩家验收尚未进行。** 最新结论见 [项目进度](../../docs/v2/status.md)；下述实现记录不代替最终通过证据。

## 最终通过证据（2026-10-15）

- 全量：24/24 脚本零失败；36/36 有解，856 个作者动作，8929 项逐动作 / UI 检查通过。
- T8：18802 个结算帧，峰值 **3.866 ms**，p95 **1.013 ms**；全 36 关逐帧 ≤ 4 ms。
- 原 D1–D5：986 帧峰值 2.638 ms，8 次预演显示峰值 68.115 ms；教学：981 帧峰值 2.240 ms，5 次预演峰值 83.651 ms。
- 机关 103 项、进度 114 项、分帧调度 1311 项通过；包括机关 / key 分类中途撤销后不再提交旧工作。
- 135 个代码 / 数据 / 测试 / 工具指纹与被测版本一致；17 项冻结文件未改；30 张 PNG 尺寸与整数放大像素核验通过。
- [macOS 试玩包](../macos-stage2a/Pushbox-stage2a-macos-arm64.dmg)：0.4.0、约 31.6 MiB，包内 2877 项回放 / 预演 / 字体 / SDK 检查零失败；签名、DMG 完整性和只读挂载 GUI 启动检查通过。
- 多轮超限与中断记录完整保留，不作为通过证据。最终汇总见 [verification.json](verification.json)；当前美术 / UI 已获进一步翻新授权，尚未获得本阶段最终美术验收。

## 实现与玩法

- 六图各 6 关：2 关★、2 关★★、2 关★★★，大图上限 20×11。稳定编号为 D/F/R/C/S/X_01..06，文件位于 `pushbox/levels/campaign/<biome>/c_<biome>_01..06.json`。
- 地牢防夹闸与矿柱塌方；森林遇水藤梯；遗迹定量漏斗与双盘天平；洞穴酸蚀、钟乳石重锤和间歇泉；天空水冰拉杆、轻重云垫与顺风场；宇宙物质传送与局部反重力。
- 接入铁箱、强酸、酸雾、熔岩、浮石沙、实心冰。反重力颗粒及移动天平底板使用静态代理材质，保留颗粒及托盘下的原材质；这些同样由现有 SDK 注册。
- 大厅 → 闯关模式：初始只开地图 1，每图先开前 2 关；每个不同关卡首次通关再开后 2 关。任意累计 3/6 立即开下一图并亮银章，6/6 亮金冠；重复过关不重复计数。
- Tab / 观察池：浏览包括锁定地图在内的全部 36 关，使用实际关卡 JSON 的完整地形、机关、箱体与目标；左右切关，上下 / Q/E 切图，悬停机关查看说明，Tab / Esc 返回。
- 进度档兼容旧教学记录，独立统计教学与闯关；写入、flush 后原子替换，失败保留待重试。不可变写档内容交给既有单 worker 池，SDK / 操作保持冻结；主线程的发起、等待轮询和原子替换帧计入 T8。退出与重开先等待落盘，新进度会使旧写入失效。

## 作者解法与几何校准

36 关共 856 个作者动作，全部录制 `solution`、`solution_hashes`、`solution_keys`。回放逐动作验证预演、实际 SDK 哈希、完整游戏状态、撤销和重做，终态要求 `session.board.won() == true` 且无结算警告。

设计表中的格子草图经过真实 SDK 颗粒模拟校准，保留各关指定的尺寸、主题与核心解谜链：

- 辅助铁箱 / 配重箱各有终点，保持既有“所有箱子与目标逐一匹配”的胜利规则。
- D_02 增加路径下的沙兜，使用真实整格挖沙阻止闸门复位；不引入“半格挖沙”操作。D_04、R_02 设置爆破损耗余量。
- D_05 / D_06 为铁箱旁保留水路旁通，并校准初始水量，保证挖出的矿砂参与抬升。D_06 的联动防夹闸横跨铁箱路线，增加下层水井与长梯；先送达上层木箱，再回收矿砂抬升下层第二木箱，66 步解法完整录制，并断言两木箱均在倒沙后上浮。
- R_04 漏斗按 256 + 192 cells 分两次玩家动作释放，避免入口堆沙堵住水道；锁存状态随 Z 和 T6 恢复。
- R_05 / R_06 使用双组配重盘及现场可挖沙，完整实现先重后轻、逐段交换载荷与托箱。
- S_03 按真实部分水位冻结；S_05 完整执行冻结通行 → 木箱过桥 → 铁箱压穿云垫 → 爆破铁锚落底 → 解冻与储水抬木箱。储水池补偿爆破移除的水量。
- X_06 的传送按机关状态开通，避免开局零散颗粒抢占接收座；反重力轻箱 / 沙与锁底铁箱均参与解法。

完整逐关动作数及结果见 [campaign-verification.json](campaign-verification.json)。生成、录制工具分别为 `tools/build_campaign.py`、`tools/record_campaign.gd`；录制器仅在确实胜利且没有错误时输出可安装记录。

## 验证与冻结保护

最终命令：`python3 tools/run_tests.py --performance`。测试项目隔离 `user://`，不包含旧精灵 PNG；SDK `threads=1`，逐进程顺序运行，数值库线程均限制为 1。

新增机关专项、池进度专项、36 关逐动作专项及真实窗口 T8，连同旧回归共 24 个脚本。最终完整摘要为 [logs/test-summary.json](logs/test-summary.json)，完整输出为 [logs/final-console.log](logs/final-console.log)。

T8 沿用旧基线口径：游戏结算 CPU + SDK 上传 + BoardView 绘制，逐帧峰值 ≤ 4 ms；原教学 / D1–D5 还保留实际悬停显示 ≤ 100 ms 门槛。GPU 光栅化、系统合成与加载 / Shader 初始化分别处理，不计入该 CPU 指标。没有提高阈值、删除超限样本或把部分回放拼成全量通过。失败与超时轮保存在 [logs/attempts/](logs/attempts/)，不能用作通过依据。

最终调度将材料读取、分类、每批最多 32 格 / 1 ms 软预算计数、逐个机关 / 箱体 / 玩家 / 闸门结算，以及每批 64 格的 key 分类分帧执行，这些阶段不增加 SDK tick。混合颗粒搬运仍提交原有逐颗粒命令及顺序，只将重复的逐颗粒缓存清理合并为每格一次；混合格采用 PackedInt32Array 原生计数，避免逐颗粒 GDScript 标签扫描，分类阈值不变。103 项机关回归包含混合沙 / 水守恒、置换、分类缓存、原位还原与部分结冰。普通 UI 回归保留窗口适配检查；长时间性能测试使用前台原生 320×180 角落窗口，真实输入与脚本回放隔离，避免 macOS 遮挡节流。CPU 指标包含同一原生画布的上传及绘制。

工具复核修正了自定义目录字段（应为 `application/config/custom_user_dir_name`，见 [Godot 官方说明](https://docs.godotengine.org/en/4.3/classes/class_projectsettings.html)）：旧工具各轮曾共用一个测试目录，该目录与默认游戏存档目录不同。最终轮使用唯一临时目录，并在每个进程启动时断言 `OS.get_user_data_dir()` 与指定目录一致；日志保留实际路径。先前诊断轮不作为最终通过依据。

[frozen-files.json](frozen-files.json) 冻结 17 项：bin 全部 7 文件、`ele.gdextension`、原 D1–D5 和 T01–T04。旧九关运行时使用原始字节的 `content/legacy` 注册表，避免新增材质改变 SDK 状态哈希；原作者哈希及关卡 JSON 不变。动态库 SHA256：

`b084eb5ffad07cc4b790285156de1bf3ef1c33fd69a8bb7fd2d7c599f6c088c4`

最终汇总由 `python3 tools/verify_stage2a.py --require-package` 生成，覆盖全量测试、36/36、性能、30 张整数放大截图、冻结文件、源码指纹及包内 SDK。T2 的 4/8 线程与 T10 真人研究不在本轮自动化范围；外部玩家试玩尚未完成。

## 实机图册

每个视图包含原生图及 1920×1080 的整数最近邻放大图，共 15 个视图 / 30 张 PNG；由真实 macOS Godot 渲染。截图尺寸与逐像素放大一致性由验证器检查。

| 视图 | 实际开局 | 全景观察 |
| --- | --- | --- |
| 地牢 D_06 | [开局](captures/dungeon-opening-1920x1080.png) | [观察](captures/dungeon-observation-1920x1080.png) |
| 森林 F_06 | [开局](captures/forest-opening-1920x1080.png) | [观察](captures/forest-observation-1920x1080.png) |
| 遗迹 R_06 | [开局](captures/ruins-opening-1920x1080.png) | [观察](captures/ruins-observation-1920x1080.png) |
| 洞穴 C_06 | [开局](captures/cave-opening-1920x1080.png) | [观察](captures/cave-observation-1920x1080.png) |
| 天空 S_06 | [开局](captures/sky_island-opening-1920x1080.png) | [观察](captures/sky_island-observation-1920x1080.png) |
| 宇宙 X_06 | [开局](captures/cosmos-opening-1920x1080.png) | [观察](captures/cosmos-observation-1920x1080.png) |

[初始关卡池](captures/campaign-pool-1920x1080.png) · [3/6 银章](captures/campaign-silver-unlock-1920x1080.png) · [下一地图解锁](captures/forest-pool-unlocked-1920x1080.png) · [截图清单](captures/manifest.json)

## 外部试玩交接

安装包验证通过后，由用户将 macOS Apple silicon / macOS 15.6+ 的自包含 DMG 发给试玩者；无需另装 Godot 或编译 SDK。包为 ad-hoc 测试签名，未 Apple 公证。玩家从大厅“闯关模式”进入，Z 撤销、R 重开、Esc 返回池；Tab 提前侦察布局。

反馈请在本开发聊天发送：

> 第二阶段 A 试玩反馈：关卡编号 ___；复现步骤 ___；预期 / 实际表现 ___；机型与 macOS 版本 ___；附截图或录屏。

下一步：当前 Codex 封存本地技术候选；随后按用户明确授权，新开同项目独立任务执行 [美术 / UI 翻新指令](art-ui-polish-next-task.md)，继续保持单 worker、SDK 冻结与全部硬性门禁。用户醒来后先在新任务验收翻新截图 / 试玩包，再分发外部玩家试玩；Codex 根据具体反馈修复。当前无需你操作。第二阶段 B、C++ 扩展、正式发布及第三阶段不在本轮范围。
