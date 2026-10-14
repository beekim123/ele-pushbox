# 推箱子：沙与水 · 第二阶段 A 试玩候选

六大风格地图、36 个有解闯关，保留四个教学关与五个经典横版推箱房间。沙、水和爆破由真实 ele-base-cpp v1.2.0（dacb93e）模拟，地图独特机关由确定性 GDScript 实现。Godot 4.7.2，macOS Apple silicon；工程已包含 SDK dylib。

## 获取与运行

```sh
git clone https://github.com/beekim123/ele-pushbox.git
cd ele-pushbox
```

仓库随附约 1.2 MB 的 macOS arm64 SDK 动态库及许可证，运行需要 macOS 15.6 或更新版本、Apple silicon 和 Godot 4.7.2，无需先编译 SDK。其他操作系统和架构尚未适配。

成品目标与持续补充入口见 [项目目标与需求记录](docs/project-goals.md)。第一阶段的大厅、教学模式和纯代码美术已获用户验收并封存于 `feaa6ba`。阶段 1.5 六风格美术已获验收。当前第二阶段 A 在现有 SDK v1.2.0 上实现六地图、36 关有解池、观察池与满 3 关解锁机制；C++ 引擎与 bin 保持不变，交付状态见 [阶段 2A 报告](artifacts/stage2a/README.md)。

双击根目录 **Run Demo.command** 即可启动。本机启动脚本会自动找到已有 Godot；其他机器可指定可执行文件：

```sh
PUSHBOX_GODOT_BIN='/你的/Godot.app/Contents/MacOS/Godot' ./tools/run_demo.sh
```

大厅选择 **闯关模式**：石牢 → 古森 → 神庙 → 晶窟 → 天空 → 星站，每图 6 关。新地图先开放 2 关，每通 1 关再开放后 2 关；本图任意通满 3 关解锁下一图，3/6 得银章、6/6 得金冠。Q/E 或顶栏切图，方向键/鼠标选关，Enter/左键进入；通关后返回关卡池。

在关卡池按 **Tab / 观察池**，可侦察全部 36 关（含锁定地图和高星关）。左右切本图关卡，上下/Q/E 切图，悬停机关看说明，Tab/Esc 返回。外部试玩使用自包含 [macOS 安装候选](artifacts/macos-stage2a/Pushbox-stage2a-macos-arm64.dmg)，无需另装 Godot；Apple silicon / macOS 15.6+。

在大厅点击 **地图风格预览 · B**，或按 **B**：浏览地牢、森林、遗迹、洞穴、天空岛、宇宙六张大地图。左右方向键、左右箭头按钮及底部主题标签均可切换，Esc 或左上「返回大厅」退出。预览使用 640×360 原生画布、整数缩放及游戏的地形 Shader；新机关展示外观。六图的原生与 1920×1080 整数 ×3 截图见 [阶段 1.5 预览报告](artifacts/biome-preview/README.md)。

方向键 / WASD 走、推、爬梯；人物站在拉杆上按 ↑，或左键点拉杆。左键点左、右、下相邻的沙格挖沙，右键点左、右相邻的空格或水格倒沙。悬停即预演，点击直接执行。把右上角炸药拖到左、右、下相邻格，松手爆破；拖回图标或在其他位置松手取消。

Z 撤销（可按住），R 重开，均无确认。结算时按任意键或点鼠标快进。Esc 打开继续、提示、重开、选关、设置、退出；方向键 / 鼠标选择，Enter 确定。设置里可打开格子类别或重看引导，类别默认关闭。教学过关 1.5 秒后自动进入下一课；闯关过关返回当前地图池。旧 D1–D5 调试入口仍按原流程。开发版 F12 回放作者解法。

关卡基础布局为 320×180，默认窗口 1280×720，最小窗口 320×180。按窗口宽高扩展逻辑画布并整数放大，保持像素清晰；关卡居中、菜单居中、背包靠右，鼠标目标跟随实际画面。非整除尺寸只留下少于一个放大逻辑像素的余量边框。SDK 世界仍为 320×192，cell_scale=1，每格16像素，模拟与房间裁剪保持原样。沙袋按图标显示，一个满袋是一格沙；炸药每枚一个图标。

关内引导在做对后消失，并记住已学过的操作。要给新的试玩者重看，先用 Esc → 设置 → 重看引导，再重开 D1。精灵和 UI 素材由 `pushbox/scripts/art/` 的分类模块在内存中生成，`ui/procedural_art.gd` 保留兼容转发；地形由 `world.gdshader` 绘制。`Style.texture(name)` 始终使用原始基线，`Style.themed_texture(name, theme_id)` 按需缓存主题变体。原始尺寸、动作和锚点元数据保留在 `pushbox/assets/sprites/manifest.json`，视觉规范见 `docs/v3/ui-art-direction.md`。字体和许可证随包交付。

验证命令（严格顺序、单 worker；启动前检查其他聊天的计算进程）：

```sh
python3 tools/run_tests.py --performance
# 六图实机渲染验证与截图导出
python3 tools/run_tests.py --only biome_showcase
# 指定 Godot 时加 --godot '/完整可执行路径'
```

2026-10-13 的历史技术基线在 `artifacts/v03/logs/`：14 项脚本通过，T8 结算帧峰值 1.663 ms、预演显示延迟 84.731 ms 达标。M1–M3 各四张 1920×1080 图在 `artifacts/v03/m1/`、`m2/`、`m3/`，同时保留原生视口图。

**2026-10-14 Bug 修复验证：** 14 个常规脚本与 1 个 T8 性能脚本全部通过，专项回归 40 项通过，核心保留 13 项通过。最新 T8 532 帧峰值 3.470 ms（阈值 4 ms），8 次预演显示延迟峰值 86.977 ms（阈值 100 ms）；原生拖动窗口、挖取、倒出和撤销已实际操作。详见 [Bug 修复记录](artifacts/2026-10-14-bugfix/README.md)。使用独立 user 目录、单 worker 顺序执行，不改变用户引导记录。此前仓库整理中 5.372 ms 的失败仍保留在 [仓库验证记录](artifacts/2026-10-14-repository/README.md)。T2 的 4/8 线程配置和 T10 新玩家试玩未执行，修复提交 `12ed0bd` 已同步 GitHub `main`，当前为技术候选，整体用户验收尚未完成。

以下为 v0.3 历史验证：当时规则、地图、预算、作者解法和每步期望 hash 保留，Board 未修改。当前阶段 A 按授权扩展 Board，旧九关通过版本化 legacy 内容包保持作者 hash 与行为。Session 按用户授权拆分调度，原始停止 tick、每步 hash 及完整局面均与冻结旧实现逐步对照，Loader 增加地图 20×11 限制和引导校验。预演复用同一结算代码，主线程按时间预算顺序推进；材料读取、32 格计数批次、离散结算和局面键生成分帧完成，SDK 在这些阶段保持冻结；开局快照与通关写档复用现有单 worker 池，期间模拟 / 操作冻结；退出前等待落盘。

## SDK 源码重建与仓库内容

以下为历史重建工具说明；第二阶段 A 禁止执行 SDK 重建，试玩包无需这些命令。

源码编译 SDK 使用 `tools/prepare_sdk.sh`，始终固定到 `dacb93e` 并用单 worker 构建。SDK 严格检查锁定环境：macOS 15.6.1、Python 3.13.12、Apple clang 17、SDK 26.0 和指定 Godot 4.7.2 二进制；详见 [固定版本的依赖约束](https://github.com/beekim123/ele-base-cpp/blob/dacb93e6dc898ac8d1dfa95f6bc15686a183cf18/DEPENDENCIES.lock.md)。预编译运行无需准备这些编译工具。

在满足锁定环境的机器上可明确指定工具：

```sh
PUSHBOX_PYTHON_BIN='/完整路径/python3.13' \
PUSHBOX_GODOT_BIN='/完整路径/Godot.app/Contents/MacOS/Godot' \
./tools/prepare_sdk.sh
```

第三方声明与许可证保存在 `bin/` 和 `pushbox/assets/fonts/`，原有许可声明保持原样。构建脚本在重建后更新 `bin/build-metadata.json` 的版本与动态库 SHA。本次仓库整理未重编或修改 SDK。

2026-10-14 已清理不再使用的 68 张旧精灵 PNG、Python 素材导出工具及可重建缓存。`manifest.json` 保留原始素材元数据，其中记录的 Python 来源属于历史实现，可在 Git 历史查阅。仓库继续保留运行代码、字体与许可证、关卡、测试、设计文档和验证证据；ZIP、vendor、Godot/Python 缓存、快照及本机构建日志由 `.gitignore` 排除。清理记录见 `artifacts/2026-10-14-cleanup/verification.json`。

`tools/package_demo.py` 保留原 v0.3 候选打包流程，读取 `artifacts/v03/logs/` 的历史摘要。后续生成新交付包时需先接入最新验证结果；不能把历史摘要当作本次检查的依据。本轮 Bug 修复已同步 GitHub `main`，尚未生成新的正式交付包。

快照保存在 Godot user://undo，退出时清理；最多200步。引导记录保存在 user://guides-v03.json。

当前候选、技术审核和真人验收状态见 [项目进度](docs/v2/status.md)，新版证据见 [v0.3 报告](docs/v3/report.md)。v0.2历史报告保留在 docs/v2/report.md，不作为v0.3通过证据。
